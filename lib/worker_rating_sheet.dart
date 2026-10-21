import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerRatingSheet extends StatefulWidget {
  final List<String> availableWorkers;
  final String? preSelectedWorker;

  const WorkerRatingSheet({
    super.key,
    required this.availableWorkers,
    this.preSelectedWorker,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<String> availableWorkers,
    String? preSelectedWorker,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF091722),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => WorkerRatingSheet(
        availableWorkers: availableWorkers,
        preSelectedWorker: preSelectedWorker,
      ),
    );
  }

  @override
  State<WorkerRatingSheet> createState() => _WorkerRatingSheetState();
}

class _WorkerRatingSheetState extends State<WorkerRatingSheet> with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _commentCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  late TabController _tabController;
  late stt.SpeechToText _speech;

  bool _isListening = false;
  bool _speechEnabled = false;

  // Rate Form State
  String? _selectedWorker;
  int _rating = 0; // Starts strictly at 0
  String _selectedTag = '';
  bool _isSubmitting = false;

  // All Ratings List State
  bool _isLoadingAll = true;
  List<Map<String, dynamic>> _allWorkersList = [];
  String _sortOrder = 'HIGH_TO_LOW'; // HIGH_TO_LOW, LOW_TO_HIGH
  String _searchFilter = '';

  final List<String> _positiveTags = [
    'Fast Wiring',
    'Neat Dressing',
    'Punctuality',
    'Zero Faults',
    'Drawing Match',
    'Clean Layout',
    'Ferrule OK',
    'Other',
  ];

  final List<String> _negativeTags = [
    'Wiring Dressing',
    'Late Delivery',
    'Ferrule Error',
    'Drawing Mistake',
    'Assembly Speed',
    'Cleanliness',
    'Staff Behavior',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _speech = stt.SpeechToText();
    _initSpeech();

    if (widget.preSelectedWorker != null &&
        widget.availableWorkers.contains(widget.preSelectedWorker)) {
      _selectedWorker = widget.preSelectedWorker;
    } else if (widget.availableWorkers.isNotEmpty) {
      _selectedWorker = widget.availableWorkers.first;
    }

    _fetchAllWorkersRating();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) {
        setState(() => _speechEnabled = available);
      }
    } catch (_) {
      if (mounted) setState(() => _speechEnabled = false);
    }
  }

  Future<void> _fetchAllWorkersRating() async {
    setState(() => _isLoadingAll = true);
    try {
      final res = await _supabase
          .from('workers')
          .select('username, full_name, rating, rating_tag, rating_comment, total_reviews')
          .order('username', ascending: true);

      final List<Map<String, dynamic>> parsed = List<Map<String, dynamic>>.from(res);

      if (mounted) {
        setState(() {
          _allWorkersList = parsed;
          _isLoadingAll = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAll = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _speech.stop();
    _commentCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (!_speechEnabled) {
      await _initSpeech();
    }

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speechEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Microphone permission denied. Allow mic from phone settings."),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      onResult: (result) {
        if (mounted) {
          setState(() {
            _commentCtrl.text = result.recognizedWords;
            _commentCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _commentCtrl.text.length),
            );
          });
        }
      },
    );
  }

  String _getRatingTitle(int star) {
    switch (star) {
      case 5:
        return "★ 5 - Outstanding Master Build!";
      case 4:
        return "★ 4 - Good & Neat Work";
      case 3:
        return "★ 3 - Average Factory Output";
      case 2:
        return "★ 2 - Below Average / Needs Focus";
      case 1:
        return "★ 1 - Poor / Incomplete Work";
      default:
        return "Tap stars to rate";
    }
  }

  Color _getRatingColor(double star) {
    if (star >= 4.0) return const Color(0xFF10B981);
    if (star >= 3.0) return const Color(0xFFE88226);
    return const Color(0xFFEF4444);
  }

  Future<void> _submitRating() async {
    if (_selectedWorker == null || _selectedWorker!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pehle worker select karein!"), backgroundColor: Colors.red),
      );
      return;
    }

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kam se kam 1 star select karein!"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final workerUsername = _selectedWorker!.trim().toUpperCase();
      final double directRating = _rating.toDouble();
      final String finalComment = _commentCtrl.text.trim().isNotEmpty
          ? _commentCtrl.text.trim()
          : _getRatingTitle(_rating);

      await _supabase.from('workers').update({
        'rating': directRating,
        'rating_tag': _selectedTag.isNotEmpty ? _selectedTag : 'Factory Verified',
        'rating_comment': finalComment,
        'total_reviews': 1,
      }).eq('username', workerUsername);

      await _fetchAllWorkersRating();

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _rating = 0;
          _commentCtrl.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "⭐ Rating updated! $workerUsername is now set to $directRating Stars.",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );

        // Auto-switch to All Ratings list to inspect
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rating save error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle & Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.stars_rounded, color: Color(0xFFE88226), size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Worker Performance Center",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // TAB BAR: [ ⭐ Rate Worker | 📋 All Ratings ]
          Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF0C2030),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF193B54)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFFE88226),
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 16),
                      SizedBox(width: 6),
                      Text("Rate Worker"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.format_list_bulleted_rounded, size: 16),
                      SizedBox(width: 6),
                      Text("All Ratings"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // TAB CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRateWorkerTab(),
                _buildAllRatingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: RATE WORKER FORM ---
  Widget _buildRateWorkerTab() {
    final bool isPositive = _rating >= 4;
    final List<String> currentTags = isPositive ? _positiveTags : _negativeTags;
    final Color activeColor = _getRatingColor(_rating.toDouble());

    if (_rating > 0 && (_selectedTag.isEmpty || !currentTags.contains(_selectedTag))) {
      _selectedTag = currentTags.first;
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "SELECT WORKER",
              style: TextStyle(
                color: const Color(0xFF38BDF8).withOpacity(0.9),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2638),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF224B6F)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedWorker,
                dropdownColor: const Color(0xFF0C2232),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF38BDF8)),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                hint: const Text("Select worker", style: TextStyle(color: Colors.grey, fontSize: 12)),
                items: widget.availableWorkers.map((w) {
                  return DropdownMenuItem<String>(
                    value: w,
                    child: Text("Panel Builder: $w"),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedWorker = val),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 5 Interactive Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              final bool isFilled = starIndex <= _rating;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = starIndex;
                    _selectedTag = (_rating >= 4) ? _positiveTags.first : _negativeTags.first;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFilled ? activeColor : const Color(0xFF475569),
                    size: 42,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          Text(
            _rating == 0 ? "Tap a star above to rate" : _getRatingTitle(_rating),
            style: TextStyle(
              color: _rating == 0 ? const Color(0xFF64748B) : activeColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),

          // ANIMATED SECTION: Stars tap hone ke baad appear hoga
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _rating > 0 ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(height: 20),
            secondChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Text(
                  isPositive ? "What was great? 😃" : "What could have been better? 😟",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: currentTags.map((tag) {
                    final bool isSelected = _selectedTag == tag;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedTag = tag),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor.withOpacity(0.18) : const Color(0xFF0F2638),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? activeColor : const Color(0xFF244866),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: isSelected ? activeColor : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // Comment with Functional Mic
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2030),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isListening ? const Color(0xFF10B981) : const Color(0xFF224866),
                      width: _isListening ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          maxLines: 3,
                          minLines: 2,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: _isListening
                                ? "Listening... Speak your feedback..."
                                : "Tap mic or type remarks (Optional)",
                            hintStyle: TextStyle(
                              color: _isListening ? const Color(0xFF10B981) : const Color(0xFF64748B),
                              fontSize: 11.5,
                              fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleListening,
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isListening
                                ? const Color(0xFF10B981).withOpacity(0.25)
                                : activeColor.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isListening ? const Color(0xFF10B981) : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                            color: _isListening ? const Color(0xFF10B981) : activeColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 1,
                    ),
                    onPressed: _isSubmitting ? null : _submitRating,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            "Submit Rating",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // --- TAB 2: ALL WORKERS RATINGS LIST & HIGH TO LOW FILTER ---
  Widget _buildAllRatingsTab() {
    if (_isLoadingAll) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE88226)),
      );
    }

    // Filter by search query
    List<Map<String, dynamic>> displayed = _allWorkersList.where((w) {
      final name = (w['full_name'] ?? '').toString().toLowerCase();
      final username = (w['username'] ?? '').toString().toLowerCase();
      return _searchFilter.isEmpty ||
          name.contains(_searchFilter) ||
          username.contains(_searchFilter);
    }).toList();

    // Sort: High to Low OR Low to High
    displayed.sort((a, b) {
      final double rA = (a['rating'] as num?)?.toDouble() ?? 0.0;
      final double rB = (b['rating'] as num?)?.toDouble() ?? 0.0;
      if (_sortOrder == 'HIGH_TO_LOW') {
        return rB.compareTo(rA);
      } else {
        return rA.compareTo(rB);
      }
    });

    return Column(
      children: [
        const SizedBox(height: 4),

        // SEARCH BAR + SORT TOGGLE BUTTON
        Row(
          children: [
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2638),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E4362)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchFilter = v.trim().toLowerCase()),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search_rounded, size: 16, color: Color(0xFF0284C7)),
                    hintText: "Search builder name or ID...",
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // High to Low / Low to High Filter Button
            GestureDetector(
              onTap: () {
                setState(() {
                  _sortOrder = (_sortOrder == 'HIGH_TO_LOW') ? 'LOW_TO_HIGH' : 'HIGH_TO_LOW';
                });
              },
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2638),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE88226)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _sortOrder == 'HIGH_TO_LOW'
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: const Color(0xFFE88226),
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortOrder == 'HIGH_TO_LOW' ? "High → Low" : "Low → High",
                      style: const TextStyle(
                        color: Color(0xFFE88226),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "WORKERS LEADERBOARD (${displayed.length})",
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const Text(
              "Tap card to rate",
              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Worker List Cards
        Expanded(
          child: displayed.isEmpty
              ? const Center(
                  child: Text(
                    "No workers found matching your filter.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayed.length,
                  itemBuilder: (context, index) {
                    final worker = displayed[index];
                    final username = (worker['username'] ?? '').toString().toUpperCase();
                    final fullName = (worker['full_name'] ?? username).toString();
                    final double rating = (worker['rating'] as num?)?.toDouble() ?? 5.0;
                    final tag = (worker['rating_tag'] ?? 'Skilled Builder').toString();
                    final comment = (worker['rating_comment'] ?? '').toString();
                    final Color color = _getRatingColor(rating);

                    return GestureDetector(
                      onTap: () {
                        // Switch to Rate tab with this worker pre-selected
                        setState(() {
                          _selectedWorker = username;
                          _rating = rating.toInt();
                          _selectedTag = tag;
                          _commentCtrl.text = comment;
                        });
                        _tabController.animateTo(0);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2638),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            // Rank circle
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: (index == 0 && _sortOrder == 'HIGH_TO_LOW')
                                    ? const Color(0xFFE88226)
                                    : const Color(0xFF1E4362),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                "#${index + 1}",
                                style: TextStyle(
                                  color: (index == 0 && _sortOrder == 'HIGH_TO_LOW')
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        fullName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "($username)",
                                        style: const TextStyle(
                                          color: Color(0xFF67B0D8),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          tag.toUpperCase(),
                                          style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      if (comment.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            "\"$comment\"",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 10.5,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Rating Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: color),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, color: color, size: 14),
                                  const SizedBox(width: 3),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
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
                ),
        ),
      ],
    );
  }
}