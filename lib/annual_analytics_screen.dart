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
    final start = (job['start_date'] ?? '').toString();
    final created = (job['created_at'] ?? '').toString();
    final target = (job['target_date'] ?? '').toString();

    if (start.contains(year) || created.contains(year) || target.contains(year)) {
      return true;
    }

    if (year == '2026' && start.isEmpty && created.isEmpty) {
      return true;
    }

    return false;
  }

  static String formatIndianCurrency(double val) {
    final double absVal = val.abs();
    if (absVal == 0) return "₹0";

    if (absVal < 100000) {
      return "₹${absVal.toStringAsFixed(0)}";
    }

    final double inLakhs = absVal / 100000;
    return "₹${inLakhs.toStringAsFixed(2)}L";
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
        final List<Map<String, dynamic>> targetJobs = _allJobs.where((j) => _matchesYear(j, _selectedYear)).toList();
        final int totalCount = targetJobs.length;

        // --- LIFECYCLE COUNTS ---
        final int countDispatch = targetJobs.where((j) {
          final st = (j['status'] ?? '').toString().toUpperCase();
          return st == 'DISPATCHED' || st == 'BILLING';
        }).length;

        final int countTesting = targetJobs.where((j) {
          final st = (j['status'] ?? '').toString().toUpperCase();
          return st == 'TESTING' || st == 'COMPLETED';
        }).length;

        final int countRunning = targetJobs.where((j) {
          final st = (j['status'] ?? '').toString().toUpperCase();
          return st == 'RUNNING';
        }).length;

        // PENDING / ON HOLD STAGE
        final int countPending = targetJobs.where((j) {
          final st = (j['status'] ?? '').toString().toUpperCase();
          return st == 'PENDING';
        }).length;

        final int countPO = targetJobs.where((j) {
          final po = (j['po_number'] ?? '').toString().trim();
          final specs = (j['specs_detail'] ?? '').toString();
          return po.isNotEmpty || specs.contains("PO:");
        }).length;

        final int totalQuotesInitiated = targetJobs.where((j) {
          final q = (j['quotation_amount'] ?? '').toString().trim();
          return q.isNotEmpty && q != '0';
        }).length;

        final int countOpenQuotes = targetJobs.where((j) {
          final st = (j['status'] ?? '').toString().toUpperCase();
          final po = (j['po_number'] ?? '').toString().trim();
          final specs = (j['specs_detail'] ?? '').toString();
          final hasPo = po.isNotEmpty || specs.contains("PO:");
          return st == 'QUOTATION' || (!hasPo && st != 'CANCELLED' && st != 'PENDING');
        }).length;

        final int countCancelled = targetJobs.where((j) {
          final st = (j['status'] ?? '').toString().toUpperCase();
          return st == 'CANCELLED';
        }).length;

        // ALL STAGES WITH EXACT MATCHING DASHBOARD COLORS
        final List<StageItem> stages = [
          StageItem(
            name: "Quotes",
            tag: "QUOTES",
            subtext: "Total $totalQuotesInitiated quotes generated ($countOpenQuotes pending PO)",
            count: countOpenQuotes > 0 ? countOpenQuotes : (totalQuotesInitiated > 0 ? totalQuotesInitiated : 0),
            color: const Color(0xFF8B5CF6),
          ),
          StageItem(
            name: "PO Received",
            tag: "PO REC'D",
            subtext: "Confirmed client orders in FY $_selectedYear",
            count: countPO,
            color: const Color(0xFF10B981),
          ),
          StageItem(
            name: "Running",
            tag: "RUNNING",
            subtext: "Panel assembly and wiring in progress on shop floor",
            count: countRunning,
            color: const Color(0xFF0284C7),
          ),
          StageItem(
            name: "Pending (On Hold)",
            tag: "PENDING",
            subtext: "Awaiting raw materials or drawing revision approval",
            count: countPending,
            color: const Color(0xFFD97706),
          ),
          StageItem(
            name: "Testing",
            tag: "TESTING",
            subtext: "High-voltage megger and FAT quality inspection",
            count: countTesting,
            color: const Color(0xFFEA580C),
          ),
          StageItem(
            name: "Dispatch",
            tag: "DISPATCH",
            subtext: "Invoiced and cleared for customer shipment",
            count: countDispatch,
            color: const Color(0xFF059669),
          ),
        ];

        if (countCancelled > 0) {
          stages.add(
            StageItem(
              name: "Cancelled",
              tag: "CANCEL",
              subtext: "Orders rejected or dropped",
              count: countCancelled,
              color: const Color(0xFFEF4444),
            ),
          );
        }

        // --- FINANCIAL AUDIT CALCULATION ---
        double yearlyTotalQuoted = 0.0;
        double yearlyTotalPO = 0.0;

        for (var j in targetJobs) {
          final qStr = (j['quotation_amount'] ?? '0').toString().replaceAll(',', '');
          final pStr = (j['invoice_amount'] ?? '0').toString().replaceAll(',', '');

          final qVal = double.tryParse(qStr) ?? 0.0;
          final pVal = double.tryParse(pStr) ?? 0.0;

          yearlyTotalQuoted += qVal;

          if (pVal > 0) {
            yearlyTotalPO += pVal;
          } else {
            final po = (j['po_number'] ?? '').toString().trim();
            final specs = (j['specs_detail'] ?? '').toString();
            if (po.isNotEmpty || specs.contains("PO:")) {
              yearlyTotalPO += qVal;
            }
          }
        }

        final double yearlyVariance = yearlyTotalPO - yearlyTotalQuoted;
        final bool isZeroDiff = yearlyVariance.abs() < 1.0;
        final double variancePercent = (!isZeroDiff && yearlyTotalQuoted > 0) ? (yearlyVariance / yearlyTotalQuoted) * 100 : 0.0;
        final double dispatchPercent = totalCount == 0 ? 0.0 : (countDispatch / totalCount) * 100;

        final int pieTotal = stages.fold(0, (sum, item) => sum + item.count);

        return Scaffold(
          backgroundColor: screenBg,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF0C2232) : Colors.white,
            elevation: 0.5,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Year Selection Buttons
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

                      // --- 1. ACCURATE COMMERCIAL AUDIT CARD (OVERFLOW FIXED) ---
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
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    "FY $_selectedYear Quoted vs PO Audit",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isZeroDiff
                                        ? const Color(0xFF0284C7).withOpacity(0.15)
                                        : (yearlyVariance < 0 ? const Color(0xFFEF4444).withOpacity(0.15) : const Color(0xFF10B981).withOpacity(0.15)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isZeroDiff
                                        ? "Exact Match (0 Diff)"
                                        : (yearlyVariance < 0
                                            ? "-${formatIndianCurrency(yearlyVariance.abs())} (${variancePercent.abs().toStringAsFixed(1)}%)"
                                            : "+${formatIndianCurrency(yearlyVariance)} (+${variancePercent.toStringAsFixed(1)}%)"),
                                    style: TextStyle(
                                      color: isZeroDiff
                                          ? const Color(0xFF0284C7)
                                          : (yearlyVariance < 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildFinanceMetricTile("Total Quoted", formatIndianCurrency(yearlyTotalQuoted), const Color(0xFF8B5CF6), isDark),
                                const SizedBox(width: 8),
                                _buildFinanceMetricTile("Final PO / Billed", formatIndianCurrency(yearlyTotalPO), const Color(0xFF10B981), isDark),
                                const SizedBox(width: 8),
                                _buildFinanceMetricTile(
                                  isZeroDiff ? "Difference" : (yearlyVariance < 0 ? "Discount / Cut" : "Extra Gain"),
                                  isZeroDiff ? "₹0" : "${yearlyVariance < 0 ? '-' : '+'}${formatIndianCurrency(yearlyVariance.abs())}",
                                  isZeroDiff ? const Color(0xFF0284C7) : (yearlyVariance < 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                                  isDark,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // --- 2. SOLID PIE CHART CARD ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Annual Production Share",
                                  style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  "Total: $totalCount (FY $_selectedYear)",
                                  style: const TextStyle(color: Color(0xFFE88226), fontSize: 12, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            Center(
                              child: SizedBox(
                                width: 220,
                                height: 220,
                                child: CustomPaint(
                                  size: const Size(220, 220),
                                  painter: CleanSolidPiePainter(
                                    stages: stages,
                                    total: pieTotal > 0 ? pieTotal : totalCount,
                                    borderColor: cardBg,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // --- 3. STAGES BREAKDOWN CARDS ---
                      ...stages.map((stage) {
                        final int baseTotal = pieTotal > 0 ? pieTotal : (totalCount > 0 ? totalCount : 1);
                        final double pct = (stage.count / baseTotal) * 100;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: stage.color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      stage.name,
                                      style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: stage.color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "${pct.toStringAsFixed(0)}%",
                                      style: TextStyle(color: stage.color, fontSize: 11, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "${stage.count}",
                                    style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (stage.count / baseTotal).clamp(0.0, 1.0),
                                  backgroundColor: isDark ? const Color(0xFF0F2638) : const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(stage.color),
                                  minHeight: 5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                stage.subtext,
                                style: TextStyle(color: textSub, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 4),

                      // --- 4. KEY INSIGHTS BOTTOM CARD ---
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F2638) : const Color(0xFFE2E8F0).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "FY $_selectedYear Summary",
                                  style: TextStyle(color: textMain, fontSize: 13.5, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  "${dispatchPercent.toStringAsFixed(0)}% Delivered",
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildInsightBullet("Total Job Cards: $totalCount (Valuation: ${formatIndianCurrency(yearlyTotalPO)})", textSub),
                            _buildInsightBullet("Shop Floor: $countRunning in active production, $countPending on hold, $countTesting in quality testing.", textSub),
                            _buildInsightBullet("Completed: $countDispatch (Cleared and dispatched)", textSub),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildFinanceMetricTile(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF071824) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 9.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightBullet(String text, Color textSub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(color: Color(0xFFE88226), fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textSub, fontSize: 11.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class StageItem {
  final String name;
  final String tag;
  final String subtext;
  final int count;
  final Color color;

  StageItem({
    required this.name,
    required this.tag,
    required this.subtext,
    required this.count,
    required this.color,
  });
}

// FULL SOLID PIE CHART PAINTER
class CleanSolidPiePainter extends CustomPainter {
  final List<StageItem> stages;
  final int total;
  final Color borderColor;

  CleanSolidPiePainter({
    required this.stages,
    required this.total,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final activeStages = stages.where((s) => s.count > 0).toList();

    if (total == 0 || activeStages.isEmpty) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF0284C7).withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );
      _drawCenteredText(canvas, center, "NO DATA", "0");
      return;
    }

    if (activeStages.length == 1) {
      final singleStage = activeStages.first;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = singleStage.color
          ..style = PaintingStyle.fill,
      );

      _drawCenteredText(canvas, center, singleStage.tag, "100% (${singleStage.count})");
      return;
    }

    double startAngle = -pi / 2;

    for (var stage in activeStages) {
      final sweepAngle = (stage.count / total) * 2 * pi;
      if (sweepAngle <= 0) continue;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
        )
        ..close();

      final slicePaint = Paint()
        ..color = stage.color
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, slicePaint);

      final lineBorderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(path, lineBorderPaint);

      final double pct = (stage.count / total) * 100;
      if (pct >= 8.0) {
        final midAngle = startAngle + (sweepAngle / 2);
        final labelRadius = radius * 0.62;
        final labelPos = Offset(
          center.dx + labelRadius * cos(midAngle),
          center.dy + labelRadius * sin(midAngle),
        );

        final labelText = pct >= 14.0 ? "${stage.tag}\n${pct.toStringAsFixed(0)}%" : "${pct.toStringAsFixed(0)}%";

        final textPainter = TextPainter(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: labelText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1.15,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(labelPos.dx - textPainter.width / 2, labelPos.dy - textPainter.height / 2),
        );
      }

      startAngle += sweepAngle;
    }
  }

  void _drawCenteredText(Canvas canvas, Offset center, String line1, String line2) {
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: "$line1\n",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
          TextSpan(
            text: line2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}