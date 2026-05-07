import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

import '../services/market_api_service.dart';
import 'chat_screen.dart';
import 'seller_profile_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listing});

  final ListingDto listing;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _service = MarketApiService();
  Map<String, dynamic>? _seller;
  Map<String, dynamic>? _sellerRatings;
  bool _savedSeller = false;
  bool _showFullDescription = false;
  bool _canManage = false;
  bool _loadingMessages = false;
  bool _loadingRatings = false;
  List<Map<String, dynamic>> _messages = const [];

  @override
  void initState() {
    super.initState();
    _loadSeller();
    _loadSavedState();
    _loadCurrentUser();
    _loadMessages();
    _loadSellerRatings();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final me = await _service.fetchMe();
      if (!mounted) return;
      setState(() => _canManage = me.firebaseUid == widget.listing.sellerUid || me.isAdmin);
    } catch (_) {}
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('saved_sellers') ?? const [];
    if (!mounted) return;
    setState(() => _savedSeller = saved.contains(widget.listing.sellerUid));
  }

  Future<void> _toggleSaveSeller() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getStringList('saved_sellers') ?? const []).toSet();
    if (saved.contains(widget.listing.sellerUid)) {
      saved.remove(widget.listing.sellerUid);
    } else {
      saved.add(widget.listing.sellerUid);
    }
    await prefs.setStringList('saved_sellers', saved.toList());
    if (!mounted) return;
    setState(() => _savedSeller = saved.contains(widget.listing.sellerUid));
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'Listed just now';
      }
      return 'Listed ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inDays == 1) {
      return 'Listed yesterday';
    } else if (diff.inDays < 30) {
      return 'Listed ${diff.inDays} days ago';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return 'Listed $months month${months == 1 ? '' : 's'} ago';
    } else {
      final years = (diff.inDays / 365).floor();
      return 'Listed $years year${years == 1 ? '' : 's'} ago';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.green;
      case 'reserved':
        return Colors.orange;
      case 'sold':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Available';
      case 'reserved':
        return 'Reserved';
      case 'sold':
        return 'Sold';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Future<void> _loadSeller() async {
    try {
      final prof = await _service.fetchUserProfileByUid(widget.listing.sellerUid);
      if (!mounted) return;
      setState(() => _seller = prof);
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    setState(() => _loadingMessages = true);
    try {
      final rows = await _service.fetchMessagesForListing(widget.listing.id, limit: 20);
      if (!mounted) return;
      setState(() => _messages = rows);
    } catch (_) {}
    finally {
      if (mounted) {
        setState(() => _loadingMessages = false);
      }
    }
  }

  Future<void> _loadSellerRatings() async {
    setState(() => _loadingRatings = true);
    try {
      final ratings = await _service.fetchUserRatings(widget.listing.sellerUid);
      if (!mounted) return;
      setState(() => _sellerRatings = ratings);
    } catch (_) {
      // Silently ignore errors - ratings are optional
    } finally {
      if (mounted) setState(() => _loadingRatings = false);
    }
  }

  Future<void> _openChat() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          listingId: widget.listing.id,
          toUid: _canManage ? null : widget.listing.sellerUid,
        ),
      ),
    );
  }
  
  void _openSellerPhotoViewer(String photoUrl, String sellerName) {
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
                        errorBuilder: (_, __, ___) => const Icon(
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.zoom_in, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sellerName,
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

  Future<void> _openEditSheet() async {
    final cropController = TextEditingController(text: widget.listing.cropName);
    final districtController = TextEditingController(text: widget.listing.district);
    final qtyController = TextEditingController(text: widget.listing.quantity.toStringAsFixed(0));
    final priceController = TextEditingController(text: widget.listing.askingPrice.toStringAsFixed(0));
    final descriptionController = TextEditingController(text: widget.listing.description);
    final unitController = TextEditingController(text: widget.listing.unit);
    String grade = widget.listing.qualityGrade;
    String status = widget.listing.status;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Edit Listing',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.green.shade800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(controller: cropController, decoration: const InputDecoration(labelText: 'Crop Name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: districtController, decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Asking Price', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: grade,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Quality Grade', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('A')),
                    DropdownMenuItem(value: 'B', child: Text('B')),
                    DropdownMenuItem(value: 'C', child: Text('C')),
                  ],
                  onChanged: (value) => grade = value ?? 'A',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('open')),
                    DropdownMenuItem(value: 'reserved', child: Text('reserved')),
                    DropdownMenuItem(value: 'sold', child: Text('sold')),
                    DropdownMenuItem(value: 'cancelled', child: Text('cancelled')),
                  ],
                  onChanged: (value) => status = value ?? 'open',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    onPressed: () async {
                      final crop = cropController.text.trim();
                      final district = districtController.text.trim();
                      final qty = double.tryParse(qtyController.text.trim());
                      final price = double.tryParse(priceController.text.trim());
                      if (crop.isEmpty || district.isEmpty || qty == null || price == null) return;
                      await _service.updateListing(
                        listingId: widget.listing.id,
                        cropName: crop,
                        district: district,
                        quantity: qty,
                        askingPrice: price,
                        unit: unitController.text.trim(),
                        qualityGrade: grade,
                        description: descriptionController.text.trim(),
                      );
                      await _service.updateListingStatus(listingId: widget.listing.id, status: status);
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext, true);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing updated')));
      await _loadSeller();
      await _loadMessages();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final recentMessages = _messages.take(4).toList();

    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('Listing'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 320,
            child: PageView.builder(
              itemCount: l.imageUrls.isEmpty ? 1 : l.imageUrls.length,
              itemBuilder: (context, i) {
                if (l.imageUrls.isEmpty) {
                  return Container(
                    color: Colors.green.shade100,
                    child: Icon(Icons.agriculture, size: 96, color: Colors.green.shade700),
                  );
                }
                return Image.network(
                  l.imageUrls[i],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CompactLoadingIndicator(size: 24));
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, size: 56),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l.cropName} • ${l.qualityGrade}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                // Availability status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _getStatusColor(l.status).withOpacity(0.2),
                      ),
                      child: Text(
                        _formatStatus(l.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(l.status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'PKR ${l.askingPrice.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.green.shade700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(l.district, style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Seller', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(
                      _formatRelativeTime(widget.listing.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap:
                              _seller != null && (_seller!['photoUrl'] ?? '').toString().isNotEmpty
                                  ? () => _openSellerPhotoViewer(
                                    _seller!['photoUrl'].toString(),
                                    (_seller?['displayName'] ?? _seller?['name'] ?? 'Seller').toString(),
                                  )
                                  : null,
                          child:
                              _seller != null && (_seller!['photoUrl'] ?? '').toString().isNotEmpty
                                  ? CircleAvatar(radius: 22, backgroundImage: NetworkImage(_seller!['photoUrl']))
                                  : CircleAvatar(radius: 22, backgroundColor: Colors.green.shade100, child: Icon(Icons.person, color: Colors.green.shade700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_seller?['displayName'] ?? 'Seller', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(_seller?['phoneNumber'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.green.shade700),
                          onPressed: _toggleSaveSeller,
                          icon: Icon(_savedSeller ? Icons.bookmark : Icons.bookmark_border),
                          label: Text(_savedSeller ? 'Saved' : 'Save Seller'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Seller ratings display
                if (_sellerRatings != null)
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.star, size: 18, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(_sellerRatings!['stats']?['avgScore'] ?? 0.0).toStringAsFixed(1)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${_sellerRatings!['stats']?['count'] ?? 0} reviews)',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if ((_sellerRatings!['recent'] as List?)?.isNotEmpty ?? false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: SizedBox(
                                    width: 260,
                                    child: Text(
                                      '${_sellerRatings!['recent'][0]['buyerName'] ?? 'Buyer'}: "${_sellerRatings!['recent'][0]['comment'] ?? ''}"',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                      onPressed: _openChat,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(_canManage ? 'Open Listing Chat' : 'Message Seller'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SellerProfileScreen(
                              sellerUid: l.sellerUid,
                              listingId: l.id,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Seller Profile'),
                    ),
                    if (_canManage)
                      OutlinedButton.icon(
                        onPressed: _openEditSheet,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Listing'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Messages',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.green.shade800),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingMessages)
                          const Center(child: CompactLoadingIndicator(size: 18))
                        else if (recentMessages.isEmpty)
                          Text(
                            'No messages yet for this listing.',
                            style: TextStyle(color: Colors.grey.shade700),
                          )
                        else
                          ...recentMessages.map(
                            (msg) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.shade100),
                                ),
                                child: Text(
                                  (msg['message'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Quantity: ${l.quantity.toStringAsFixed(0)} ${l.unit}'),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final text = l.description.trim().isEmpty
                        ? 'Fresh produce available in good condition.'
                        : l.description.trim();
                    const clamp = 120;
                    final long = text.length > clamp;
                    final shown = !_showFullDescription && long ? '${text.substring(0, clamp)}...' : text;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shown),
                        if (long)
                          TextButton(
                            onPressed: () => setState(() => _showFullDescription = !_showFullDescription),
                            child: Text(_showFullDescription ? 'See less' : 'See more'),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                const Text('Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final productLat = l.latitude;
                    final productLon = l.longitude;
                    final sellerLat = (_seller?['lat'] as num?)?.toDouble();
                    final sellerLon = (_seller?['lon'] as num?)?.toDouble();
                    
                    // Show product location map if available
                    if (productLat != null && productLon != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 190,
                          child: Stack(
                            children: [
                              MapWidget(
                                key: ValueKey('product-map-${productLat}_$productLon'),
                                styleUri: MapboxStyles.MAPBOX_STREETS,
                                cameraOptions: CameraOptions(
                                  center: Point(coordinates: Position(productLon, productLat)),
                                  zoom: 13,
                                ),
                                onMapCreated: (mapboxMap) async {
                                  final pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                                  try {
                                    await pointAnnotationManager.create(
                                      PointAnnotationOptions(
                                        geometry: Point(coordinates: Position(productLon, productLat)),
                                        iconSize: 1.5,
                                      ),
                                    );
                                  } catch (e) {
                                    debugPrint('Error adding product marker: $e');
                                  }
                                },
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade700,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Pinned Location',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    // Fall back to seller location if available
                    if (sellerLat == null || sellerLon == null) {
                      return Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade100)),
                        alignment: Alignment.center,
                        child: Text('Location approximate: ${l.district}', style: TextStyle(color: Colors.grey.shade700)),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 190,
                        child: MapWidget(
                          key: ValueKey('seller-map-${sellerLat}_$sellerLon'),
                          styleUri: MapboxStyles.MAPBOX_STREETS,
                          cameraOptions: CameraOptions(
                            center: Point(coordinates: Position(sellerLon, sellerLat)),
                            zoom: 12,
                          ),
                          onMapCreated: (map) {
                            map.flyTo(
                              CameraOptions(
                                center: Point(coordinates: Position(sellerLon, sellerLat)),
                                zoom: 12,
                              ),
                              null,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
