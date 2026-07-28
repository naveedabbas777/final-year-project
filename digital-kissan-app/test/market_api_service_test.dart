import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockup_app/services/api_client.dart';
import 'package:mockup_app/services/market_api_service.dart';

void main() {
  group('UserProfileDto', () {
    test('parses public and contact fields consistently', () {
      final profile = UserProfileDto.fromJson({
        '_id': 'user-doc-1',
        'firebaseUid': 'firebase-uid-1',
        'name': 'Ali Khan',
        'displayName': 'Ali Khan',
        'phone': '0300-1234567',
        'phoneNumber': '0300-1234567',
        'email': 'ali@example.com',
        'role': 'buyer',
        'district': 'Lahore',
        'province': 'Punjab',
        'address': 'Garden Town',
        'lat': 31.5204,
        'lon': '74.3587',
        'locationUpdatedAt': '2026-05-08T10:15:00.000Z',
        'createdAt': '2026-05-01T09:00:00.000Z',
        'photoUrl': 'https://example.com/profile.jpg',
      });

      expect(profile.id, 'user-doc-1');
      expect(profile.firebaseUid, 'firebase-uid-1');
      expect(profile.primaryName, 'Ali Khan');
      expect(profile.contactPhone, '0300-1234567');
      expect(profile.email, 'ali@example.com');
      expect(profile.locationSummary, 'Lahore, Punjab, Garden Town');
      expect(profile.latitude, 31.5204);
      expect(profile.longitude, 74.3587);
      expect(profile.photoUrl, 'https://example.com/profile.jpg');
      expect(profile.hasVisibleContactInfo, isTrue);
      expect(profile.hasLocationInfo, isTrue);
      expect(profile.initials, 'A');
      expect(profile.locationUpdatedAt, isNotNull);
      expect(profile.createdAt, isNotNull);

      final map = profile.toMap();
      expect(map['firebaseUid'], 'firebase-uid-1');
      expect(map['displayName'], 'Ali Khan');
    });

    test('marks redacted contacts as hidden', () {
      final profile = UserProfileDto.fromJson({
        'firebaseUid': 'firebase-uid-2',
        'name': 'Seller',
        'displayName': 'Seller',
        'role': 'farmer',
        'district': 'Multan',
        'province': 'Punjab',
      });

      expect(profile.hasVisibleContactInfo, isFalse);
      expect(profile.contactPhone, isEmpty);
      expect(profile.locationSummary, 'Multan, Punjab');
    });
  });

  group('ChatMessageDto', () {
    test('parses message snapshots and derives preview text', () {
      final message = ChatMessageDto.fromJson({
        'id': 'msg-1',
        'message': 'Hello buyer',
        'fromUid': 'seller-uid',
        'toUid': 'buyer-uid',
        'listingId': 'listing-1',
        'timestamp': '2026-05-08T11:30:00.000Z',
        'readBy': ['seller-uid', 'buyer-uid'],
      });

      expect(message.id, 'msg-1');
      expect(message.message, 'Hello buyer');
      expect(message.previewText, 'Hello buyer');
      expect(message.fromUid, 'seller-uid');
      expect(message.toUid, 'buyer-uid');
      expect(message.listingId, 'listing-1');
      expect(message.readBy, contains('buyer-uid'));
      expect(message.timestamp, isNotNull);
    });

    test('falls back to attachment copy when text is missing', () {
      final message = ChatMessageDto.fromJson({
        '_id': 'msg-2',
        'fromUid': 'seller-uid',
        'timestamp': {'seconds': 1715167800},
      });

      expect(message.id, 'msg-2');
      expect(message.message, isEmpty);
      expect(message.previewText, 'Attachment or unsupported message');
    });
  });

  group('MarketApiService pagination and cache', () {
    test('fetchListings sends cursor parameters', () async {
      String? requestedBefore;
      String? requestedLimit;
      final service = MarketApiService(
        client: ApiClient(
          httpClient: MockClient((request) async {
            requestedBefore = request.url.queryParameters['before'];
            requestedLimit = request.url.queryParameters['limit'];
            return http.Response('[]', 200);
          }),
        ),
      );

      await service.fetchListings(
        sellerUid: 'seller-1',
        limit: 25,
        before: DateTime.parse('2026-05-08T10:00:00.000Z'),
      );

      expect(requestedBefore, '2026-05-08T10:00:00.000Z');
      expect(requestedLimit, '25');
    });

    test('fetchMessagesForListing sends cursor parameters', () async {
      String? requestedBefore;
      String? requestedLimit;
      final service = MarketApiService(
        client: ApiClient(
          httpClient: MockClient((request) async {
            requestedBefore = request.url.queryParameters['before'];
            requestedLimit = request.url.queryParameters['limit'];
            return http.Response('[]', 200);
          }),
        ),
      );

      await service.fetchMessagesForListing(
        'listing-1',
        limit: 10,
        before: DateTime.parse('2026-05-08T09:30:00.000Z'),
        auth: false,
      );

      expect(requestedBefore, '2026-05-08T09:30:00.000Z');
      expect(requestedLimit, '10');
    });

    test('caches and restores listings locally', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MarketApiService();
      final listings = [
        ListingDto.fromJson({
          '_id': 'listing-1',
          'cropName': 'Wheat',
          'qualityGrade': 'A',
          'quantity': 20,
          'unit': 'kg',
          'askingPrice': 1200,
          'district': 'Lahore',
          'sellerUid': 'seller-1',
          'status': 'open',
          'description': 'Fresh',
          'createdAt': '2026-05-08T10:00:00.000Z',
          'imageUrls': [],
        }),
      ];

      await service.cacheListings(listings: listings);
      final cached = await service.readCachedListings();

      expect(cached, hasLength(1));
      expect(cached.first.id, 'listing-1');
    });
  });
}
