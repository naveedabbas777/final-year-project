import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/market_api_service.dart';
import 'offers_screen.dart';
import 'orders_screen.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('Market'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Offers',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const OffersScreen()));
            },
            icon: const Icon(Icons.local_offer_outlined),
          ),
          IconButton(
            tooltip: 'Order history',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
            },
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Rates'), Tab(text: 'Buy/Sell')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_RatesTab(), _MarketplaceTab()],
      ),
    );
  }
}

class _RatesTab extends StatefulWidget {
  const _RatesTab();

  @override
  State<_RatesTab> createState() => _RatesTabState();
}

class _RatesTabState extends State<_RatesTab> {
  final _service = MarketApiService();
  final _cropController = TextEditingController();
  final _districtController = TextEditingController();
  bool _loading = false;
  bool _ingesting = false;
  String? _error;
  List<CropRateDto> _rates = const [];
  UserProfileDto? _me;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _load();
  }

  @override
  void dispose() {
    _cropController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final me = await _service.fetchMe();
      if (!mounted) return;
      setState(() => _me = me);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _service.fetchLatestRates(
        crop: _cropController.text,
        district: _districtController.text,
      );
      if (!mounted) return;
      setState(() => _rates = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _triggerIngestion() async {
    setState(() => _ingesting = true);
    try {
      final msg = await _service.triggerOfficialRatesIngestion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (!mounted) return;
      setState(() => _ingesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _me?.isAdmin == true;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Official Crop Rates',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cropController,
                          decoration: const InputDecoration(
                            labelText: 'Crop',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _districtController,
                          decoration: const InputDecoration(
                            labelText: 'District',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _loading ? null : _load,
                        icon: const Icon(Icons.search),
                        label: const Text('Search Rates'),
                      ),
                      if (isAdmin)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _ingesting ? null : _triggerIngestion,
                          icon:
                              _ingesting
                                  ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.cloud_download_outlined),
                          label: const Text('Ingest Official Rates'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          else if (_rates.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No rates available yet. Ingest official rates from backend.',
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  itemCount: _rates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = _rates[index];
                    return Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: Icon(
                            Icons.storefront,
                            color: Colors.green.shade700,
                          ),
                        ),
                        title: Text('${row.cropName} - ${row.marketName}'),
                        subtitle: Text(
                          '${row.district}\n${row.sourceName}\n${row.sourceUrl}',
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Min: ${row.minPrice.toStringAsFixed(0)}'),
                            Text('Max: ${row.maxPrice.toStringAsFixed(0)}'),
                            Text(
                              row.unit,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarketplaceTab extends StatefulWidget {
  const _MarketplaceTab();

  @override
  State<_MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<_MarketplaceTab> {
  final _service = MarketApiService();
  final _cropFilter = TextEditingController();
  final _districtFilter = TextEditingController();

  final _cropController = TextEditingController();
  final _districtController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();

  bool _loading = false;
  bool _creating = false;
  String? _error;
  List<ListingDto> _rows = const [];
  final List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cropFilter.dispose();
    _districtFilter.dispose();
    _cropController.dispose();
    _districtController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(limit: 5);
    if (picked.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _selectedImages
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchListings(
        crop: _cropFilter.text,
        district: _districtFilter.text,
      );
      if (!mounted) return;
      setState(() => _rows = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _createListing() async {
    final crop = _cropController.text.trim();
    final district = _districtController.text.trim();
    final qty = double.tryParse(_qtyController.text.trim());
    final price = double.tryParse(_priceController.text.trim());

    if (crop.isEmpty || district.isEmpty || qty == null || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill crop, district, quantity, and price'),
        ),
      );
      return;
    }

    setState(() => _creating = true);

    try {
      final imageUrls = <String>[];
      for (final image in _selectedImages) {
        final url = await _service.uploadListingImage(image.path);
        imageUrls.add(url);
      }

      await _service.createListing(
        cropName: crop,
        district: district,
        quantity: qty,
        askingPrice: price,
        imageUrls: imageUrls,
      );
      if (!mounted) return;
      _cropController.clear();
      _districtController.clear();
      _qtyController.clear();
      _priceController.clear();
      setState(() => _selectedImages.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing created successfully')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (!mounted) return;
      setState(() => _creating = false);
    }
  }

  Future<void> _offerDialog(ListingDto row) async {
    final offerPriceController = TextEditingController();
    final quantityController = TextEditingController();

    final approved = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Make Offer - ${row.cropName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: offerPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Offer Price'),
                ),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send'),
              ),
            ],
          ),
    );

    if (approved != true) return;

    final price = double.tryParse(offerPriceController.text.trim());
    final qty = double.tryParse(quantityController.text.trim());
    if (price == null || qty == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid offer values')));
      return;
    }

    try {
      await _service.makeOffer(
        listingId: row.id,
        offerPrice: price,
        quantity: qty,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Offer sent successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: ExpansionTile(
              title: Text(
                'Create Sell Listing',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade800,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _cropController,
                        decoration: const InputDecoration(
                          labelText: 'Crop Name',
                        ),
                      ),
                      TextField(
                        controller: _districtController,
                        decoration: const InputDecoration(
                          labelText: 'District',
                        ),
                      ),
                      TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                      ),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Asking Price',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Attach Images'),
                          ),
                          const SizedBox(width: 8),
                          Text('${_selectedImages.length} selected'),
                        ],
                      ),
                      if (_selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(width: 8),
                            itemBuilder:
                                (_, i) => ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_selectedImages[i].path),
                                    fit: BoxFit.cover,
                                    width: 72,
                                    errorBuilder:
                                        (_, __, ___) => Container(
                                          width: 72,
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                            Icons.image_not_supported_outlined,
                                          ),
                                        ),
                                  ),
                                ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _creating ? null : _createListing,
                          icon:
                              _creating
                                  ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.add),
                          label: const Text('Create Listing'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cropFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filter crop',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _districtFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filter district',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _load,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          else if (_rows.isEmpty)
            const Expanded(
              child: Center(child: Text('No active listings found.')),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: ListTile(
                        leading:
                            row.imageUrls.isNotEmpty
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    row.imageUrls.first,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => const Icon(Icons.image),
                                  ),
                                )
                                : const Icon(Icons.agriculture),
                        title: Text('${row.cropName} (${row.qualityGrade})'),
                        subtitle: Text(
                          '${row.district} • Qty: ${row.quantity.toStringAsFixed(0)} ${row.unit} • Seller: ${row.sellerUid.substring(0, row.sellerUid.length > 6 ? 6 : row.sellerUid.length)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('PKR ${row.askingPrice.toStringAsFixed(0)}'),
                            const SizedBox(height: 4),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _offerDialog(row),
                              child: const Text('Offer'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
