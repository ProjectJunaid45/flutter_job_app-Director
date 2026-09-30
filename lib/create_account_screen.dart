import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sing_in.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController(text: '28');
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedSex = 'Male';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> _handleRegister() async {
    final fullName = _fullNameController.text.trim();
    final ageText = _ageController.text.trim();
    final phone = _phoneController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (fullName.isEmpty || phone.isEmpty || username.isEmpty || password.isEmpty) {
      _showMsg("Saari zaroori fields (*) bharna compulsory hai!", isError: true);
      return;
    }

    if (password.length < 4) {
      _showMsg("Password kam se kam 4 characters ka hona chahiye!", isError: true);
      return;
    }

    if (password != confirmPassword) {
      _showMsg("Passwords match nahi ho rahe!", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Username ko internal auth email format dete hain: username@nextgen.local
      final authEmail = '$username@nextgen.local';

      final AuthResponse res = await _supabase.auth.signUp(
        email: authEmail,
        password: password,
      );

      final user = res.user;

      if (user != null) {
        // Profiles table me exact fields save karna
        await _supabase.from('profiles').insert({
          'id': user.id,
          'full_name': fullName,
          'age': int.tryParse(ageText) ?? 28,
          'gender': _selectedSex,
          'phone': phone,
          'username': username,
          'role': 'OPERATOR',
        });

        if (mounted) {
          setState(() => _isLoading = false);
          _showMsg("Operator Registered Successfully!");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SignInScreen()),
          );
        }
      } else {
        throw "Registration process incomplete!";
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMsg("Failed: $e", isError: true);
      }
    }
  }

  void _showMsg(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071824),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP BAR WITH BACK & SYSTEM CHIP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2D3D).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1A4A62)),
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF00E676)),
                        SizedBox(width: 8),
                        Text(
                          "SYSTEM: NEW OPERATOR",
                          style: TextStyle(
                            color: Color(0xFF67B0D8),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                ],
              ),

              const SizedBox(height: 18),

              // 2. BRAND TITLE & SLOGAN
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "NEXTGEN",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE88226),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "CONTROLS",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Industrial Telemetry & Automation Hub",
                      style: TextStyle(
                        color: Color(0xFF67B0D8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. SEGMENTED TAB SWITCHER
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2232),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1B3D55)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SignInScreen()),
                          );
                        },
                        child: Container(
                          alignment: Alignment.center,
                          color: Colors.transparent,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.login_rounded, size: 16, color: Color(0xFF88A4B8)),
                              SizedBox(width: 6),
                              Text(
                                "Sign In",
                                style: TextStyle(
                                  color: Color(0xFF88A4B8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE88226),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              "Create Account",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 4. ENTER FULL NAME
              _buildInputContainer(
                controller: _fullNameController,
                hint: "Enter full name",
                prefixIcon: Icons.person_outline_rounded,
              ),

              const SizedBox(height: 14),

              // 5. AGE & SEX ROW
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AGE FIELD
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Age",
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        _buildInputContainer(
                          controller: _ageController,
                          hint: "28",
                          prefixText: "#  ",
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // SEX DROPDOWN FIELD
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Sex",
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A2030),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1E435E)),
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

              // 6. MOBILE NUMBER *
              _buildLabeledField(
                label: "Mobile Number *",
                controller: _phoneController,
                hint: "10-digit phone number",
                prefixIcon: Icons.smartphone_rounded,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 14),

              // 7. CREATE USER ID *
              _buildLabeledField(
                label: "Create User ID *",
                controller: _usernameController,
                hint: "Choose unique username",
                prefixIcon: Icons.badge_outlined,
              ),

              const SizedBox(height: 14),

              // 8. PASSWORD *
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Password *",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2030),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E435E)),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF38BDF8), size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF678196),
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        hintText: "Min 4 characters",
                        hintStyle: const TextStyle(color: Color(0xFF4C6A80), fontSize: 12.5),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 9. CONFIRM PASSWORD *
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Confirm Password *",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2030),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E435E)),
                    ),
                    child: TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF38BDF8), size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF678196),
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        hintText: "Re-enter password",
                        hintStyle: const TextStyle(color: Color(0xFF4C6A80), fontSize: 12.5),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 10. REGISTER NEW OPERATOR BUTTON
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE88226),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          "Register New Operator",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // --- REUSABLE LABELED FIELD ---
  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _buildInputContainer(
          controller: controller,
          hint: hint,
          prefixIcon: prefixIcon,
          keyboardType: keyboardType,
        ),
      ],
    );
  }

  // --- REUSABLE CONTAINER FIELD ---
  Widget _buildInputContainer({
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    String? prefixText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0A2030),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E435E)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: const Color(0xFF38BDF8), size: 18)
              : (prefixText != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 14, top: 14),
                      child: Text(prefixText, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                    )
                  : null),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF4C6A80), fontSize: 12.5),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
    );
  }
}