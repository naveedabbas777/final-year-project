import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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
  bool _savedSeller = false;
  bool _showFullDescription = false;

  @override
  void initState() {
    super.initState();
    _loadSeller();
    _loadSavedState();
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

  Future<void> _loadSeller() async {
    try {
      final prof = await _service.fetchUserProfileByUid(widget.listing.sellerUid);
      if (!mounted) return;
      setState(() => _seller = prof);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
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
                    return Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1) : null));
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
                const Text('Seller', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _seller != null && (_seller!['photoUrl'] ?? '').toString().isNotEmpty
                            ? CircleAvatar(radius: 22, backgroundImage: NetworkImage(_seller!['photoUrl']))
                            : CircleAvatar(radius: 22, backgroundColor: Colors.green.shade100, child: Icon(Icons.person, color: Colors.green.shade700)),
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
                TextButton(
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
                  child: const Text('View seller profile'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(listingId: l.id, toUid: l.sellerUid)));
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Message Seller'),
                ),
                const SizedBox(height: 16),
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
                    final lat = (_seller?['lat'] as num?)?.toDouble();
                    final lon = (_seller?['lon'] as num?)?.toDouble();
                    if (lat == null || lon == null) {
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
                          key: ValueKey('seller-map-${lat}_$lon'),
                          styleUri: MapboxStyles.MAPBOX_STREETS,
                          cameraOptions: CameraOptions(
                            center: Point(coordinates: Position(lon, lat)),
                            zoom: 12,
                          ),
                          onMapCreated: (map) {
                            map.flyTo(
                              CameraOptions(
                                center: Point(coordinates: Position(lon, lat)),
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
