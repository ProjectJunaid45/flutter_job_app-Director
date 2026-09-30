import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sing_in.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase background me start hoga taaki pehli baar me app freeze/cut na ho
  Supabase.initialize(
    url: 'https://xfmbzzwlfglltidudjsn.supabase.co',
    anonKey: 'sb_publishable_zgdxED00ZLe7MyojA6XJig_ksFfkWUr',
  ).catchError((e) {
    debugPrint("Supabase background init note: $e");
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WelcomeScreen(),
    );
  }
}

// ==========================================
// WELCOME SCREEN (INSTANT LAUNCH - NO TIMEOUT)
// ==========================================
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
            colors: [
              Color(0xFF193B54),
              Color(0xFF0D2230),
              Color(0xFF061017),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. BRAND LOGO
                Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF67B0D8), width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF67B0D8).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/nextgen_logo.jpeg',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.settings_suggest_rounded,
                            size: 28,
                            color: Color(0xFFE88226),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                // 2. BRAND TITLE & OFFICIAL GEAR "C⚙️NTR⚙️LS"
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "NEXTGEN",
                      style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        Text(
                          "C",
                          style: TextStyle(
                            color: Color(0xFFE88226),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 1),
                        Icon(
                          Icons.settings,
                          size: 14,
                          color: Color(0xFFE88226),
                        ),
                        SizedBox(width: 1),
                        Text(
                          "NTR",
                          style: TextStyle(
                            color: Color(0xFFE88226),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 1),
                        Icon(
                          Icons.settings,
                          size: 14,
                          color: Color(0xFFE88226),
                        ),
                        SizedBox(width: 1),
                        Text(
                          "LS",
                          style: TextStyle(
                            color: Color(0xFFE88226),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "PRIVATE LIMITED • SIMPLIFY YOUR INDUSTRY",
                      style: TextStyle(
                        color: Color(0xFF67B0D8),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 3. 3x2 BALANCED GRID
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 9,
                    childAspectRatio: 1.40,
                    children: [
                      _buildLargeMatrixCard(
                        icon: Icons.electrical_services_rounded,
                        tag: "PANEL",
                        title: "Control Panels",
                        desc: "PLC Panels, VFD, APFC, MCC & PCC manufacturing.",
                        color: const Color(0xFFE88226),
                      ),
                      _buildLargeMatrixCard(
                        icon: Icons.speed_rounded,
                        tag: "DRIVES",
                        title: "AC & DC Drives",
                        desc: "VFD drives setup, motor tuning & syncing.",
                        color: const Color(0xFFF59E0B),
                      ),
                      _buildLargeMatrixCard(
                        icon: Icons.phone_android_rounded,
                        tag: "MOBILE",
                        title: "Mobile Telemetry",
                        desc: "Live PLC telemetry, alerts & mobile control.",
                        color: const Color(0xFF38BDF8),
                      ),
                      _buildLargeMatrixCard(
                        icon: Icons.laptop_chromebook_rounded,
                        tag: "SOFTWARE",
                        title: "Industrial Software",
                        desc: "Dashboard, Alarms, Logging & reports.",
                        color: const Color(0xFFA855F7),
                      ),
                      _buildLargeMatrixCard(
                        icon: Icons.memory_rounded,
                        tag: "AUTOMATION",
                        title: "PLC Retrofitting",
                        desc: "Machine logic modernizing & programming.",
                        color: const Color(0xFF00E676),
                      ),
                      _buildLargeMatrixCard(
                        icon: Icons.build_circle_outlined,
                        tag: "SERVICE",
                        title: "AMC Maintenance",
                        desc: "Breakdown repair & monthly contracts.",
                        color: const Color(0xFFF43F5E),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 4. GOV BADGES
                Row(
                  children: [
                    Expanded(
                      child: _buildGovBadge(
                        label: "GSTIN",
                        val: "27BUZPS8168M1Z4",
                        icon: Icons.verified_user_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildGovBadge(
                        label: "UDYAM",
                        val: "MH-33-0454689",
                        icon: Icons.domain_verification_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                // 5. CONTACT CONTAINER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1C2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1A3B54)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.mail_outline_rounded, size: 12.5, color: Color(0xFFE88226)),
                          SizedBox(width: 6),
                          Text(
                            "nextgencontrols@gmail.com",
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Divider(color: Color(0xFF16324A), height: 1),
                      const SizedBox(height: 5),

                      Row(
                        children: [
                          Expanded(child: _buildPhoneChip("+91 9892485539")),
                          const SizedBox(width: 6),
                          Expanded(child: _buildPhoneChip("+91 9921379012")),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(child: _buildPhoneChip("+91 9987369614")),
                          const SizedBox(width: 6),
                          Expanded(child: _buildPhoneChip("+91 9767013933")),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 6. CONTINUE BUTTON
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF7941D), Color(0xFFE88226)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE88226).withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignInScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Continue to Sign In",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildLargeMatrixCard({
    required IconData icon,
    required String tag,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2638).withOpacity(0.85),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF132D42),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2.5),
              Text(
                desc,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 9.2,
                  height: 1.22,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildGovBadge({
    required String label,
    required String val,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2538),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF20486A)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13.5, color: const Color(0xFF00E676)),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Color(0xFF67B0D8), fontSize: 7, fontWeight: FontWeight.bold),
                ),
                Text(
                  val,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPhoneChip(String number) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF10283C),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF1E4260)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.call_rounded, size: 10.5, color: Color(0xFF67B0D8)),
          const SizedBox(width: 4),
          Text(
            number,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}