import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'custom_drawer.dart';

final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(true);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  String _selectedTab = 'ALL';
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _jobCards = [];
  List<String> _availableWorkers = ['MALIK10'];
  List<Map<String, dynamic>> _workersFullList = [];
  bool _isLoading = true;
  String _currentOperator = 'JUNAID';

  @override
  void initState() {
    super.initState();
    _loadCurrentOperator();
    _fetchWorkers();
    _fetchJobCards();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentOperator() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('logged_operator_username');
      if (savedUser != null && savedUser.trim().isNotEmpty && mounted) {
        setState(() {
          _currentOperator = savedUser.trim().toUpperCase();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchWorkers() async {
    try {
      final res = await _supabase.from('workers').select().order('username');
      if (mounted) {
        final list = List<Map<String, dynamic>>.from(res)
            .map((w) => (w['username'] ?? '').toString().trim().toUpperCase())
            .where((w) => w.isNotEmpty)
            .toSet()
            .toList();
        setState(() {
          _workersFullList = List<Map<String, dynamic>>.from(res);
          if (list.isNotEmpty) {
            _availableWorkers = list;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchJobCards() async {
    try {
      final data = await _supabase
          .from('job_cards')
          .select()
          .order('id', ascending: false);

      if (mounted) {
        setState(() {
          _jobCards = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Data fetch error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : 'Jan';
  }

  static String _formatDate(DateTime dt) {
    return "${dt.day} ${_monthName(dt.month)} ${dt.year}";
  }

  static String _extractQuoteNo(String specs) {
    final reg = RegExp(r'\[QUOTE:\s*(.*?)\]');
    final match = reg.firstMatch(specs);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim() ?? '';
    }
    return '';
  }

  static String _extractCleanScope(String specs) {
    return specs
        .replaceAll(RegExp(r'\[QUOTE:.*?\]'), '')
        .replaceAll(RegExp(r'\[PO:.*?\]'), '')
        .replaceAll(RegExp(r'\[BY:.*?\]'), '')
        .replaceAll(RegExp(r'\[WORKER:.*?\]'), '')
        .replaceAll(RegExp(r'\[PREV_WORKER:.*?\]'), '')
        .replaceAll(RegExp(r'\[TRANSFER:.*?\]'), '')
        .replaceAll(RegExp(r'\[SCORE:.*?\]'), '')
        .trim();
  }

  static String _extractScoreBadge(String specs) {
    final reg = RegExp(r'\[SCORE:\s*(\d+)');
    final match = reg.firstMatch(specs);
    if (match != null && match.groupCount >= 1) {
      return "${match.group(1)}/100";
    }
    return '';
  }

  List<String> _getUniqueSuggestions(String fieldKey, {bool isSpec = false}) {
    final Set<String> results = {};
    for (var job in _jobCards) {
      if (isSpec) {
        String raw = (job[fieldKey] ?? '').toString();
        raw = _extractCleanScope(raw);
        if (raw.isNotEmpty) results.add(raw);
      } else {
        String val = (job[fieldKey] ?? '').toString();
        if (fieldKey == 'panel_type') {
          val = val.replaceAll('[PANEL]', '').replaceAll(RegExp(r'\[ITEM:.*?\]'), '').trim();
        }
        if (val.trim().isNotEmpty) {
          results.add(val.trim());
        }
      }
    }
    return results.toList();
  }

  // =========================================================================
  // 🔄 RE-ASSIGNMENT MODAL
  // =========================================================================
  Future<void> _handleWorkerReassignment(Map<String, dynamic> job, String newWorker) async {
    final oldWorker = (job['assigned_to'] ?? '').toString().trim().toUpperCase();
    if (oldWorker == newWorker) return;

    final reasonCtrl = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C2232),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: const [
              Icon(Icons.swap_horiz_rounded, color: Color(0xFFE88226), size: 22),
              SizedBox(width: 8),
              Text("Reassign Panel Builder", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Transferring ${job['job_no']} from $oldWorker to $newWorker.",
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                "Enter Transfer Reason (Mandatory Audit): *",
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF091A26),
                  hintText: "e.g. Worker on leave, Urgent delivery schedule",
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF193B54))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "* Note: $oldWorker's mobile app will display a crossed-out card with this reason.",
                style: const TextStyle(color: Color(0xFFE88226), fontSize: 9.5, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Reassignment reason is required!"), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text("Confirm Transfer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final reasonText = reasonCtrl.text.trim();
      String curSpecs = (job['specs_detail'] ?? '').toString();

      curSpecs = curSpecs.replaceAll(RegExp(r'\[TRANSFER:.*?\]'), '');
      curSpecs = curSpecs.replaceAll(RegExp(r'\[WORKER:.*?\]'), '');

      final transferTag = "[TRANSFER:FROM:$oldWorker|TO:$newWorker|REASON:$reasonText|BY:$_currentOperator]";
      final prevWorkerTag = "[PREV_WORKER:$oldWorker]";
      final newWorkerTag = "[WORKER:$newWorker]";

      curSpecs = "$curSpecs $transferTag $prevWorkerTag $newWorkerTag".trim();

      await _updateJobStatus(job['id'], {
        'assigned_to': newWorker,
        'specs_detail': curSpecs,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Panel transferred to $newWorker. Reason recorded for $oldWorker."),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _deleteJob(dynamic jobId, BuildContext? sheetContext) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0C2232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text(
              "Delete Job Record?",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to permanently delete this job card? This action cannot be undone.",
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('job_cards').delete().eq('id', jobId);
        await _fetchJobCards();
        if (sheetContext != null && sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Job record permanently deleted!"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Delete failed: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _openEditQuoteModal(Map<String, dynamic> job, bool isDark, [BuildContext? sheetCtx]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => NewQuoteFormScreen(
          isDark: isDark,
          isEditMode: true,
          initialJob: job,
          availableWorkers: _availableWorkers,
          currentOperator: _currentOperator,
          clientSuggestions: _getUniqueSuggestions('client'),
          panelSuggestions: _getUniqueSuggestions('panel_type'),
          specsSuggestions: _getUniqueSuggestions('specs_detail', isSpec: true),
          onSaved: (payload) async {
            try {
              await _supabase.from('job_cards').update(payload).eq('id', job['id']);
            } catch (_) {
              payload.remove('created_by');
              await _supabase.from('job_cards').update(payload).eq('id', job['id']);
            }
            await _fetchJobCards();
            if (ctx.mounted) Navigator.pop(ctx);
            if (sheetCtx != null && sheetCtx.mounted) Navigator.pop(sheetCtx);
          },
        ),
      ),
    );
  }

  void _openNewQuoteModal(bool isDark) {
    final now = DateTime.now();
    final defaultJobNo = "JOB-${now.year}-${100 + _jobCards.length + 1}";
    final defaultQuoteNo = "QT-${now.year}-${100 + _jobCards.length + 1}";

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => NewQuoteFormScreen(
          isDark: isDark,
          isEditMode: false,
          defaultJobNo: defaultJobNo,
          defaultQuoteNo: defaultQuoteNo,
          availableWorkers: _availableWorkers,
          currentOperator: _currentOperator,
          clientSuggestions: _getUniqueSuggestions('client'),
          panelSuggestions: _getUniqueSuggestions('panel_type'),
          specsSuggestions: _getUniqueSuggestions('specs_detail', isSpec: true),
          onSaved: (payload) async {
            try {
              await _supabase.from('job_cards').insert(payload);
            } catch (e) {
              payload.remove('created_by');
              await _supabase.from('job_cards').insert(payload);
            }
            await _fetchJobCards();
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  // =========================================================================
  // ⚙️ 100-MARK AUDIT SHEET WITH SLIDE-TO-CONFIRM RIGHT SWIPE
  // =========================================================================
  void _openDirector100MarkInspectionSheet({
    required String targetWorker,
    String? jobNo,
    int? jobId,
    int? auditMonth,
    int? auditYear,
    VoidCallback? onAuditSaved,
  }) {
    final now = DateTime.now();
    final int month = auditMonth ?? now.month;
    final int year = auditYear ?? now.year;

    // Direct 0 se shuru hoga
    int wiring = 0;
    int dressing = 0;
    int attendance = 0;
    int ferrule = 0;
    int plcSignal = 0;
    int mounting = 0;
    int safety = 0;

    final feedbackCtrl = TextEditingController(text: "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF091722),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int totalScore = wiring + dressing + attendance + ferrule + plcSignal + mounting + safety;
            final double starRating = (totalScore / 20.0).clamp(0.0, 5.0);

            String qualityTag;
            Color badgeColor;
            if (totalScore >= 90) {
              qualityTag = "MASTER BUILDER";
              badgeColor = const Color(0xFF10B981);
            } else if (totalScore >= 80) {
              qualityTag = "FACTORY STANDARD";
              badgeColor = const Color(0xFF38BDF8);
            } else if (totalScore >= 60) {
              qualityTag = "AVERAGE FACTORY OUTPUT";
              badgeColor = const Color(0xFFE88226);
            } else if (totalScore > 0) {
              qualityTag = "IN PROGRESS";
              badgeColor = const Color(0xFFE88226);
            } else {
              qualityTag = "NOT EVALUATED (0/100)";
              badgeColor = const Color(0xFF64748B);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFF244866), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jobNo != null ? "$jobNo Inspection" : "Worker Quality Audit",
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Builder: $targetWorker • Period: ${_monthName(month)} $year",
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: badgeColor),
                          ),
                          child: Text(
                            "$totalScore / 100",
                            style: TextStyle(color: badgeColor, fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          "Rating: ${starRating.toStringAsFixed(1)} ★  •  ",
                          style: const TextStyle(color: Color(0xFFE88226), fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          qualityTag,
                          style: TextStyle(color: badgeColor, fontSize: 11.5, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF193B54), height: 18),

                    _buildSliderItem("1. Wiring & Crimping Quality (Max 20)", wiring, 20, (v) => setModalState(() => wiring = v)),
                    _buildSliderItem("2. Wiring Dressing & Aesthetics (Max 20)", dressing, 20, (v) => setModalState(() => dressing = v)),
                    _buildSliderItem("3. Attendance & Floor Punctuality (Max 20)", attendance, 20, (v) => setModalState(() => attendance = v)),
                    _buildSliderItem("4. Ferrule & Tagging Match (Max 10)", ferrule, 10, (v) => setModalState(() => ferrule = v)),
                    _buildSliderItem("5. PLC & Signal Noise Isolation (Max 10)", plcSignal, 10, (v) => setModalState(() => plcSignal = v)),
                    _buildSliderItem("6. Component Mounting Alignment (Max 10)", mounting, 10, (v) => setModalState(() => mounting = v)),
                    _buildSliderItem("7. Safety & QC Factory Check (Max 10)", safety, 10, (v) => setModalState(() => safety = v)),

                    const SizedBox(height: 10),
                    const Text("Director Quality Review Remark:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: feedbackCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0C2030),
                        hintText: "Enter inspection remarks (optional)...",
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF193B54))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 👉 SLIDE TO PUBLISH SCORE (RIGHT SWIPE BUTTON)
                    SlideToConfirmButton(
                      label: "Slide to Publish Score ($totalScore/100) ➔",
                      onConfirmed: () async {
                        final scoreTagString = "[SCORE: $totalScore|W:$wiring|D:$dressing|A:$attendance|F:$ferrule|P:$plcSignal|M:$mounting|S:$safety|PERIOD:$month-$year]";
                        final commentText = feedbackCtrl.text.trim().isNotEmpty
                            ? feedbackCtrl.text.trim()
                            : "Audit updated ($totalScore/100) for ${_monthName(month)} $year.";

                        final updatePayload = {
                          'username': targetWorker,
                          'rating': starRating,
                          'rating_tag': qualityTag,
                          'rating_comment': commentText,
                          'score_100': totalScore,
                          'qc_breakdown': scoreTagString,
                        };

                        // 1. Database Workers table update
                        try {
                          final exist = await _supabase.from('workers').select().eq('username', targetWorker).maybeSingle();
                          if (exist != null) {
                            await _supabase.from('workers').update(updatePayload).eq('username', targetWorker);
                          } else {
                            await _supabase.from('workers').insert(updatePayload);
                          }
                        } catch (_) {
                          try {
                            await _supabase.from('workers').upsert(updatePayload);
                          } catch (_) {}
                        }

                        // 2. Job Card update if linked
                        if (jobId != null) {
                          try {
                            final existing = _jobCards.firstWhere((j) => j['id'] == jobId);
                            String curSpecs = (existing['specs_detail'] ?? '').toString();
                            curSpecs = curSpecs.replaceAll(RegExp(r'\[SCORE:.*?\]'), '').trim();
                            curSpecs = "$curSpecs $scoreTagString";

                            await _supabase.from('job_cards').update({
                              'status': 'COMPLETED',
                              'stage': 'QC Passed (Score: $totalScore/100 • $qualityTag)',
                              'progress': 0.90,
                              'specs_detail': curSpecs,
                            }).eq('id', jobId);
                          } catch (_) {}
                        }

                        // 3. Local refresh & parent refresh
                        await _fetchWorkers();
                        await _fetchJobCards();
                        if (onAuditSaved != null) onAuditSaved();

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("✓ Published $totalScore/100 for $targetWorker (${_monthName(month)} $year)"),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSliderItem(String title, int val, int max, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            Text("$val / $max", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            activeTrackColor: const Color(0xFF0284C7),
            inactiveTrackColor: const Color(0xFF193B54),
            thumbColor: const Color(0xFF38BDF8),
          ),
          child: Slider(
            value: val.toDouble(),
            min: 0,
            max: max.toDouble(),
            divisions: max,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 🏅 MONTHLY & YEARLY WORKER QUALITY LEADERBOARD (ACCURATE LIVE SCORES)
  // =========================================================================
  void _openWorkerScoresLeaderboard() {
    final now = DateTime.now();
    int selYear = now.year;
    int selMonth = now.month;
    bool isYearlyMode = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C2232),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLeaderboardState) {
            final activeWorkers = _workersFullList.isNotEmpty
                ? _workersFullList
                : _availableWorkers.map((w) => {'username': w, 'full_name': w, 'score_100': 0, 'rating': 0.0, 'rating_tag': 'NOT EVALUATED'}).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Worker Quality Scorecard (100 Marks)", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                      Icon(Icons.workspace_premium_rounded, color: Color(0xFFE88226), size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Mode Switcher (Monthly vs Yearly)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF071824),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF193B54)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setLeaderboardState(() => isYearlyMode = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: !isYearlyMode ? const Color(0xFF0284C7) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Monthly Audits",
                                    style: TextStyle(
                                      color: !isYearlyMode ? Colors.white : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setLeaderboardState(() => isYearlyMode = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isYearlyMode ? const Color(0xFF0284C7) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Yearly Overview",
                                    style: TextStyle(
                                      color: isYearlyMode ? Colors.white : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Date Navigator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: Color(0xFF38BDF8)),
                              onPressed: () {
                                setLeaderboardState(() {
                                  if (isYearlyMode) {
                                    selYear--;
                                  } else {
                                    if (selMonth == 1) {
                                      selMonth = 12;
                                      selYear--;
                                    } else {
                                      selMonth--;
                                    }
                                  }
                                });
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C2232),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(isYearlyMode ? Icons.calendar_today_rounded : Icons.calendar_month_rounded, size: 14, color: const Color(0xFFE88226)),
                                  const SizedBox(width: 6),
                                  Text(
                                    isYearlyMode ? "Full Year $selYear" : "${_monthName(selMonth)} $selYear",
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Color(0xFF38BDF8)),
                              onPressed: () {
                                setLeaderboardState(() {
                                  if (isYearlyMode) {
                                    selYear++;
                                  } else {
                                    if (selMonth == 12) {
                                      selMonth = 1;
                                      selYear++;
                                    } else {
                                      selMonth++;
                                    }
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF193B54), height: 1),
                  const SizedBox(height: 8),

                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: activeWorkers.length,
                      itemBuilder: (context, idx) {
                        final w = activeWorkers[idx];
                        final uName = (w['username'] ?? '').toString();
                        final fName = (w['full_name'] ?? uName).toString();

                        // Job cards se period matching
                        final List<int> periodScores = [];
                        final targetYearStr = selYear.toString();
                        final targetMonthStr = _monthName(selMonth).toLowerCase();

                        for (var job in _jobCards) {
                          final assigned = (job['assigned_to'] ?? '').toString().trim().toUpperCase();
                          final specs = (job['specs_detail'] ?? '').toString();
                          final bool isWorkerMatch = (assigned == uName.toUpperCase()) || specs.toUpperCase().contains('[WORKER: ${uName.toUpperCase()}]');

                          if (!isWorkerMatch) continue;

                          final dateStr = (job['target_date'] ?? job['start_date'] ?? '').toString().toLowerCase();
                          bool matchesPeriod = dateStr.contains(targetYearStr);
                          if (!isYearlyMode) {
                            if (!dateStr.contains(targetMonthStr) && !specs.contains('PERIOD:$selMonth-$selYear')) {
                              matchesPeriod = false;
                            }
                          }

                          if (matchesPeriod) {
                            final scoreBadge = _extractScoreBadge(specs);
                            if (scoreBadge.isNotEmpty) {
                              final numVal = int.tryParse(scoreBadge.replaceAll('/100', '').trim());
                              if (numVal != null) periodScores.add(numVal);
                            }
                          }
                        }

                        // 🔥 DIRECT DATABASE PROFILE SCORE CHECK (FIX FOR 0/100 ISSUE)
                        final dbScore = (w['score_100'] as num?)?.toInt() ?? 0;
                        final rawBreakdown = (w['qc_breakdown'] ?? '').toString();
                        final bool hasPeriodInBreakdown = isYearlyMode
                            ? rawBreakdown.contains("-$selYear")
                            : rawBreakdown.contains("PERIOD:$selMonth-$selYear");

                        int displayScore = 0;
                        String auditCountText = "";

                        if (periodScores.isNotEmpty) {
                          displayScore = (periodScores.reduce((a, b) => a + b) / periodScores.length).round();
                          auditCountText = "${periodScores.length} Panel${periodScores.length > 1 ? 's' : ''} Audited in ${isYearlyMode ? '$selYear' : '${_monthName(selMonth)} $selYear'}";
                        } else if (hasPeriodInBreakdown || dbScore > 0) {
                          displayScore = dbScore;
                          auditCountText = "Active Score: $displayScore/100 (${isYearlyMode ? '$selYear' : _monthName(selMonth)})";
                        } else {
                          displayScore = 0;
                          auditCountText = "No audits recorded yet (0/100)";
                        }

                        final double calculatedRating = displayScore > 0 ? (displayScore / 20.0).clamp(1.0, 5.0) : 0.0;
                        String calculatedTag;
                        Color statusBadgeColor;
                        if (displayScore >= 90) {
                          calculatedTag = "MASTER BUILDER";
                          statusBadgeColor = const Color(0xFF10B981);
                        } else if (displayScore >= 80) {
                          calculatedTag = "FACTORY STANDARD";
                          statusBadgeColor = const Color(0xFF38BDF8);
                        } else if (displayScore >= 60) {
                          calculatedTag = "AVERAGE FACTORY OUTPUT";
                          statusBadgeColor = const Color(0xFFE88226);
                        } else if (displayScore > 0) {
                          calculatedTag = (w['rating_tag'] ?? "IN PROGRESS").toString();
                          statusBadgeColor = const Color(0xFF10B981);
                        } else {
                          calculatedTag = "NOT EVALUATED (0)";
                          statusBadgeColor = const Color(0xFF64748B);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F2638),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1E3E5A)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_rounded, color: Color(0xFF38BDF8), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("$fName ($uName)", style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(
                                      "$calculatedTag • ${calculatedRating.toStringAsFixed(1)} ★",
                                      style: TextStyle(color: statusBadgeColor, fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      auditCountText,
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: statusBadgeColor.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: statusBadgeColor),
                                    ),
                                    child: Text(
                                      "$displayScore / 100",
                                      style: TextStyle(color: statusBadgeColor, fontSize: 12, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () {
                                      _openDirector100MarkInspectionSheet(
                                        targetWorker: uName,
                                        auditMonth: selMonth,
                                        auditYear: selYear,
                                        onAuditSaved: () async {
                                          await _fetchWorkers();
                                          setLeaderboardState(() {});
                                        },
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "Audit (${_monthName(selMonth)}) ➔",
                                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openMonthlyGraphModal(String categoryLabel, Color themeColor, bool isDark) {
    final now = DateTime.now();
    int selectedMonthIndex = now.month - 1;
    int selectedYear = now.year;

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final upperCat = categoryLabel.toUpperCase().trim();

    List<Map<String, dynamic>> categoryJobs = _jobCards.where((j) {
      final st = (j['status'] ?? '').toString().toUpperCase();
      final po = (j['po_number'] ?? '').toString().trim();
      final specs = (j['specs_detail'] ?? '').toString();

      if (upperCat == 'ALL') {
        return true;
      } else if (upperCat == "PO REC'D" || upperCat == "PO" || upperCat == "PO_RECEIVED") {
        return po.isNotEmpty || specs.contains("PO:");
      } else if (upperCat == 'QUOTE' || upperCat == 'QUOTATION') {
        return true;
      } else if (upperCat == 'RUNNING') {
        return st == 'RUNNING' || st == 'TESTING' || st == 'COMPLETED' || st == 'BILLING' || st == 'DISPATCHED';
      } else if (upperCat == 'TESTING') {
        return st == 'TESTING' || st == 'COMPLETED' || st == 'BILLING' || st == 'DISPATCHED';
      } else if (upperCat == 'READY' || upperCat == 'COMPLETED') {
        return st == 'COMPLETED' || st == 'BILLING' || st == 'DISPATCHED';
      } else if (upperCat == 'BILLING') {
        return st == 'BILLING' || st == 'DISPATCHED';
      } else if (upperCat == 'DISPATCH' || upperCat == 'DISPATCHED') {
        return st == 'DISPATCHED';
      } else if (upperCat == 'PENDING') {
        return st == 'PENDING';
      } else if (upperCat == 'CANCEL' || upperCat == 'CANCELLED') {
        return st == 'CANCELLED';
      }
      return st == upperCat;
    }).toList();

    final Color sheetBg = isDark ? const Color(0xFF091A26) : Colors.white;
    final Color primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final Color containerBg = isDark ? const Color(0xFF0C2232) : const Color(0xFFF8FAFC);
    final Color borderClr = isDark ? const Color(0xFF1E3E5A) : const Color(0xFFCBD5E1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final String filterYearStr = selectedYear.toString();

            List<int> monthlyCounts = List.filled(12, 0);
            for (var job in categoryJobs) {
              final sDate = (job['start_date'] ?? job['target_date'] ?? '').toString();
              if (sDate.contains(filterYearStr)) {
                for (int m = 0; m < 12; m++) {
                  if (sDate.toLowerCase().contains(months[m].toLowerCase())) {
                    monthlyCounts[m]++;
                    break;
                  }
                }
              }
            }

            int maxCount = monthlyCounts.fold(0, (max, count) => count > max ? count : max);
            if (maxCount == 0) maxCount = 1;

            final selMonthName = months[selectedMonthIndex];
            final selJobs = categoryJobs.where((j) {
              final sDate = (j['start_date'] ?? j['target_date'] ?? '').toString();
              return sDate.contains(filterYearStr) && sDate.toLowerCase().contains(selMonthName.toLowerCase());
            }).toList();

            double selMonthValuation = 0.0;
            for (var j in selJobs) {
              final valStr = (j['invoice_amount'] ?? j['quotation_amount'] ?? '0').toString().replaceAll(',', '');
              selMonthValuation += double.tryParse(valStr) ?? 0.0;
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.80,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(
                            "$categoryLabel Pipeline",
                            style: TextStyle(color: primaryText, fontSize: 14, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: containerBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderClr),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => setSheetState(() => selectedYear--),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(Icons.arrow_left_rounded, size: 18, color: themeColor),
                              ),
                            ),
                            Text(
                              "$selectedYear",
                              style: TextStyle(color: primaryText, fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                            InkWell(
                              onTap: () => setSheetState(() => selectedYear++),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(Icons.arrow_right_rounded, size: 18, color: themeColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.close_rounded, color: secondaryText, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Divider(color: borderClr),
                  const SizedBox(height: 8),
                  Container(
                    height: 175,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    decoration: BoxDecoration(
                      color: containerBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderClr),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(12, (index) {
                        final count = monthlyCounts[index];
                        final bool isSelected = (index == selectedMonthIndex);
                        final double barHeightRatio = (count / maxCount).clamp(0.12, 1.0);

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setSheetState(() => selectedMonthIndex = index),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                decoration: isSelected
                                    ? BoxDecoration(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(4),
                                      )
                                    : null,
                                child: Text(
                                  "$count",
                                  style: TextStyle(
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                        : (count > 0 ? themeColor : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 17,
                                height: 95 * barHeightRatio,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : themeColor.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(5),
                                  border: isSelected
                                      ? Border.all(color: isDark ? Colors.white : const Color(0xFF0F172A), width: 1.5)
                                      : null,
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: (isDark ? Colors.white : themeColor).withOpacity(0.4),
                                            blurRadius: 5,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                months[index],
                                style: TextStyle(
                                  color: isSelected ? (isDark ? const Color(0xFF38BDF8) : themeColor) : secondaryText,
                                  fontSize: 9,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F2638) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: themeColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$selMonthName $selectedYear: ${selJobs.length} Processed",
                          style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          "Value: ₹${(selMonthValuation / 100000).toStringAsFixed(2)} Lakhs",
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Pipeline Orders in $selMonthName $selectedYear:", style: TextStyle(color: secondaryText, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: selJobs.isEmpty
                        ? Center(
                            child: Text("No pipeline orders for $selMonthName $selectedYear", style: TextStyle(color: secondaryText, fontSize: 11.5, fontWeight: FontWeight.w600)),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: selJobs.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 6),
                            itemBuilder: (subCtx, idx) {
                              final item = selJobs[idx];
                              final amount = item['invoice_amount'] ?? item['quotation_amount'] ?? '0';
                              final String itemStatus = (item['status'] ?? '').toString();
                              final String itemPanel = (item['panel_type'] ?? '').toString();

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0C2232) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderClr),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(item['job_no'] ?? '', style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(color: themeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                                                child: Text(itemStatus, style: TextStyle(color: themeColor, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                              ),
                                              const Spacer(),
                                              Text("₹$amount", style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.w900)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item['client'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: primaryText, fontSize: 12, fontWeight: FontWeight.w700),
                                          ),
                                          Text(
                                            itemPanel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: secondaryText, fontSize: 9.5),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text("Start: ${item['start_date'] ?? '-'}", style: TextStyle(color: secondaryText, fontSize: 8.5)),
                                              Row(
                                                children: [
                                                  InkWell(
                                                    onTap: () => _openEditQuoteModal(item, isDark, ctx),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: const Color(0xFF0284C7).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                                      child: const Row(
                                                        children: [
                                                          Icon(Icons.edit, size: 10, color: Color(0xFF0284C7)),
                                                          SizedBox(width: 2),
                                                          Text("Edit", style: TextStyle(color: Color(0xFF0284C7), fontSize: 9, fontWeight: FontWeight.bold)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  InkWell(
                                                    onTap: () => _deleteJob(item['id'], ctx),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                                      child: const Row(
                                                        children: [
                                                          Icon(Icons.delete_outline, size: 10, color: Colors.red),
                                                          SizedBox(width: 2),
                                                          Text("Delete", style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // WORKFLOW ACTION MODAL
  // =========================================================================
  void _openStatusActionModal(Map<String, dynamic> job, bool isDark) {
    final status = (job['status'] ?? '').toString().toUpperCase();
    final reasonCtrl = TextEditingController(text: job['pending_reason'] ?? '');
    final poNumberCtrl = TextEditingController();

    final rawQuotationPrice = (job['quotation_amount'] ?? '').toString().replaceAll(',', '').trim();
    final rawInvoicePrice = (job['invoice_amount'] ?? '').toString().replaceAll(',', '').trim();
    final poAmtCtrl = TextEditingController(
      text: rawInvoicePrice.isNotEmpty ? rawInvoicePrice : rawQuotationPrice,
    );

    final invoiceNoCtrl = TextEditingController(text: job['invoice_no'] ?? 'INV-');
    final invoiceAmtCtrl = TextEditingController(
      text: rawInvoicePrice.isNotEmpty ? rawInvoicePrice : rawQuotationPrice,
    );
    final vehicleCtrl = TextEditingController(text: job['dispatch_vehicle'] ?? '');

    String currentAssigned = (job['assigned_to'] ?? '').toString().trim().toUpperCase();
    if (currentAssigned.isEmpty && _availableWorkers.isNotEmpty) {
      currentAssigned = _availableWorkers.first;
    }
    String selectedWorker = currentAssigned.isNotEmpty ? currentAssigned : 'MALIK10';

    final Color dialogBg = isDark ? const Color(0xFF0C2232) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final Color fieldBg = isDark ? const Color(0xFF091A26) : const Color(0xFFF1F5F9);
    final Color dividerColor = isDark ? const Color(0xFF193B54) : const Color(0xFFE2E8F0);

    bool hvTestOk = true;
    bool plcLogicOk = true;
    bool dressingOk = true;
    bool drawingOk = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.hub_rounded, color: Color(0xFF0284C7), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("${job['job_no']} Workflow & Builder", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F2638) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF1E3E5A) : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Current Status:", style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w600)),
                          Text(status, style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w900, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Assigned Builder:", style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text(selectedWorker, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.5)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _availableWorkers.contains(selectedWorker) ? selectedWorker : null,
                          hint: Text("Reassign Builder", style: TextStyle(color: subTextColor, fontSize: 11)),
                          dropdownColor: dialogBg,
                          isExpanded: true,
                          icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFE88226), size: 20),
                          items: _availableWorkers.map((w) {
                            return DropdownMenuItem<String>(
                              value: w,
                              child: Text("Builder: $w", style: TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                          onChanged: (val) async {
                            if (val != null && val != selectedWorker) {
                              Navigator.pop(ctx);
                              await _handleWorkerReassignment(job, val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: dividerColor),
                    const SizedBox(height: 6),

                    if (status == 'QUOTATION') ...[
                      Text("Client Purchase Order (PO):", style: TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: poNumberCtrl,
                        style: TextStyle(color: textColor, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "Enter PO Number (e.g. PO/2026/894)",
                          hintStyle: TextStyle(color: subTextColor, fontSize: 11),
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: poAmtCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: "Final PO Amount (₹) (Auto-filled)",
                          labelStyle: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                          icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                          label: const Text("Verify PO & Move to RUNNING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                          onPressed: () async {
                            if (poNumberCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("PO Number is required!"), backgroundColor: Colors.red),
                              );
                              return;
                            }

                            final Map<String, dynamic> upFields = {
                              'status': 'RUNNING',
                              'stage': 'Fabrication & Layout Stage',
                              'po_number': poNumberCtrl.text.trim(),
                              'assigned_to': selectedWorker,
                              'progress': 0.25,
                            };
                            if (poAmtCtrl.text.trim().isNotEmpty) {
                              upFields['invoice_amount'] = poAmtCtrl.text.trim();
                            }

                            String curSpecs = (job['specs_detail'] ?? '').toString();
                            curSpecs = curSpecs.replaceAll(RegExp(r'\[WORKER:.*?\]'), '').trim();
                            curSpecs = "$curSpecs [WORKER: $selectedWorker]";
                            upFields['specs_detail'] = curSpecs;

                            await _updateJobStatus(job['id'], upFields);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 15),
                          label: const Text("Cancel Quotation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          onPressed: () async {
                            await _updateJobStatus(job['id'], {
                              'status': 'CANCELLED',
                              'stage': 'Quotation Rejected / Cancelled',
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],

                    if (status == 'RUNNING') ...[
                      Text("Update Stage Progress:", style: TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildStageChip(job['id'], "Fabrication", 0.25, ctx, isDark),
                          _buildStageChip(job['id'], "Busbar & Mounting", 0.45, ctx, isDark),
                          _buildStageChip(job['id'], "Control Wiring", 0.65, ctx, isDark),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                          icon: const Icon(Icons.electric_meter_rounded, color: Colors.white, size: 17),
                          label: const Text("Move to Quality Testing", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                          onPressed: () async {
                            await _updateJobStatus(job['id'], {
                              'status': 'TESTING',
                              'stage': 'HV & PLC Logic Testing',
                              'progress': 0.80,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(color: dividerColor),
                      TextField(
                        controller: reasonCtrl,
                        style: TextStyle(color: textColor, fontSize: 11.5),
                        decoration: InputDecoration(
                          hintText: "Reason for hold or cancellation",
                          hintStyle: TextStyle(color: subTextColor, fontSize: 10.5),
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 34,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB45309)),
                                icon: const Icon(Icons.pause_circle_outline_rounded, color: Colors.white, size: 15),
                                label: const Text("Hold (Pending)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5)),
                                onPressed: () async {
                                  final r = reasonCtrl.text.trim();
                                  await _updateJobStatus(job['id'], {
                                    'status': 'PENDING',
                                    'stage': r.isNotEmpty ? 'On Hold: $r' : 'On Hold (Pending)',
                                    'pending_reason': r,
                                  });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 34,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                icon: const Icon(Icons.cancel_outlined, color: Colors.white, size: 15),
                                label: const Text("Cancel Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5)),
                                onPressed: () async {
                                  final r = reasonCtrl.text.trim();
                                  await _updateJobStatus(job['id'], {
                                    'status': 'CANCELLED',
                                    'stage': r.isNotEmpty ? 'Cancelled: $r' : 'Order Cancelled',
                                    'pending_reason': r,
                                  });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (status == 'PENDING') ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                job['pending_reason'] != null && job['pending_reason'].toString().isNotEmpty
                                    ? "Reason: ${job['pending_reason']}"
                                    : "Job is currently on hold. Resume work or cancel this order.",
                                style: const TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text("Pending Decision Action:", style: TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                          icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 17),
                          label: const Text("Resume Work ➔ Move to RUNNING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                          onPressed: () async {
                            await _updateJobStatus(job['id'], {
                              'status': 'RUNNING',
                              'stage': 'Work Resumed (Active Production)',
                              'pending_reason': null,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                          icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 17),
                          label: const Text("Cancel Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                          onPressed: () async {
                            await _updateJobStatus(job['id'], {
                              'status': 'CANCELLED',
                              'stage': 'Order Cancelled from Pending',
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],

                    if (status == 'TESTING') ...[
                      const Text("Factory QC Inspection & Score:", style: TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 18),
                          label: const Text("Evaluate 100-Mark Panel Score", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openDirector100MarkInspectionSheet(
                              targetWorker: selectedWorker,
                              jobNo: job['job_no'],
                              jobId: job['id'],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Divider(color: dividerColor),

                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF10B981),
                        title: Text("Electrical Wiring Drawing & Schematic OK", style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w700)),
                        subtitle: Text("Busbar size, wire tags, terminal numbers matched", style: TextStyle(color: subTextColor, fontSize: 9.5)),
                        value: drawingOk,
                        onChanged: (v) => setDialogState(() => drawingOk = v ?? false),
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF10B981),
                        title: Text("High Voltage & Insulation OK", style: TextStyle(color: textColor, fontSize: 11)),
                        value: hvTestOk,
                        onChanged: (v) => setDialogState(() => hvTestOk = v ?? false),
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF10B981),
                        title: Text("PLC Logic & I/O Telemetry OK", style: TextStyle(color: textColor, fontSize: 11)),
                        value: plcLogicOk,
                        onChanged: (v) => setDialogState(() => plcLogicOk = v ?? false),
                      ),
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF10B981),
                        title: Text("Ferrule Numbering & Dressing OK", style: TextStyle(color: textColor, fontSize: 11)),
                        value: dressingOk,
                        onChanged: (v) => setDialogState(() => dressingOk = v ?? false),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 17),
                          label: const Text("QC Passed ➔ Mark COMPLETED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                          onPressed: (drawingOk && hvTestOk && plcLogicOk && dressingOk)
                              ? () async {
                                  await _updateJobStatus(job['id'], {
                                    'status': 'COMPLETED',
                                    'stage': 'Drawing & QC Passed, Ready for Billing',
                                    'progress': 0.90,
                                  });
                                  if (ctx.mounted) Navigator.pop(ctx);
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          icon: const Icon(Icons.cancel_outlined, size: 15),
                          label: const Text("Cancel Order from Testing", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            await _updateJobStatus(job['id'], {
                              'status': 'CANCELLED',
                              'stage': 'Cancelled during testing',
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],

                    if (status == 'COMPLETED' || status == 'BILLING') ...[
                      TextField(
                        controller: invoiceNoCtrl,
                        style: TextStyle(color: textColor, fontSize: 11.5),
                        decoration: InputDecoration(
                          labelText: "GST Invoice Number",
                          labelStyle: TextStyle(color: subTextColor, fontSize: 10.5),
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: invoiceAmtCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor, fontSize: 11.5),
                        decoration: InputDecoration(
                          labelText: "Final Invoice Amount (₹)",
                          labelStyle: TextStyle(color: subTextColor, fontSize: 10.5),
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: vehicleCtrl,
                        style: TextStyle(color: textColor, fontSize: 11.5),
                        decoration: InputDecoration(
                          labelText: "Vehicle No / Gate Pass",
                          labelStyle: TextStyle(color: subTextColor, fontSize: 10.5),
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                          icon: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 17),
                          label: const Text("Generate Invoice & DISPATCH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                          onPressed: () async {
                            if (invoiceNoCtrl.text.trim().isEmpty) return;
                            await _updateJobStatus(job['id'], {
                              'status': 'DISPATCHED',
                              'stage': 'Dispatched via ${vehicleCtrl.text.trim()}',
                              'progress': 1.0,
                              'invoice_no': invoiceNoCtrl.text.trim(),
                              'invoice_amount': invoiceAmtCtrl.text.trim(),
                              'dispatch_vehicle': vehicleCtrl.text.trim(),
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],

                    if (status == 'CANCELLED') ...[
                      const Text("Order Status: CANCELLED", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text("This order has been cancelled. To resume, reopen the order below:", style: TextStyle(color: subTextColor, fontSize: 11)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                          icon: const Icon(Icons.restore_rounded, color: Colors.white, size: 16),
                          label: const Text("Reopen Order ➔ Move to RUNNING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                          onPressed: () async {
                            await _updateJobStatus(job['id'], {
                              'status': 'RUNNING',
                              'stage': 'Order Reopened for production',
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Close", style: TextStyle(color: subTextColor, fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStageChip(dynamic jobId, String stageName, double prog, BuildContext ctx, bool isDark) {
    return ActionChip(
      label: Text(stageName, style: TextStyle(fontSize: 10, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600)),
      backgroundColor: isDark ? const Color(0xFF0F2638) : const Color(0xFFF1F5F9),
      side: BorderSide(color: isDark ? const Color(0xFF1E3E5A) : const Color(0xFFCBD5E1)),
      onPressed: () async {
        await _updateJobStatus(jobId, {'stage': stageName, 'progress': prog});
        if (ctx.mounted) Navigator.pop(ctx);
      },
    );
  }

  Future<void> _updateJobStatus(dynamic jobId, Map<String, dynamic> updateFields) async {
    try {
      await _supabase.from('job_cards').update(updateFields).eq('id', jobId);
      _fetchJobCards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pipeline status updated!"), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotationCount = _jobCards.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'QUOTATION').length;
    final pendingCount = _jobCards.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'PENDING').length;
    final runningCount = _jobCards.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'RUNNING').length;
    final testingCount = _jobCards.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'TESTING').length;
    final completedCount = _jobCards.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'COMPLETED').length;
    final billingCount = _jobCards.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'BILLING').length;
    final dispatchedCount = _jobCards.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'DISPATCHED').length;
    final cancelledCount = _jobCards.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'CANCELLED').length;

    final poCount = _jobCards.where((j) {
      final po = j['po_number'];
      final specs = (j['specs_detail'] ?? '').toString();
      return (po != null && po.toString().trim().isNotEmpty) || specs.contains("PO:");
    }).length;

    final filteredJobs = _jobCards.where((j) {
      final st = (j['status'] ?? '').toString().toUpperCase();
      final String? poNoVal = j['po_number'];
      final String specs = (j['specs_detail'] ?? '').toString();
      final bool hasPoValid = (poNoVal != null && poNoVal.toString().trim().isNotEmpty) || specs.contains("PO:");

      bool matchesTab = false;
      if (_selectedTab == 'ALL') {
        matchesTab = true;
      } else if (_selectedTab == 'PO_RECEIVED') {
        matchesTab = hasPoValid;
      } else {
        matchesTab = (st == _selectedTab);
      }

      final client = (j['client'] ?? '').toString().toLowerCase();
      final jobNo = (j['job_no'] ?? '').toString().toLowerCase();
      final panelType = (j['panel_type'] ?? '').toString().toLowerCase();
      final poNoStr = (poNoVal ?? '').toString().toLowerCase();
      final quoteNoStr = _extractQuoteNo(specs).toLowerCase();
      final scopeStr = _extractCleanScope(specs).toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          client.contains(_searchQuery) ||
          jobNo.contains(_searchQuery) ||
          panelType.contains(_searchQuery) ||
          poNoStr.contains(_searchQuery) ||
          quoteNoStr.contains(_searchQuery) ||
          scopeStr.contains(_searchQuery);

      return matchesTab && matchesSearch;
    }).toList();

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final Color screenBg = isDark ? const Color(0xFF07121A) : const Color(0xFFF1F5F9);
        final Color appBarBg = isDark ? const Color(0xFF0C2232) : Colors.white;

        return Scaffold(
          backgroundColor: screenBg,
          drawer: const CustomDrawer(activeRoute: 'dashboard'),
          appBar: AppBar(
            backgroundColor: appBarBg,
            elevation: isDark ? 0 : 1,
            iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF0F172A)),
            titleSpacing: 0,
            title: _isSearchOpen
                ? Container(
                    height: 38,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F2638) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.5)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF0284C7)),
                        suffixIcon: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _searchCtrl.clear();
                              _searchQuery = '';
                              _isSearchOpen = false;
                            });
                          },
                        ),
                        hintText: "Search Job #, PO #, Scope of Work...",
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/images/nextgen_logo_1.jpg',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.precision_manufacturing_rounded, color: Color(0xFF1E5BB0), size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "NEXTGEN ",
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1E3A5F),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: "CONTROLS",
                                      style: TextStyle(
                                        color: Color(0xFFE88226),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                              ),
                            ),
                            Text(
                              "PRIVATE LIMITED • Simplify Your Industry",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontSize: 7.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
            actions: _isSearchOpen
                ? null
                : [
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFE88226), size: 21),
                      tooltip: "Worker Quality Leaderboard (Monthly/Yearly)",
                      onPressed: _openWorkerScoresLeaderboard,
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      icon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7), size: 21),
                      tooltip: "Search",
                      onPressed: () => setState(() => _isSearchOpen = true),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: const Color(0xFFE88226), size: 21),
                      tooltip: isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
                      onPressed: () => isDarkModeNotifier.value = !isDark,
                    ),
                    const SizedBox(width: 4),
                  ],
          ),
          body: RefreshIndicator(
            color: const Color(0xFF8B5CF6),
            backgroundColor: isDark ? const Color(0xFF0C2232) : Colors.white,
            onRefresh: _fetchJobCards,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _buildInteractiveTile("QUOTE", "$quotationCount", const Color(0xFF8B5CF6), isDark),
                                const SizedBox(width: 5),
                                _buildInteractiveTile("PO REC'D", "$poCount", const Color(0xFF10B981), isDark),
                                const SizedBox(width: 5),
                                _buildInteractiveTile("RUNNING", "$runningCount", const Color(0xFF0284C7), isDark),
                                const SizedBox(width: 5),
                                _buildInteractiveTile("PENDING", "$pendingCount", const Color(0xFFD97706), isDark),
                                const SizedBox(width: 5),
                                _buildInteractiveTile("TESTING", "$testingCount", const Color(0xFFEA580C), isDark),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                _buildInteractiveTile("READY", "$completedCount", const Color(0xFF0284C7), isDark),
                                const SizedBox(width: 5),
                                _buildInteractiveTile("BILLING", "$billingCount", const Color(0xFFE88226), isDark),
                                const SizedBox(width: 5),
                                _buildInteractiveTile("DISPATCH", "$dispatchedCount", const Color(0xFF10B981), isDark),
                                const SizedBox(width: 5),
                                _buildInteractiveTile("CANCEL", "$cancelledCount", const Color(0xFFEF4444), isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildFilterChip("ALL", "All (${_jobCards.length})", isDark),
                              const SizedBox(width: 6),
                              _buildFilterChip("PO_RECEIVED", "PO Received ($poCount)", isDark),
                              const SizedBox(width: 6),
                              _buildFilterChip("QUOTATION", "Quote ($quotationCount)", isDark),
                              const SizedBox(width: 6),
                              _buildFilterChip("RUNNING", "Running ($runningCount)", isDark),
                              const SizedBox(width: 6),
                              _buildFilterChip("PENDING", "Pending ($pendingCount)", isDark),
                              const SizedBox(width: 6),
                              _buildFilterChip("TESTING", "Testing ($testingCount)", isDark),
                              const SizedBox(width: 6),
                              _buildFilterChip("COMPLETED", "QC Ready ($completedCount)", isDark),
                              const SizedBox(width: 6),
                              _buildFilterChip("DISPATCHED", "Delivered ($dispatchedCount)", isDark),
                              const SizedBox(width: 6),
                              _buildFilterChip("CANCELLED", "Cancelled ($cancelledCount)", isDark),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: filteredJobs.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 90),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.35,
                                    child: Center(
                                      child: Text(
                                        _searchQuery.isNotEmpty ? "No order found for '$_searchQuery'" : "No orders in $_selectedTab status",
                                        style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                                itemCount: filteredJobs.length,
                                itemBuilder: (context, index) {
                                  final job = filteredJobs[index];
                                  return _buildCrispIndustrialCard(job, isDark);
                                },
                              ),
                      ),
                    ],
                  ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF8B5CF6),
            onPressed: () => _openNewQuoteModal(isDark),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              "New Quote",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInteractiveTile(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _openMonthlyGraphModal(label, color, isDark),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C2232) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(isDark ? 0.35 : 0.2)),
          ),
          child: Column(
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  fontSize: 7.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final bool isSelected = _selectedTab == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE88226) : (isDark ? const Color(0xFF0F2638) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFFE88226) : (isDark ? const Color(0xFF1E3E5A) : const Color(0xFFCBD5E1))),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155)),
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCrispIndustrialCard(Map<String, dynamic> job, bool isDark) {
    final statusStr = (job['status'] ?? '').toString().toUpperCase();
    final String? poNumber = job['po_number'];
    final String specsStr = (job['specs_detail'] ?? '').toString();
    final String quoteNo = _extractQuoteNo(specsStr);
    final String jobNo = (job['job_no'] ?? '').toString().trim();
    final String scopeOfWork = _extractCleanScope(specsStr);
    final String scoreBadge = _extractScoreBadge(specsStr);

    final transferMatch = RegExp(r'\[TRANSFER:FROM:(.*?)\|TO:(.*?)\|REASON:(.*?)\|').firstMatch(specsStr);
    final bool hasTransferHistory = transferMatch != null;

    final byReg = RegExp(r'\[BY:\s*(.*?)\]');
    final byMatch = byReg.firstMatch(specsStr);
    String createdBy = (job['created_by'] ?? '').toString().trim();
    if (createdBy.isEmpty && byMatch != null && byMatch.groupCount >= 1) {
      createdBy = byMatch.group(1)?.trim().toUpperCase() ?? '';
    }
    if (createdBy.isEmpty) {
      createdBy = 'JUNAID';
    }

    String assignedBuilder = (job['assigned_to'] ?? '').toString().trim().toUpperCase();
    if (assignedBuilder.isEmpty) {
      final wReg = RegExp(r'\[WORKER:\s*(.*?)\]');
      final wMatch = wReg.firstMatch(specsStr);
      if (wMatch != null && wMatch.groupCount >= 1) {
        assignedBuilder = wMatch.group(1)?.trim().toUpperCase() ?? '';
      }
    }

    Color statusColor;
    switch (statusStr) {
      case 'QUOTATION':
        statusColor = const Color(0xFF8B5CF6);
        break;
      case 'RUNNING':
        statusColor = const Color(0xFF0284C7);
        break;
      case 'TESTING':
        statusColor = const Color(0xFFEA580C);
        break;
      case 'COMPLETED':
        statusColor = const Color(0xFF10B981);
        break;
      case 'PENDING':
        statusColor = const Color(0xFFD97706);
        break;
      case 'CANCELLED':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFF10B981);
    }

    final double progress = (job['progress'] as num?)?.toDouble() ?? 0.05;
    final int progressPercent = (progress * 100).toInt();

    final Color cardBg = isDark ? const Color(0xFF0B1F2F) : Colors.white;
    final Color borderC = isDark ? const Color(0xFF193B54) : const Color(0xFFE2E8F0);
    final Color titleC = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subC = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final rawDesc = (job['panel_type'] ?? '').toString().replaceAll('[PANEL]', '').replaceAll(RegExp(r'\[ITEM:.*?\]'), '').trim();

    final quoteStr = (job['quotation_amount'] ?? '').toString().replaceAll(',', '').trim();
    final poStr = (job['invoice_amount'] ?? '').toString().replaceAll(',', '').trim();
    final double? quoteVal = double.tryParse(quoteStr);
    final double? poVal = double.tryParse(poStr);

    final String startDateStr = (job['start_date'] ?? '-').toString().trim();
    final String targetDateStr = (job['target_date'] ?? '-').toString().trim();

    return GestureDetector(
      onTap: () => _openStatusActionModal(job, isDark),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderC, width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (jobNo.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.6), width: 1.1),
                          ),
                          child: Text(
                            jobNo.startsWith("JOB") ? jobNo : "JOB: $jobNo",
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      if (quoteNo.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.6), width: 1.1),
                          ),
                          child: Text(
                            quoteNo.startsWith("QT") ? quoteNo : "QT: $quoteNo",
                            style: const TextStyle(
                              color: Color(0xFFA78BFA),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      if ((poNumber != null && poNumber.isNotEmpty) || specsStr.contains("PO:"))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6), width: 1.1),
                          ),
                          child: Text(
                            poNumber != null && poNumber.isNotEmpty ? "PO: $poNumber" : "PO REC'D",
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      if (scoreBadge.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Text(
                            "QC: $scoreBadge",
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.7)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 5, height: 5, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(statusStr, style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 3),
                      Icon(Icons.edit_note_rounded, size: 12, color: statusColor),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job['client'] ?? '',
                    style: TextStyle(color: titleC, fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                ),
                if (poVal != null && poVal > 0)
                  Text("PO: ₹${poVal.toStringAsFixed(0)}", style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w900))
                else if (quoteVal != null && quoteVal > 0)
                  Text("Quoted: ₹${quoteVal.toStringAsFixed(0)}", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 3),

            if (rawDesc.isNotEmpty)
              Text(
                rawDesc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 11.5, fontWeight: FontWeight.w600),
              ),

            if (scopeOfWork.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                scopeOfWork,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            if (hasTransferHistory) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE88226).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFFE88226).withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, color: Color(0xFFE88226), size: 13),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        "Reassigned: ${transferMatch.group(1)} ➔ ${transferMatch.group(2)} (${transferMatch.group(3)})",
                        style: const TextStyle(color: Color(0xFFE88226), fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(job['stage'] ?? statusStr, style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.w600)),
                Text("$progressPercent%", style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3.5,
                backgroundColor: isDark ? const Color(0xFF132A3E) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),

            const SizedBox(height: 8),
            Divider(color: borderC, height: 1),
            const SizedBox(height: 6),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(startDateStr, style: TextStyle(color: subC, fontSize: 9.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        "Target: $targetDateStr",
                        style: const TextStyle(color: Color(0xFFE88226), fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _openEditQuoteModal(job, isDark),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFF0284C7).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                            child: const Row(
                              children: [
                                Icon(Icons.edit, size: 11, color: Color(0xFF0284C7)),
                                SizedBox(width: 3),
                                Text("Edit", style: TextStyle(color: Color(0xFF0284C7), fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _deleteJob(job['id'], null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                            child: const Row(
                              children: [
                                Icon(Icons.delete_outline, size: 11, color: Colors.red),
                                SizedBox(width: 3),
                                Text("Delete", style: TextStyle(color: Colors.red, fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline_rounded, size: 11, color: subC),
                        const SizedBox(width: 3),
                        Text(
                          "Created by: $createdBy",
                          style: TextStyle(
                            color: subC,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.engineering_outlined,
                          size: 11,
                          color: assignedBuilder.isNotEmpty ? const Color(0xFF38BDF8) : subC,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          assignedBuilder.isNotEmpty ? "Built by: $assignedBuilder" : "Built by: Not Assigned",
                          style: TextStyle(
                            color: assignedBuilder.isNotEmpty ? const Color(0xFF38BDF8) : subC,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 👉 SLIDE TO CONFIRM (RIGHT SWIPE) INTERACTIVE WIDGET
// ===========================================================================
class SlideToConfirmButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onConfirmed;

  const SlideToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
  });

  @override
  State<SlideToConfirmButton> createState() => _SlideToConfirmButtonState();
}

class _SlideToConfirmButtonState extends State<SlideToConfirmButton> {
  double _dragValue = 0.0;
  bool _isFinished = false;

  @override
  Widget build(BuildContext context) {
    const double buttonHeight = 48.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxDrag = maxWidth - buttonHeight;

        return Container(
          width: maxWidth,
          height: buttonHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF061824),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 1.2),
          ),
          child: Stack(
            children: [
              Container(
                width: _dragValue + buttonHeight,
                height: buttonHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              Center(
                child: Text(
                  _isFinished ? "Publishing Score..." : widget.label,
                  style: TextStyle(
                    color: _isFinished ? const Color(0xFF10B981) : Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Positioned(
                left: _dragValue,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isFinished) return;
                    setState(() {
                      _dragValue = (_dragValue + details.delta.dx).clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (details) async {
                    if (_isFinished) return;
                    if (_dragValue >= maxDrag * 0.80) {
                      setState(() {
                        _dragValue = maxDrag;
                        _isFinished = true;
                      });
                      await widget.onConfirmed();
                    } else {
                      setState(() {
                        _dragValue = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: buttonHeight,
                    height: buttonHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isFinished
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                            )
                          : const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NewQuoteFormScreen extends StatefulWidget {
  final bool isDark;
  final bool isEditMode;
  final Map<String, dynamic>? initialJob;
  final String? defaultJobNo;
  final String? defaultQuoteNo;
  final List<String> availableWorkers;
  final String currentOperator;
  final List<String> clientSuggestions;
  final List<String> panelSuggestions;
  final List<String> specsSuggestions;
  final Future<void> Function(Map<String, dynamic>) onSaved;

  const NewQuoteFormScreen({
    super.key,
    required this.isDark,
    required this.isEditMode,
    this.initialJob,
    this.defaultJobNo,
    this.defaultQuoteNo,
    required this.availableWorkers,
    required this.currentOperator,
    required this.clientSuggestions,
    required this.panelSuggestions,
    required this.specsSuggestions,
    required this.onSaved,
  });

  @override
  State<NewQuoteFormScreen> createState() => _NewQuoteFormScreenState();
}

class _NewQuoteFormScreenState extends State<NewQuoteFormScreen> {
  late DateTime startDateTime;
  late DateTime targetDateTime;

  late final TextEditingController jobNoCtrl;
  late final TextEditingController quoteNumberCtrl;
  late final TextEditingController clientCtrl;
  late final TextEditingController panelSpecCtrl;
  late final TextEditingController specsCtrl;
  late final TextEditingController quotePriceCtrl;
  late final TextEditingController targetDateCtrl;

  String? selectedBuilder;
  bool isSaving = false;
  String? localError;
  String existingAuthor = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDateTime = now;
    targetDateTime = now.add(const Duration(days: 14));

    if (widget.isEditMode && widget.initialJob != null) {
      final job = widget.initialJob!;
      final rawSpecs = (job['specs_detail'] ?? '').toString();
      final qReg = RegExp(r'\[QUOTE:\s*(.*?)\]');
      final qMatch = qReg.firstMatch(rawSpecs);
      final currentQuoteNo = (qMatch != null && qMatch.groupCount >= 1) ? (qMatch.group(1)?.trim() ?? '') : '';

      final byReg = RegExp(r'\[BY:\s*(.*?)\]');
      final byMatch = byReg.firstMatch(rawSpecs);
      existingAuthor = (job['created_by'] ?? '').toString().trim();
      if (existingAuthor.isEmpty && byMatch != null && byMatch.groupCount >= 1) {
        existingAuthor = byMatch.group(1)?.trim().toUpperCase() ?? '';
      }
      if (existingAuthor.isEmpty) {
        existingAuthor = widget.currentOperator;
      }

      String initWorker = (job['assigned_to'] ?? '').toString().trim().toUpperCase();
      if (initWorker.isNotEmpty && widget.availableWorkers.contains(initWorker)) {
        selectedBuilder = initWorker;
      }

      final cleanSpecs = rawSpecs
          .replaceAll(RegExp(r'\[QUOTE:.*?\]'), '')
          .replaceAll(RegExp(r'\[PO:.*?\]'), '')
          .replaceAll(RegExp(r'\[BY:.*?\]'), '')
          .replaceAll(RegExp(r'\[WORKER:.*?\]'), '')
          .replaceAll(RegExp(r'\[PREV_WORKER:.*?\]'), '')
          .replaceAll(RegExp(r'\[TRANSFER:.*?\]'), '')
          .replaceAll(RegExp(r'\[SCORE:.*?\]'), '')
          .trim();

      jobNoCtrl = TextEditingController(text: job['job_no'] ?? '');
      quoteNumberCtrl = TextEditingController(text: currentQuoteNo);
      clientCtrl = TextEditingController(text: job['client'] ?? '');
      panelSpecCtrl = TextEditingController(text: (job['panel_type'] ?? '').toString().replaceAll('[PANEL]', '').trim());
      specsCtrl = TextEditingController(text: cleanSpecs);
      quotePriceCtrl = TextEditingController(text: (job['quotation_amount'] ?? '').toString());
      targetDateCtrl = TextEditingController(text: job['target_date'] ?? _formatDate(targetDateTime));
    } else {
      existingAuthor = widget.currentOperator;
      jobNoCtrl = TextEditingController(text: widget.defaultJobNo ?? '');
      quoteNumberCtrl = TextEditingController(text: widget.defaultQuoteNo ?? '');
      clientCtrl = TextEditingController();
      panelSpecCtrl = TextEditingController();
      specsCtrl = TextEditingController();
      quotePriceCtrl = TextEditingController();
      targetDateCtrl = TextEditingController(text: _formatDate(targetDateTime));
    }
  }

  @override
  void dispose() {
    jobNoCtrl.dispose();
    quoteNumberCtrl.dispose();
    clientCtrl.dispose();
    panelSpecCtrl.dispose();
    specsCtrl.dispose();
    quotePriceCtrl.dispose();
    targetDateCtrl.dispose();
    super.dispose();
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : 'Jan';
  }

  static String _formatDate(DateTime dt) {
    return "${dt.day} ${_monthName(dt.month)} ${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final Color screenBg = widget.isDark ? const Color(0xFF07121A) : const Color(0xFFF1F5F9);
    final Color cardBg = widget.isDark ? const Color(0xFF0C2232) : Colors.white;
    final Color textColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: screenBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEditMode ? "Edit Quotation Details" : "New Quotation",
              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Row(
              children: [
                Text("Created By: ", style: TextStyle(color: subTextColor, fontSize: 10)),
                Text(existingAuthor, style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (localError != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(localError!, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),

              Row(
                children: [
                  Expanded(
                    child: _buildInput(label: "Job Number *", hint: "e.g. JOB-2026-101", ctrl: jobNoCtrl),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInput(label: "Quotation Ref (QT) *", hint: "e.g. QT-2026-101", ctrl: quoteNumberCtrl),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _buildLiveSearchField(
                label: "Client / Company Name *",
                hint: "e.g. Basant Rubber, Jindal Steel",
                ctrl: clientCtrl,
                suggestions: widget.clientSuggestions,
              ),
              const SizedBox(height: 10),

              _buildLiveSearchField(
                label: "Panel / Machine Specification *",
                hint: "e.g. 50 HP VFD Control Panel",
                ctrl: panelSpecCtrl,
                suggestions: widget.panelSuggestions,
              ),
              const SizedBox(height: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Assign Floor Builder / Technician (Optional)", style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF0F2638) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.isDark ? const Color(0xFF193B54) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedBuilder,
                        hint: Text("Assign Builder (Optional)", style: TextStyle(color: subTextColor, fontSize: 11)),
                        dropdownColor: cardBg,
                        isExpanded: true,
                        items: widget.availableWorkers.map((w) {
                          return DropdownMenuItem<String>(
                            value: w,
                            child: Text("Panel Builder: $w", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedBuilder = val),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _buildLiveSearchField(
                label: "Scope of Work / Instructions",
                hint: "e.g. Wiring, Programming, Busbar sizing",
                ctrl: specsCtrl,
                suggestions: widget.specsSuggestions,
              ),
              const SizedBox(height: 10),

              _buildInput(
                label: "Quoted Price (₹) *",
                hint: "e.g. 25000",
                ctrl: quotePriceCtrl,
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  if (!widget.isEditMode) ...[
                    Expanded(
                      child: _buildDatePicker(
                        label: "Start Date",
                        currentDate: startDateTime,
                        onSelect: (dt) => setState(() => startDateTime = dt),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _buildDatePicker(
                      label: "Target Delivery Date *",
                      currentDate: targetDateTime,
                      onSelect: (dt) {
                        setState(() {
                          targetDateTime = dt;
                          targetDateCtrl.text = _formatDate(dt);
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving ? null : () async {
                    if (jobNoCtrl.text.trim().isEmpty) {
                      setState(() => localError = "Job Card Number is required!");
                      return;
                    }

                    if (clientCtrl.text.trim().isEmpty || panelSpecCtrl.text.trim().isEmpty) {
                      setState(() => localError = "Client Name and Panel specification are required!");
                      return;
                    }

                    if (quotePriceCtrl.text.trim().isEmpty) {
                      setState(() => localError = "Quoted Price is required!");
                      return;
                    }

                    setState(() {
                      isSaving = true;
                      localError = null;
                    });

                    final finalJobNo = jobNoCtrl.text.trim();
                    final quoteTag = quoteNumberCtrl.text.trim().isNotEmpty ? " [QUOTE: ${quoteNumberCtrl.text.trim()}]" : "";
                    final authorTag = " [BY: $existingAuthor]";
                    final workerTag = selectedBuilder != null && selectedBuilder!.isNotEmpty ? " [WORKER: $selectedBuilder]" : "";
                    final String finalSpecs = "${specsCtrl.text.trim()}$quoteTag$authorTag$workerTag".trim();

                    if (widget.isEditMode) {
                      final Map<String, dynamic> updateData = {
                        'job_no': finalJobNo,
                        'client': clientCtrl.text.trim(),
                        'panel_type': "[PANEL] ${panelSpecCtrl.text.trim()}",
                        'quotation_amount': quotePriceCtrl.text.trim(),
                        'specs_detail': finalSpecs,
                        'created_by': existingAuthor,
                        'target_date': targetDateCtrl.text.trim().isNotEmpty ? targetDateCtrl.text.trim() : _formatDate(targetDateTime),
                      };
                      if (selectedBuilder != null && selectedBuilder!.isNotEmpty) {
                        updateData['assigned_to'] = selectedBuilder;
                      }
                      try {
                        await widget.onSaved(updateData);
                      } catch (e) {
                        setState(() {
                          isSaving = false;
                          localError = "Failed to update: $e";
                        });
                      }
                    } else {
                      final Map<String, dynamic> insertPayload = {
                        'job_no': finalJobNo,
                        'client': clientCtrl.text.trim(),
                        'panel_type': "[PANEL] ${panelSpecCtrl.text.trim()}",
                        'specs_detail': finalSpecs,
                        'quotation_amount': quotePriceCtrl.text.trim(),
                        'stage': 'Quotation / Commercial Review',
                        'status': 'QUOTATION',
                        'progress': 0.05,
                        'start_date': _formatDate(startDateTime),
                        'target_date': targetDateCtrl.text.trim().isNotEmpty ? targetDateCtrl.text.trim() : _formatDate(targetDateTime),
                        'created_by': existingAuthor,
                      };
                      if (selectedBuilder != null && selectedBuilder!.isNotEmpty) {
                        insertPayload['assigned_to'] = selectedBuilder;
                      }

                      try {
                        await widget.onSaved(insertPayload);
                      } catch (err) {
                        setState(() {
                          isSaving = false;
                          localError = "Save Failed: $err";
                        });
                      }
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                      : Text(
                          widget.isEditMode ? "Update Quotation" : "Save Quotation",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({required String label, required String hint, required TextEditingController ctrl, TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF0F2638) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.isDark ? const Color(0xFF193B54) : const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: keyboard,
            style: TextStyle(color: widget.isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 11),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveSearchField({
    required String label,
    required String hint,
    required TextEditingController ctrl,
    required List<String> suggestions,
  }) {
    final query = ctrl.text.trim().toLowerCase();
    final matchedList = query.isEmpty
        ? <String>[]
        : suggestions.where((s) => s.toLowerCase().contains(query)).take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF0F2638) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.isDark ? const Color(0xFF193B54) : const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: ctrl,
            onChanged: (v) => setState(() {}),
            style: TextStyle(color: widget.isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 11),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
        if (matchedList.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF071824) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.5)),
            ),
            child: Column(
              children: matchedList.map((match) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      ctrl.text = match;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    width: double.infinity,
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 13, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            match,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDatePicker({required String label, required DateTime currentDate, required Function(DateTime) onSelect}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        GestureDetector(
          onTap: () async {
            FocusScope.of(context).unfocus();
            final picked = await showDatePicker(
              context: context,
              initialDate: currentDate,
              firstDate: DateTime(2023),
              lastDate: DateTime(2035),
            );
            if (picked != null) onSelect(picked);
          },
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF0F2638) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.isDark ? const Color(0xFF193B54) : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDate(currentDate), style: TextStyle(color: widget.isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFFE88226)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}