import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

import '../services/market_api_service.dart';
import '../utils/error_presenter.dart';
import '../utils/form_validators.dart';
import 'listing_detail_screen.dart';
import 'offers_screen.dart';
import 'orders_screen.dart';
import 'admin_dashboard_screen.dart';
import 'my_listings_screen.dart';

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Market'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 48,
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
          indicatorWeight: 2,
          labelPadding: const EdgeInsets.symmetric(horizontal: 10),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'Rates'),
            Tab(text: 'Buy/Sell'),
            Tab(text: 'Mine'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_RatesTab(), _MarketplaceTab(), MyListingsScreen()],
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
  final _searchController = TextEditingController();

  bool _loading = false;
  bool _ingesting = false;
  String? _error;
  List<CropRateDto> _rates = const [];
  List<String> _cropOptions = const [];
  List<String> _districtOptions = const [];
  String? _selectedCropFilter;
  String? _selectedDistrictFilter;
  UserProfileDto? _me;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
        crop: _selectedCropFilter,
        district: _selectedDistrictFilter,
      );
      if (!mounted) return;
      setState(() {
        _rates = rows;
        _cropOptions = _buildOptions(rows.map((row) => row.cropName));
        _districtOptions = _buildOptions(rows.map((row) => row.district));
      });
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

  List<String> _buildOptions(Iterable<String> values) {
    final options =
        values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();
    options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  List<CropRateDto> get _filteredRates {
    final query = _searchController.text.trim().toLowerCase();
    return _rates.where((row) {
      if (query.isEmpty) return true;
      return row.cropName.toLowerCase().contains(query) ||
          row.marketName.toLowerCase().contains(query) ||
          row.district.toLowerCase().contains(query) ||
          row.sourceName.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildEmptyOrError({required bool isRatesTab}) {
    final message =
        _error != null
            ? ErrorPresenter.present(_error!)
            : isRatesTab
            ? 'No rates available yet. Ingest official rates from backend.'
            : 'No active listings found.';

    final actionLabel = _error != null ? 'Retry' : 'Refresh';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          if (_error != null) const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel),
              ),
              if (_error != null) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _me?.isAdmin == true;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Official Crop Rates',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isAdmin)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminDashboardScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.admin_panel_settings),
                        label: const Text('Open Admin Console'),
                      ),
                    ),
                  if (isAdmin) const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              isDense: true,
                              hintText: 'Search',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              border: const OutlineInputBorder(),
                              suffixIcon:
                                  _searchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                        tooltip: 'Clear search',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                      ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 134,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedCropFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              labelText: 'Crop',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All crops'),
                              ),
                              ..._cropOptions.map(
                                (value) => DropdownMenuItem<String?>(
                                  value: value,
                                  child: Text(value),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedCropFilter = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 146,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedDistrictFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              labelText: 'District',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All districts'),
                              ),
                              ..._districtOptions.map(
                                (value) => DropdownMenuItem<String?>(
                                  value: value,
                                  child: Text(value),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedDistrictFilter = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 84,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _loading ? null : _load,
                            child: const Text('Apply'),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 96,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _ingesting ? null : _triggerIngestion,
                              child:
                                  _ingesting
                                      ? const CompactLoadingIndicator(
                                        size: 16,
                                        color: Colors.white,
                                      )
                                      : const Text('Ingest'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: AsyncLoadingWidget())
          else if (_error != null || _filteredRates.isEmpty)
            Expanded(child: _buildEmptyOrError(isRatesTab: true))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  itemCount: _filteredRates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final row = _filteredRates[index];
                    return Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green.shade100,
                                  radius: 22,
                                  child: Icon(
                                    Icons.storefront,
                                    color: Colors.green.shade700,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${row.cropName} - ${row.marketName}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        row.district,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(height: 1, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Min Price',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      row.minPrice.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Max Price',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      row.maxPrice.toStringAsFixed(0),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Unit',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      row.unit,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              row.sourceName,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
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
  final _searchController = TextEditingController();

  bool _loading = false;
  bool _creating = false;
  String? _error;
  List<ListingDto> _rows = const [];
  List<ListingDto> get _filteredRows {
    final query = _searchController.text.trim().toLowerCase();
    return _rows.where((row) {
      if (query.isEmpty) return true;
      return row.cropName.toLowerCase().contains(query) ||
          row.qualityGrade.toLowerCase().contains(query) ||
          row.district.toLowerCase().contains(query) ||
          row.sellerUid.toLowerCase().contains(query);
    }).toList();
  }

  List<String> _cropOptions = const [];
  List<String> _districtOptions = const [];
  String? _selectedCropFilter;
  String? _selectedDistrictFilter;
  final List<XFile> _selectedImages = [];
  final _cropController = TextEditingController();
  final _districtController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _selectedGradeController = TextEditingController(text: 'A');

  final Map<String, int> _unreadCounts = <String, int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cropController.dispose();
    _districtController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _selectedGradeController.dispose();
    super.dispose();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchListings(
        crop: _selectedCropFilter,
        district: _selectedDistrictFilter,
      );
      if (!mounted) return;
      setState(() {
        _rows = data;
        _cropOptions = _buildOptions(data.map((row) => row.cropName));
        _districtOptions = _buildOptions(data.map((row) => row.district));
        _unreadCounts.clear();
      });

      // Fetch unread counts in background (non-blocking) to avoid slow rendering
      _fetchUnreadCountsInBackground(data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Fetch unread counts in background without blocking market screen rendering
  void _fetchUnreadCountsInBackground(List<ListingDto> listings) {
    // Fire and forget: runs in parallel with 3-second timeout per listing
    Future.wait(
      listings.map((listing) async {
        try {
          final count = await _service.getUnreadCount(listing.id);
          if (mounted) {
            setState(() => _unreadCounts[listing.id] = count);
          }
        } catch (_) {
          // Silently ignore; unread count is non-critical to market display
        }
      }),
      eagerError: false,
    ).ignore();
  }

  List<String> _buildOptions(Iterable<String> values) {
    final options =
        values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();
    options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  Widget _buildEmptyOrError() {
    final message =
        _error != null
            ? ErrorPresenter.present(_error!)
            : 'No active listings found.';
    final actionLabel = _error != null ? 'Retry' : 'Refresh';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          if (_error != null) const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel),
              ),
              if (_error != null) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(limit: 5);
    if (picked.isEmpty) return;

    const maxFileSizeBytes = 5 * 1024 * 1024;
    final invalidImages = <String>[];
    for (final xfile in picked) {
      final fileSize = await xfile.length();
      if (fileSize > maxFileSizeBytes) {
        invalidImages.add('${xfile.name} (${_formatFileSize(fileSize)})');
      }
    }

    if (invalidImages.isNotEmpty) {
      if (!mounted) return;
      _showError(
        'Some images are too large (max 5MB each):\n${invalidImages.join('\n')}',
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedImages
        ..clear()
        ..addAll(picked);
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openCreateListingSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (sheetContext) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Create Sell Listing',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cropController,
                    decoration: const InputDecoration(
                      labelText: 'Crop Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _districtController,
                    decoration: const InputDecoration(
                      labelText: 'District',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Asking Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGradeController.text,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Quality Grade',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'A', child: Text('A')),
                      DropdownMenuItem(value: 'B', child: Text('B')),
                      DropdownMenuItem(value: 'C', child: Text('C')),
                    ],
                    onChanged: (value) {
                      _selectedGradeController.text = value ?? 'A';
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Attach Images'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedImages.isEmpty
                              ? 'No images selected'
                              : '${_selectedImages.length} selected',
                        ),
                      ),
                    ],
                  ),
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    FutureBuilder<int>(
                      future: _getTotalImageSize(),
                      builder: (context, snapshot) {
                        final sizeText =
                            snapshot.hasData
                                ? _formatFileSize(snapshot.data!)
                                : 'Calculating...';
                        return Text(
                          'Total: $sizeText',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed:
                          _creating
                              ? null
                              : () async {
                                final navigator = Navigator.of(sheetContext);
                                await _createListing();
                                if (mounted && navigator.canPop()) {
                                  navigator.pop();
                                }
                              },
                      icon:
                          _creating
                              ? const CompactLoadingIndicator(
                                size: 16,
                                color: Colors.white,
                              )
                              : const Icon(Icons.add),
                      label: const Text('Create Listing'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _createListing() async {
    final crop = _cropController.text.trim();
    final district = _districtController.text.trim();
    final qty = double.tryParse(_qtyController.text.trim());
    final price = double.tryParse(_priceController.text.trim());

    final cropError = FormValidators.validateCropName(crop);
    if (cropError != null) {
      _showError(cropError);
      return;
    }
    final districtError = FormValidators.validateDistrict(district);
    if (districtError != null) {
      _showError(districtError);
      return;
    }
    if (qty == null) {
      _showError('Please enter a valid quantity');
      return;
    }
    final qtyError = FormValidators.validateQuantity(qty.toString());
    if (qtyError != null) {
      _showError(qtyError);
      return;
    }
    if (price == null) {
      _showError('Please enter a valid price');
      return;
    }
    final priceError = FormValidators.validatePrice(price.toString());
    if (priceError != null) {
      _showError(priceError);
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
      _descriptionController.clear();
      _selectedGradeController.text = 'A';
      setState(() => _selectedImages.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            imageUrls.any((url) => url.contains('res.cloudinary.com'))
                ? 'Listing created and images uploaded to Cloudinary'
                : 'Listing created successfully',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showError(ErrorPresenter.present(e));
    } finally {
      if (!mounted) return;
      setState(() => _creating = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<int> _getTotalImageSize() async {
    int total = 0;
    for (final image in _selectedImages) {
      total += await image.length();
    }
    return total;
  }

  Future<void> _offerDialog(ListingDto row) async {
    final offerPriceController = TextEditingController();
    final quantityController = TextEditingController();

    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Make Offer - ${row.cropName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: offerPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Offer Price',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Send'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    if (approved != true) return;

    final price = double.tryParse(offerPriceController.text.trim());
    final qty = double.tryParse(quantityController.text.trim());
    if (price == null || qty == null) {
      if (!mounted) return;
      _showError('Invalid offer values');
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

  Future<void> _messageSellerDialog(ListingDto row) async {
    final messageController = TextEditingController();
    final service = _service;

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Message Seller - ${row.cropName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<Map<String, dynamic>>(
                      future: service.fetchUserProfileByUid(row.sellerUid),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        if (!snap.hasData) {
                          return const SizedBox.shrink();
                        }
                        final prof = snap.data!;
                        return Column(
                          children: [
                            ListTile(
                              leading: GestureDetector(
                                onTap:
                                    prof['photoUrl'] != null &&
                                            prof['photoUrl']
                                                .toString()
                                                .isNotEmpty
                                        ? () => _openSellerPhotoViewer(
                                          prof['photoUrl'].toString(),
                                          (prof['displayName'] ??
                                                  prof['name'] ??
                                                  'Seller')
                                              .toString(),
                                        )
                                        : null,
                                child:
                                    prof['photoUrl'] != null &&
                                            prof['photoUrl']
                                                .toString()
                                                .isNotEmpty
                                        ? CircleAvatar(
                                          backgroundImage: NetworkImage(
                                            prof['photoUrl'],
                                          ),
                                        )
                                        : const CircleAvatar(
                                          child: Icon(Icons.person),
                                        ),
                              ),
                              title: Text(prof['displayName'] ?? 'Seller'),
                              subtitle: Text(prof['phoneNumber'] ?? ''),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Send'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    if (sent != true) return;
    final text = messageController.text.trim();
    if (text.isEmpty) {
      if (!mounted) return;
      _showError('Please enter a message');
      return;
    }

    try {
      await service.sendMessage(
        message: text,
        listingId: row.id,
        toUid: row.sellerUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message sent')));
    } catch (e) {
      if (!mounted) return;
      _showError(ErrorPresenter.present(e));
    }
  }

  Widget _buildListingCard(ListingDto row) {
    final unreadCount = _unreadCounts[row.id] ?? 0;

    return InkWell(
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ListingDetailScreen(listing: row),
            ),
          ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row.imageUrls.isNotEmpty
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
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
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      Icons.agriculture,
                      color: Colors.green.shade700,
                      size: 22,
                    ),
                  ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row.cropName} • ${row.qualityGrade}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            row.district,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Qty: ${row.quantity.toStringAsFixed(0)} ${row.unit}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount unread',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          'PKR ${row.askingPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _offerDialog(row),
                          child: const Text('Offer'),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _messageSellerDialog(row),
                          child: const Text('Message'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter Products',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 150,
                              child: DropdownButtonFormField<String?>(
                                initialValue: _selectedCropFilter,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Crop',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All crops'),
                                  ),
                                  ..._cropOptions.map(
                                    (value) => DropdownMenuItem<String?>(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedCropFilter = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 160,
                              child: DropdownButtonFormField<String?>(
                                initialValue: _selectedDistrictFilter,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'District',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All districts'),
                                  ),
                                  ..._districtOptions.map(
                                    (value) => DropdownMenuItem<String?>(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(
                                    () => _selectedDistrictFilter = value,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 96,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _loading ? null : _load,
                                child: const Text('Apply'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Expanded(child: AsyncLoadingWidget())
              else if (_error != null || _filteredRows.isEmpty)
                Expanded(child: _buildEmptyOrError())
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      itemCount: _filteredRows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildListingCard(_filteredRows[index]);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'market_create_listing',
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            onPressed: _openCreateListingSheet,
            icon: const Icon(Icons.add),
            label: const Text('Create Listing'),
          ),
        ),
      ],
    );
  }
}
