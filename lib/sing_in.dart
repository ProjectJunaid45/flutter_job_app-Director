import 'dart:math';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isSignInTab = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Controllers for Sign In & Create Account
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController(text: '28');
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String _selectedSex = 'Male';

  // Inline Validation States
  String? _fullNameError;
  String? _userIdError;
  String? _mobileError;
  String? _passwordError;
  String? _confirmPasswordError;

  // Supabase & Biometric Instances
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _mobileController.dispose();
    _userIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- SECURE BIOMETRIC / FACE ID AUTHENTICATION ---
  Future<void> _authenticateBiometrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool hasLoggedInOnce = prefs.getBool('is_operator_logged_in_once') ?? false;

      if (!hasLoggedInOnce) {
        if (mounted) {
          _showSnack(
            "Biometrics not linked. Please sign in with User ID and Password first.",
            isError: true,
          );
        }
        return;
      }

      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheck && !isDeviceSupported) {
        if (mounted) {
          _showSnack("Biometric or Face recognition hardware is not supported on this device.", isError: true);
        }
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Scan Face or Fingerprint to unlock Nextgen Portal',
      );

      if (didAuthenticate && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack("Authentication Error: $e", isError: true);
      }
    }
  }

  // --- SUBMIT: SIGN IN OR CREATE ACCOUNT ---
  Future<void> _handleSubmit() async {
    final userId = _userIdController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _userIdError = userId.isEmpty ? "User ID / Username is required" : null;
      _passwordError = password.isEmpty ? "Password is required" : null;
      _fullNameError = (!_isSignInTab && _fullNameController.text.trim().isEmpty) ? "Full Name is required" : null;
      _mobileError = (!_isSignInTab && _mobileController.text.trim().length != 10) ? "Enter valid 10-digit number" : null;
      _confirmPasswordError = (!_isSignInTab && password != _confirmPasswordController.text.trim()) ? "Passwords do not match" : null;
    });

    if (_userIdError != null || _passwordError != null || _fullNameError != null || _mobileError != null || _confirmPasswordError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignInTab) {
        final res = await _supabase
            .from('operators')
            .select()
            .eq('username', userId)
            .eq('password', password)
            .maybeSingle();

        if (res != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_operator_logged_in_once', true);
          await prefs.setString('logged_operator_username', userId);

          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          }
        } else {
          setState(() => _isLoading = false);
          _showSnack("Invalid User ID or Password.", isError: true);
        }
      } else {
        await _supabase.from('operators').insert({
          'full_name': _fullNameController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 28,
          'gender': _selectedSex,
          'phone': _mobileController.text.trim(),
          'username': userId,
          'password': password,
        });

        if (mounted) {
          setState(() {
            _isLoading = false;
            _isSignInTab = true;
          });
          _showSnack("Operator registered successfully. Please sign in.");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack("Database Error: $e", isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- FORGOT PASSWORD BOTTOM SHEET ---
  void _openForgotPasswordSheet() {
    final TextEditingController forgotMobileCtrl = TextEditingController();
    final TextEditingController otpCtrl = TextEditingController();
    final TextEditingController newPassCtrl = TextEditingController();
    final TextEditingController confirmPassCtrl = TextEditingController();

    bool isChecking = false;
    bool isUpdating = false;
    bool isOtpGenerated = false;
    bool isOtpVerified = false;
    String generatedOtp = "";
    String? sheetError;
    String fetchedUserId = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF091A26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> sendOtpToPhone() async {
              final phone = forgotMobileCtrl.text.trim();
              if (phone.length != 10) {
                setSheetState(() => sheetError = "Please enter a valid 10-digit registered number.");
                return;
              }

              setSheetState(() {
                sheetError = null;
                isChecking = true;
              });

              try {
                final res = await _supabase
                    .from('operators')
                    .select('username')
                    .eq('phone', phone)
                    .maybeSingle();

                if (res != null && res['username'] != null) {
                  final randomCode = (1000 + Random().nextInt(9000)).toString();

                  setSheetState(() {
                    fetchedUserId = res['username'].toString();
                    generatedOtp = randomCode;
                    isOtpGenerated = true;
                    isChecking = false;
                  });
                } else {
                  setSheetState(() {
                    sheetError = "Mobile number not found in database.";
                    isChecking = false;
                  });
                }
              } catch (e) {
                setSheetState(() {
                  sheetError = "Database Error: $e";
                  isChecking = false;
                });
              }
            }

            void verifyEnteredOtp() {
              final enteredOtp = otpCtrl.text.trim();
              if (enteredOtp.isEmpty) {
                setSheetState(() => sheetError = "Please enter the 4-digit code.");
                return;
              }

              if (enteredOtp == generatedOtp) {
                setSheetState(() {
                  sheetError = null;
                  isOtpVerified = true;
                });
              } else {
                setSheetState(() => sheetError = "Invalid verification code. Please try again.");
              }
            }

            Future<void> saveNewPassword() async {
              final newPass = newPassCtrl.text.trim();
              final confirmPass = confirmPassCtrl.text.trim();
              final phone = forgotMobileCtrl.text.trim();

              if (newPass.length < 4) {
                setSheetState(() => sheetError = "Password must be at least 4 characters.");
                return;
              }

              if (newPass != confirmPass) {
                setSheetState(() => sheetError = "Passwords do not match.");
                return;
              }

              setSheetState(() {
                sheetError = null;
                isUpdating = true;
              });

              try {
                await _supabase
                    .from('operators')
                    .update({'password': newPass})
                    .eq('phone', phone);

                if (mounted) {
                  Navigator.pop(context);
                  _showSnack("Password updated successfully. Please sign in with your new password.");
                }
              } catch (e) {
                setSheetState(() {
                  sheetError = "Password update failed: $e";
                  isUpdating = false;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Password Recovery Portal",
                          style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF193B54)),
                    const SizedBox(height: 10),

                    if (sheetError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Text(sheetError!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                      ),

                    if (!isOtpGenerated) ...[
                      const Text("Registered Mobile Number", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _buildSheetInput(
                        controller: forgotMobileCtrl,
                        hint: "Enter 10-digit mobile",
                        prefixIcon: Icons.phone_android_rounded,
                        keyboard: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE88226)),
                          onPressed: isChecking ? null : sendOtpToPhone,
                          child: isChecking
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Verify Mobile & Generate Code", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else if (!isOtpVerified) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2638),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Operator Security Verification Code:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "OTP: $generatedOtp",
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text("SECURE AUTH", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text("Enter 4-Digit Security OTP", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _buildSheetInput(
                        controller: otpCtrl,
                        hint: "Enter 4-digit code",
                        prefixIcon: Icons.mark_email_read_rounded,
                        keyboard: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                          onPressed: verifyEnteredOtp,
                          child: const Text("Verify Security Code", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2638),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E676).withOpacity(0.6)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Verified Operator ID:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            Text(
                              fetchedUserId,
                              style: const TextStyle(color: Color(0xFF00E676), fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text("New Password", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      _buildSheetInput(controller: newPassCtrl, hint: "Enter new password", prefixIcon: Icons.lock_outline_rounded, isPassword: true),
                      const SizedBox(height: 12),
                      const Text("Confirm Password", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      _buildSheetInput(controller: confirmPassCtrl, hint: "Confirm new password", prefixIcon: Icons.lock_rounded, isPassword: true),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                          onPressed: isUpdating ? null : saveNewPassword,
                          child: isUpdating
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Text("Update & Save Password", style: TextStyle(color: Color(0xFF071B14), fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildSheetInput({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool isPassword = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0E2536),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF67B0D8), size: 17),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07121A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.75),
            radius: 1.3,
            colors: [Color(0xFF193B54), Color(0xFF0D2230), Color(0xFF061017)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),

                  // TOP BADGE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2D3D).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1A4A62)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 3.5,
                          backgroundColor: _isSignInTab ? const Color(0xFF38BDF8) : const Color(0xFF00E676),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSignInTab ? "PORTAL: SECURE ACCESS" : "SYSTEM: NEW OPERATOR",
                          style: TextStyle(
                            color: _isSignInTab ? const Color(0xFF38BDF8) : const Color(0xFF67B0D8),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // --- LOGO IMAGE (SQUARE SHAPE & BLUE BORDER) ---
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: const Color(0xFF0284C7), width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/nextgen_logo_1.jpg',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.settings_suggest_rounded,
                          size: 32,
                          color: Color(0xFF0284C7),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // BRAND HEADER WITH OFFICIAL GEAR "C⚙️NTR⚙️LS"
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "NEXTGEN",
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Text(
                            "C",
                            style: TextStyle(
                              color: Color(0xFFE88226),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 1),
                          Icon(
                            Icons.settings,
                            size: 15,
                            color: Color(0xFFE88226),
                          ),
                          SizedBox(width: 1),
                          Text(
                            "NTR",
                            style: TextStyle(
                              color: Color(0xFFE88226),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 1),
                          Icon(
                            Icons.settings,
                            size: 15,
                            color: Color(0xFFE88226),
                          ),
                          SizedBox(width: 1),
                          Text(
                            "LS",
                            style: TextStyle(
                              color: Color(0xFFE88226),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "PRIVATE LIMITED • SIMPLIFY YOUR INDUSTRY",
                        style: TextStyle(
                          color: Color(0xFF67B0D8),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // SEGMENTED TAB SWITCHER
                  Container(
                    height: 46,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C2030),
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(color: const Color(0xFF193B54)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _isSignInTab = true;
                              _clearErrors();
                            }),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isSignInTab ? const Color(0xFFE88226) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login_rounded, size: 16, color: _isSignInTab ? Colors.white : const Color(0xFF94A3B8)),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Sign In",
                                    style: TextStyle(
                                      color: _isSignInTab ? Colors.white : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _isSignInTab = false;
                              _clearErrors();
                            }),
                            child: Container(
                              decoration: BoxDecoration(
                                color: !_isSignInTab ? const Color(0xFFE88226) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_add_alt_1_rounded, size: 16, color: !_isSignInTab ? Colors.white : const Color(0xFF94A3B8)),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Create Account",
                                    style: TextStyle(
                                      color: !_isSignInTab ? Colors.white : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 1. CREATE ACCOUNT EXTRA FIELDS
                  if (!_isSignInTab) ...[
                    _buildInputField(
                      controller: _fullNameController,
                      hintText: "Enter full name",
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    if (_fullNameError != null) _buildErrorMessage(_fullNameError!),
                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel("Age"),
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C2030),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF193B54)),
                                ),
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(left: 14, right: 6),
                                      child: Text("#", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _ageController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          hintText: "28",
                                          hintStyle: TextStyle(color: Color(0xFF64748B)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel("Sex"),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C2030),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF193B54)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedSex,
                                    dropdownColor: const Color(0xFF0A2030),
                                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF38BDF8)),
                                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                                    items: ['Male', 'Female', 'Other'].map((String val) {
                                      return DropdownMenuItem<String>(value: val, child: Text(val));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedSex = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildInputLabel("Mobile Number *"),
                    _buildInputField(
                      controller: _mobileController,
                      hintText: "10-digit phone number",
                      prefixIcon: Icons.smartphone_rounded,
                      keyboard: TextInputType.phone,
                    ),
                    if (_mobileError != null) _buildErrorMessage(_mobileError!),
                    const SizedBox(height: 14),
                  ],

                  // 2. USER ID / USERNAME FIELD
                  _buildInputLabel(_isSignInTab ? "Operator User ID / System Code" : "Create User ID *"),
                  _buildInputField(
                    controller: _userIdController,
                    hintText: _isSignInTab ? "e.g. admin or OP-2026-01" : "Choose unique username",
                    prefixIcon: Icons.badge_outlined,
                  ),
                  if (_userIdError != null) _buildErrorMessage(_userIdError!),

                  const SizedBox(height: 14),

                  // 3. PASSWORD FIELD
                  _buildInputLabel(_isSignInTab ? "Security Password" : "Password *"),
                  _buildInputField(
                    controller: _passwordController,
                    hintText: _isSignInTab ? "Enter your password" : "Min 4 characters",
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                    isObscured: _obscurePassword,
                    onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  if (_passwordError != null) _buildErrorMessage(_passwordError!),

                  // 4. CONFIRM PASSWORD FIELD (ONLY CREATE TAB)
                  if (!_isSignInTab) ...[
                    const SizedBox(height: 14),
                    _buildInputLabel("Confirm Password *"),
                    _buildInputField(
                      controller: _confirmPasswordController,
                      hintText: "Re-enter password",
                      prefixIcon: Icons.lock_reset_rounded,
                      isPassword: true,
                      isObscured: _obscureConfirmPassword,
                      onTogglePassword: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    if (_confirmPasswordError != null) _buildErrorMessage(_confirmPasswordError!),
                  ],

                  // FORGOT PASSWORD
                  if (_isSignInTab)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _openForgotPasswordSheet,
                        style: TextButton.styleFrom(padding: const EdgeInsets.only(top: 4, bottom: 8)),
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(color: Color(0xFF67B0D8), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                  const SizedBox(height: 18),

                  // 5. SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE88226),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_isSignInTab ? 10 : 24),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              _isSignInTab ? "Authenticate & Sign In" : "Register New Operator",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),

                  // 6. BIOMETRIC / FACE ID SECTION (ONLY SIGN IN TAB)
                  if (_isSignInTab) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Expanded(child: Divider(color: Color(0xFF193B54))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "OR QUICK BIOMETRIC",
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFF193B54))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _authenticateBiometrics,
                      icon: const Icon(
                        Icons.fingerprint_rounded,
                        color: Color(0xFF38BDF8),
                        size: 22,
                      ),
                      label: const Text(
                        "Scan Face ID / Fingerprint",
                        style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 46),
                        side: const BorderSide(color: Color(0xFF193B54), width: 1.2),
                        backgroundColor: const Color(0xFF0D2130),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearErrors() {
    _fullNameError = null;
    _userIdError = null;
    _mobileError = null;
    _passwordError = null;
    _confirmPasswordError = null;
  }

  // --- HELPERS ---
  static Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6.0),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onTogglePassword,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0C2030),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF193B54)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? isObscured : false,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF67B0D8), size: 18),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 18),
                  onPressed: onTogglePassword,
                )
              : null,
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  static Widget _buildErrorMessage(String msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(msg, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}