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
import 'create_account_screen.dart';
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

  // --- 1. EXCEL/CSV BUILDER (PHOTO 1 FORMAT) ---
  String _generateExcelCsvContent({
    required List<Map<String, dynamic>> records,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    final now = DateTime.now();
    final buffer = StringBuffer();

    // Top Header Lines as seen in Screenshot 1
    buffer.writeln("NEXTGEN CONTROLS PRIVATE LIMITED");
    buffer.writeln("Simplify Your Industry");
    buffer.writeln("Statement Period: ${fromDate.day}/${fromDate.month}/${fromDate.year} to ${toDate.day}/${toDate.month}/${toDate.year}");
    buffer.writeln("Generated On: ${now.day}/${now.month}/${now.year}");
    buffer.writeln("Total Orders Billed / Logged: ${records.length}");
    buffer.writeln(""); // Blank spacing line

    // Column Headers
    buffer.writeln("SR NO,START DATE,JOB NO,CLIENT NAME,PANEL / ITEM,WORK STATUS,PROGRESS,PRICE (INR),DELIVERY DATE,PO NUMBER,INVOICE NO,VEHICLE NO");

    for (int i = 0; i < records.length; i++) {
      final r = records[i];
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

  // --- 2. OFFICIAL PDF BUILDER (PHOTO 2 FORMAT) ---
  Future<List<int>> _generateOfficialPdfBytes({
    required List<Map<String, dynamic>> records,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    final List<List<String>> tableData = [];
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
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
              // Dark Header Banner matching Screenshot 2
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

              // The Official Table
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

              // Footer matching Screenshot 2
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

  // --- DOWNLOAD & SHARE LOGIC ---
  Future<void> _handleStatementAction({
    required ScaffoldMessengerState messenger,
    required DateTime fromDate,
    required DateTime toDate,
    required bool isPdf,
    required bool isShare,
  }) async {
    final String typeName = isPdf ? "PDF" : "Excel";
    final String dateSlug = "${fromDate.day}_${fromDate.month}_to_${toDate.day}_${toDate.month}_${toDate.year}";
    final String fileName = "NextGen_Statement_$dateSlug.${isPdf ? 'pdf' : 'csv'}";

    // 1. Blue Loading SnackBar
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "Downloading $typeName Statement...",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0284C7),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final supabase = Supabase.instance.client;
      final data = await supabase.from('job_cards').select().order('id', ascending: false);
      final records = List<Map<String, dynamic>>.from(data);

      if (records.isEmpty) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(content: Text("No records found in database!"), backgroundColor: Colors.red),
        );
        return;
      }

      // Generate exact bytes based on type
      List<int> fileBytes;
      if (isPdf) {
        fileBytes = await _generateOfficialPdfBytes(records: records, fromDate: fromDate, toDate: toDate);
      } else {
        final csvContent = _generateExcelCsvContent(records: records, fromDate: fromDate, toDate: toDate);
        fileBytes = utf8.encode(csvContent);
      }

      // Cache file path
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(fileBytes, flush: true);

      final displayPath = "/storage/emulated/0/Download/$fileName";

      // Device Download directory copy
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final targetFile = File('${downloadDir.path}/$fileName');
          await targetFile.writeAsBytes(fileBytes, flush: true);
        }
      } catch (_) {}

      // 2. Green Confirmation Banner
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

      // 3. Android Share Sheet trigger
      if (isShare) {
        final xFile = XFile(tempFile.path, mimeType: isPdf ? 'application/pdf' : 'text/csv');
        await Share.shareXFiles(
          [xFile],
          text: "Nextgen Controls - Statement of Operations (${fromDate.day}/${fromDate.month}/${fromDate.year} to ${toDate.day}/${toDate.month}/${toDate.year})",
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
  void _openStatementBottomSheet(BuildContext rootContext) {
    DateTime fromDate = DateTime(2026, 10, 1);
    DateTime toDate = DateTime(2026, 10, 23);
    final messenger = ScaffoldMessenger.of(rootContext);

    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                          const Text(
                            "Statement of Operations",
                            style: TextStyle(
                              color: Colors.white,
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
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 21),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    "Select date range and export or download records directly to your device:",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      // FROM DATE BOX
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
                              color: const Color(0xFF071520),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF1E3A52)),
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
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // TO DATE BOX
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
                              color: const Color(0xFF071520),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF1E3A52)),
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
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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

                  // EXCEL SECTION
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
                              messenger: messenger,
                              fromDate: fromDate,
                              toDate: toDate,
                              isPdf: false,
                              isShare: false,
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
                              messenger: messenger,
                              fromDate: fromDate,
                              toDate: toDate,
                              isPdf: false,
                              isShare: true,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PDF SECTION
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
                              messenger: messenger,
                              fromDate: fromDate,
                              toDate: toDate,
                              isPdf: true,
                              isShare: false,
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
                              messenger: messenger,
                              fromDate: fromDate,
                              toDate: toDate,
                              isPdf: true,
                              isShare: true,
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
    return Drawer(
      backgroundColor: const Color(0xFF07121A),
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
                        const Text(
                          "PRIVATE LIMITED • Simplify Your Industry",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
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
                  color: const Color(0xFF0C2232),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF193B54), width: 1),
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
                            const TextSpan(
                              text: "OPERATOR: ",
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
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
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFF38BDF8),
                      iconBg: const Color(0xFF0284C7).withOpacity(0.2),
                      title: "Rate Worker Performance",
                      subtitle: "5-Star review, badges & feedback",
                      isActive: widget.activeRoute == 'worker_rating',
                      onTap: () {
                        Navigator.pop(context);
                        if (widget.activeRoute != 'create_account') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
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
                      onTap: () {
                        Navigator.pop(context);
                        _openStatementBottomSheet(context);
                      },
                    ),
                  ],
                ),
              ),

              // 4. LOCK & SIGN OUT BUTTON
              GestureDetector(
                onTap: () => _handleLogout(context),
                child: Container(
                  width: double.infinity,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF140D15),
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

              const Center(
                child: Text(
                  "NEXTGEN OS • v1 (Industrial Edition)",
                  style: TextStyle(
                    color: Color(0xFF64748B),
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
  }

  Widget _buildIndustrialCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeBorderColor,
    bool showChevron = false,
  }) {
    final borderClr = isActive
        ? (activeBorderColor ?? const Color(0xFF38BDF8))
        : const Color(0xFF193B54);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2232),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
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