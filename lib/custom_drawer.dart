import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'annual_analytics_screen.dart';
import 'sing_in.dart';

// GLOBAL THEME CONTROLLER
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(true);

class CustomDrawer extends StatefulWidget {
  final String activeRoute;

  const CustomDrawer({
    super.key,
    this.activeRoute = 'dashboard',
    String? currentRoute,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String _operatorName = "JUNAID";
  final ShorebirdUpdater _shorebirdUpdater = ShorebirdUpdater();
  int _appPatchVersion = 1;

  @override
  void initState() {
    super.initState();
    _loadOperatorName();
    _loadShorebirdVersion();
  }

  Future<void> _loadOperatorName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('logged_operator_username');
    if (savedUser != null && savedUser.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _operatorName = savedUser.toUpperCase();
        });
      }
    }
  }

  Future<void> _loadShorebirdVersion() async {
    try {
      final patch = await _shorebirdUpdater.readCurrentPatch();
      if (patch != null && mounted) {
        setState(() {
          // Base build = v1, Patch 1 = v2, Patch 2 = v3 ...
          _appPatchVersion = 1 + patch.number;
        });
      }
    } catch (_) {
      // Offline ya desktop fallback ke liye default v1 rahega
    }
  }

  // --- DATE PARSER HELPER ---
  DateTime? _parseJobDate(dynamic dateStr) {
    if (dateStr == null) return null;
    final str = dateStr.toString().trim();
    if (str.isEmpty) return null;

    try {
      final parts = str.split(' ');
      if (parts.length >= 3) {
        final day = int.parse(parts[0]);
        final monthStr = parts[1].toLowerCase();
        final year = int.parse(parts[2]);

        const months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
        };
        final month = months[monthStr] ?? 1;
        return DateTime(year, month, day);
      }
    } catch (_) {}

    try {
      return DateTime.parse(str);
    } catch (_) {}

    return null;
  }

  // --- CROSS-PLATFORM DOWNLOAD DIRECTORY HELPER (WINDOWS + MOBILE) ---
  Future<Directory> _getTargetDirectory(bool isDownload) async {
    if (!isDownload) {
      return await getApplicationDocumentsDirectory();
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final winDownloads = Directory('$userProfile\\Downloads');
        if (await winDownloads.exists()) {
          return winDownloads;
        }
      }
      final dl = await getDownloadsDirectory();
      if (dl != null) return dl;
    } else if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final androidDownloads = Directory('/storage/emulated/0/Download');
        if (await androidDownloads.exists()) {
          return androidDownloads;
        }
        return ext;
      }
    }

    final fallback = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    return fallback;
  }

  // --- CSV GENERATOR ---
  String _buildCsvContent(List<Map<String, dynamic>> records, DateTime startDate, DateTime endDate) {
    final fromStr = "${startDate.day}/${startDate.month}/${startDate.year}";
    final toStr = "${endDate.day}/${endDate.month}/${endDate.year}";
    final now = DateTime.now();

    final StringBuffer csv = StringBuffer();
    csv.writeln("NEXTGEN CONTROLS PRIVATE LIMITED");
    csv.writeln("Simplify Your Industry");
    csv.writeln("Statement Period: $fromStr to $toStr");
    csv.writeln("Generated On: ${now.day}/${now.month}/${now.year}");
    csv.writeln("Total Orders Billed / Logged: ${records.length}");
    csv.writeln("");

    csv.writeln(
        "SR NO,START DATE,JOB NO,CLIENT NAME,PANEL / ITEM DETAILS,WORK STATUS,PROGRESS,PRICE (INR),DELIVERY DATE,PO NUMBER,INVOICE NO,VEHICLE NO");

    int sr = 1;
    for (var row in records) {
      String clean(dynamic val) {
        if (val == null || val.toString().trim().isEmpty) return '"-"';
        String str = val.toString().replaceAll('"', '""');
        return '"$str"';
      }

      final price = row['invoice_amount'] ?? row['quotation_amount'] ?? '-';
      final progress = "${(((row['progress'] as num?)?.toDouble() ?? 0) * 100).toInt()}%";

      final line = [
        sr.toString(),
        clean(row['start_date']),
        clean(row['job_no']),
        clean(row['client']),
        clean(row['panel_type']),
        clean(row['status']),
        clean(progress),
        clean(price),
        clean(row['target_date']),
        clean(row['po_number']),
        clean(row['invoice_no']),
        clean(row['dispatch_vehicle']),
      ].join(',');

      csv.writeln(line);
      sr++;
    }

    return csv.toString();
  }

  // --- PDF GENERATOR ---
  pw.Document _buildPdfDocument(List<Map<String, dynamic>> records, DateTime startDate, DateTime endDate) {
    final fromStr = "${startDate.day}/${startDate.month}/${startDate.year}";
    final toStr = "${endDate.day}/${endDate.month}/${endDate.year}";
    final now = DateTime.now();

    double totalAmount = 0.0;
    for (var r in records) {
      final p = double.tryParse((r['invoice_amount'] ?? r['quotation_amount'] ?? '0')
              .toString()
              .replaceAll(',', '')) ??
          0.0;
      totalAmount += p;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        build: (pw.Context pwContext) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#0C2232'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          "NEXTGEN",
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 1.1,
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          "CONTROLS",
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#E88226'),
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "PRIVATE LIMITED • Simplify Your Industry",
                      style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8.5),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Statement Period: $fromStr - $toStr",
                      style: pw.TextStyle(
                          color: PdfColors.amber300, fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text("Generated: ${now.day}/${now.month}/${now.year}",
                        style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8.5)),
                    pw.Text("Total Orders: ${records.length} Panels",
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 8.5)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: [
              'SR',
              'DATE',
              'JOB NO',
              'CLIENT NAME',
              'PANEL / ITEM DETAILS',
              'PO NUMBER',
              'STATUS',
              'DELIVERY',
              'PRICE (INR)',
              'INVOICE NO'
            ],
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3E5A')),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
            data: records.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final j = entry.value;
              final price = j['invoice_amount'] ?? j['quotation_amount'] ?? '-';
              return [
                "$idx",
                j['start_date'] ?? '-',
                j['job_no'] ?? '-',
                j['client'] ?? '-',
                j['panel_type'] ?? '-',
                j['po_number'] ?? '-',
                j['status'] ?? '-',
                j['target_date'] ?? '-',
                price != '-' ? "Rs. $price" : '-',
                j['invoice_no'] ?? '-',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColors.grey400),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "Total Statement Valuation: Rs. ${totalAmount.toStringAsFixed(0)}",
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
              ),
              pw.Text(
                "NEXTGEN CONTROLS PRIVATE LIMITED - Official Verified Statement",
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  // --- 1. EXCEL EXPORT & DOWNLOAD ---
  Future<void> _handleExcelOperation(
      BuildContext context, DateTime startDate, DateTime endDate, {required bool isDownload}) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(isDownload ? "Downloading Excel Statement..." : "Generating Excel Statement...",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        duration: const Duration(milliseconds: 1400),
      ),
    );

    try {
      final supabase = Supabase.instance.client;
      final data = await supabase.from('job_cards').select().order('id', ascending: true);

      final records = List<Map<String, dynamic>>.from(data).where((job) {
        final d = _parseJobDate(job['start_date']);
        if (d == null) return false;
        final startZero = DateTime(startDate.year, startDate.month, startDate.day);
        final endZero = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        return (d.isAfter(startZero) || d.isAtSameMomentAs(startZero)) &&
            (d.isBefore(endZero) || d.isAtSameMomentAs(endZero));
      }).toList();

      if (records.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text("No job cards found for the selected date range."),
              backgroundColor: Colors.orange),
        );
        return;
      }

      final csvString = _buildCsvContent(records, startDate, endDate);
      final directory = await _getTargetDirectory(isDownload);
      final fileName =
          "NextGen_Statement_${startDate.day}_${startDate.month}_to_${endDate.day}_${endDate.month}_${endDate.year}.csv";
      final file = File("${directory.path}/$fileName");
      await file.writeAsString(csvString);

      if (isDownload) {
        messenger.showSnackBar(
          SnackBar(
            content: Text("Excel saved to: ${file.path}"),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        final fromStr = "${startDate.day}/${startDate.month}/${startDate.year}";
        final toStr = "${endDate.day}/${endDate.month}/${endDate.year}";
        final xFile = XFile(file.path, mimeType: 'text/csv');
        await Share.shareXFiles(
          [xFile],
          text: 'NextGen Statement ($fromStr to $toStr)',
          subject: 'NextGen Statement of Operations',
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Export error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // --- 2. PDF EXPORT & DOWNLOAD ---
  Future<void> _handlePdfOperation(
      BuildContext context, DateTime startDate, DateTime endDate, {required bool isDownload}) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(isDownload ? "Downloading PDF Statement..." : "Generating PDF Statement...",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFFE88226),
        duration: const Duration(milliseconds: 1400),
      ),
    );

    try {
      final supabase = Supabase.instance.client;
      final data = await supabase.from('job_cards').select().order('id', ascending: true);

      final records = List<Map<String, dynamic>>.from(data).where((job) {
        final d = _parseJobDate(job['start_date']);
        if (d == null) return false;
        final startZero = DateTime(startDate.year, startDate.month, startDate.day);
        final endZero = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        return (d.isAfter(startZero) || d.isAtSameMomentAs(startZero)) &&
            (d.isBefore(endZero) || d.isAtSameMomentAs(endZero));
      }).toList();

      if (records.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text("No job cards found for the selected date range."),
              backgroundColor: Colors.orange),
        );
        return;
      }

      final pdf = _buildPdfDocument(records, startDate, endDate);
      final directory = await _getTargetDirectory(isDownload);
      final fileName =
          "NextGen_Statement_${startDate.day}_${startDate.month}_to_${endDate.day}_${endDate.month}_${endDate.year}.pdf";
      final file = File("${directory.path}/$fileName");
      await file.writeAsBytes(await pdf.save());

      if (isDownload) {
        messenger.showSnackBar(
          SnackBar(
            content: Text("PDF saved to: ${file.path}"),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        final fromStr = "${startDate.day}/${startDate.month}/${startDate.year}";
        final toStr = "${endDate.day}/${endDate.month}/${endDate.year}";
        final xFile = XFile(file.path, mimeType: 'application/pdf');
        await Share.shareXFiles(
          [xFile],
          text: 'NextGen Statement ($fromStr to $toStr)',
          subject: 'NextGen Statement of Operations',
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("PDF error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // --- 3. STATEMENT DATE SELECTOR DIALOG WITH SHARE & DOWNLOAD ---
  void _openStatementModal(BuildContext context, bool isDark) {
    DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime endDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1724),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String formatD(DateTime dt) => "${dt.day}/${dt.month}/${dt.year}";

            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: dynamic_spaceBetween(),
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.date_range_rounded, color: Color(0xFFE88226), size: 24),
                            SizedBox(width: 8),
                            Text(
                              "Statement of Operations",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF1E3A52), height: 18),
                    const Text(
                      "Select date range and export or download records directly to your device:",
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),

                    // DATES BOXES
                    Row(
                      children: [
                        // FROM DATE
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() => startDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFF102436),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF224B6F), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "FROM DATE",
                                    style: TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded,
                                          size: 15, color: Color(0xFFE88226)),
                                      const SizedBox(width: 7),
                                      Text(
                                        formatD(startDate),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // TO DATE
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() => endDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFF102436),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF224B6F), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "TO DATE",
                                    style: TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded,
                                          size: 15, color: Color(0xFFE88226)),
                                      const SizedBox(width: 7),
                                      Text(
                                        formatD(endDate),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // EXCEL ACTIONS (DOWNLOAD & SHARE)
                    const Text(
                      "EXCEL (.CSV) STATEMENT",
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                              label: const Text(
                                "Download Excel",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _handleExcelOperation(context, startDate, endDate, isDownload: true);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.share_rounded, color: Color(0xFF10B981), size: 17),
                              label: const Text(
                                "Share Excel",
                                style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _handleExcelOperation(context, startDate, endDate, isDownload: false);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // PDF ACTIONS (DOWNLOAD & SHARE)
                    const Text(
                      "PDF STATEMENT OF OPERATIONS",
                      style: TextStyle(color: Color(0xFFE88226), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE88226),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                              label: const Text(
                                "Download PDF",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _handlePdfOperation(context, startDate, endDate, isDownload: true);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE88226), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.share_rounded, color: Color(0xFFE88226), size: 17),
                              label: const Text(
                                "Share PDF",
                                style: TextStyle(color: Color(0xFFE88226), fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _handlePdfOperation(context, startDate, endDate, isDownload: false);
                              },
                            ),
                          ),
                        ),
                      ],
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

  static MainAxisAlignment dynamic_spaceBetween() => MainAxisAlignment.spaceBetween;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final Color bgColor = isDark ? const Color(0xFF071420) : const Color(0xFFF1F5F9);
        final Color cardBg = isDark ? const Color(0xFF0B1F2F) : Colors.white;
        final Color borderColor = isDark ? const Color(0xFF1E3E5A) : const Color(0xFFCBD5E1);
        final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

        return Drawer(
          backgroundColor: bgColor,
          child: SafeArea(
            child: Column(
              children: [
                // 1. BRAND HEADER
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF071420) : Colors.white,
                    border: Border(bottom: BorderSide(color: borderColor, width: 1.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE88226), width: 1.6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE88226).withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/nextgen_logo_1.jpg',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.settings_suggest_rounded,
                                  size: 26,
                                  color: Color(0xFFE88226),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "NEXTGEN",
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1E3A5F),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: const [
                                        Text(
                                          "C",
                                          style: TextStyle(
                                            color: Color(0xFFE88226),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        Icon(
                                          Icons.settings,
                                          size: 11,
                                          color: Color(0xFFE88226),
                                        ),
                                        Text(
                                          "NTR",
                                          style: TextStyle(
                                            color: Color(0xFFE88226),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        Icon(
                                          Icons.settings,
                                          size: 11,
                                          color: Color(0xFFE88226),
                                        ),
                                        Text(
                                          "LS",
                                          style: TextStyle(
                                            color: Color(0xFFE88226),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "PRIVATE LIMITED • Simplify Your Industry",
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // OPERATOR STATUS BADGE
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "OPERATOR: ",
                              style: TextStyle(
                                color: subColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "$_operatorName (ADMIN)",
                              style: TextStyle(
                                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. NAVIGATION TILES
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                    children: [
                      _buildDrawerTile(
                        context: context,
                        icon: Icons.dashboard_rounded,
                        title: "Operations Dashboard",
                        subtitle: "Active pipeline & stage overview",
                        isActive: widget.activeRoute == 'dashboard',
                        isDark: isDark,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(height: 8),

                      _buildDrawerTile(
                        context: context,
                        icon: Icons.analytics_rounded,
                        title: "Annual Graph & Analytics",
                        subtitle: "Year-on-year growth & donut distribution",
                        isActive: widget.activeRoute == 'analytics',
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AnnualAnalyticsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 8),

                      _buildDrawerTile(
                        context: context,
                        icon: Icons.receipt_long_rounded,
                        title: "Statement of Operations",
                        subtitle: "Date-Range PDF / Excel export & download",
                        isActive: false,
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                          _openStatementModal(context, isDark);
                        },
                      ),
                    ],
                  ),
                ),

                // 3. LOGOUT & FOOTER (DYNAMIC VERSION)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF071420) : Colors.white,
                    border: Border(top: BorderSide(color: borderColor, width: 1)),
                  ),
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const SignInScreen()),
                              (route) => false,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 16),
                                SizedBox(width: 8),
                                Text(
                                  "Lock & Sign Out",
                                  style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "NEXTGEN OS • v$_appPatchVersion (Industrial Edition)",
                        style: TextStyle(
                          color: subColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildDrawerTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeBg = isDark ? const Color(0xFF163650) : const Color(0xFFE0F2FE);
    final inactiveBg = isDark ? const Color(0xFF0B1F2F) : Colors.white;
    final activeBorder = const Color(0xFFE88226);
    final inactiveBorder = isDark ? const Color(0xFF1A3852) : const Color(0xFFCBD5E1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? activeBorder : inactiveBorder,
              width: isActive ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFE88226)
                      : (isDark ? const Color(0xFF132F45) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: isActive
                      ? Colors.white
                      : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Color(0xFFE88226),
                ),
            ],
          ),
        ),
      ),
    );
  }
}