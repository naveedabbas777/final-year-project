import 'dart:async';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import '../utils/json_response.dart';
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
    required this.description,
    required this.createdAt,
    required this.imageUrls,
    this.latitude,
    this.longitude,
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
  final String description;
  final DateTime createdAt;
  final List<String> imageUrls;
  final double? latitude;
  final double? longitude;

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
      description: toStringOrEmpty(json['description']),
      createdAt: toDateTimeOrNow(json['createdAt']),
      imageUrls: toStringListOrEmpty(json['imageUrls']),
      latitude: toDoubleOrNull(json['latitude']),
      longitude: toDoubleOrNull(json['longitude']),
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
    String? sellerUid,
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
    if (sellerUid != null && sellerUid.trim().isNotEmpty) {
      query['sellerUid'] = sellerUid.trim();
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
    double? latitude,
    double? longitude,
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
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
  }

  Future<void> updateListing({
    required String listingId,
    String? cropName,
    String? qualityGrade,
    double? quantity,
    String? unit,
    double? askingPrice,
    String? district,
    String? description,
    List<String>? imageUrls,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{};
    if (cropName != null) body['cropName'] = cropName;
    if (qualityGrade != null) body['qualityGrade'] = qualityGrade;
    if (quantity != null) body['quantity'] = quantity;
    if (unit != null) body['unit'] = unit;
    if (askingPrice != null) body['askingPrice'] = askingPrice;
    if (district != null) body['district'] = district;
    if (description != null) body['description'] = description;
    if (imageUrls != null) body['imageUrls'] = imageUrls;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;

    await _client.patch('/api/listings/$listingId', auth: true, body: body);
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
    return await RetryHelper.retry<String>(
      () async {
        final resp = await _client.uploadFile(
          '/api/uploads/listing-image',
          fieldName: 'image',
          filePath: filePath,
          auth: true,
        );
        if (resp is! Map<String, dynamic>) {
          throw Exception('Invalid upload response from server');
        }

        final url = resp['imageUrl']?.toString() ?? '';
        if (url.isEmpty) throw Exception('Upload did not return an image URL');
        return url;
      },
      maxAttempts: 3,
      initialDelayMs: 500,
      onRetry: (attempt, delay) {
        if (kDebugMode) {
          debugPrint(
            '[MarketApi] Retry upload attempt $attempt after ${delay.inMilliseconds}ms',
          );
        }
      },
    );
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

  Future<List<OfferDto>> fetchIncomingOffersForListing(String listingId) async {
    final rows = await fetchIncomingOffers();
    return rows.where((offer) => offer.listingId == listingId).toList();
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

  // Messaging: send message to seller or generic message
  Future<void> sendMessage({
    required String message,
    String? listingId,
    String? toUid,
  }) async {
    try {
      await _client.post(
        '/api/messages',
        auth: true,
        body: {
          'message': message,
          if (listingId != null) 'listingId': listingId,
          if (toUid != null) 'toUid': toUid,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[MarketApi] sendMessage failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessagesForListing(
    String listingId, {
    int limit = 100,
  }) async {
    final data = await _client.get(
      '/api/messages/listing/$listingId',
      query: {'limit': limit.toString()},
      auth: true,
    );
    if (data is! List<dynamic>) return const [];
    return asMapList(data);
  }

  Future<void> markListingMessagesRead(String listingId) async {
    try {
      await _client.post('/api/messages/listing/$listingId/read', auth: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[MarketApi] markListingMessagesRead failed: $e');
      // Non-critical - ignore errors
    }
  }

  Future<void> setTyping({
    required String listingId,
    required bool isTyping,
  }) async {
    try {
      await _client.post(
        '/api/messages/typing',
        auth: true,
        body: {'listingId': listingId, 'isTyping': isTyping},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[MarketApi] setTyping failed: $e');
      // Non-critical - ignore
    }
  }

  // User profiles and ratings
  Future<Map<String, dynamic>> fetchUserProfileByUid(String uid) async {
    final data = await _client.get('/api/users/$uid', auth: true);
    if (data is! Map<String, dynamic>) throw Exception('Invalid user profile');
    return Map<String, dynamic>.from(data);
  }

  Future<void> rateUser({
    required String targetUid,
    required int score,
    String? comment,
  }) async {
    await _client.post(
      '/api/ratings',
      auth: true,
      body: {'targetUid': targetUid, 'score': score, 'comment': comment ?? ''},
    );
  }

  Future<Map<String, dynamic>> fetchUserRatings(String uid) async {
    final data = await _client.get('/api/ratings/$uid');
    if (data is! Map<String, dynamic>) {
      return {
        'stats': {'avgScore': 0, 'count': 0},
        'recent': [],
      };
    }
    return Map<String, dynamic>.from(data);
  }

  // Device token registration for push notifications
  Future<void> registerDeviceToken(String token) async {
    await _client.post(
      '/api/users/me/fcm-token',
      auth: true,
      body: {'token': token},
    );
  }

  Future<void> unregisterDeviceToken(String token) async {
    await _client.post(
      '/api/users/me/fcm-token/remove',
      auth: true,
      body: {'token': token},
    );
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

  Future<void> updateListingStatus({
    required String listingId,
    required String status,
  }) async {
    await _client.patch(
      '/api/listings/$listingId/status',
      auth: true,
      body: {'status': status},
    );
  }

  Future<void> deleteListing(String listingId) async {
    await _client.delete('/api/listings/$listingId', auth: true);
  }

  Future<String> triggerOfficialRatesIngestion() async {
    final data = await _client.post('/api/rates/ingest/official', auth: true);
    if (data is Map<String, dynamic> && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Ingestion triggered';
  }

  // Presence: update user online/offline status
  Future<void> setPresence({required bool isOnline}) async {
    try {
      await _client.post(
        '/api/users/me/presence',
        auth: true,
        body: {'isOnline': isOnline},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[MarketApi] setPresence failed: $e');
      // Non-critical - ignore failures
    }
  }

  // Presence: get user presence status
  Future<Map<String, dynamic>> getPresence(String uid) async {
    final data = await _client.get('/api/users/$uid/presence');
    if (data is! Map<String, dynamic>) {
      return {'uid': uid, 'isOnline': false, 'lastSeen': null};
    }
    return Map<String, dynamic>.from(data);
  }

  // Unread messages: get count of unread messages for a listing
  // Non-critical: returns 0 silently on error/timeout (including 403 if not participant)
  Future<int> getUnreadCount(String listingId) async {
    try {
      final data = await _client
          .get('/api/messages/listing/$listingId/unread-count', auth: true)
          .timeout(
            const Duration(seconds: 3),
            onTimeout:
                () => throw TimeoutException('Unread count request timed out'),
          );
      if (data is! Map<String, dynamic>) return 0;
      return (data['unreadCount'] as int?) ?? 0;
    } catch (e) {
      // Silently return 0 on any error (timeout, 403, network, etc.)
      // This prevents retries from blocking market screen rendering
      return 0;
    }
  }
}
