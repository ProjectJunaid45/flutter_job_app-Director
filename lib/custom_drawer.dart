import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'dashboard_screen.dart';
import 'annual_analytics_screen.dart';
import 'sing_in.dart';

class CustomDrawer extends StatefulWidget {
  final String activeRoute;

  const CustomDrawer({super.key, required this.activeRoute});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String _operatorName = 'SAEED SHAIKH (ADMIN)';

  @override
  void initState() {
    super.initState();
    _loadOperator();
  }

  Future<void> _loadOperator() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('logged_operator_username');
      if (saved != null && saved.trim().isNotEmpty && mounted) {
        setState(() {
          _operatorName = "${saved.trim().toUpperCase()} (ADMIN)";
        });
      }
    } catch (_) {}
  }

  // --- CONFIRMATION POPUP BEFORE LOGOUT ---
  Future<void> _confirmAndLogout(BuildContext context, bool isDark) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final Color dialogBg = isDark ? const Color(0xFF0C2232) : Colors.white;
        final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E3A52) : const Color(0xFFE2E8F0),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                "Sign Out Confirmation",
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          content: Text(
            "Are you sure you want to end your current session and return to the login screen?",
            style: TextStyle(
              color: subTextColor,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: subTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text(
                "Yes, Sign Out",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && context.mounted) {
      await _handleLogout(context);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
        (route) => false,
      );
    }
  }

  // --- 1. EXCEL/CSV BUILDER ---
  String _generateExcelCsvContent(
    dynamic recordsList,
    DateTime fromDate,
    DateTime toDate,
  ) {
    final now = DateTime.now();
    final buffer = StringBuffer();
    final records = recordsList as List;

    buffer.writeln("NEXTGEN CONTROLS PRIVATE LIMITED");
    buffer.writeln("Simplify Your Industry");
    buffer.writeln("Statement Period: ${fromDate.day}/${fromDate.month}/${fromDate.year} to ${toDate.day}/${toDate.month}/${toDate.year}");
    buffer.writeln("Generated On: ${now.day}/${now.month}/${now.year}");
    buffer.writeln("Total Orders Billed / Logged: ${records.length}");
    buffer.writeln("");

    buffer.writeln("SR NO,START DATE,JOB NO,CLIENT NAME,PANEL / ITEM,WORK STATUS,PROGRESS,PRICE (INR),DELIVERY DATE,PO NUMBER,INVOICE NO,VEHICLE NO");

    for (int i = 0; i < records.length; i++) {
      final r = records[i] as Map;
      final srNo = i + 1;
      final startDate = (r['start_date'] ?? '-').toString().replaceAll(',', ' ');
      final jobNo = (r['job_no'] ?? '').toString().replaceAll(',', ' ');
      final client = (r['client'] ?? '').toString().replaceAll(',', ' ');
      final panel = (r['panel_type'] ?? '')
          .toString()
          .replaceAll(',', ' ')
          .replaceAll('[PANEL]', '')
          .replaceAll(RegExp(r'\[ITEM:.*?\]'), '')
          .trim();
      final status = (r['status'] ?? '').toString();
      final progress = "${(((r['progress'] as num?)?.toDouble() ?? 0.0) * 100).toInt()}%";
      final price = (r['invoice_amount'] ?? r['quotation_amount'] ?? '0').toString().replaceAll(',', '');
      final deliveryDate = (r['target_date'] ?? '-').toString().replaceAll(',', ' ');
      final poNumber = (r['po_number'] ?? '-').toString().replaceAll(',', ' ');
      final invoiceNo = (r['invoice_no'] ?? '-').toString().replaceAll(',', ' ');
      final vehicleNo = (r['dispatch_vehicle'] ?? '-').toString().replaceAll(',', ' ');

      buffer.writeln("$srNo,$startDate,$jobNo,$client,$panel,$status,$progress,$price,$deliveryDate,$poNumber,$invoiceNo,$vehicleNo");
    }

    return buffer.toString();
  }

  // --- 2. OFFICIAL PDF BUILDER ---
  Future<dynamic> _generateOfficialPdfBytes(
    dynamic recordsList,
    DateTime fromDate,
    DateTime toDate,
  ) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final records = recordsList as List;

    final List<List<dynamic>> tableData = [];
    for (int i = 0; i < records.length; i++) {
      final r = records[i] as Map;
      tableData.add([
        "${i + 1}",
        (r['job_no'] ?? '-').toString(),
        (r['client'] ?? '-').toString(),
        (r['panel_type'] ?? '-').toString().replaceAll('[PANEL]', '').replaceAll(RegExp(r'\[ITEM:.*?\]'), '').trim(),
        (r['status'] ?? '-').toString(),
        "${(((r['progress'] as num?)?.toDouble() ?? 0.0) * 100).toInt()}%",
        "Rs. ${(r['invoice_amount'] ?? r['quotation_amount'] ?? '0').toString().replaceAll(',', '')}",
        (r['target_date'] ?? '-').toString(),
        (r['invoice_no'] ?? '-').toString(),
      ]);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0F1E2E),
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
                              "NEXTGEN ",
                              style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFFE88226),
                                borderRadius: pw.BorderRadius.circular(3),
                              ),
                              child: pw.Text(
                                "CONTROLS & AUTOMATION",
                                style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "Shop-Floor Production, Testing & Delivery Register",
                          style: const pw.TextStyle(color: PdfColor.fromInt(0xFF94A3B8), fontSize: 8),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Date: ${now.day} ${_monthName(now.month)} ${now.year}",
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 8.5),
                        ),
                        pw.Text(
                          "Total: ${records.length} Panels",
                          style: const pw.TextStyle(color: PdfColor.fromInt(0xFF94A3B8), fontSize: 7.5),
                        ),
                        pw.Text(
                          "Filter: ALL",
                          style: const pw.TextStyle(color: PdfColor.fromInt(0xFF10B981), fontSize: 7.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['SR', 'JOB NO', 'CLIENT NAME', 'PANEL DETAILS', 'STATUS', 'PROGRESS', 'PRICE (INR)', 'DELIVERY', 'INVOICE NO'],
                data: tableData,
                headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A52)),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("NEXTGEN Operations Suite • Official Record", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                  pw.Text("Confidential Internal Document", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (m >= 1 && m <= 12) ? months[m - 1] : 'Jan';
  }

  // --- WINDOWS NATIVE "SAVE AS" FILE DIALOG ---
  Future<String?> _showWindowsSaveDialog(String defaultFileName, String ext) async {
    try {
      final filter = ext == 'pdf'
          ? 'PDF Document (*.pdf)|*.pdf|All Files (*.*)|*.*'
          : 'CSV Spreadsheet (*.csv)|*.csv|All Files (*.*)|*.*';

      final escapedFilter = filter.replaceAll("'", "''");
      final escapedFileName = defaultFileName.replaceAll("'", "''");

      final script = '''
[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
\$dlg = New-Object System.Windows.Forms.SaveFileDialog
\$dlg.Filter = '$escapedFilter'
\$dlg.FileName = '$escapedFileName'
\$dlg.Title = 'Save As'
if (\$dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::Out.Write(\$dlg.FileName)
} else {
  [Console]::Out.Write('__USER_CANCELLED__')
}
''';

      final result = await Process.run('powershell', ['-NoProfile', '-Command', script]);
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path == '__USER_CANCELLED__') {
          return '__CANCELLED__';
        }
        if (path.isNotEmpty) {
          return path;
        }
      }
    } catch (_) {}
    return null;
  }

  // --- DOWNLOAD & SHARE LOGIC (WINDOWS + MOBILE SAFE) ---
  Future<void> _handleStatementAction(
    ScaffoldMessengerState messenger,
    DateTime fromDate,
    DateTime toDate,
    bool isPdf,
    bool isShare,
  ) async {
    final String typeName = isPdf ? "PDF" : "Excel";
    final String ext = isPdf ? "pdf" : "csv";
    final String dateSlug = "${fromDate.day}_${fromDate.month}_to_${toDate.day}_${toDate.month}_${toDate.year}";
    final String fileName = "NextGen_Statement_$dateSlug.$ext";

    // 1. Loading Notification
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "Preparing $typeName Statement...",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0284C7),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final supabase = Supabase.instance.client;
      final data = await supabase.from('job_cards').select().order('id', ascending: false);
      final records = List.from(data);

      if (records.isEmpty) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(content: Text("No records found in database!"), backgroundColor: Colors.red),
        );
        return;
      }

      dynamic fileBytes;
      if (isPdf) {
        fileBytes = await _generateOfficialPdfBytes(records, fromDate, toDate);
      } else {
        final csvContent = _generateExcelCsvContent(records, fromDate, toDate);
        fileBytes = utf8.encode(csvContent);
      }

      // Cache file in temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(fileBytes as List<int>, flush: true);

      // --- SHARE FLOW ---
      if (isShare) {
        final xFile = XFile(tempFile.path, mimeType: isPdf ? 'application/pdf' : 'text/csv');
        await Share.shareXFiles(
          [xFile],
          text: "Nextgen Controls - Statement of Operations (${fromDate.day}/${fromDate.month}/${fromDate.year} to ${toDate.day}/${toDate.month}/${toDate.year})",
        );
        return;
      }

      // --- DOWNLOAD FLOW ---
      if (Platform.isWindows) {
        // Laptop/Windows: Native "Save As" popup opens
        final chosenPath = await _showWindowsSaveDialog(fileName, ext);

        if (chosenPath == '__CANCELLED__') {
          messenger.clearSnackBars();
          messenger.showSnackBar(
            const SnackBar(
              content: Text("Download cancelled.", style: TextStyle(color: Colors.white)),
              backgroundColor: Color(0xFF64748B),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        String savedLocation;
        if (chosenPath != null && chosenPath.isNotEmpty) {
          final targetFile = File(chosenPath);
          await targetFile.writeAsBytes(fileBytes as List<int>, flush: true);
          savedLocation = chosenPath;
        } else {
          // Fallback to user's Windows Downloads directory
          final userProfile = Platform.environment['USERPROFILE'] ?? '';
          final winDownloads = Directory('$userProfile\\Downloads');
          if (await winDownloads.exists()) {
            final targetFile = File('${winDownloads.path}\\$fileName');
            await targetFile.writeAsBytes(fileBytes as List<int>, flush: true);
            savedLocation = targetFile.path;
          } else {
            savedLocation = tempFile.path;
          }
        }

        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "$typeName saved to: $savedLocation",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        // Mobile (Android / iOS): Unchanged original download behavior
        final displayPath = "/storage/emulated/0/Download/$fileName";
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            final targetFile = File('${downloadDir.path}/$fileName');
            await targetFile.writeAsBytes(fileBytes as List<int>, flush: true);
          }
        } catch (_) {}

        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "$typeName saved to: $displayPath",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // --- STATEMENT BOTTOM SHEET MODAL ---
  void _openStatementBottomSheet(BuildContext rootContext, bool isDark) {
    DateTime fromDate = DateTime(2026, 10, 1);
    DateTime toDate = DateTime(2026, 10, 23);
    final messenger = ScaffoldMessenger.of(rootContext);

    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0C1F2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final Color inputBg = isDark ? const Color(0xFF071520) : const Color(0xFFF1F5F9);
            final Color borderClr = isDark ? const Color(0xFF1E3A52) : const Color(0xFFCBD5E1);

            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE88226).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.calendar_month_rounded, color: Color(0xFFE88226), size: 19),
                          ),
                          const SizedBox(width: 9),
                          Text(
                            "Statement of Operations",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.close_rounded, color: subColor, size: 21),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Select date range and export or download records directly to your device:",
                    style: TextStyle(
                      color: subColor,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: fromDate,
                              firstDate: DateTime(2023),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setSheetState(() => fromDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderClr),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "FROM DATE",
                                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFFE88226)),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${fromDate.day}/${fromDate.month}/${fromDate.year}",
                                      style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: toDate,
                              firstDate: DateTime(2023),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setSheetState(() => toDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderClr),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "TO DATE",
                                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFFE88226)),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${toDate.day}/${toDate.month}/${toDate.year}",
                                      style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
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
                  const Text(
                    "EXCEL (.CSV) STATEMENT",
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 16),
                          label: const Text(
                            "Download Excel",
                            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _handleStatementAction(
                              messenger,
                              fromDate,
                              toDate,
                              false,
                              false,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.share_outlined, size: 15),
                          label: const Text(
                            "Share Excel",
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _handleStatementAction(
                              messenger,
                              fromDate,
                              toDate,
                              false,
                              true,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "PDF STATEMENT OF OPERATIONS",
                    style: TextStyle(
                      color: Color(0xFFE88226),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE88226),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 16),
                          label: const Text(
                            "Download PDF",
                            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _handleStatementAction(
                              messenger,
                              fromDate,
                              toDate,
                              true,
                              false,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE88226),
                            side: const BorderSide(color: Color(0xFFE88226), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.share_outlined, size: 15),
                          label: const Text(
                            "Share PDF",
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _handleStatementAction(
                              messenger,
                              fromDate,
                              toDate,
                              true,
                              true,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final Color drawerBg = isDark ? const Color(0xFF07121A) : const Color(0xFFF8FAFC);
        final Color cardBg = isDark ? const Color(0xFF0C2232) : Colors.white;
        final Color borderClr = isDark ? const Color(0xFF193B54) : const Color(0xFFCBD5E1);
        final Color textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Drawer(
          backgroundColor: drawerBg,
          elevation: 16,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. BRAND HEADER
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderClr),
                        ),
                        child: Image.asset(
                          'assets/images/nextgen_logo_1.jpg',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.settings_suggest_rounded,
                            color: Color(0xFFE88226),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: const [
                                Text(
                                  "NEXTGEN ",
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  "CONTROLS",
                                  style: TextStyle(
                                    color: Color(0xFFE88226),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "PRIVATE LIMITED • Simplify Your Industry",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textSub,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. OPERATOR BADGE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderClr, width: 1),
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
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "OPERATOR: ",
                                  style: TextStyle(
                                    color: textSub,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: _operatorName,
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. MENU ITEMS
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        _buildIndustrialCard(
                          icon: Icons.grid_view_rounded,
                          iconColor: Colors.white,
                          iconBg: const Color(0xFFE88226),
                          title: "Operations Dashboard",
                          subtitle: "Active pipeline & stage overview",
                          isActive: widget.activeRoute == 'dashboard',
                          activeBorderColor: const Color(0xFFE88226),
                          showChevron: true,
                          cardBg: cardBg,
                          defaultBorderColor: borderClr,
                          textMain: textMain,
                          textSub: textSub,
                          onTap: () {
                            Navigator.pop(context);
                            if (widget.activeRoute != 'dashboard') {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const DashboardScreen()),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 9),

                        _buildIndustrialCard(
                          icon: Icons.bar_chart_rounded,
                          iconColor: const Color(0xFF38BDF8),
                          iconBg: const Color(0xFF0284C7).withOpacity(0.2),
                          title: "Annual Graph & Analytics",
                          subtitle: "Year-on-year growth & donut distribution",
                          isActive: widget.activeRoute == 'analytics',
                          cardBg: cardBg,
                          defaultBorderColor: borderClr,
                          textMain: textMain,
                          textSub: textSub,
                          onTap: () {
                            Navigator.pop(context);
                            if (widget.activeRoute != 'analytics') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AnnualAnalyticsScreen()),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 9),

                        // STATEMENT OF OPERATIONS
                        _buildIndustrialCard(
                          icon: Icons.description_outlined,
                          iconColor: const Color(0xFF38BDF8),
                          iconBg: const Color(0xFF0284C7).withOpacity(0.2),
                          title: "Statement of Operations",
                          subtitle: "Date-Range PDF / Excel export &\ndownload",
                          isActive: widget.activeRoute == 'statement',
                          cardBg: cardBg,
                          defaultBorderColor: borderClr,
                          textMain: textMain,
                          textSub: textSub,
                          onTap: () {
                            Navigator.pop(context);
                            _openStatementBottomSheet(context, isDark);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 4. LOCK & SIGN OUT BUTTON PINNED AT BOTTOM WITH CONFIRMATION
                  GestureDetector(
                    onTap: () => _confirmAndLogout(context, isDark),
                    child: Container(
                      width: double.infinity,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF140D15) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.7),
                          width: 1.1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, size: 15, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text(
                            "Lock & Sign Out",
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Center(
                    child: Text(
                      "NEXTGEN OS • v1 (Industrial Edition)",
                      style: TextStyle(
                        color: textSub,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIndustrialCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color cardBg,
    required Color defaultBorderColor,
    required Color textMain,
    required Color textSub,
    bool isActive = false,
    Color? activeBorderColor,
    bool showChevron = false,
  }) {
    final borderClr = isActive
        ? (activeBorderColor ?? const Color(0xFF38BDF8))
        : defaultBorderColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderClr, width: isActive ? 1.4 : 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textMain,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textSub,
                      fontSize: 9,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFE88226),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}