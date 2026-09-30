import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'custom_drawer.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchJobCards();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  // --- DELETE JOB FUNCTION ---
  Future<void> _deleteJob(dynamic jobId, BuildContext? sheetContext) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0C2232),
        title: const Text("Delete Job?", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        content: const Text("Kya aap sach me is job record ko delete karna chahte hain?", style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            const SnackBar(content: Text("Job record successfully delete ho gaya!"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Delete error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // --- EDIT JOB MODAL ---
  void _openEditJobModal(Map<String, dynamic> job, bool isDark, [BuildContext? sheetCtx]) {
    final clientCtrl = TextEditingController(text: job['client'] ?? '');
    final itemOrPanelCtrl = TextEditingController(text: job['panel_type'] ?? '');
    final specsCtrl = TextEditingController(text: job['specs_detail'] ?? '');
    final priceCtrl = TextEditingController(text: (job['invoice_amount'] ?? job['quotation_amount'] ?? '').toString());
    final poNumberCtrl = TextEditingController(text: job['po_number'] ?? '');
    bool isSaving = false;
    String? localError;

    final Color modalBg = isDark ? const Color(0xFF0C1924) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderColor = isDark ? const Color(0xFF1E3A52) : const Color(0xFFCBD5E1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: modalBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (editCtx) {
        return StatefulBuilder(
          builder: (context, setEditState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(editCtx).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Edit ${job['job_no']}", style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w800)),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.close_rounded, color: subTextColor, size: 20),
                          onPressed: () => Navigator.pop(editCtx),
                        ),
                      ],
                    ),
                    Divider(color: borderColor),
                    if (localError != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(localError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                      ),
                    _buildModalField("Client / Company Name", "Client", clientCtrl, isDark),
                    const SizedBox(height: 8),
                    _buildModalField("Item / Panel Specifications", "Specification", itemOrPanelCtrl, isDark),
                    const SizedBox(height: 8),
                    _buildModalField("PO Number (if available)", "PO Number", poNumberCtrl, isDark),
                    const SizedBox(height: 8),
                    _buildModalField("Amount / Value (₹)", "e.g. 50000", priceCtrl, isDark, keyboard: TextInputType.number),
                    const SizedBox(height: 8),
                    _buildModalField("Scope of Work / Spares", "Scope of work", specsCtrl, isDark),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                        onPressed: isSaving ? null : () async {
                          setEditState(() {
                            isSaving = true;
                            localError = null;
                          });
                          try {
                            final Map<String, dynamic> updateData = {
                              'client': clientCtrl.text.trim(),
                              'panel_type': itemOrPanelCtrl.text.trim(),
                              'quotation_amount': priceCtrl.text.trim(),
                              'specs_detail': specsCtrl.text.trim(),
                            };
                            if (poNumberCtrl.text.trim().isNotEmpty) {
                              updateData['po_number'] = poNumberCtrl.text.trim();
                            }

                            await _supabase.from('job_cards').update(updateData).eq('id', job['id']);

                            await _fetchJobCards();
                            Navigator.pop(editCtx);
                            if (sheetCtx != null && sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                            }
                          } catch (e) {
                            setEditState(() {
                              isSaving = false;
                              localError = "Update nahi ho saka: $e";
                            });
                          }
                        },
                        child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
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

  // =========================================================================
  // --- PIPELINE THROUGHPUT ENGINE: (MONTHLY BAR GRAPH + THROUGHPUT MODAL) ---
  // =========================================================================
  void _openMonthlyGraphModal(String categoryLabel, Color themeColor, bool isDark) {
    final now = DateTime.now();
    int selectedMonthIndex = now.month - 1;
    final currentYear = now.year.toString();

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final upperCat = categoryLabel.toUpperCase().trim();

    // --- PIPELINE LIFECYCLE FILTERING ---
    // Agar panel Testing ya Dispatch ho chuka hai, toh woh Running se hamesha count hoga!
    List<Map<String, dynamic>> categoryJobs = _jobCards.where((j) {
      final st = (j['status'] ?? '').toString().toUpperCase();
      final po = (j['po_number'] ?? '').toString().trim();
      final specs = (j['specs_detail'] ?? '').toString();

      if (upperCat == 'ALL') {
        return true;
      } else if (upperCat == "PO REC'D" || upperCat == "PO" || upperCat == "PO_RECEIVED") {
        return po.isNotEmpty || specs.contains("PO:");
      } else if (upperCat == 'QUOTE' || upperCat == 'QUOTATION') {
        return true; // Har banne wala panel quotation stage se guzarta hai
      } else if (upperCat == 'RUNNING') {
        // Running me woh sab aayenge jo RUNNING hain ya aage badh chuke hain (TESTING, COMPLETED, BILLING, DISPATCHED)
        return st == 'RUNNING' || st == 'TESTING' || st == 'COMPLETED' || st == 'BILLING' || st == 'DISPATCHED';
      } else if (upperCat == 'TESTING') {
        // Testing me woh sab aayenge jo TESTING me hain ya aage badh chuke hain (COMPLETED, BILLING, DISPATCHED)
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
            List<int> monthlyCounts = List.filled(12, 0);
            for (var job in categoryJobs) {
              final sDate = (job['start_date'] ?? job['target_date'] ?? '').toString();
              if (sDate.contains(currentYear)) {
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
              return sDate.contains(currentYear) && sDate.toLowerCase().contains(selMonthName.toLowerCase());
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
                      Expanded(
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "$categoryLabel Stage Pipeline ($currentYear)",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: primaryText, fontSize: 14.5, fontWeight: FontWeight.w900),
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

                  // 12 MONTHS BARS CONTAINER
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
                                  color: isSelected ? (isDark ? Colors.white : themeColor) : themeColor.withOpacity(0.85),
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
                          "$selMonthName $currentYear: ${selJobs.length} Processed",
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
                  Text("Pipeline Orders in $selMonthName:", style: TextStyle(color: secondaryText, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),

                  // DETAILED JOB LISTING WITH EDIT AND DELETE
                  Expanded(
                    child: selJobs.isEmpty
                        ? Center(
                            child: Text("No pipeline orders for $selMonthName $currentYear", style: TextStyle(color: secondaryText, fontSize: 11.5, fontWeight: FontWeight.w600)),
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
                                                    onTap: () => _openEditJobModal(item, isDark, ctx),
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

  // --- 1. NEW JOB MODAL ---
  void _openNewJobModal(bool isDark) {
    final now = DateTime.now();
    DateTime startDateTime = now;
    DateTime targetDateTime = now.add(const Duration(days: 14));
    DateTime poDateTime = now;

    final clientCtrl = TextEditingController();
    final itemOrPanelCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: "1");
    final poNumberCtrl = TextEditingController();
    final specsCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    String jobNature = 'PANEL';
    String jobCategory = 'QUOTATION';
    bool hasPo = false;
    bool isSaving = false;
    String? localError;

    final Color modalBg = isDark ? const Color(0xFF0C1924) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderColor = isDark ? const Color(0xFF1E3A52) : const Color(0xFFCBD5E1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: modalBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jobNature == 'PANEL' ? "New Control Panel Job" : "New Component / Spare Job",
                              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            Text("Industrial shop-floor registration", style: TextStyle(color: subTextColor, fontSize: 10)),
                          ],
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.close_rounded, color: subTextColor, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Divider(color: borderColor),
                    const SizedBox(height: 6),

                    if (localError != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.withOpacity(0.4))),
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
                          child: GestureDetector(
                            onTap: () => setModalState(() => jobNature = 'PANEL'),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: jobNature == 'PANEL' ? const Color(0xFFE88226) : (isDark ? const Color(0xFF0F2638) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: jobNature == 'PANEL' ? const Color(0xFFE88226) : borderColor),
                              ),
                              alignment: Alignment.center,
                              child: Text("Control Panel", style: TextStyle(color: jobNature == 'PANEL' ? Colors.white : subTextColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => jobNature = 'ITEM'),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: jobNature == 'ITEM' ? const Color(0xFF0284C7) : (isDark ? const Color(0xFF0F2638) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: jobNature == 'ITEM' ? const Color(0xFF0284C7) : borderColor),
                              ),
                              alignment: Alignment.center,
                              child: Text("Spare Item", style: TextStyle(color: jobNature == 'ITEM' ? Colors.white : subTextColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => jobCategory = 'QUOTATION'),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: jobCategory == 'QUOTATION' ? const Color(0xFF8B5CF6) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF8B5CF6)),
                              ),
                              alignment: Alignment.center,
                              child: Text("Quotation Stage", style: TextStyle(color: jobCategory == 'QUOTATION' ? Colors.white : const Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!hasPo) {
                                setModalState(() => localError = "Direct Running ke liye pehle PO enable karke number dalein!");
                                return;
                              }
                              setModalState(() {
                                jobCategory = 'RUNNING';
                                localError = null;
                              });
                            },
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: jobCategory == 'RUNNING' ? const Color(0xFF10B981) : (isDark ? const Color(0xFF0F2638) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: jobCategory == 'RUNNING' ? const Color(0xFF10B981) : borderColor),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!hasPo) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.lock_outline_rounded, size: 13, color: Colors.grey)),
                                  Flexible(
                                    child: Text(
                                      hasPo ? "Running Order" : "Running (Needs PO)",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: jobCategory == 'RUNNING' ? Colors.white : subTextColor, fontWeight: FontWeight.bold, fontSize: 11.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasPo ? const Color(0xFF10B981).withOpacity(0.12) : (isDark ? const Color(0xFF0F2638) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: hasPo ? const Color(0xFF10B981) : borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.verified_rounded, size: 16, color: hasPo ? const Color(0xFF10B981) : subTextColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text("Client Purchase Order (PO) Received?", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: hasPo,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              setModalState(() {
                                hasPo = val;
                                if (!hasPo) jobCategory = 'QUOTATION';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (hasPo) ...[
                      Row(
                        children: [
                          Expanded(flex: 3, child: _buildModalField("Client PO Number *", "e.g. PO/2026/894", poNumberCtrl, isDark)),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _buildDatePickerField(label: "PO Date", currentDate: poDateTime, isDark: isDark, onSelect: (dt) => setModalState(() => poDateTime = dt)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    _buildModalField("Client / Company Name *", "e.g. Jindal Steel, Reliance", clientCtrl, isDark),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildModalField(
                            jobNature == 'PANEL' ? "Panel Specification *" : "Item Details *",
                            jobNature == 'PANEL' ? "e.g. 50 HP VFD Control Panel" : "e.g. Mitsubishi FX5U PLC",
                            itemOrPanelCtrl,
                            isDark,
                          ),
                        ),
                        if (jobNature == 'ITEM') ...[
                          const SizedBox(width: 8),
                          Expanded(flex: 1, child: _buildModalField("Qty", "1", qtyCtrl, isDark, keyboard: TextInputType.number)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    _buildModalField("Scope of Work / Spares", "e.g. Wiring, Programming, Busbar sizing", specsCtrl, isDark),
                    const SizedBox(height: 8),
                    _buildModalField("Price / PO Value (₹)", "e.g. 150000", priceCtrl, isDark, keyboard: TextInputType.number),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePickerField(label: "Start Date", currentDate: startDateTime, isDark: isDark, onSelect: (dt) => setModalState(() => startDateTime = dt)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDatePickerField(label: "Target Delivery", currentDate: targetDateTime, isDark: isDark, onSelect: (dt) => setModalState(() => targetDateTime = dt)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE88226)),
                        onPressed: isSaving ? null : () async {
                          if (clientCtrl.text.trim().isEmpty || itemOrPanelCtrl.text.trim().isEmpty) {
                            setModalState(() => localError = "Client name aur Item/Panel detail bharna zaroori hai!");
                            return;
                          }

                          if (jobCategory == 'RUNNING' && (!hasPo || poNumberCtrl.text.trim().isEmpty)) {
                            setModalState(() => localError = "PO Number ke bina Job Running mein nahi ja sakta!");
                            return;
                          }

                          setModalState(() {
                            isSaving = true;
                            localError = null;
                          });

                          final String typeTag = jobNature == 'ITEM' ? "[ITEM: ${qtyCtrl.text.trim()} Nos] " : "[PANEL] ";
                          final String fullDesc = "$typeTag${itemOrPanelCtrl.text.trim()}";
                          final newJobNo = "JOB-${now.year}-${100 + _jobCards.length + 1}";

                          final poDetailsStr = hasPo ? " [PO: ${poNumberCtrl.text.trim()} | Date: ${_formatDate(poDateTime)}]" : "";
                          final String finalSpecs = "${specsCtrl.text.trim()}$poDetailsStr".trim();

                          final Map<String, dynamic> insertPayload = {
                            'job_no': newJobNo,
                            'client': clientCtrl.text.trim(),
                            'panel_type': fullDesc,
                            'specs_detail': finalSpecs,
                            'quotation_amount': priceCtrl.text.trim(),
                            'stage': jobCategory == 'QUOTATION'
                                ? 'Quotation / Commercial Review'
                                : (jobNature == 'ITEM' ? 'Testing & Servicing Stage' : 'Fabrication & Layout Stage'),
                            'status': jobCategory,
                            'progress': jobCategory == 'QUOTATION' ? 0.05 : 0.25,
                            'start_date': _formatDate(startDateTime),
                            'target_date': _formatDate(targetDateTime),
                          };

                          try {
                            if (hasPo && poNumberCtrl.text.trim().isNotEmpty) {
                              insertPayload['po_number'] = poNumberCtrl.text.trim();
                            }
                            await _supabase.from('job_cards').insert(insertPayload);
                            await _fetchJobCards();
                            Navigator.pop(ctx);
                          } catch (e) {
                            try {
                              insertPayload.remove('po_number');
                              await _supabase.from('job_cards').insert(insertPayload);
                              await _fetchJobCards();
                              Navigator.pop(ctx);
                            } catch (e2) {
                              setModalState(() {
                                isSaving = false;
                                localError = "Save Failed: $e2";
                              });
                            }
                          }
                        },
                        child: isSaving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                            : Text(
                                jobCategory == 'QUOTATION' ? "Save Quotation" : "Start Production Order (With PO)",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                      ),
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

  Widget _buildDatePickerField({
    required String label,
    required DateTime currentDate,
    required bool isDark,
    required Function(DateTime) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155), fontSize: 11, fontWeight: FontWeight.w600)),
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
            if (picked != null) {
              onSelect(picked);
            }
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F2638) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF193B54) : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDate(currentDate), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFFE88226)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 2. PIPELINE STATUS ACTION MODAL ---
  void _openStatusActionModal(Map<String, dynamic> job, bool isDark) {
    final status = (job['status'] ?? '').toString().toUpperCase();
    final reasonCtrl = TextEditingController();
    final poNumberCtrl = TextEditingController(text: job['po_number'] ?? '');
    final invoiceNoCtrl = TextEditingController(text: job['invoice_no'] ?? 'INV-');
    final invoiceAmtCtrl = TextEditingController(text: job['invoice_amount'] ?? job['quotation_amount'] ?? '');
    final vehicleCtrl = TextEditingController(text: job['dispatch_vehicle'] ?? '');

    final Color dialogBg = isDark ? const Color(0xFF0C2232) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final Color fieldBg = isDark ? const Color(0xFF091A26) : const Color(0xFFF1F5F9);
    final Color dividerColor = isDark ? const Color(0xFF193B54) : const Color(0xFFE2E8F0);

    bool hvTestOk = true;
    bool plcLogicOk = true;
    bool dressingOk = true;

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
                    child: Text("${job['job_no']} Workflow", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
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

                    if (status == 'QUOTATION') ...[
                      Text("Client PO Number Required:", style: TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                          icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                          label: const Text("Verify PO & Move to RUNNING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                          onPressed: () async {
                            if (poNumberCtrl.text.trim().isEmpty) return;
                            await _updateJobStatus(job['id'], {
                              'status': 'RUNNING',
                              'stage': 'Fabrication & Layout Stage',
                              'po_number': poNumberCtrl.text.trim(),
                              'progress': 0.25,
                            });
                            Navigator.pop(ctx);
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
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(color: dividerColor),
                      TextField(
                        controller: reasonCtrl,
                        style: TextStyle(color: textColor, fontSize: 11.5),
                        decoration: InputDecoration(
                          hintText: "Hold reason (Waiting for spares / drawings)",
                          hintStyle: TextStyle(color: subTextColor, fontSize: 10.5),
                          filled: true,
                          fillColor: fieldBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB45309)),
                          icon: const Icon(Icons.pause_circle_outline_rounded, color: Colors.white, size: 15),
                          label: const Text("Put on Hold (Pending)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          onPressed: () async {
                            if (reasonCtrl.text.trim().isEmpty) return;
                            await _updateJobStatus(job['id'], {
                              'status': 'PENDING',
                              'stage': 'On Hold: ${reasonCtrl.text.trim()}',
                              'pending_reason': reasonCtrl.text.trim(),
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],

                    if (status == 'TESTING') ...[
                      const Text("Factory QC Checklist:", style: TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.bold)),
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
                          onPressed: (hvTestOk && plcLogicOk && dressingOk)
                              ? () async {
                                  await _updateJobStatus(job['id'], {
                                    'status': 'COMPLETED',
                                    'stage': 'QC Passed & Ready for Billing',
                                    'progress': 0.90,
                                  });
                                  Navigator.pop(ctx);
                                }
                              : null,
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
                            Navigator.pop(ctx);
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
        Navigator.pop(ctx);
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

  static Widget _buildModalField(String label, String hint, TextEditingController ctrl, bool isDark, {TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F2638) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF193B54) : const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: keyboard,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 11),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Current Active Shop-Floor counts (Live status)
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

      final matchesSearch = _searchQuery.isEmpty ||
          client.contains(_searchQuery) ||
          jobNo.contains(_searchQuery) ||
          panelType.contains(_searchQuery) ||
          poNoStr.contains(_searchQuery);

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
                        hintText: "Search Job #, PO #, Client...",
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
                        child: Image.asset('assets/images/nextgen_logo.jpeg', width: 34, height: 34, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text("NEXTGEN", style: TextStyle(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1E3A5F), fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                              const SizedBox(width: 4),
                              const Text("CONTROLS", style: TextStyle(color: Color(0xFFE88226), fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                            ],
                          ),
                          Text("PRIVATE LIMITED • Simplify Your Industry", style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 7.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
            actions: _isSearchOpen
                ? null
                : [
                    IconButton(
                      icon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7), size: 22),
                      tooltip: "Search",
                      onPressed: () => setState(() => _isSearchOpen = true),
                    ),
                    IconButton(
                      icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: const Color(0xFFE88226), size: 22),
                      tooltip: isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
                      onPressed: () => isDarkModeNotifier.value = !isDark,
                    ),
                  ],
          ),
          body: RefreshIndicator(
            color: const Color(0xFFE88226),
            backgroundColor: isDark ? const Color(0xFF0C2232) : Colors.white,
            onRefresh: _fetchJobCards,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE88226)))
                : Column(
                    children: [
                      // TOP 9 METRIC TILES
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

                      // HORIZONTAL STATUS FILTER CHIPS
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

                      // INDUSTRIAL JOB CARDS
                      Expanded(
                        child: filteredJobs.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            backgroundColor: const Color(0xFFE88226),
            onPressed: () => _openNewJobModal(isDark),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text("New Job / Item", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          border: Border.all(color: isSelected ? const Color(0xFFE88226) : (isDark ? const Color(0xFF1E4362) : const Color(0xFFCBD5E1))),
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

    final double progress = (job['progress'] as num?)?.toDouble() ?? 0.25;
    final int progressPercent = (progress * 100).toInt();

    final Color cardBg = isDark ? const Color(0xFF0B1F2F) : Colors.white;
    final Color borderC = isDark ? const Color(0xFF193B54) : const Color(0xFFE2E8F0);
    final Color titleC = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subC = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final rawDesc = (job['panel_type'] ?? '').toString();
    final bool isItem = rawDesc.contains('[ITEM:');

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
                Row(
                  children: [
                    Text(
                      job['job_no'] ?? '',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),

                    if ((poNumber != null && poNumber.isNotEmpty) || specsStr.contains("PO:"))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                        ),
                        child: Text(
                          poNumber != null && poNumber.isNotEmpty ? "PO: $poNumber" : "PO RECEIVED",
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                        child: const Text("NO PO / QUOTE", style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 8.5, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.7)),
                  ),
                  child: Row(
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
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(job['client'] ?? '', style: TextStyle(color: titleC, fontSize: 13.5, fontWeight: FontWeight.w800))),
                if (job['invoice_amount'] != null && job['invoice_amount'].toString().isNotEmpty)
                  Text("₹${job['invoice_amount']}", style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w900))
                else if (job['quotation_amount'] != null && job['quotation_amount'].toString().isNotEmpty)
                  Text("₹${job['quotation_amount']}", style: TextStyle(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7), fontSize: 12.5, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 3),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isItem ? const Color(0xFF0284C7).withOpacity(0.15) : const Color(0xFFE88226).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(isItem ? "ITEM" : "PANEL", style: TextStyle(color: isItem ? const Color(0xFF0284C7) : const Color(0xFFE88226), fontSize: 8.5, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rawDesc.replaceAll('[PANEL]', '').replaceAll(RegExp(r'\[ITEM:.*?\]'), '').trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subC, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(job['stage'] ?? statusStr, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF1E293B), fontSize: 10.5, fontWeight: FontWeight.w700)),
                Text("$progressPercent%", style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: isDark ? const Color(0xFF132A3E) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),

            const SizedBox(height: 8),
            Divider(color: borderC, height: 1),
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Start: ${job['start_date'] ?? '-'}", style: TextStyle(color: subC, fontSize: 9.5, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _openEditJobModal(job, isDark),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF0284C7).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                        child: const Row(
                          children: [
                            Icon(Icons.edit, size: 11, color: Color(0xFF0284C7)),
                            SizedBox(width: 2),
                            Text("Edit", style: TextStyle(color: Color(0xFF0284C7), fontSize: 9.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _deleteJob(job['id'], null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline, size: 11, color: Colors.red),
                            SizedBox(width: 2),
                            Text("Delete", style: TextStyle(color: Colors.red, fontSize: 9.5, fontWeight: FontWeight.bold)),
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
    );
  }
}