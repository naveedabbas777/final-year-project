import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/market_api_service.dart';
import 'chat_screen.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({super.key, required this.sellerUid, this.listingId});
  final String sellerUid;
  final String? listingId;
  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final _service = MarketApiService();
  UserProfileDto? _seller;
  Map<String, dynamic>? _ratings;
  Map<String, dynamic> _stats = {};
  List<ListingDto> _openListings = const [];
  bool _loading = true;
  bool _savedSeller = false;
  bool _canRate = false;
  String _rateBlockReason = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.fetchUserProfileByUidWithCache(widget.sellerUid)
            .then((v) async => v ?? await _service.fetchUserProfileByUid(widget.sellerUid)),
        _service.fetchUserRatings(widget.sellerUid),
        _service.fetchSellerStats(widget.sellerUid),
        _service.fetchListingsWithCache(sellerUid: widget.sellerUid),
        SharedPreferences.getInstance(),
        _service.fetchRatingEligibility(widget.sellerUid),
      ]);
      if (!mounted) return;
      final seller = results[0] as UserProfileDto?;
      final ratings = results[1] as Map<String, dynamic>;
      final stats = results[2] as Map<String, dynamic>;
      final allListings = results[3] as List<ListingDto>;
      final prefs = results[4] as SharedPreferences;
      final eligibility = results[5] as Map<String, dynamic>;
      setState(() {
        _seller = seller;
        _ratings = ratings;
        _stats = stats;
        _openListings = allListings.where((l) => l.status == 'open').toList();
        _savedSeller = (prefs.getStringList('saved_sellers') ?? []).contains(widget.sellerUid);
        _canRate = eligibility['canRate'] == true;
        _rateBlockReason = eligibility['reason']?.toString() ?? '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getStringList('saved_sellers') ?? []).toSet();
    saved.contains(widget.sellerUid) ? saved.remove(widget.sellerUid) : saved.add(widget.sellerUid);
    await prefs.setStringList('saved_sellers', saved.toList());
    if (!mounted) return;
    setState(() => _savedSeller = saved.contains(widget.sellerUid));
  }

  void _openChat() {
    final id = widget.listingId ?? (_openListings.isNotEmpty ? _openListings.first.id : null);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active listing to start a chat.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(listingId: id, toUid: widget.sellerUid)));
  }

  Future<void> _showRateDialog() async {
    int selectedStars = 0;
    final commentCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Rate this Seller', style: TextStyle(fontWeight: FontWeight.w800)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tap the stars to rate your experience:', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  // Interactive star row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return GestureDetector(
                        onTap: () => setLocal(() => selectedStars = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            selectedStars > i ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: Colors.amber.shade600,
                            size: 36,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedStars == 0 ? 'Tap to select' : _starLabel(selectedStars),
                    style: TextStyle(
                      fontSize: 12,
                      color: selectedStars > 0 ? Colors.green.shade700 : Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Write a comment (optional)…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: selectedStars == 0
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await _service.rateUser(
                              targetUid: widget.sellerUid,
                              score: selectedStars,
                              comment: commentCtrl.text.trim(),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Thanks for your $selectedStars-star rating!'),
                                backgroundColor: Colors.green.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                            // Refresh only the ratings section
                            final updated = await _service.fetchUserRatings(widget.sellerUid);
                            if (mounted) setState(() => _ratings = updated);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to submit rating: $e'), backgroundColor: Colors.red.shade700),
                            );
                          }
                        },
                  child: const Text('Submit Rating'),
                ),
              ],
            );
          },
        );
      },
    );
    commentCtrl.dispose();
  }

  String _starLabel(int stars) {
    switch (stars) {
      case 1: return '⭐ Poor';
      case 2: return '⭐⭐ Fair';
      case 3: return '⭐⭐⭐ Good';
      case 4: return '⭐⭐⭐⭐ Very Good';
      case 5: return '⭐⭐⭐⭐⭐ Excellent!';
      default: return '';
    }
  }

  String _formatPresence() {
    final isOnline = _stats['isOnline'] == true;
    if (isOnline) return 'Online now';
    final raw = _stats['lastSeen'];
    if (raw == null) return 'Offline';
    final last = raw is DateTime ? raw : DateTime.tryParse(raw.toString());
    if (last == null) return 'Offline';
    final diff = DateTime.now().difference(last);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inHours < 1) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Last seen ${diff.inHours}h ago';
    return 'Last seen ${diff.inDays}d ago';
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Unknown';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, title: const Text('Seller Profile')),
        body: const AsyncLoadingWidget(),
      );
    }

    final s = _seller;
    final name = s?.primaryName ?? 'Seller';
    final photo = s?.photoUrl ?? '';
    final phone = s?.contactPhone ?? '';
    final email = s?.email ?? '';
    final district = s?.district ?? '';
    final province = s?.province ?? '';
    final address = s?.address ?? '';
    final role = s?.role ?? 'farmer';
    final roleLabel = role[0].toUpperCase() + role.substring(1);
    final joiningDate = _formatDate(s?.createdAt);
    final isOnline = _stats['isOnline'] == true;

    final stats = (_ratings?['stats'] as Map?) ?? {};
    final avgScore = (stats['avgScore'] ?? 0.0) as num;
    final ratingCount = (stats['count'] ?? 0) as num;
    final recentReviews = (_ratings?['recent'] as List?) ?? [];
    final completedOrders = (_stats['completedOrders'] ?? 0) as num;
    final totalListings = (_stats['totalListings'] ?? 0) as num;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: Colors.green.shade700,
        child: CustomScrollView(
          slivers: [
            // ── Hero header ────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: _savedSeller ? 'Saved' : 'Save seller',
                  icon: Icon(_savedSeller ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: _toggleSaved,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: Colors.white24,
                              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                              child: photo.isEmpty
                                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                      style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700))
                                  : null,
                            ),
                            Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.green.shade400 : Colors.grey.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white38),
                              ),
                              child: Text(roleLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.green.shade400.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isOnline ? Colors.green.shade300 : Colors.white24),
                              ),
                              child: Text(_formatPresence(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stats row ─────────────────────────────────────────────
                  Container(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        _statCell('${completedOrders.toInt()}', 'Orders\nCompleted', Icons.check_circle_outline, Colors.green.shade700),
                        _divider(),
                        _statCell(
                          ratingCount > 0 ? avgScore.toStringAsFixed(1) : '—',
                          '$ratingCount ${ratingCount == 1 ? 'Review' : 'Reviews'}',
                          Icons.star_rounded,
                          Colors.amber.shade700,
                        ),
                        _divider(),
                        _statCell('${totalListings.toInt()}', 'Total\nListings', Icons.inventory_2_outlined, Colors.blue.shade700),
                        _divider(),
                        _statCell(joiningDate, 'Member\nSince', Icons.calendar_today_outlined, Colors.purple.shade700),
                      ],
                    ),
                  ),

                  // ── Action buttons ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _openChat,
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Message Seller', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    side: BorderSide(color: Colors.green.shade700),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    foregroundColor: Colors.green.shade700,
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: phone));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: const Text('Phone number copied'), backgroundColor: Colors.green.shade700,
                                        behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                    );
                                  },
                                  icon: const Icon(Icons.call),
                                  label: const Text('Copy No.'),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Rate Seller button — only shown when buyer is eligible
                        if (_canRate)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                side: BorderSide(color: Colors.amber.shade600),
                                foregroundColor: Colors.amber.shade700,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _showRateDialog,
                              icon: const Icon(Icons.star_outline_rounded),
                              label: const Text('Rate this Seller', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          )
                        else
                          // Show why rating is locked
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade500),
                                const SizedBox(width: 8),
                                Text(
                                  _rateBlockReason == 'already_rated'
                                      ? 'You have already rated this seller'
                                      : _rateBlockReason == 'no_completed_order'
                                          ? 'Complete an order with this seller to rate them'
                                          : _rateBlockReason == 'cannot_rate_self'
                                              ? 'You cannot rate yourself'
                                              : 'Rating not available',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Contact & Location ────────────────────────────────────
                  _sectionCard(
                    title: 'Contact & Location',
                    icon: Icons.person_outline,
                    children: [
                      if (phone.isNotEmpty) _infoRow(Icons.phone_outlined, 'Phone', phone),
                      if (email.isNotEmpty) _infoRow(Icons.email_outlined, 'Email', email),
                      if (district.isNotEmpty) _infoRow(Icons.location_on_outlined, 'District', district),
                      if (province.isNotEmpty) _infoRow(Icons.map_outlined, 'Province', province),
                      if (address.isNotEmpty) _infoRow(Icons.home_outlined, 'Address', address),
                      if (phone.isEmpty && email.isEmpty && district.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            Icon(Icons.privacy_tip_outlined, size: 16, color: Colors.amber.shade700),
                            const SizedBox(width: 6),
                            Expanded(child: Text('Contact details are hidden until you have a shared transaction.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                          ]),
                        ),
                    ],
                  ),

                  // ── About ─────────────────────────────────────────────────
                  _sectionCard(
                    title: 'About',
                    icon: Icons.info_outline,
                    children: [
                      _infoRow(Icons.work_outline, 'Role', roleLabel),
                      _infoRow(Icons.calendar_today_outlined, 'Member since', joiningDate),
                      _infoRow(Icons.inventory_2_outlined, 'Open listings', '${_openListings.length}'),
                    ],
                  ),

                  // ── Ratings & Reviews ─────────────────────────────────────
                  if (_ratings != null)
                    _sectionCard(
                      title: 'Ratings & Reviews',
                      icon: Icons.star_rounded,
                      children: [
                        if (ratingCount > 0) ...[
                          Row(
                            children: [
                              Text(avgScore.toStringAsFixed(1),
                                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.green.shade800, height: 1)),
                              const SizedBox(width: 12),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _starRow(avgScore.toDouble()),
                                const SizedBox(height: 4),
                                Text('Based on $ratingCount ${ratingCount == 1 ? 'review' : 'reviews'}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...recentReviews.take(3).map((r) => _reviewTile(r as Map)),
                        ] else
                          Text('No reviews yet.', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),

                  // ── Open Listings ─────────────────────────────────────────
                  _sectionCard(
                    title: 'Open Listings (${_openListings.length})',
                    icon: Icons.storefront_outlined,
                    children: _openListings.isEmpty
                        ? [Text('No open listings at the moment.', style: TextStyle(color: Colors.grey.shade500))]
                        : _openListings.map((l) => _listingTile(l)).toList(),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ──────────────────────────────────────────────────────

  Widget _statCell(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, height: 1.3)),
      ]),
    );
  }

  Widget _divider() => Container(width: 1, height: 48, color: Colors.grey.shade200);

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.grey.shade900)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: Colors.green.shade600),
        const SizedBox(width: 10),
        SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _starRow(double avg) {
    return Row(children: List.generate(5, (i) {
      if (avg >= i + 1) return Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 16);
      if (avg > i) return Icon(Icons.star_half_rounded, color: Colors.amber.shade600, size: 16);
      return Icon(Icons.star_outline_rounded, color: Colors.amber.shade300, size: 16);
    }));
  }

  Widget _reviewTile(Map review) {
    final buyer = review['buyerName'] ?? review['raterUid'] ?? 'Buyer';
    final score = (review['score'] ?? 0) as num;
    final comment = (review['comment'] ?? '').toString().trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 14, backgroundColor: Colors.green.shade200,
              child: Text(buyer.isNotEmpty ? buyer[0].toUpperCase() : 'B', style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Text(buyer, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          _starRow(score.toDouble()),
          const SizedBox(width: 4),
          Text(score.toString(), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('"$comment"', style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }

  Widget _listingTile(ListingDto l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: l.imageUrls.isNotEmpty
              ? Image.network(l.imageUrls.first, width: 52, height: 52, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _cropPlaceholder())
              : _cropPlaceholder(),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${l.cropName} — Grade ${l.qualityGrade}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Text('${l.quantity.toStringAsFixed(0)} ${l.unit} • ${l.district}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ])),
        Text('PKR ${l.askingPrice.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.green.shade700, fontSize: 13)),
      ]),
    );
  }

  Widget _cropPlaceholder() => Container(
      width: 52, height: 52,
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.agriculture, color: Colors.green.shade400));
}
