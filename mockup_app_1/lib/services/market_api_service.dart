import 'package:flutter/foundation.dart';

import 'api_client.dart';

class UserProfileDto {
  UserProfileDto({
    required this.firebaseUid,
    required this.name,
    required this.phone,
    required this.role,
    required this.district,
    required this.province,
  });

  final String firebaseUid;
  final String name;
  final String phone;
  final String role;
  final String district;
  final String province;

  bool get isAdmin => role == 'admin';

  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    return UserProfileDto(
      firebaseUid: (json['firebaseUid'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      role: (json['role'] ?? 'farmer').toString(),
      district: (json['district'] ?? '').toString(),
      province: (json['province'] ?? '').toString(),
    );
  }
}

class CropRateDto {
  CropRateDto({
    required this.id,
    required this.cropName,
    required this.marketName,
    required this.district,
    required this.minPrice,
    required this.maxPrice,
    required this.unit,
    required this.sourceName,
    required this.sourceUrl,
    required this.rateDate,
  });

  final String id;
  final String cropName;
  final String marketName;
  final String district;
  final double minPrice;
  final double maxPrice;
  final String unit;
  final String sourceName;
  final String sourceUrl;
  final DateTime rateDate;

  factory CropRateDto.fromJson(Map<String, dynamic> json) {
    return CropRateDto(
      id: (json['_id'] ?? '').toString(),
      cropName: (json['cropName'] ?? '').toString(),
      marketName: (json['marketName'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      minPrice: (json['minPrice'] as num?)?.toDouble() ?? 0,
      maxPrice: (json['maxPrice'] as num?)?.toDouble() ?? 0,
      unit: (json['unit'] ?? '').toString(),
      sourceName: (json['sourceName'] ?? '').toString(),
      sourceUrl: (json['sourceUrl'] ?? '').toString(),
      rateDate:
          DateTime.tryParse((json['rateDate'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class ListingDto {
  ListingDto({
    required this.id,
    required this.cropName,
    required this.qualityGrade,
    required this.quantity,
    required this.unit,
    required this.askingPrice,
    required this.district,
    required this.sellerUid,
    required this.status,
    required this.createdAt,
    required this.imageUrls,
  });

  final String id;
  final String cropName;
  final String qualityGrade;
  final double quantity;
  final String unit;
  final double askingPrice;
  final String district;
  final String sellerUid;
  final String status;
  final DateTime createdAt;
  final List<String> imageUrls;

  factory ListingDto.fromJson(Map<String, dynamic> json) {
    return ListingDto(
      id: (json['_id'] ?? '').toString(),
      cropName: (json['cropName'] ?? '').toString(),
      qualityGrade: (json['qualityGrade'] ?? 'A').toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: (json['unit'] ?? '').toString(),
      askingPrice: (json['askingPrice'] as num?)?.toDouble() ?? 0,
      district: (json['district'] ?? '').toString(),
      sellerUid: (json['sellerUid'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      imageUrls:
          (json['imageUrls'] is List<dynamic>)
              ? (json['imageUrls'] as List<dynamic>)
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList()
              : const [],
    );
  }
}

class OfferDto {
  OfferDto({
    required this.id,
    required this.listingId,
    required this.buyerUid,
    required this.offerPrice,
    required this.quantity,
    required this.status,
    required this.createdAt,
    required this.listing,
  });

  final String id;
  final String listingId;
  final String buyerUid;
  final double offerPrice;
  final double quantity;
  final String status;
  final DateTime createdAt;
  final ListingDto? listing;

  factory OfferDto.fromJson(Map<String, dynamic> json) {
    final listingRaw = json['listingId'];
    ListingDto? listing;
    if (listingRaw is Map<String, dynamic>) {
      listing = ListingDto.fromJson(listingRaw);
    }

    return OfferDto(
      id: (json['_id'] ?? '').toString(),
      listingId:
          listing != null ? listing.id : (json['listingId'] ?? '').toString(),
      buyerUid: (json['buyerUid'] ?? '').toString(),
      offerPrice: (json['offerPrice'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      status: (json['status'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      listing: listing,
    );
  }
}

class OrderDto {
  OrderDto({
    required this.id,
    required this.listingId,
    required this.offerId,
    required this.buyerUid,
    required this.sellerUid,
    required this.finalPrice,
    required this.quantity,
    required this.unit,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final String offerId;
  final String buyerUid;
  final String sellerUid;
  final double finalPrice;
  final double quantity;
  final String unit;
  final String status;
  final DateTime createdAt;

  factory OrderDto.fromJson(Map<String, dynamic> json) {
    return OrderDto(
      id: (json['_id'] ?? '').toString(),
      listingId: (json['listingId'] ?? '').toString(),
      offerId: (json['offerId'] ?? '').toString(),
      buyerUid: (json['buyerUid'] ?? '').toString(),
      sellerUid: (json['sellerUid'] ?? '').toString(),
      finalPrice: (json['finalPrice'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: (json['unit'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class MarketApiService {
  MarketApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<CropRateDto>> fetchLatestRates({
    String? crop,
    String? district,
  }) async {
    if (kDebugMode) {
      debugPrint('[MarketApi] Fetching rates (crop=$crop, district=$district)');
    }
    
    final query = <String, String>{};
    if (crop != null && crop.trim().isNotEmpty) query['crop'] = crop.trim();
    if (district != null && district.trim().isNotEmpty) {
      query['district'] = district.trim();
    }

    try {
      final data = await _client.get(
        '/api/rates/latest',
        query: query.isEmpty ? null : query,
      );
      if (kDebugMode) {
        debugPrint('[MarketApi] Got rates data: $data');
      }
      if (data is! List<dynamic>) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => CropRateDto.fromJson(e))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MarketApi] Error fetching rates: $e');
      }
      rethrow;
    }
  }

  Future<List<ListingDto>> fetchListings({
    String? crop,
    String? district,
  }) async {
    if (kDebugMode) {
      debugPrint('[MarketApi] Fetching listings (crop=$crop, district=$district)');
    }
    
    final query = <String, String>{};
    if (crop != null && crop.trim().isNotEmpty) query['crop'] = crop.trim();
    if (district != null && district.trim().isNotEmpty) {
      query['district'] = district.trim();
    }

    try {
      final data = await _client.get(
        '/api/listings',
        query: query.isEmpty ? null : query,
      );
      if (kDebugMode) {
        debugPrint('[MarketApi] Got listings data: $data');
      }
      if (data is! List<dynamic>) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => ListingDto.fromJson(e))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MarketApi] Error fetching listings: $e');
      }
      rethrow;
    }
  }

  Future<void> createListing({
    required String cropName,
    required String district,
    required double quantity,
    required double askingPrice,
    String qualityGrade = 'A',
    String unit = '40kg',
    String description = '',
    List<String> imageUrls = const [],
  }) async {
    await _client.post(
      '/api/listings',
      auth: true,
      body: {
        'cropName': cropName,
        'district': district,
        'quantity': quantity,
        'askingPrice': askingPrice,
        'qualityGrade': qualityGrade,
        'unit': unit,
        'description': description,
        'imageUrls': imageUrls,
      },
    );
  }

  Future<void> makeOffer({
    required String listingId,
    required double offerPrice,
    required double quantity,
  }) async {
    await _client.post(
      '/api/offers',
      auth: true,
      body: {
        'listingId': listingId,
        'offerPrice': offerPrice,
        'quantity': quantity,
      },
    );
  }

  Future<UserProfileDto> fetchMe() async {
    if (kDebugMode) {
      debugPrint('[MarketApi] Fetching user profile');
    }
    try {
      final data = await _client.get('/api/users/me', auth: true);
      if (kDebugMode) {
        debugPrint('[MarketApi] Got user profile: $data');
      }
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid user profile response');
      }
      return UserProfileDto.fromJson(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MarketApi] Error fetching user profile: $e');
      }
      rethrow;
    }
  }

  Future<String> uploadListingImage(String filePath) async {
    final data = await _client.uploadFile(
      '/api/uploads/listing-image',
      fieldName: 'image',
      filePath: filePath,
      auth: true,
    );

    if (data is! Map<String, dynamic> || data['imageUrl'] == null) {
      throw Exception('Invalid upload response');
    }

    return data['imageUrl'].toString();
  }

  Future<List<OfferDto>> fetchMyOffers() async {
    final data = await _client.get('/api/offers/me', auth: true);
    if (data is! List<dynamic>) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => OfferDto.fromJson(e))
        .toList();
  }

  Future<List<OfferDto>> fetchIncomingOffers() async {
    final data = await _client.get('/api/offers/incoming', auth: true);
    if (data is! List<dynamic>) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => OfferDto.fromJson(e))
        .toList();
  }

  Future<void> acceptOffer(String offerId) async {
    await _client.post('/api/offers/$offerId/accept', auth: true);
  }

  Future<void> rejectOffer(String offerId) async {
    await _client.post('/api/offers/$offerId/reject', auth: true);
  }

  Future<void> cancelOffer(String offerId) async {
    await _client.post('/api/offers/$offerId/cancel', auth: true);
  }

  Future<List<OrderDto>> fetchMyOrders() async {
    final data = await _client.get('/api/orders/me', auth: true);
    if (data is! List<dynamic>) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => OrderDto.fromJson(e))
        .toList();
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _client.patch(
      '/api/orders/$orderId/status',
      auth: true,
      body: {'status': status},
    );
  }

  Future<String> triggerOfficialRatesIngestion() async {
    final data = await _client.post('/api/rates/ingest/official', auth: true);
    if (data is Map<String, dynamic> && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Ingestion triggered';
  }
}
