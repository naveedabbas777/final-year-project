import 'package:flutter/material.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';
import 'package:mockup_app/widgets/photo_viewer.dart';
import 'package:mockup_app/config/app_router.dart';

import '../services/market_api_service.dart';
import '../utils/error_presenter.dart';
import 'listing_detail_screen.dart';
import 'offers_screen.dart';
import 'orders_screen.dart';
import 'admin/admin_console_shell.dart';
import 'my_listings_screen.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.storefront_rounded, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              _t('Marketplace', 'مارکیٹ پلیس'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade800, Colors.green.shade600],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 52,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              tooltip: _t('Offers', 'آفرز'),
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const OffersScreen()));
              },
              icon: const Icon(Icons.local_offer_outlined, size: 20),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              tooltip: _t('Order history', 'آرڈر ہسٹری'),
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
              },
              icon: const Icon(Icons.receipt_long_outlined, size: 20),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          dividerColor: Colors.transparent,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.trending_up_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text(_t('Rates', 'ریٹس')),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(_t('Buy/Sell', 'خرید/فروخت')),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(_t('My Items', 'میری اشیاء')),
                ],
              ),
            ),
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
  List<CropRateDto> _allRates = const []; // Full unfiltered list
  List<String> _cropOptions = const [];
  List<String> _districtOptions = const [];
  String? _selectedCropFilter;
  String? _selectedDistrictFilter;
  UserProfileDto? _me;
  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

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
      // Fetch all rates (no server-side filter) so dropdown options stay complete
      final rows = await _service.fetchLatestRates();
      if (!mounted) return;
      setState(() {
        _allRates = rows;
        // Build options from the FULL list so they never shrink
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

  /// Apply all filters client-side: text search, crop dropdown, district dropdown
  List<CropRateDto> get _filteredRates {
    final query = _searchController.text.trim().toLowerCase();
    return _allRates.where((row) {
      // Dropdown filters
      if (_selectedCropFilter != null && row.cropName != _selectedCropFilter)
        return false;
      if (_selectedDistrictFilter != null &&
          row.district != _selectedDistrictFilter)
        return false;
      // Text search
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
            ? _t(
              'No rates available yet.\nIngest official rates from the backend.',
              'ابھی کوئی ریٹس دستیاب نہیں۔\nبیک اینڈ سے سرکاری ریٹس انجیست کریں۔',
            )
            : _t('No active listings found.', 'کوئی فعال لسٹنگ نہیں ملی۔');
    final actionLabel =
        _error != null ? _t('Retry', 'دوبارہ کوشش') : _t('Refresh', 'ریفریش');
    final iconData =
        _error != null
            ? Icons.error_outline
            : isRatesTab
            ? Icons.trending_up
            : Icons.inbox_outlined;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    _error != null ? Colors.red.shade50 : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                size: 64,
                color:
                    _error != null
                        ? Colors.red.shade400
                        : Colors.green.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel),
                ),
                if (_error != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(_t('Go Back', 'واپس جائیں')),
                  ),
                ],
              ],
            ),
          ],
        ),
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
                    _t('Official Crop Rates', 'سرکاری فصل ریٹس'),
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
                              builder: (_) => const AdminConsoleShell(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.admin_panel_settings),
                        label: Text(
                          _t('Open Admin Console', 'ایڈمن کنسول کھولیں'),
                        ),
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
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              isDense: true,
                              hintText: _t('Search', 'تلاش کریں'),
                              prefixIcon: const Icon(Icons.search, size: 18),
                              border: const OutlineInputBorder(),
                              suffixIcon:
                                  _searchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                        tooltip: _t(
                                          'Clear search',
                                          'تلاش صاف کریں',
                                        ),
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
                            value: _selectedCropFilter,
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              labelText: _t('Crop', 'فصل'),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  _t('All crops', 'تمام فصلیں'),
                                  style: const TextStyle(color: AppColors.textPrimary),
                                ),
                              ),
                              ..._cropOptions.map(
                                (value) => DropdownMenuItem<String?>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: const TextStyle(color: AppColors.textPrimary),
                                  ),
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
                            value: _selectedDistrictFilter,
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              labelText: _t('District', 'ضلع'),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  _t('All districts', 'تمام اضلاع'),
                                  style: const TextStyle(color: AppColors.textPrimary),
                                ),
                              ),
                              ..._districtOptions.map(
                                (value) => DropdownMenuItem<String?>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: const TextStyle(color: AppColors.textPrimary),
                                  ),
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
                            onPressed: () => setState(() {}),
                            child: Text(_t('Apply', 'لاگو کریں')),
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
                                      : Text(_t('Ingest', 'انجیست')),
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
                                      _t('Min Price', 'کم از کم قیمت'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'PKR ${row.minPrice.toStringAsFixed(0)}',
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
                                      _t('Max Price', 'زیادہ سے زیادہ قیمت'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'PKR ${row.maxPrice.toStringAsFixed(0)}',
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
                                      _t('Unit', 'یونٹ'),
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
  String? _error;
  bool _loadingMoreListings = false;
  List<ListingDto> _rows = const [];
  List<ListingDto> get _filteredRows {
    final query = _searchController.text.trim().toLowerCase();
    return _rows.where((row) {
      if (_selectedCropFilter != null && row.cropName != _selectedCropFilter) {
        return false;
      }
      if (_selectedDistrictFilter != null &&
          row.district != _selectedDistrictFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return row.cropName.toLowerCase().contains(query) ||
          row.qualityGrade.toLowerCase().contains(query) ||
          row.district.toLowerCase().contains(query) ||
          row.sellerUid.toLowerCase().contains(query);
    }).toList();
  }

  final Map<String, int> _unreadCounts = <String, int>{};

  // Filter / pagination state for the browse tab
  List<String> _cropOptions = const [];
  List<String> _districtOptions = const [];
  String? _selectedCropFilter;
  String? _selectedDistrictFilter;
  int _listingLimit = 20;
  bool _hasMoreListings = true;
  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMoreListings = true;
      _rows = const [];
      _unreadCounts.clear();
    });
    try {
      final data = await _service.fetchListingsWithCache(
        crop: _selectedCropFilter,
        district: _selectedDistrictFilter,
        status: 'open', // Only show open listings in browse
        limit: _listingLimit,
      );
      if (!mounted) return;
      setState(() {
        _rows = data;
        _hasMoreListings = data.length >= _listingLimit;
        _cropOptions = _buildOptions(data.map((row) => row.cropName));
        _districtOptions = _buildOptions(data.map((row) => row.district));
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

  Future<void> _loadMoreListings() async {
    if (_loadingMoreListings || !_hasMoreListings || _rows.isEmpty) return;
    final cursor = _rows.last.createdAt;
    setState(() => _loadingMoreListings = true);
    try {
      final more = await _service.fetchListings(
        crop: _selectedCropFilter,
        district: _selectedDistrictFilter,
        status: 'open',
        limit: _listingLimit,
        before: cursor,
      );
      if (!mounted) return;
      setState(() {
        final ids = _rows.map((row) => row.id).toSet();
        _rows = [..._rows, ...more.where((row) => !ids.contains(row.id))];
        _hasMoreListings = more.length >= _listingLimit;
      });
      await _service.cacheListings(
        crop: _selectedCropFilter,
        district: _selectedDistrictFilter,
        listings: _rows,
      );
      _fetchUnreadCountsInBackground(more);
    } finally {
      if (mounted) setState(() => _loadingMoreListings = false);
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
            : _t('No active listings found.', 'کوئی فعال لسٹنگ نہیں ملی۔');
    final actionLabel =
        _error != null ? _t('Retry', 'دوبارہ کوشش') : _t('Refresh', 'ریفریش');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    _error != null ? Colors.red.shade50 : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _error != null
                    ? Icons.error_outline
                    : Icons.shopping_basket_outlined,
                size: 64,
                color:
                    _error != null
                        ? Colors.red.shade400
                        : Colors.green.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel),
                ),
                if (_error != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(_t('Go Back', 'واپس جائیں')),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _offerDialog(ListingDto row) async {
    final offerPriceController = TextEditingController();
    final quantityController = TextEditingController();

    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // Use sheetCtx (the sheet's own BuildContext) for Navigator.pop so we
      // always close the bottom sheet rather than the wrong route.
      builder:
          (sheetCtx) => Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_t('Make Offer', 'آفر دیں')} - ${row.cropName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: offerPriceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: _t('Offer Price (PKR)', 'آفر قیمت (PKR)'),
                        prefixIcon: Icon(Icons.payments_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: '${_t('Quantity', 'مقدار')} (${row.unit})',
                        prefixIcon: const Icon(Icons.scale_outlined),
                        border: const OutlineInputBorder(),
                        hintText:
                            '${_t('Max', 'زیادہ سے زیادہ')}: ${row.quantity.toStringAsFixed(0)}',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetCtx, false),
                            child: Text(_t('Cancel', 'منسوخ')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(sheetCtx, true),
                            child: Text(_t('Send Offer', 'آفر بھیجیں')),
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
      _showError(_t('Invalid offer values', 'آفر کی قدریں درست نہیں'));
      return;
    }

    try {
      await _service.makeOffer(
        listingId: row.id,
        offerPrice: price,
        quantity: qty,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Offer sent successfully', 'آفر کامیابی سے بھیج دی گئی'),
          ),
        ),
      );
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
                      '${_t('Message Seller', 'فروخت کنندہ کو پیغام')} - ${row.cropName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<UserProfileDto>(
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
                                    prof.photoUrl.isNotEmpty
                                        ? () => PhotoViewer.show(
                                          context,
                                          url: prof.photoUrl,
                                          caption: prof.primaryName,
                                        )
                                        : null,
                                child:
                                    prof.photoUrl.isNotEmpty
                                        ? CircleAvatar(
                                          backgroundImage: NetworkImage(
                                            prof.photoUrl,
                                          ),
                                        )
                                        : CircleAvatar(
                                          backgroundColor:
                                              Colors.green.shade100,
                                          child: Text(
                                            prof.initials,
                                            style: TextStyle(
                                              color: Colors.green.shade800,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                              ),
                              title: Text(prof.primaryName),
                              subtitle: Text(
                                prof.contactPhone.isNotEmpty
                                    ? prof.contactPhone
                                    : _t('Contact hidden', 'رابطہ چھپایا گیا'),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: _t('Message', 'پیغام'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(_t('Cancel', 'منسوخ')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(_t('Send', 'بھیجیں')),
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
      _showError(_t('Please enter a message', 'براہ کرم پیغام درج کریں'));
      return;
    }

    try {
      await service.sendMessage(
        message: text,
        listingId: row.id,
        toUid: row.sellerUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Message sent', 'پیغام بھیج دیا گیا'))),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(ErrorPresenter.present(e));
    }
  }

  Widget _buildListingCard(ListingDto row) {
    final unreadCount = _unreadCounts[row.id] ?? 0;

    return InkWell(
      onTap: () async {
        await Navigator.of(
          context,
        ).push(AppRoutes.slideRight(ListingDetailScreen(listing: row)));
        // Refresh unread count after returning from detail screen
        if (mounted) {
          try {
            final count = await _service.getUnreadCount(row.id);
            setState(() => _unreadCounts[row.id] = count);
          } catch (_) {}
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        shadowColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'listing_image_${row.id}',
                child:
                    row.imageUrls.isNotEmpty
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            row.imageUrls.first,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        )
                        : Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.agriculture,
                            color: Colors.green.shade400,
                            size: 28,
                          ),
                        ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row.cropName} • ${_t('Grade', 'گریڈ')} ${row.qualityGrade}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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
                              fontSize: 12,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${_t('Qty', 'مقدار')}: ${row.quantity.toStringAsFixed(0)} ${row.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'PKR ${row.askingPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mark_chat_unread,
                                  size: 12,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$unreadCount new',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _offerDialog(row),
                              child: Text(
                                _t('Make Offer', 'آفر دیں'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                                foregroundColor: Colors.green.shade800,
                                elevation: 0,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _messageSellerDialog(row),
                              child: Text(
                                _t('Message', 'پیغام'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
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
                        _t('Filter Products', 'مصنوعات فلٹر کریں'),
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
                                value: _selectedCropFilter,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: _t('Crop', 'فصل'),
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      _t('All crops', 'تمام فصلیں'),
                                      style: const TextStyle(color: AppColors.textPrimary),
                                    ),
                                  ),
                                  ..._cropOptions.map(
                                    (value) => DropdownMenuItem<String?>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: const TextStyle(color: AppColors.textPrimary),
                                      ),
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
                                value: _selectedDistrictFilter,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: _t('District', 'ضلع'),
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      _t('All districts', 'تمام اضلاع'),
                                      style: const TextStyle(color: AppColors.textPrimary),
                                    ),
                                  ),
                                  ..._districtOptions.map(
                                    (value) => DropdownMenuItem<String?>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: const TextStyle(color: AppColors.textPrimary),
                                      ),
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
                                child: Text(_t('Apply', 'لاگو کریں')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 96,
                              child: OutlinedButton(
                                onPressed:
                                    _selectedCropFilter != null ||
                                            _selectedDistrictFilter != null
                                        ? () {
                                          setState(() {
                                            _selectedCropFilter = null;
                                            _selectedDistrictFilter = null;
                                          });
                                          _load();
                                        }
                                        : null,
                                child: Text(_t('Clear', 'صاف')),
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
                      itemCount:
                          _filteredRows.length + (_hasMoreListings ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (_hasMoreListings && index == _filteredRows.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Center(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _loadingMoreListings
                                        ? null
                                        : _loadMoreListings,
                                icon:
                                    _loadingMoreListings
                                        ? const CompactLoadingIndicator(
                                          size: 16,
                                        )
                                        : const Icon(Icons.expand_more),
                                label: Text(
                                  _loadingMoreListings
                                      ? _t(
                                        'Loading more...',
                                        'مزید لوڈ ہو رہا ہے...',
                                      )
                                      : _t(
                                        'Load more listings',
                                        'مزید لسٹنگز لوڈ کریں',
                                      ),
                                ),
                              ),
                            ),
                          );
                        }
                        return _buildListingCard(_filteredRows[index]);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
