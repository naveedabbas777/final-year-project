import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/market_api_service.dart';
import 'chat_screen.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({
    super.key,
    required this.sellerUid,
    this.listingId,
  });

  final String sellerUid;
  final String? listingId;

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final _service = MarketApiService();

  Map<String, dynamic>? _seller;
  Map<String, dynamic>? _ratings;
  List<ListingDto> _sellerListings = const [];
  bool _loading = true;
  bool _savedSeller = false;
  bool _sellerIsOnline = false;
  DateTime? _sellerLastSeen;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final seller = await _service.fetchUserProfileByUid(widget.sellerUid);
      final ratings = await _service.fetchUserRatings(widget.sellerUid);
      final listings = await _service.fetchListings(sellerUid: widget.sellerUid);
      final presence = await _service.getPresence(widget.sellerUid);
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('saved_sellers') ?? const [];
      if (!mounted) return;
      
      DateTime? lastSeen;
      final lastSeenRaw = presence['lastSeen'];
      if (lastSeenRaw != null) {
        if (lastSeenRaw is DateTime) {
          lastSeen = lastSeenRaw;
        } else if (lastSeenRaw is String) {
          lastSeen = DateTime.tryParse(lastSeenRaw);
        }
      }
      
      setState(() {
        _seller = seller;
        _ratings = ratings;
        _sellerListings = listings.where((l) => l.status == 'open').toList();
        _savedSeller = saved.contains(widget.sellerUid);
        _sellerIsOnline = presence['isOnline'] == true;
        _sellerLastSeen = lastSeen;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleSavedSeller() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getStringList('saved_sellers') ?? const []).toSet();
    if (saved.contains(widget.sellerUid)) {
      saved.remove(widget.sellerUid);
    } else {
      saved.add(widget.sellerUid);
    }
    await prefs.setStringList('saved_sellers', saved.toList());
    if (!mounted) return;
    setState(() => _savedSeller = saved.contains(widget.sellerUid));
  }

  void _openChat() {
    final listingId = widget.listingId ?? (_sellerListings.isNotEmpty ? _sellerListings.first.id : null);
    if (listingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active listing to start chat.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(listingId: listingId, toUid: widget.sellerUid),
      ),
    );
  }

  void _copyPhone() {
    final phone = (_seller?['phoneNumber'] ?? '').toString();
    if (phone.isEmpty) return;
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone number copied')),
    );
  }

  String _formatPresence() {
    if (_sellerIsOnline) {
      return 'Online now';
    }
    if (_sellerLastSeen == null) {
      return 'Offline';
    }
    final now = DateTime.now();
    final diff = now.difference(_sellerLastSeen!);
    if (diff.inMinutes < 1) {
      return 'Last seen just now';
    } else if (diff.inHours < 1) {
      return 'Last seen ${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return 'Last seen ${diff.inHours}h ago';
    } else {
      return 'Last seen ${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerName = (_seller?['displayName'] ?? 'Seller').toString();
    final phone = (_seller?['phoneNumber'] ?? '').toString();
    final district = (_seller?['district'] ?? '').toString();
    final province = (_seller?['province'] ?? '').toString();
    final stats = (_ratings?['stats'] as Map?) ?? const {};
    final avg = (stats['avgScore'] ?? 0).toString();
    final count = (stats['count'] ?? 0).toString();

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('Seller Profile'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.green.shade100,
                            child: Icon(Icons.person, color: Colors.green.shade700),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sellerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(phone.isEmpty ? 'No phone provided' : phone),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                                    const SizedBox(width: 4),
                                    Text('$avg ($count ratings)'),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _sellerIsOnline ? Colors.green.shade100 : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatPresence(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _sellerIsOnline ? Colors.green.shade900 : Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _openChat,
                          icon: const Icon(Icons.message),
                          label: const Text('Chat'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: phone.isEmpty ? null : _copyPhone,
                          icon: const Icon(Icons.call),
                          label: const Text('Copy Number'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _toggleSavedSeller,
                    icon: Icon(_savedSeller ? Icons.bookmark : Icons.bookmark_border),
                    label: Text(_savedSeller ? 'Saved Seller' : 'Save Seller'),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Location'),
                      subtitle: Text(
                        [district, province].where((e) => e.trim().isNotEmpty).join(', ').isEmpty
                            ? 'Not specified'
                            : [district, province].where((e) => e.trim().isNotEmpty).join(', '),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Active Listings (${_sellerListings.length})',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.green.shade800),
                  ),
                  const SizedBox(height: 8),
                  if (_sellerListings.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No active listings yet.'),
                      ),
                    )
                  else
                    ..._sellerListings.map(
                      (row) => Card(
                        child: ListTile(
                          leading: row.imageUrls.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(row.imageUrls.first, width: 52, height: 52, fit: BoxFit.cover),
                                )
                              : Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.agriculture, color: Colors.green.shade700),
                                ),
                          title: Text('${row.cropName} • ${row.qualityGrade}'),
                          subtitle: Text('${row.quantity.toStringAsFixed(0)} ${row.unit} - ${row.district}'),
                          trailing: Text(
                            'PKR ${row.askingPrice.toStringAsFixed(0)}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade700),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
