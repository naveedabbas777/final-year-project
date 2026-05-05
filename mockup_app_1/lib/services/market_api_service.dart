import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import '../utils/json_response.dart';
import '../config/app_config.dart';
import '../utils/retry_helper.dart';

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
      firebaseUid: toStringOrEmpty(json['firebaseUid']),
      name: toStringOrEmpty(json['name']),
      phone: toStringOrEmpty(json['phone']),
      role:
          toStringOrEmpty(json['role']).isEmpty
              ? 'farmer'
              : toStringOrEmpty(json['role']),
      district: toStringOrEmpty(json['district']),
      province: toStringOrEmpty(json['province']),
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
      id: toStringOrEmpty(json['_id']),
      cropName: toStringOrEmpty(json['cropName']),
      marketName: toStringOrEmpty(json['marketName']),
      district: toStringOrEmpty(json['district']),
      minPrice: toDoubleOrZero(json['minPrice']),
      maxPrice: toDoubleOrZero(json['maxPrice']),
      unit: toStringOrEmpty(json['unit']),
      sourceName: toStringOrEmpty(json['sourceName']),
      sourceUrl: toStringOrEmpty(json['sourceUrl']),
      rateDate: toDateTimeOrNow(json['rateDate']),
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
      id: toStringOrEmpty(json['_id']),
      cropName: toStringOrEmpty(json['cropName']),
      qualityGrade:
          toStringOrEmpty(json['qualityGrade']).isEmpty
              ? 'A'
              : toStringOrEmpty(json['qualityGrade']),
      quantity: toDoubleOrZero(json['quantity']),
      unit: toStringOrEmpty(json['unit']),
      askingPrice: toDoubleOrZero(json['askingPrice']),
      district: toStringOrEmpty(json['district']),
      sellerUid: toStringOrEmpty(json['sellerUid']),
      status: toStringOrEmpty(json['status']),
      createdAt: toDateTimeOrNow(json['createdAt']),
      imageUrls: toStringListOrEmpty(json['imageUrls']),
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
      id: toStringOrEmpty(json['_id']),
      listingId: listing?.id ?? toStringOrEmpty(json['listingId']),
      buyerUid: toStringOrEmpty(json['buyerUid']),
      offerPrice: toDoubleOrZero(json['offerPrice']),
      quantity: toDoubleOrZero(json['quantity']),
      status: toStringOrEmpty(json['status']),
      createdAt: toDateTimeOrNow(json['createdAt']),
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
      id: toStringOrEmpty(json['_id']),
      listingId: toStringOrEmpty(json['listingId']),
      offerId: toStringOrEmpty(json['offerId']),
      buyerUid: toStringOrEmpty(json['buyerUid']),
      sellerUid: toStringOrEmpty(json['sellerUid']),
      finalPrice: toDoubleOrZero(json['finalPrice']),
      quantity: toDoubleOrZero(json['quantity']),
      unit: toStringOrEmpty(json['unit']),
      status: toStringOrEmpty(json['status']),
      createdAt: toDateTimeOrNow(json['createdAt']),
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
      return asMapList(data).map(CropRateDto.fromJson).toList();
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
      debugPrint(
        '[MarketApi] Fetching listings (crop=$crop, district=$district)',
      );
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
      return asMapList(data).map(ListingDto.fromJson).toList();
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
    // Request a server-signed Cloudinary upload signature
    final signResp = await _client.post(
      '/api/uploads/cloudinary/sign',
      auth: true,
      body: {'folder': 'listings'},
    );

    if (signResp is! Map<String, dynamic>) {
      throw Exception('Invalid signing response from server');
    }

    final timestamp = signResp['timestamp']?.toString() ?? '';
    final signature = signResp['signature']?.toString() ?? '';
    final apiKey = signResp['apiKey']?.toString() ?? '';
    final cloudName = signResp['cloudName']?.toString() ?? AppConfig.cloudinaryCloudName;

    if (timestamp.isEmpty || signature.isEmpty || apiKey.isEmpty || cloudName.isEmpty) {
      throw Exception('Missing Cloudinary signing data');
    }

    return await RetryHelper.retry<String>(() async {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final req = http.MultipartRequest('POST', uri);
      req.fields['api_key'] = apiKey;
      req.fields['timestamp'] = timestamp;
      req.fields['signature'] = signature;
      req.fields['folder'] = 'listings';
      req.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Cloudinary upload failed (${resp.statusCode})');
      }

      final body = json.decode(resp.body) as Map<String, dynamic>;
      final url = body['secure_url'] as String? ?? body['url'] as String? ?? '';
      if (url.isEmpty) throw Exception('Cloudinary did not return a URL');
      return url;
    }, maxAttempts: 3, initialDelayMs: 500, onRetry: (attempt, delay) {
      if (kDebugMode) debugPrint('[MarketApi] Retry upload attempt $attempt after ${delay.inMilliseconds}ms');
    });
  }

  Future<List<OfferDto>> fetchMyOffers() async {
    final data = await _client.get('/api/offers/me', auth: true);
    if (data is! List<dynamic>) return const [];
    return asMapList(data).map(OfferDto.fromJson).toList();
  }

  Future<List<OfferDto>> fetchIncomingOffers() async {
    final data = await _client.get('/api/offers/incoming', auth: true);
    if (data is! List<dynamic>) return const [];
    return asMapList(data).map(OfferDto.fromJson).toList();
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
    return asMapList(data).map(OrderDto.fromJson).toList();
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
