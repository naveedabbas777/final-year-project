import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

import '../services/market_api_service.dart';
import '../utils/error_presenter.dart';
import '../utils/form_validators.dart';
import 'chat_screen.dart';
import 'listing_detail_screen.dart';
import 'listing_location_picker.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _service = MarketApiService();
  final _searchController = TextEditingController();

  final _cropController = TextEditingController();
  final _districtController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitController = TextEditingController(text: '40kg');
  final _gradeController = TextEditingController(text: 'A');
  final _descriptionController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final List<String> _editingImageUrls = [];

  bool _loading = true;
  bool _creating = false;
  bool _loadingOffers = false;
  bool _loadingMoreListings = false;
  String? _error;
  UserProfileDto? _me;
  String _selectedStatusFilter = 'all';
  String? _editingListingId;
  double? _selectedLatitude;
  double? _selectedLongitude;
  int _listingLimit = 20;
  bool _hasMoreListings = true;

  List<ListingDto> _rows = const [];
  final Map<String, List<OfferDto>> _offersByListingId =
      <String, List<OfferDto>>{};
  final Map<String, int> _unreadCounts = <String, int>{};

  static const List<String> _statusFilters = <String>[
    'all',
    'open',
    'reserved',
    'sold',
    'cancelled',
  ];

  int get _totalOffersCount => _offersByListingId.values.fold<int>(
    0,
    (sum, offers) => sum + offers.length,
  );
  int get _totalUnreadCount =>
      _unreadCounts.values.fold<int>(0, (sum, count) => sum + count);

  int _statusCount(String status) =>
      _rows.where((row) => row.status == status).length;

  List<ListingDto> get _filteredRows {
    final query = _searchController.text.trim().toLowerCase();
    return _rows.where((row) {
      if (_selectedStatusFilter != 'all' &&
          row.status != _selectedStatusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return row.cropName.toLowerCase().contains(query) ||
          row.district.toLowerCase().contains(query) ||
          row.status.toLowerCase().contains(query);
    }).toList();
  }

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
    _unitController.dispose();
    _gradeController.dispose();
    _descriptionController.dispose();
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
      UserProfileDto? me;
      try {
        me = await _service.fetchMe();
      } catch (_) {
        me = null;
      }

      final sellerUid = FirebaseAuth.instance.currentUser?.uid;
      final rows = await _service.fetchListingsWithCache(
        sellerUid: sellerUid,
        limit: _listingLimit,
      );
      if (!mounted) return;
      setState(() {
        _me = me;
        _rows = rows;
        _hasMoreListings = rows.length >= _listingLimit;
      });
      await _loadOffers();
      _fetchUnreadCountsInBackground(rows);
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
    final sellerUid = FirebaseAuth.instance.currentUser?.uid;
    final cursor = _rows.last.createdAt;
    setState(() => _loadingMoreListings = true);
    try {
      final more = await _service.fetchListings(
        sellerUid: sellerUid,
        limit: _listingLimit,
        before: cursor,
      );
      if (!mounted) return;
      setState(() {
        final ids = _rows.map((row) => row.id).toSet();
        _rows = [
          ..._rows,
          ...more.where((row) => !ids.contains(row.id)),
        ];
        _hasMoreListings = more.length >= _listingLimit;
      });
      await _service.cacheListings(
        sellerUid: sellerUid,
        listings: _rows,
      );
      _fetchUnreadCountsInBackground(more);
    } finally {
      if (mounted) setState(() => _loadingMoreListings = false);
    }
  }

  Future<void> _loadOffers() async {
    setState(() => _loadingOffers = true);
    try {
      final offers = await _service.fetchIncomingOffers();
      final grouped = <String, List<OfferDto>>{};
      for (final offer in offers) {
        grouped.putIfAbsent(offer.listingId, () => <OfferDto>[]).add(offer);
      }
      if (!mounted) return;
      setState(() {
        _offersByListingId
          ..clear()
          ..addAll(grouped);
      });
    } catch (_) {
      // Optional summary data; keep the dashboard usable if it fails.
    } finally {
      if (mounted) setState(() => _loadingOffers = false);
    }
  }

  void _fetchUnreadCountsInBackground(List<ListingDto> rows) {
    for (final row in rows) {
      _service
          .getUnreadCount(row.id)
          .then((count) {
            if (!mounted) return;
            setState(() => _unreadCounts[row.id] = count);
          })
          .catchError((_) {
            // Ignore unread-count failures to keep screen responsive.
          });
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(limit: 5);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _selectedImages
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _openCreateListingSheet() async {
    _editingListingId = null;
    _cropController.clear();
    _districtController.clear();
    _qtyController.clear();
    _priceController.clear();
    _unitController.text = '40kg';
    _gradeController.text = 'A';
    _descriptionController.clear();
    _selectedImages.clear();
    _editingImageUrls.clear();
    _selectedLatitude = null;
    _selectedLongitude = null;
    await _openListingFormSheet(
      title: 'Product Listing',
      buttonLabel: 'Create Listing',
      allowImages: true,
    );
  }

  Future<void> _openEditListingSheet(ListingDto row) async {
    _editingListingId = row.id;
    _cropController.text = row.cropName;
    _districtController.text = row.district;
    _qtyController.text = row.quantity.toStringAsFixed(0);
    _priceController.text = row.askingPrice.toStringAsFixed(0);
    _unitController.text = row.unit;
    _gradeController.text = row.qualityGrade;
    _descriptionController.text = row.description;
    _selectedImages.clear();
    _editingImageUrls
      ..clear()
      ..addAll(row.imageUrls);
    _selectedLatitude = row.latitude;
    _selectedLongitude = row.longitude;
    await _openListingFormSheet(
      title: 'Edit Listing',
      buttonLabel: 'Save Changes',
      allowImages: true,
    );
  }

  Future<void> _openListingFormSheet({
    required String title,
    required String buttonLabel,
    required bool allowImages,
  }) async {
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
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
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
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
                    initialValue: _gradeController.text,
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
                    onChanged: (value) => _gradeController.text = value ?? 'A',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.of(
                              context,
                            ).push<Map<String, dynamic>>(
                              MaterialPageRoute(
                                builder:
                                    (_) => ListingLocationPicker(
                                      initialLatitude: _selectedLatitude,
                                      initialLongitude: _selectedLongitude,
                                    ),
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                _selectedLatitude = result['latitude'];
                                _selectedLongitude = result['longitude'];
                              });
                            }
                          },
                          icon: const Icon(Icons.location_on),
                          label: const Text('Pin Location'),
                        ),
                      ),
                      if (_selectedLatitude != null &&
                          _selectedLongitude != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '📍 Pinned',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (allowImages) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            _editingListingId == null
                                ? 'Attach Images'
                                : 'Replace Images',
                          ),
                        ),
                        if (_editingListingId != null) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed:
                                _editingImageUrls.isEmpty
                                    ? null
                                    : () => setState(
                                      () => _editingImageUrls.clear(),
                                    ),
                            child: const Text('Clear Existing'),
                          ),
                        ],
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedImages.isEmpty
                                ? (_editingListingId == null
                                    ? 'No images selected'
                                    : '${_editingImageUrls.length} existing image${_editingImageUrls.length == 1 ? '' : 's'}')
                                : '${_selectedImages.length} new image${_selectedImages.length == 1 ? '' : 's'} selected',
                          ),
                        ),
                      ],
                    ),
                    if (_editingListingId != null && _selectedImages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Saving will replace existing images with selected images.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    if (_editingListingId != null &&
                        _selectedImages.isEmpty &&
                        _editingImageUrls.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _editingImageUrls.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final imageUrl = _editingImageUrls[index];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: -6,
                                    top: -6,
                                    child: IconButton(
                                      visualDensity: VisualDensity.compact,
                                      iconSize: 18,
                                      onPressed:
                                          () => setState(
                                            () => _editingImageUrls.removeAt(
                                              index,
                                            ),
                                          ),
                                      icon: const Icon(
                                        Icons.cancel,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
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
                                await _saveListing();
                                if (mounted &&
                                    Navigator.of(sheetContext).canPop()) {
                                  Navigator.pop(sheetContext);
                                }
                              },
                      icon:
                          _creating
                              ? const CompactLoadingIndicator(
                                size: 16,
                                color: Colors.white,
                              )
                              : const Icon(Icons.save),
                      label: Text(buttonLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _saveListing() async {
    final crop = _cropController.text.trim();
    final district = _districtController.text.trim();
    final qty = double.tryParse(_qtyController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    final unit = _unitController.text.trim();

    final cropError = FormValidators.validateCropName(crop);
    if (cropError != null) return _showError(cropError);
    final districtError = FormValidators.validateDistrict(district);
    if (districtError != null) return _showError(districtError);
    if (qty == null) return _showError('Please enter a valid quantity');
    final qtyError = FormValidators.validateQuantity(qty.toString());
    if (qtyError != null) return _showError(qtyError);
    if (price == null) return _showError('Please enter a valid price');
    final priceError = FormValidators.validatePrice(price.toString());
    if (priceError != null) return _showError(priceError);

    setState(() => _creating = true);
    try {
      if (_editingListingId == null) {
        final imageUrls = <String>[];
        for (final image in _selectedImages) {
          imageUrls.add(await _service.uploadListingImage(image.path));
        }
        await _service.createListing(
          cropName: crop,
          district: district,
          quantity: qty,
          askingPrice: price,
          qualityGrade:
              _gradeController.text.trim().isEmpty
                  ? 'A'
                  : _gradeController.text.trim(),
          unit: unit.isEmpty ? '40kg' : unit,
          description: _descriptionController.text.trim(),
          imageUrls: imageUrls,
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Listing created')));
      } else {
        List<String>? updatedImageUrls;
        if (_selectedImages.isNotEmpty) {
          updatedImageUrls = <String>[];
          for (final image in _selectedImages) {
            updatedImageUrls.add(await _service.uploadListingImage(image.path));
          }
        } else {
          updatedImageUrls = List<String>.from(_editingImageUrls);
        }

        await _service.updateListing(
          listingId: _editingListingId!,
          cropName: crop,
          district: district,
          quantity: qty,
          askingPrice: price,
          qualityGrade:
              _gradeController.text.trim().isEmpty
                  ? 'A'
                  : _gradeController.text.trim(),
          unit: unit.isEmpty ? '40kg' : unit,
          description: _descriptionController.text.trim(),
          imageUrls: updatedImageUrls,
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Listing updated')));
      }

      _cropController.clear();
      _districtController.clear();
      _qtyController.clear();
      _priceController.clear();
      _unitController.text = '40kg';
      _gradeController.text = 'A';
      _descriptionController.clear();
      _selectedImages.clear();
      _editingImageUrls.clear();
      _editingListingId = null;
      _selectedLatitude = null;
      _selectedLongitude = null;
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showError(ErrorPresenter.present(e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _deleteListing(ListingDto row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete listing?'),
            content: Text(
              'Delete ${row.cropName} from your listings? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteListing(row.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Listing deleted')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showError(ErrorPresenter.present(e));
    }
  }

  Future<void> _openChat(ListingDto row) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(listingId: row.id, toUid: row.sellerUid),
      ),
    );
  }

  Future<void> _openMessagesSheet(ListingDto row) async {
    final previewsFuture = _fetchConversationPreviews(row.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (sheetContext) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Messages for ${row.cropName}',
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
                FutureBuilder<List<_ConversationPreview>>(
                  future: previewsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CompactLoadingIndicator(size: 18)),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Text(
                              ErrorPresenter.present(snapshot.error),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text('Close and reopen to retry.'),
                          ],
                        ),
                      );
                    }

                    final previews =
                        snapshot.data ?? const <_ConversationPreview>[];
                    if (previews.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No messages yet for this listing.'),
                      );
                    }

                    return SizedBox(
                      height: 360,
                      child: ListView.separated(
                        itemCount: previews.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final preview = previews[index];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            tileColor:
                                preview.isUnread
                                    ? Colors.blue.shade50
                                    : Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: Icon(
                                Icons.person,
                                color: Colors.green.shade700,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    preview.buyerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight:
                                          preview.isUnread
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatPreviewTime(preview.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                preview.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight:
                                      preview.isUnread
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                ),
                              ),
                            ),
                            trailing:
                                preview.isUnread
                                    ? Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade700,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                    : const SizedBox(width: 9, height: 9),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => ChatScreen(
                                        listingId: row.id,
                                        toUid: preview.peerUid,
                                      ),
                                ),
                              );
                              await _load();
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<List<_ConversationPreview>> _fetchConversationPreviews(
    String listingId,
  ) async {
    final messages = await _service.fetchMessagesForListing(
      listingId,
      limit: 200,
    );
    final meUid = _me?.firebaseUid ?? '';
    final grouped = <String, _ConversationPreview>{};

    for (final message in messages) {
      final fromUid = message.fromUid;
      final toUid = message.toUid ?? '';
      if (fromUid.isEmpty && toUid.isEmpty) continue;

      final peerUid = fromUid == meUid ? toUid : fromUid;
      if (peerUid.isEmpty || peerUid == meUid) continue;

      final createdAt = message.timestamp;
      final text = message.message.trim();
      final readBy = message.readBy.toSet();
      final isUnreadForMe = toUid == meUid && !readBy.contains(meUid);

      final existing = grouped[peerUid];
      if (existing == null || createdAt.isAfter(existing.createdAt)) {
        grouped[peerUid] = _ConversationPreview(
          peerUid: peerUid,
          buyerName: peerUid,
          lastMessage:
              text.isEmpty ? 'Attachment or unsupported message' : text,
          createdAt: createdAt,
          isUnread: isUnreadForMe,
        );
      }
    }

    final uids = grouped.keys.toList();
    for (final uid in uids) {
      try {
        final profile = await _service.fetchUserProfileByUid(uid);
        final name = profile.primaryName.isNotEmpty ? profile.primaryName : uid;
        final current = grouped[uid];
        if (current != null) {
          grouped[uid] = current.copyWith(buyerName: name);
        }
      } catch (_) {
        // Keep UID as fallback if profile lookup fails.
      }
    }

    final sorted =
        grouped.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  String _formatPreviewTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday =
        now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day;
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    if (isToday) return '$hh:$mm';
    final dd = dateTime.day.toString().padLeft(2, '0');
    final mo = dateTime.month.toString().padLeft(2, '0');
    return '$dd/$mo';
  }

  Future<void> _openOffersSheet(ListingDto row) async {
    final offers = _offersByListingId[row.id] ?? const [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (sheetContext) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Offers for ${row.cropName}',
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
                if (_loadingOffers)
                  const Center(child: CompactLoadingIndicator(size: 18))
                else if (offers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No offers yet for this listing.'),
                  )
                else
                  SizedBox(
                    height: 340,
                    child: ListView.separated(
                      itemCount: offers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder:
                          (context, index) => _buildOfferTile(offers[index]),
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _buildOfferTile(OfferDto offer) {
    return Card(
      child: FutureBuilder<UserProfileDto>(
        future: _service.fetchUserProfileByUid(offer.buyerUid),
        builder: (context, snapshot) {
          final buyerName =
              snapshot.hasData && snapshot.data!.primaryName.isNotEmpty
                  ? snapshot.data!.primaryName
                  : offer.buyerUid;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.green.shade100,
                      child: Icon(
                        Icons.person,
                        color: Colors.green.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            buyerName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Status: ${offer.status}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'PKR ${offer.offerPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Quantity: ${offer.quantity.toStringAsFixed(0)} ${_unitForOffer(offer)}',
                ),
                const SizedBox(height: 10),
                if (offer.status == 'pending')
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          try {
                            await _service.acceptOffer(offer.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Offer accepted — order created!',
                                ),
                                backgroundColor: Colors.green.shade700,
                              ),
                            );
                            Navigator.pop(context);
                            await _load();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to accept: ${e.toString().replaceAll('Exception: ', '')}',
                                ),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Accept'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await _service.rejectOffer(offer.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Offer rejected'),
                              ),
                            );
                            Navigator.pop(context);
                            await _load();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to reject: ${e.toString().replaceAll('Exception: ', '')}',
                                ),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _unitForOffer(OfferDto offer) {
    final listing = _rows.where((row) => row.id == offer.listingId).toList();
    return listing.isNotEmpty ? listing.first.unit : '40kg';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildCard(ListingDto row) {
    final offers = _offersByListingId[row.id] ?? const [];
    final unreadCount = _unreadCounts[row.id] ?? 0;
    final createdLabel = _formatPreviewTime(row.createdAt);
    final description = row.description.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        shadowColor: Colors.black12,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListingDetailScreen(listing: row),
                ),
              ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
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
                        if (offers.isNotEmpty)
                          Positioned(
                            right: -8,
                            top: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '${offers.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -8,
                            bottom: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row.cropName} • Grade ${row.qualityGrade}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${row.quantity.toStringAsFixed(0)} ${row.unit}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
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
                                    color: Colors.green.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PKR ${row.askingPrice.toStringAsFixed(0)} • ${row.status}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 10,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Posted $createdLabel',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        if (offers.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${offers.length} offer${offers.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          )
                        else
                          Text(
                            'No offers yet',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$unreadCount new message${unreadCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: [
                        _buildCardActionIcon(
                          tooltip: 'Offers',
                          icon: Icons.receipt_long_outlined,
                          color: Colors.orange.shade700,
                          onPressed: () => _openOffersSheet(row),
                        ),
                        _buildCardActionIcon(
                          tooltip: 'Messages',
                          icon: Icons.mark_chat_read_outlined,
                          color: Colors.blue.shade700,
                          onPressed: () => _openMessagesSheet(row),
                        ),
                        _buildCardActionIcon(
                          tooltip: 'Chat',
                          icon: Icons.chat_bubble_outline,
                          color: Colors.green.shade700,
                          onPressed: () => _openChat(row),
                        ),
                        _buildCardActionIcon(
                          tooltip: 'Edit',
                          icon: Icons.edit_outlined,
                          color: Colors.grey.shade800,
                          onPressed: () => _openEditListingSheet(row),
                        ),
                        _buildCardActionIcon(
                          tooltip: 'Delete',
                          icon: Icons.delete_outline,
                          color: Colors.red.shade700,
                          onPressed: () => _deleteListing(row),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateListingSheet,
        backgroundColor: Colors.green.shade700,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Listing', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
          children: [
            Card(
              elevation: 0,
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search your listings',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final status in _statusFilters)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  status == 'all'
                                      ? 'All'
                                      : status[0].toUpperCase() +
                                          status.substring(1),
                                ),
                                selected: _selectedStatusFilter == status,
                                onSelected:
                                    (_) => setState(
                                      () => _selectedStatusFilter = status,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryChip(
                            'Open',
                            _statusCount('open'),
                            Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryChip(
                            'Reserved',
                            _statusCount('reserved'),
                            Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryChip(
                            'Sold',
                            _statusCount('sold'),
                            Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryChip(
                            'Cancelled',
                            _statusCount('cancelled'),
                            Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_rows.length} listing${_rows.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (_loadingOffers)
                          const CompactLoadingIndicator(size: 16)
                        else
                          Text(
                            'Offers: $_totalOffersCount  Messages: $_totalUnreadCount',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const SizedBox(
                height: 320,
                child: Center(child: AsyncLoadingWidget()),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ErrorPresenter.present(_error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_filteredRows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 56),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.green.shade400,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No listings found.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._filteredRows.map(_buildCard),
            if (_hasMoreListings)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed:
                        _loadingMoreListings ? null : _loadMoreListings,
                    icon:
                        _loadingMoreListings
                            ? const CompactLoadingIndicator(size: 16)
                            : const Icon(Icons.expand_more),
                    label: Text(
                      _loadingMoreListings
                          ? 'Loading more...'
                          : 'Load more listings',
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCardActionIcon({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}

class _ConversationPreview {
  const _ConversationPreview({
    required this.peerUid,
    required this.buyerName,
    required this.lastMessage,
    required this.createdAt,
    required this.isUnread,
  });

  final String peerUid;
  final String buyerName;
  final String lastMessage;
  final DateTime createdAt;
  final bool isUnread;

  _ConversationPreview copyWith({String? buyerName}) {
    return _ConversationPreview(
      peerUid: peerUid,
      buyerName: buyerName ?? this.buyerName,
      lastMessage: lastMessage,
      createdAt: createdAt,
      isUnread: isUnread,
    );
  }
}
