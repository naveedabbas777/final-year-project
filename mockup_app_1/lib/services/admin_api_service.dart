import 'api_client.dart';
import 'market_api_service.dart';
import '../utils/json_response.dart';

String? _toNullableString(dynamic value) {
  final text = toStringOrEmpty(value);
  return text.isEmpty ? null : text;
}

class AdminOverviewDto {
  AdminOverviewDto({
    required this.users,
    required this.admins,
    required this.listings,
    required this.openListings,
    required this.offers,
    required this.orders,
    required this.rates,
    required this.onlineUsers,
    required this.recentAlerts,
  });

  final int users;
  final int admins;
  final int listings;
  final int openListings;
  final int offers;
  final int orders;
  final int rates;
  final int onlineUsers;
  final int recentAlerts;

  factory AdminOverviewDto.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'];
    final map = counts is Map<String, dynamic> ? counts : <String, dynamic>{};
    return AdminOverviewDto(
      users: toIntOrZero(map['users']),
      admins: toIntOrZero(map['admins']),
      listings: toIntOrZero(map['listings']),
      openListings: toIntOrZero(map['openListings']),
      offers: toIntOrZero(map['offers']),
      orders: toIntOrZero(map['orders']),
      rates: toIntOrZero(map['rates']),
      onlineUsers: toIntOrZero(map['onlineUsers']),
      recentAlerts: toIntOrZero(map['recentAlerts']),
    );
  }
}

class AdminUserDto {
  AdminUserDto({
    required this.firebaseUid,
    required this.name,
    required this.role,
    required this.phone,
    required this.district,
    required this.province,
    required this.email,
    required this.photoUrl,
    required this.isOnline,
    required this.lastSeen,
  });

  final String firebaseUid;
  final String name;
  final String role;
  final String phone;
  final String district;
  final String province;
  final String email;
  final String photoUrl;
  final bool isOnline;
  final String? lastSeen;

  bool get isAdmin => role == 'admin';

  factory AdminUserDto.fromJson(Map<String, dynamic> json) {
    return AdminUserDto(
      firebaseUid: toStringOrEmpty(json['firebaseUid']),
      name:
          toStringOrEmpty(json['displayName']).isNotEmpty
              ? toStringOrEmpty(json['displayName'])
              : toStringOrEmpty(json['name']),
      role:
          toStringOrEmpty(json['role']).isEmpty
              ? 'farmer'
              : toStringOrEmpty(json['role']),
      phone:
          toStringOrEmpty(json['phoneNumber']).isNotEmpty
              ? toStringOrEmpty(json['phoneNumber'])
              : toStringOrEmpty(json['phone']),
      district: toStringOrEmpty(json['district']),
      province: toStringOrEmpty(json['province']),
      email: toStringOrEmpty(json['email']),
      photoUrl: toStringOrEmpty(json['photoUrl']),
      isOnline: json['isOnline'] == true,
      lastSeen: _toNullableString(json['lastSeen']),
    );
  }
}

class AdminAlertDto {
  AdminAlertDto({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    required this.address,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final bool read;
  final String? createdAt;
  final String address;

  factory AdminAlertDto.fromJson(Map<String, dynamic> json) {
    return AdminAlertDto(
      id: toStringOrEmpty(json['id']),
      userId: toStringOrEmpty(json['userId']),
      type: toStringOrEmpty(json['type']),
      title: toStringOrEmpty(json['title']),
      body: toStringOrEmpty(json['body']),
      read: json['read'] == true,
      createdAt: _toNullableString(json['createdAt']),
      address: toStringOrEmpty(json['address']),
    );
  }
}

class AdminOrderDto {
  AdminOrderDto({
    required this.id,
    required this.buyerUid,
    required this.sellerUid,
    required this.finalPrice,
    required this.quantity,
    required this.unit,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String buyerUid;
  final String sellerUid;
  final double finalPrice;
  final double quantity;
  final String unit;
  final String status;
  final String createdAt;

  factory AdminOrderDto.fromJson(Map<String, dynamic> json) {
    return AdminOrderDto(
      id: toStringOrEmpty(json['_id']),
      buyerUid: toStringOrEmpty(json['buyerUid']),
      sellerUid: toStringOrEmpty(json['sellerUid']),
      finalPrice: toDoubleOrZero(json['finalPrice']),
      quantity: toDoubleOrZero(json['quantity']),
      unit: toStringOrEmpty(json['unit']),
      status: toStringOrEmpty(json['status']),
      createdAt: toStringOrEmpty(json['createdAt']),
    );
  }
}

class AdminNotificationLogDto {
  AdminNotificationLogDto({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.mode,
    required this.title,
    required this.body,
    required this.recipients,
    required this.alertCreated,
    required this.pushSent,
    required this.createdAt,
  });

  final String id;
  final String senderUid;
  final String senderName;
  final String mode;
  final String title;
  final String body;
  final int recipients;
  final int alertCreated;
  final int pushSent;
  final String? createdAt;

  factory AdminNotificationLogDto.fromJson(Map<String, dynamic> json) {
    return AdminNotificationLogDto(
      id: toStringOrEmpty(json['id']),
      senderUid: toStringOrEmpty(json['senderUid']),
      senderName: toStringOrEmpty(json['senderName']),
      mode: toStringOrEmpty(json['mode']),
      title: toStringOrEmpty(json['title']),
      body: toStringOrEmpty(json['body']),
      recipients: toIntOrZero(json['recipients']),
      alertCreated: toIntOrZero(json['alertCreated']),
      pushSent: toIntOrZero(json['pushSent']),
      createdAt: _toNullableString(json['createdAt']),
    );
  }
}

class AdminApiService {
  AdminApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<AdminOverviewDto> fetchOverview() async {
    final data = await _client.get('/api/admin/overview', auth: true);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid admin overview response');
    }
    return AdminOverviewDto.fromJson(data);
  }

  Future<List<AdminUserDto>> fetchUsers({int limit = 50, String? role}) async {
    final query = <String, String>{'limit': limit.toString()};
    if (role != null && role.trim().isNotEmpty) query['role'] = role.trim();
    final data = await _client.get(
      '/api/admin/users',
      auth: true,
      query: query,
    );
    if (data is! List<dynamic>) return const [];
    return asMapList(data).map(AdminUserDto.fromJson).toList();
  }

  Future<List<ListingDto>> fetchListings({int limit = 50}) async {
    final data = await _client.get(
      '/api/admin/listings',
      auth: true,
      query: {'limit': limit.toString()},
    );
    if (data is! List<dynamic>) return const [];
    return asMapList(data).map(ListingDto.fromJson).toList();
  }

  Future<List<CropRateDto>> fetchRates({int limit = 50}) async {
    final data = await _client.get(
      '/api/admin/rates',
      auth: true,
      query: {'limit': limit.toString()},
    );
    if (data is! List<dynamic>) return const [];
    return asMapList(data).map(CropRateDto.fromJson).toList();
  }

  Future<List<AdminAlertDto>> fetchAlerts({int limit = 50}) async {
    final data = await _client.get(
      '/api/admin/alerts',
      auth: true,
      query: {'limit': limit.toString()},
    );
    if (data is! List<dynamic>) return const [];
    return asMapList(data).map(AdminAlertDto.fromJson).toList();
  }

  Future<List<AdminOrderDto>> fetchOrders({
    int limit = 100,
    String? status,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    if (status != null && status.trim().isNotEmpty)
      query['status'] = status.trim();
    final data = await _client.get(
      '/api/admin/orders',
      auth: true,
      query: query,
    );
    if (data is! List<dynamic>) return const [];
    return asMapList(data).map(AdminOrderDto.fromJson).toList();
  }

  Future<String> refreshWeather() async {
    final data = await _client.post('/api/admin/weather/refresh', auth: true);
    if (data is! Map<String, dynamic>) {
      return 'Weather refresh complete';
    }
    return toStringOrEmpty(data['message']).isNotEmpty
        ? toStringOrEmpty(data['message'])
        : 'Weather refresh complete';
  }

  Future<String> ingestOfficialRates() async {
    final data = await _client.post('/api/rates/ingest/official', auth: true);
    if (data is! Map<String, dynamic>) {
      return 'Official rates ingested';
    }
    return toStringOrEmpty(data['message']).isNotEmpty
        ? toStringOrEmpty(data['message'])
        : 'Official rates ingested';
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    await _client.patch(
      '/api/users/$userId/role',
      auth: true,
      body: {'role': role},
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

  Future<Map<String, dynamic>> sendNotificationToFarmers({
    required String mode,
    required String title,
    required String body,
    List<String> targetUserIds = const [],
  }) async {
    final data = await _client.post(
      '/api/admin/notifications/send',
      auth: true,
      body: {
        'mode': mode,
        'title': title,
        'body': body,
        'targetUserIds': targetUserIds,
      },
    );
    if (data is! Map<String, dynamic>) {
      return <String, dynamic>{'message': 'Notifications processed'};
    }
    return data;
  }

  Future<List<AdminNotificationLogDto>> fetchNotificationHistory({
    int limit = 50,
    String? mode,
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    if (mode != null && mode.trim().isNotEmpty) {
      query['mode'] = mode.trim();
    }
    if (from != null) {
      query['from'] = from.toUtc().toIso8601String();
    }
    if (to != null) {
      query['to'] = to.toUtc().toIso8601String();
    }
    final data = await _client.get(
      '/api/admin/notifications/history',
      auth: true,
      query: query,
    );
    if (data is! List<dynamic>) return const [];
    return asMapList(data).map(AdminNotificationLogDto.fromJson).toList();
  }
}
