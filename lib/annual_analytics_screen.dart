import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'custom_drawer.dart';

class AnnualAnalyticsScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialJobs;

  const AnnualAnalyticsScreen({super.key, this.initialJobs});

  @override
  State<AnnualAnalyticsScreen> createState() => _AnnualAnalyticsScreenState();
}

class _AnnualAnalyticsScreenState extends State<AnnualAnalyticsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> _allJobs = [];
  String _selectedYear = '2026';

  final List<String> _trackedYears = ['2024', '2025', '2026', '2027'];

  @override
  void initState() {
    super.initState();
    if (widget.initialJobs != null && widget.initialJobs!.isNotEmpty) {
      _allJobs = List<Map<String, dynamic>>.from(widget.initialJobs!);
      _isLoading = false;
    } else {
      _isLoading = true;
      _fetchYearlyData();
    }
  }

  Future<void> _fetchYearlyData() async {
    try {
      final data = await _supabase.from('job_cards').select().order('id', ascending: false);
      if (mounted) {
        setState(() {
          _allJobs = List<Map<String, dynamic>>.from(data);
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

  bool _matchesYear(Map<String, dynamic> job, String year) {
    final dateStr = "${job['start_date']} ${job['created_at']} ${job['target_date']}";
    if (dateStr.contains(year)) return true;

    if (year == '2026' && (job['start_date'] == null || job['start_date'].toString().isEmpty)) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final Color screenBg = isDark ? const Color(0xFF07121A) : const Color(0xFFF1F5F9);
        final Color cardBg = isDark ? const Color(0xFF0C2232) : Colors.white;
        final Color borderColor = isDark ? const Color(0xFF1E3E5A) : const Color(0xFFCBD5E1);
        final Color textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        // Filter Jobs for Selected Year
        final selectedYearJobs = _allJobs.where((j) => _matchesYear(j, _selectedYear)).toList();
        final int totalPanels = selectedYearJobs.length;

        // --- YEARLY SUMMARY COUNTS (SAAL ME KITNA HUA / GAYA) ---
        final int yearlyQuotes = selectedYearJobs.length;

        final int yearlyPO = selectedYearJobs.where((j) {
          final po = (j['po_number'] ?? '').toString().trim();
          final specs = (j['specs_detail'] ?? '').toString();
          return po.isNotEmpty || specs.contains("PO:");
        }).length;

        final int yearlyRunning = selectedYearJobs.where((j) {
          final st = (j['status'] ?? '').toString().toUpperCase();
          return st == 'RUNNING' || st == 'TESTING' || st == 'COMPLETED' || st == 'BILLING' || st == 'DISPATCHED';
        }).length;

        final int yearlyTesting = selectedYearJobs.where((j) {
          final st = (j['status'] ?? '').toString().toUpperCase();
          return st == 'TESTING' || st == 'COMPLETED' || st == 'BILLING' || st == 'DISPATCHED';
        }).length;

        final int yearlyReady = selectedYearJobs.where((j) {
          final st = (j['status'] ?? '').toString().toUpperCase();
          return st == 'COMPLETED' || st == 'BILLING' || st == 'DISPATCHED';
        }).length;

        final int yearlyBilling = selectedYearJobs.where((j) {
          final st = (j['status'] ?? '').toString().toUpperCase();
          return st == 'BILLING' || st == 'DISPATCHED';
        }).length;

        final int yearlyDispatched = selectedYearJobs.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'DISPATCHED').length;
        final int yearlyPending = selectedYearJobs.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'PENDING').length;
        final int yearlyCancelled = selectedYearJobs.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'CANCELLED').length;

        // Segments for Multi-colored Circle Chart
        final List<DonutSegment> segments = [
          DonutSegment(title: "QUOTES", count: yearlyQuotes, color: const Color(0xFF8B5CF6)),
          DonutSegment(title: "PO REC'D", count: yearlyPO, color: const Color(0xFF10B981)),
          DonutSegment(title: "RUNNING", count: yearlyRunning, color: const Color(0xFF0284C7)),
          DonutSegment(title: "TESTING", count: yearlyTesting, color: const Color(0xFFEA580C)),
          DonutSegment(title: "READY", count: yearlyReady, color: const Color(0xFF38BDF8)),
          DonutSegment(title: "BILLING", count: yearlyBilling, color: const Color(0xFFE88226)),
          DonutSegment(title: "DISPATCH", count: yearlyDispatched, color: const Color(0xFF059669)),
          DonutSegment(title: "PENDING", count: yearlyPending, color: const Color(0xFFD97706)),
          DonutSegment(title: "CANCEL", count: yearlyCancelled, color: const Color(0xFFEF4444)),
        ];

        // Revenue Sum
        double totalValuation = 0.0;
        for (var j in selectedYearJobs) {
          final valStr = (j['invoice_amount'] ?? j['quotation_amount'] ?? '0').toString().replaceAll(',', '');
          totalValuation += double.tryParse(valStr) ?? 0.0;
        }

        // Year-Over-Year Volume
        final Map<String, int> yearlyTotals = {
          for (var y in _trackedYears)
            y: _allJobs.where((j) => _matchesYear(j, y)).length
        };
        final int maxYearCount = yearlyTotals.values.fold(0, (p, c) => c > p ? c : p);

        return Scaffold(
          backgroundColor: screenBg,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF0C2232) : Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: textMain),
            title: Text(
              "Annual Intelligence & Charts",
              style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE88226)))
              : RefreshIndicator(
                  color: const Color(0xFFE88226),
                  onRefresh: _fetchYearlyData,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // 1. YEAR SELECTOR TABS
                      Row(
                        children: _trackedYears.map((yr) {
                          final isSelected = yr == _selectedYear;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedYear = yr),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFE88226) : cardBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFE88226) : borderColor,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "FY $yr",
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : textSub,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // 2. YEARLY STAGE AUDIT STATS (SAAL ME KITNA HUA / GAYA)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("FY $_selectedYear Stage Flow Summary", style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w900)),
                                Text("₹${(totalValuation / 100000).toStringAsFixed(1)}L Valuation", style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildSummaryTile("Quotes", "$yearlyQuotes", const Color(0xFF8B5CF6), isDark),
                                const SizedBox(width: 6),
                                _buildSummaryTile("PO Received", "$yearlyPO", const Color(0xFF10B981), isDark),
                                const SizedBox(width: 6),
                                _buildSummaryTile("Running", "$yearlyRunning", const Color(0xFF0284C7), isDark),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildSummaryTile("Testing Done", "$yearlyTesting", const Color(0xFFEA580C), isDark),
                                const SizedBox(width: 6),
                                _buildSummaryTile("Dispatched Out", "$yearlyDispatched", const Color(0xFF059669), isDark),
                                const SizedBox(width: 6),
                                _buildSummaryTile("Total Orders", "$totalPanels", const Color(0xFFE88226), isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. YEARLY CIRCLE / DONUT GRAPH CARD
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Annual Production Share (FY $_selectedYear)",
                                  style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  "$totalPanels Units",
                                  style: const TextStyle(color: Color(0xFFE88226), fontSize: 12.5, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // CIRCLE CHART WITH CENTER BADGE
                            SizedBox(
                              width: 210,
                              height: 210,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(210, 210),
                                    painter: YearlyDonutPainter(segments: segments),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "$totalPanels",
                                        style: TextStyle(color: textMain, fontSize: 26, fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "TOTAL ORDERS",
                                        style: TextStyle(color: textSub, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "FY $_selectedYear",
                                        style: const TextStyle(color: Color(0xFFE88226), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // STAGE CHIPS WITH ACTUAL COUNTS
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: segments.map((s) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F2638) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: s.color.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Text(s.title, style: TextStyle(color: textSub, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 5),
                                      Text("${s.count}", style: TextStyle(color: textMain, fontSize: 10.5, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. YEAR-ON-YEAR OVERALL COMPARISON (MULTI-YEAR BARS)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Year-on-Year Production Growth",
                              style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text("Saalaana panel production ka direct comparison:", style: TextStyle(color: textSub, fontSize: 11)),
                            const SizedBox(height: 16),

                            Column(
                              children: _trackedYears.map((yr) {
                                final count = yearlyTotals[yr] ?? 0;
                                final double ratio = maxYearCount == 0 ? 0.0 : (count / maxYearCount);
                                final isCur = yr == _selectedYear;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 54,
                                        child: Text(
                                          "FY $yr",
                                          style: TextStyle(
                                            color: isCur ? const Color(0xFFE88226) : textMain,
                                            fontWeight: isCur ? FontWeight.w900 : FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            Container(
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF0F2638) : const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                            ),
                                            FractionallySizedBox(
                                              widthFactor: ratio.clamp(0.04, 1.0),
                                              child: Container(
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  color: isCur ? const Color(0xFFE88226) : const Color(0xFF0284C7),
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 50,
                                        child: Text(
                                          "$count Units",
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: isCur ? const Color(0xFFE88226) : textMain,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSummaryTile(String title, String val, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF071824) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class DonutSegment {
  final String title;
  final int count;
  final Color color;

  DonutSegment({required this.title, required this.count, required this.color});
}

// PAINTER JO SABHI STAGES KO EQUAL MULTI-COLOR SLICES ME DIVIDE KAREGA
class YearlyDonutPainter extends CustomPainter {
  final List<DonutSegment> segments;

  YearlyDonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    const strokeWidth = 24.0;

    final bgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final activeSegments = segments.where((s) => s.count > 0).toList();
    if (activeSegments.isEmpty) return;

    final double totalActiveCount = activeSegments.fold(0.0, (sum, s) => sum + s.count);
    double startAngle = -pi / 2;

    for (var segment in activeSegments) {
      final sweepAngle = (segment.count / totalActiveCount) * 2 * pi;

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = activeSegments.length > 1 ? StrokeCap.round : StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (activeSegments.length > 1 ? 0.05 : 0.0),
        max(sweepAngle - (activeSegments.length > 1 ? 0.10 : 0.0), 0.02),
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}