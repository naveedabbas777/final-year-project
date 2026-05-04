import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mockup_app/services/weather_service.dart';

void main() {
  test('WeatherService times out slow backend responses', () async {
    final service = WeatherService(
      httpClient: MockClient((request) async {
        await Future<void>.delayed(const Duration(seconds: 25));
        return http.Response('{"current":{},"forecast":{"daily":[]}}', 200);
      }),
    );

    await expectLater(
      service.fetchWeatherData(31.5, 74.3),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('timed out'),
        ),
      ),
    );
  });
}
