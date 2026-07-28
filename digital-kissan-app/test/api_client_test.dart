import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mockup_app/services/api_client.dart';

void main() {
  test('ApiClient times out slow requests', () async {
    final client = ApiClient(
      requestTimeout: const Duration(milliseconds: 20),
      httpClient: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{"ok":true}', 200);
      }),
    );

    await expectLater(
      client.get('/slow'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('timed out'),
        ),
      ),
    );
  });

  test('ApiClient surfaces network errors clearly', () async {
    final client = ApiClient(
      httpClient: MockClient((request) {
        throw const SocketException('offline');
      }),
    );

    await expectLater(
      client.get('/offline'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Network error'),
        ),
      ),
    );
  });
}
