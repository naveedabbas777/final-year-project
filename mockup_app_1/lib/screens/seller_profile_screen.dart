import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/market_api_service.dart';
import 'chat_screen.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

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
  List<ListingDto> _allSellerListings = const [];
  bool _loading = true;
  bool _savedSeller = false;
  bool _sellerIsOnline = false;
  DateTime? _sellerLastSeen;

  String get _sellerName {
    return (_seller?['displayName'] ?? _seller?['name'] ?? 'Seller').toString();
  }

  String get _sellerUsername {
    return (_seller?['name'] ?? _seller?['displayName'] ?? widget.sellerUid)
        .toString();
  }

  String get _sellerFullName {
    return (_seller?['displayName'] ?? _seller?['name'] ?? 'Seller').toString();
  }

  String get _sellerPhone {
    return (_seller?['phoneNumber'] ?? _seller?['phone'] ?? '').toString();
  }

  String get _sellerEmail {
    return (_seller?['email'] ?? '').toString();
  }

  String get _sellerPhotoUrl {
    return (_seller?['photoUrl'] ?? _seller?['photoURL'] ?? '').toString();
  }

  String get _sellerDistrict {
    return (_seller?['district'] ?? '').toString();
  }

  String get _sellerProvince {
    return (_seller?['province'] ?? '').toString();
  }

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
      final listings = await _service.fetchListings(
        sellerUid: widget.sellerUid,
      );
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
        _allSellerListings = listings;
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
    final listingId =
        widget.listingId ??
        (_sellerListings.isNotEmpty ? _sellerListings.first.id : null);
    if (listingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active listing to start chat.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ChatScreen(listingId: listingId, toUid: widget.sellerUid),
      ),
    );
  }

  void _copyPhone() {
    final phone = _sellerPhone;
    if (phone.isEmpty) return;
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Phone number copied')));
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

  void _openPhotoViewer(String photoUrl, String title) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 80,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Text(
                          'Pinch to zoom',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
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

  Widget _buildProfileInfoTile(IconData icon, String label, String value) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.green.shade700),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        value.isEmpty ? 'Not provided' : value,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sellerName = _sellerName;
    final username = _sellerUsername;
    final fullName = _sellerFullName;
    final phone = _sellerPhone;
    final email = _sellerEmail;
    final photoUrl = _sellerPhotoUrl;
    final district = _sellerDistrict;
    final province = _sellerProvince;
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
      body:
          _loading
              ? const AsyncLoadingWidget()
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
                            GestureDetector(
                              onTap:
                                  photoUrl.isEmpty
                                      ? null
                                      : () => _openPhotoViewer(
                                        photoUrl,
                                        sellerName,
                                      ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.green.shade100,
                                backgroundImage:
                                    photoUrl.isNotEmpty
                                        ? NetworkImage(photoUrl)
                                        : null,
                                child:
                                    photoUrl.isEmpty
                                        ? Icon(
                                          Icons.person,
                                          color: Colors.green.shade700,
                                        )
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sellerName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    phone.isEmpty ? 'No phone provided' : phone,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Colors.amber.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text('$avg ($count ratings)'),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _sellerIsOnline
                                                  ? Colors.green.shade100
                                                  : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          _formatPresence(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                _sellerIsOnline
                                                    ? Colors.green.shade900
                                                    : Colors.grey.shade800,
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            _buildProfileInfoTile(
                              Icons.person_outline,
                              'Username',
                              username,
                            ),
                            Divider(height: 16, color: Colors.green.shade100),
                            _buildProfileInfoTile(
                              Icons.badge_outlined,
                              'Full name',
                              fullName,
                            ),
                            if (email.trim().isNotEmpty) ...[
                              Divider(height: 16, color: Colors.green.shade100),
                              _buildProfileInfoTile(
                                Icons.email_outlined,
                                'Email',
                                email,
                              ),
                            ],
                            if (phone.trim().isNotEmpty) ...[
                              Divider(height: 16, color: Colors.green.shade100),
                              _buildProfileInfoTile(
                                Icons.phone_outlined,
                                'Phone number',
                                phone,
                              ),
                            ],
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
                      icon: Icon(
                        _savedSeller ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      label: Text(
                        _savedSeller ? 'Saved Seller' : 'Save Seller',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: const Text('Location'),
                        subtitle: Text(
                          [district, province]
                                  .where((e) => e.trim().isNotEmpty)
                                  .join(', ')
                                  .isEmpty
                              ? 'Not specified'
                              : [
                                district,
                                province,
                              ].where((e) => e.trim().isNotEmpty).join(', '),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'All Listings (${_allSellerListings.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_allSellerListings.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No listings found for this seller.'),
                        ),
                      )
                    else
                      ..._allSellerListings.map(
                        (row) => Card(
                          child: ListTile(
                            leading:
                                row.imageUrls.isNotEmpty
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        row.imageUrls.first,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.agriculture,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                            title: Text(
                              '${row.cropName} • ${row.qualityGrade}',
                            ),
                            subtitle: Text(
                              '${row.quantity.toStringAsFixed(0)} ${row.unit} - ${row.district} • ${row.status}',
                            ),
                            trailing: Text(
                              'PKR ${row.askingPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Open Listings (${_sellerListings.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_sellerListings.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No open listings at the moment.'),
                        ),
                      )
                    else
                      ..._sellerListings.map(
                        (row) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.shopping_bag_outlined),
                            title: Text(
                              '${row.cropName} • ${row.qualityGrade}',
                            ),
                            subtitle: Text(
                              '${row.quantity.toStringAsFixed(0)} ${row.unit} - ${row.district}',
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
