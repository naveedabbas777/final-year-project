import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
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
  UserProfileDto? _seller;
  Map<String, dynamic>? _sellerRatings;
  bool _savedSeller = false;
  bool _showFullDescription = false;
  bool _canManage = false;
  bool _loadingMessages = false;
  bool _loadingMoreMessages = false;
  bool _hasMoreMessages = true;
  int _messageLimit = 20;
  List<ChatMessageDto> _messages = const [];
  int _currentImagePage = 0;
  late final PageController _imagePageController;
  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
    _loadSeller();
    _loadSavedState();
    _loadCurrentUser();
    _loadMessages();
    _loadSellerRatings();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final me = await _service.fetchMe();
      if (!mounted) return;
      setState(
        () =>
            _canManage =
                me.firebaseUid == widget.listing.sellerUid || me.isAdmin,
      );
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
      if (diff.inHours == 0) return _t('Just listed', 'ابھی شامل کی گئی');
      return '${diff.inHours}${_t('h ago', ' گھنٹے پہلے')}';
    } else if (diff.inDays == 1) {
      return _t('Yesterday', 'کل');
    } else if (diff.inDays < 30) {
      return '${diff.inDays}${_t('d ago', ' دن پہلے')}';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '${months}${_t('mo ago', ' ماہ پہلے')}';
    } else {
      final years = (diff.inDays / 365).floor();
      return '${years}${_t('y ago', ' سال پہلے')}';
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
        return _t('Available', 'دستیاب');
      case 'reserved':
        return _t('Reserved', 'ریزرو');
      case 'sold':
        return _t('Sold', 'فروخت شدہ');
      case 'cancelled':
        return _t('Cancelled', 'منسوخ');
      default:
        return status;
    }
  }

  Future<void> _loadSeller() async {
    try {
      final prof =
          await _service.fetchUserProfileByUidWithCache(
            widget.listing.sellerUid,
          ) ??
          await _service.fetchUserProfileByUid(
            widget.listing.sellerUid,
          );
      if (!mounted) return;
      setState(() => _seller = prof);
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    setState(() => _loadingMessages = true);
    try {
      final rows = await _service.fetchMessagesForListingWithCache(
        widget.listing.id,
        limit: _messageLimit,
      );
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _hasMoreMessages = rows.length >= _messageLimit;
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingMessages = false);
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_loadingMoreMessages || !_hasMoreMessages) return;
    setState(() {
      _loadingMoreMessages = true;
      _messageLimit += 20;
    });
    try {
      await _loadMessages();
    } finally {
      if (mounted) setState(() => _loadingMoreMessages = false);
    }
  }

  Future<void> _loadSellerRatings() async {
    try {
      final ratings = await _service.fetchUserRatings(widget.listing.sellerUid);
      if (!mounted) return;
      setState(() => _sellerRatings = ratings);
    } catch (_) {
      // Silently ignore — ratings are optional enrichment
    }
  }

  Future<void> _openChat() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ChatScreen(
              listingId: widget.listing.id,
              toUid: _canManage ? null : widget.listing.sellerUid,
              productName: widget.listing.cropName,
              productImageUrl: widget.listing.imageUrls.isNotEmpty ? widget.listing.imageUrls.first : null,
            ),
      ),
    );
  }

  void _openImageViewer(List<String> imageUrls, int initialIndex) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(0),
          child: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: imageUrls.length,
                itemBuilder:
                    (_, i) => InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        child: Image.network(
                          imageUrls[i],
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) => const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 64,
                              ),
                        ),
                      ),
                    ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.zoom_in,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _t('Pinch to zoom • Swipe for more', 'زوم کے لیے پنچ کریں • مزید کے لیے سوائپ کریں'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
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
                        Text(
                          _t('Pinch to zoom', 'زوم کے لیے پنچ کریں'),
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
    final districtController = TextEditingController(
      text: widget.listing.district,
    );
    final qtyController = TextEditingController(
      text: widget.listing.quantity.toStringAsFixed(0),
    );
    final priceController = TextEditingController(
      text: widget.listing.askingPrice.toStringAsFixed(0),
    );
    final descriptionController = TextEditingController(
      text: widget.listing.description,
    );
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
                        _t('Edit Listing', 'لسٹنگ ترمیم کریں'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cropController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: _t('Crop Name', 'فصل کا نام'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: districtController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: _t('District', 'ضلع'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: _t('Quantity', 'مقدار'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: _t('Asking Price', 'مانگی گئی قیمت'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unitController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: _t('Unit', 'یونٹ'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: grade,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _t('Quality Grade', 'معیار گریڈ'),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'A',
                      child: Text('A', style: const TextStyle(color: AppColors.textPrimary)),
                    ),
                    DropdownMenuItem(
                      value: 'B',
                      child: Text('B', style: const TextStyle(color: AppColors.textPrimary)),
                    ),
                    DropdownMenuItem(
                      value: 'C',
                      child: Text('C', style: const TextStyle(color: AppColors.textPrimary)),
                    ),
                  ],
                  onChanged: (value) => grade = value ?? 'A',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: status,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _t('Status', 'حالت'),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'open',
                      child: Text(_t('Open', 'اوپن'), style: const TextStyle(color: AppColors.textPrimary)),
                    ),
                    DropdownMenuItem(
                      value: 'reserved',
                      child: Text(_t('Reserved', 'ریزرو'), style: const TextStyle(color: AppColors.textPrimary)),
                    ),
                    DropdownMenuItem(
                      value: 'sold',
                      child: Text(_t('Sold', 'فروخت شدہ'), style: const TextStyle(color: AppColors.textPrimary)),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text(_t('Cancelled', 'منسوخ'), style: const TextStyle(color: AppColors.textPrimary)),
                    ),
                  ],
                  onChanged: (value) => status = value ?? 'open',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: _t('Description', 'تفصیل'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final crop = cropController.text.trim();
                      final district = districtController.text.trim();
                      final qty = double.tryParse(qtyController.text.trim());
                      final price = double.tryParse(
                        priceController.text.trim(),
                      );
                      if (crop.isEmpty ||
                          district.isEmpty ||
                          qty == null ||
                          price == null)
                        return;
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
                      await _service.updateListingStatus(
                        listingId: widget.listing.id,
                        status: status,
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext, true);
                    },
                    icon: const Icon(Icons.save),
                    label: Text(_t('Save Changes', 'تبدیلیاں محفوظ کریں')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('Listing updated', 'لسٹنگ اپڈیٹ ہو گئی'))));
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
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade800, Colors.green.shade600],
                ),
              ),
              child: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'listing_image_${l.id}',
                      child: PageView.builder(
                        controller: _imagePageController,
                        onPageChanged:
                            (page) => setState(() => _currentImagePage = page),
                        itemCount: l.imageUrls.isEmpty ? 1 : l.imageUrls.length,
                        itemBuilder: (context, i) {
                          if (l.imageUrls.isEmpty) {
                            return Container(
                              color: Colors.green.shade100,
                              child: Icon(
                                Icons.agriculture,
                                size: 96,
                                color: Colors.green.shade700,
                              ),
                            );
                          }
                          return GestureDetector(
                            onTap: () => _openImageViewer(l.imageUrls, i),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  l.imageUrls[i],
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: CompactLoadingIndicator(size: 24),
                                    );
                                  },
                                  errorBuilder:
                                      (_, __, ___) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 56,
                                        ),
                                      ),
                                ),
                                // Dark gradient overlay for better back button visibility
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.center,
                                      colors: [
                                        Colors.black54,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Page indicator dots
                    if (l.imageUrls.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(l.imageUrls.length, (i) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _currentImagePage == i ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color:
                                    _currentImagePage == i
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.4),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            foregroundColor: Colors.white,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  tooltip: _t('Share listing', 'لسٹنگ شیئر کریں'),
                  icon: const Icon(Icons.share_rounded, size: 20),
                  onPressed: () {
                    final text =
                        '${l.cropName} - ${_t('Grade', 'گریڈ')} ${l.qualityGrade}\n'
                        'PKR ${l.askingPrice.toStringAsFixed(0)} per ${l.unit}\n'
                        '${_t('District', 'ضلع')}: ${l.district}\n'
                        '${_t('Digital Kissan Marketplace', 'ڈیجیٹل کسان مارکیٹ پلیس')}';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _t('Listing details copied to clipboard', 'لسٹنگ کی تفصیلات کلپ بورڈ میں کاپی ہو گئیں'),
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${l.cropName} • ${_t('Grade', 'گریڈ')} ${l.qualityGrade}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: _getStatusColor(l.status).withOpacity(0.15),
                          border: Border.all(
                            color: _getStatusColor(l.status).withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          _formatStatus(l.status),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _getStatusColor(l.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Price section - more prominent
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 22,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PKR ${l.askingPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade800,
                              ),
                            ),
                            Text(
                              '${_t('per', 'فی')} ${l.unit}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.scale_outlined,
                                size: 14,
                                color: Colors.amber.shade800,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${l.quantity.toStringAsFixed(0)} ${l.unit}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Time + district row
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        l.district,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        _formatRelativeTime(widget.listing.createdAt),
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ── Description ─────────────────────────────────────────
                  Text(
                    _t('Description', 'تفصیل'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final text =
                          l.description.trim().isEmpty
                              ? _t('Fresh produce available in good condition.', 'تازہ پیداوار اچھی حالت میں دستیاب ہے۔')
                              : l.description.trim();
                      const clamp = 180;
                      final long = text.length > clamp;
                      final shown =
                          !_showFullDescription && long
                              ? '${text.substring(0, clamp)}...'
                              : text;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shown,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.55,
                            ),
                          ),
                          if (long)
                            TextButton(
                              onPressed: () => setState(
                                () => _showFullDescription = !_showFullDescription,
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: Colors.green.shade700,
                              ),
                              child: Text(
                                _showFullDescription ? _t('▲ Show less', '▲ کم دکھائیں') : _t('▼ Show more', '▼ مزید دکھائیں'),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap:
                                _seller?.photoUrl.isNotEmpty == true
                                    ? () => _openSellerPhotoViewer(
                                      _seller!.photoUrl,
                                      _seller!.primaryName,
                                    )
                                    : null,
                            child:
                                _seller?.photoUrl.isNotEmpty == true
                                    ? CircleAvatar(
                                      radius: 22,
                                      backgroundImage: NetworkImage(
                                        _seller!.photoUrl,
                                      ),
                                    )
                                    : CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.green.shade100,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _seller?.primaryName ?? _t('Seller', 'فروخت کنندہ'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _seller?.contactPhone ?? '',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                            ),
                            onPressed: _toggleSaveSeller,
                            icon: Icon(
                              _savedSeller
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                            ),
                            label: Text(_savedSeller ? _t('Saved', 'محفوظ') : _t('Save Seller', 'فروخت کنندہ محفوظ کریں')),
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
                                    Icon(
                                      Icons.star,
                                      size: 18,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(_sellerRatings!['stats']?['avgScore'] ?? 0.0).toStringAsFixed(1)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${_sellerRatings!['stats']?['count'] ?? 0} ${_t('reviews', 'ریویوز')})',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if ((_sellerRatings!['recent'] as List?)
                                        ?.isNotEmpty ??
                                    false)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: SizedBox(
                                      width: 260,
                                      child: Text(
                                        '${_sellerRatings!['recent'][0]['buyerName'] ?? _t('Buyer', 'خریدار')}: "${_sellerRatings!['recent'][0]['comment'] ?? ''}"',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _openChat,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(
                          _canManage ? _t('Open Listing Chat', 'لسٹنگ چیٹ کھولیں') : _t('Message Seller', 'فروخت کنندہ کو پیغام'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => SellerProfileScreen(
                                    sellerUid: l.sellerUid,
                                    listingId: l.id,
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_outline),
                        label: Text(
                          _t('Seller Profile', 'فروخت کنندہ پروفائل'),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_canManage)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _openEditSheet,
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(
                            _t('Edit Listing', 'لسٹنگ ترمیم کریں'),
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('Recent Messages', 'حالیہ پیغامات'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _t('Showing the latest conversation activity for this listing.', 'اس لسٹنگ کے لیے تازہ ترین گفتگو کی سرگرمی دکھائی جا رہی ہے۔'),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_loadingMessages)
                            const Center(
                              child: CompactLoadingIndicator(size: 18),
                            )
                          else if (recentMessages.isEmpty)
                            Text(
                              _t('No messages yet for this listing.', 'اس لسٹنگ کے لیے ابھی کوئی پیغام نہیں۔'),
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
                                    border: Border.all(
                                      color: Colors.green.shade100,
                                    ),
                                  ),
                                  child: Text(
                                    msg.previewText,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ),
                          if (_hasMoreMessages)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed:
                                    _loadingMoreMessages
                                        ? null
                                        : _loadMoreMessages,
                                icon:
                                    _loadingMoreMessages
                                        ? const CompactLoadingIndicator(
                                          size: 14,
                                        )
                                        : const Icon(Icons.more_horiz),
                                label: Text(
                                  _loadingMoreMessages
                                      ? _t('Loading more...', 'مزید لوڈ ہو رہا ہے...')
                                      : _t('Load more messages', 'مزید پیغامات لوڈ کریں'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t('Location', 'مقام'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final productLat = l.latitude;
                      final productLon = l.longitude;
                      final sellerLat = _seller?.latitude;
                      final sellerLon = _seller?.longitude;

                      // Show product location map if available
                      if (productLat != null && productLon != null) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 190,
                            child: Stack(
                              children: [
                                MapWidget(
                                  key: ValueKey(
                                    'product-map-${productLat}_$productLon',
                                  ),
                                  styleUri: MapboxStyles.MAPBOX_STREETS,
                                  cameraOptions: CameraOptions(
                                    center: Point(
                                      coordinates: Position(
                                        productLon,
                                        productLat,
                                      ),
                                    ),
                                    zoom: 13,
                                  ),
                                  onMapCreated: (mapboxMap) async {
                                    final pointAnnotationManager =
                                        await mapboxMap.annotations
                                            .createPointAnnotationManager();
                                    try {
                                      await pointAnnotationManager.create(
                                        PointAnnotationOptions(
                                          geometry: Point(
                                            coordinates: Position(
                                              productLon,
                                              productLat,
                                            ),
                                          ),
                                          iconSize: 1.5,
                                        ),
                                      );
                                    } catch (e) {
                                      debugPrint(
                                        'Error adding product marker: $e',
                                      );
                                    }
                                  },
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade700,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _t('Pinned Location', 'پن شدہ مقام'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
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
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${_t('Location approximate', 'تقریبی مقام')}: ${l.district}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
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
                              center: Point(
                                coordinates: Position(sellerLon, sellerLat),
                              ),
                              zoom: 12,
                            ),
                            onMapCreated: (map) {
                              map.flyTo(
                                CameraOptions(
                                  center: Point(
                                    coordinates: Position(sellerLon, sellerLat),
                                  ),
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
