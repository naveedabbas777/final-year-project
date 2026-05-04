import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/json_response.dart';
import '../config/app_config.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WeatherService {
  WeatherService({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> fetchWeatherData([
    double? lat,
    double? lon,
  ]) async {
    try {
      final base = AppConfig.apiBaseUrl;
      final useSavedLocation = lat == null || lon == null;
      final uri =
          useSavedLocation
              ? Uri.parse('$base/api/weather/me')
              : Uri.parse('$base/api/weather?lat=$lat&lon=$lon');

      final headers = <String, String>{};
      if (useSavedLocation) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception(
            'You must sign in first to load weather for your saved location.',
          );
        }
        headers['Authorization'] = 'Bearer ${await user.getIdToken(true)}';
      }

      final resp = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) {
        throw Exception(
          'Failed to load weather from backend (${resp.statusCode})',
        );
      }

      final body = json.decode(resp.body) as Map<String, dynamic>;
      final currentData = asMap(body['current']) ?? {};
      final forecastData = asMap(body['forecast']) ?? {'daily': []};

      final currentOneCallLike =
          currentData.containsKey('temp') && currentData.containsKey('weather')
              ? currentData
              : _toOneCallCurrent(currentData);

      final dailySynthesized =
          forecastData['daily'] is List
              ? asMapList(
                forecastData['daily'],
              ).map((item) => DailyForecast.fromJson(item)).toList()
              : _toDailyFromForecast(
                forecastData,
              ).map((item) => DailyForecast.fromJson(item)).toList();

      return {
        'current': currentOneCallLike,
        'forecast': {'daily': dailySynthesized},
        'cached': body,
      };
    } on TimeoutException {
      throw Exception('Weather request timed out. Please try again.');
    } on SocketException {
      throw Exception(
        'Weather request failed. Check your internet connection.',
      );
    }
  }
}

// Simple data models for weather information
class CurrentWeather {
  final double temperature;
  final String description;
  final String icon;
  final double windSpeed;
  final String windDirection;
  final int windDegree;
  final double precipitation;
  final int humidity;
  final int cloudCover;
  final String sunrise;
  final String sunset;

  CurrentWeather({
    required this.temperature,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.windDirection,
    required this.windDegree,
    required this.precipitation,
    required this.humidity,
    required this.cloudCover,
    required this.sunrise,
    required this.sunset,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    // json is the `current` map from OpenWeather One Call
    final weatherArr = json['weather'] as List<dynamic>?;
    final weather =
        weatherArr != null &&
                weatherArr.isNotEmpty &&
                weatherArr.first is Map<String, dynamic>
            ? weatherArr.first as Map<String, dynamic>
            : null;

    return CurrentWeather(
      temperature: (json['temp'] as num?)?.toDouble() ?? 0.0,
      description: weather != null ? (weather['description'] ?? '') : '',
      icon:
          weather != null && weather['icon'] != null
              ? 'https://openweathermap.org/img/wn/${weather['icon']}@2x.png'
              : '',
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0.0,
      windDirection: _degToCompass((json['wind_deg'] as num?)?.toInt()),
      windDegree: (json['wind_deg'] as num?)?.toInt() ?? 0,
      precipitation: _extractPrecip(json),
      humidity: (json['humidity'] as num?)?.toInt() ?? 0,
      cloudCover: (json['clouds'] as num?)?.toInt() ?? 0,
      sunrise: _formatTime((json['sunrise'] as num?)?.toInt()),
      sunset: _formatTime((json['sunset'] as num?)?.toInt()),
    );
  }
}

class DailyForecast {
  final String day;
  final String description;
  final double maxTemperature;
  final double minTemperature;
  final double avgTemperature;
  final String icon;
  final double pop;
  final double uv;
  final double avgHumidity;
  final double visibilityKm;
  final String sunrise;
  final String sunset;
  final String moonPhase;
  final double maxWindSpeed;
  final String windDirection;
  final int windDegree;
  final int cloudCoverage;
  final List<HourlyForecast> hourlyForecasts;

  DailyForecast({
    required this.day,
    required this.description,
    required this.maxTemperature,
    required this.minTemperature,
    required this.avgTemperature,
    required this.icon,
    required this.pop,
    required this.uv,
    required this.avgHumidity,
    required this.visibilityKm,
    required this.sunrise,
    required this.sunset,
    required this.moonPhase,
    required this.maxWindSpeed,
    required this.windDirection,
    required this.windDegree,
    required this.cloudCoverage,
    required this.hourlyForecasts,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    // json is one element from OpenWeather `daily`
    final dt = (json['dt'] as num?)?.toInt();
    final date =
        dt != null
            ? DateTime.fromMillisecondsSinceEpoch(dt * 1000)
            : DateTime.now();

    final weatherArr = json['weather'] as List<dynamic>?;
    final weather =
        weatherArr != null &&
                weatherArr.isNotEmpty &&
                weatherArr.first is Map<String, dynamic>
            ? weatherArr.first as Map<String, dynamic>
            : null;
    final temp = json['temp'] as Map<String, dynamic>?;

    final hourlyRaw = json['hourly'];
    final hourly =
        hourlyRaw is List<dynamic>
            ? hourlyRaw
                .whereType<Map<String, dynamic>>()
                .map((h) => HourlyForecast.fromJson(h))
                .toList()
            : <HourlyForecast>[];

    return DailyForecast(
      day: DateFormat('EEE, MMM d').format(date),
      description: weather != null ? (weather['description'] ?? '') : '',
      maxTemperature: (temp?['max'] as num?)?.toDouble() ?? 0.0,
      minTemperature: (temp?['min'] as num?)?.toDouble() ?? 0.0,
      avgTemperature: (temp?['day'] as num?)?.toDouble() ?? 0.0,
      icon:
          weather != null && weather['icon'] != null
              ? 'https://openweathermap.org/img/wn/${weather['icon']}@2x.png'
              : '',
      pop: (json['pop'] as num?)?.toDouble() ?? 0.0,
      uv: (json['uvi'] as num?)?.toDouble() ?? 0.0,
      avgHumidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
      visibilityKm: (json['visibility'] as num?)?.toDouble() ?? 0.0,
      sunrise: _formatTime((json['sunrise'] as num?)?.toInt()),
      sunset: _formatTime((json['sunset'] as num?)?.toInt()),
      moonPhase: (json['moon_phase'] as num?)?.toString() ?? '',
      maxWindSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0.0,
      windDirection: _degToCompass((json['wind_deg'] as num?)?.toInt()),
      windDegree: (json['wind_deg'] as num?)?.toInt() ?? 0,
      cloudCoverage: (json['clouds'] as num?)?.toInt() ?? 0,
      hourlyForecasts: hourly,
    );
  }
}

class HourlyForecast {
  final String time;
  final double temperature;
  final String icon;
  final String description;
  final double chanceOfRain;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.icon,
    required this.description,
    required this.chanceOfRain,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    final dt = (json['dt'] as num?)?.toInt();
    final time =
        dt != null
            ? DateTime.fromMillisecondsSinceEpoch(dt * 1000)
            : DateTime.now();
    final weatherArr = json['weather'] as List<dynamic>?;
    final weather =
        weatherArr != null &&
                weatherArr.isNotEmpty &&
                weatherArr.first is Map<String, dynamic>
            ? weatherArr.first as Map<String, dynamic>
            : null;
    return HourlyForecast(
      time: DateFormat('h a').format(time),
      temperature:
          (json['temp'] as num?)?.toDouble() ??
          (json['main']?['temp'] as num?)?.toDouble() ??
          0.0,
      icon:
          weather != null && weather['icon'] != null
              ? 'https://openweathermap.org/img/wn/${weather['icon']}@2x.png'
              : '',
      description: weather != null ? (weather['description'] ?? '') : '',
      chanceOfRain: (json['pop'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// Helpers for OpenWeather parsing
String _degToCompass(int? deg) {
  if (deg == null) return '';
  const dirs = [
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW',
  ];
  final idx = ((deg / 22.5) + 0.5).floor() % 16;
  return dirs[idx];
}

double _extractPrecip(Map<String, dynamic> current) {
  // OpenWeather current may include rain/1h or snow/1h
  final rain = current['rain'];
  if (rain is Map && rain['1h'] is num) return (rain['1h'] as num).toDouble();
  final snow = current['snow'];
  if (snow is Map && snow['1h'] is num) return (snow['1h'] as num).toDouble();
  return 0.0;
}

String _formatTime(int? epochSeconds) {
  if (epochSeconds == null) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  return DateFormat('h:mm a').format(dt);
}

// Transformations from OpenWeather "weather" and "forecast" endpoints into
// shapes similar to One Call for reuse of parsers.
Map<String, dynamic> _toOneCallCurrent(Map<String, dynamic> current) {
  final weatherArr = current['weather'] as List?;
  final weather =
      weatherArr != null && weatherArr.isNotEmpty && weatherArr.first is Map
          ? weatherArr.first as Map<String, dynamic>
          : null;

  return {
    'temp': (current['main']?['temp'] as num?)?.toDouble(),
    'weather': weather != null ? [weather] : [],
    'wind_speed': (current['wind']?['speed'] as num?)?.toDouble(),
    'wind_deg': (current['wind']?['deg'] as num?)?.toInt(),
    'humidity': (current['main']?['humidity'] as num?)?.toInt(),
    'clouds': (current['clouds']?['all'] as num?)?.toInt(),
    'rain': current['rain'],
    'snow': current['snow'],
    'sunrise': (current['sys']?['sunrise'] as num?),
    'sunset': (current['sys']?['sunset'] as num?),
  };
}

List<Map<String, dynamic>> _toDailyFromForecast(Map<String, dynamic> forecast) {
  final list = forecast['list'];
  if (list is! List) return const [];

  // Group by date (yyyy-MM-dd) and aggregate.
  final Map<String, List<Map<String, dynamic>>> byDate = {};
  for (final item in list) {
    if (item is! Map) continue;
    final dt = item['dt'];
    if (dt is! num) continue;
    final date = DateTime.fromMillisecondsSinceEpoch(dt.toInt() * 1000);
    final key = DateFormat('yyyy-MM-dd').format(date);
    byDate.putIfAbsent(key, () => []).add(Map<String, dynamic>.from(item));
  }

  final daily = <Map<String, dynamic>>[];
  for (final entry in byDate.entries) {
    final items = entry.value;
    if (items.isEmpty) continue;

    num? tempMin;
    num? tempMax;
    num tempSum = 0;
    int tempCount = 0;
    num popMax = 0;
    final List<double> pops = [];
    num humiditySum = 0;
    int humidityCount = 0;
    num cloudsSum = 0;
    int cloudsCount = 0;
    num visibilitySum = 0;
    int visibilityCount = 0;
    num windSpeedMax = 0;
    int? windDeg;
    Map<String, dynamic>? firstWeather;

    for (final item in items) {
      final main = item['main'] as Map?;
      final temp = main?['temp'] as num?;
      final tMin = main?['temp_min'] as num?;
      final tMax = main?['temp_max'] as num?;
      if (tMin != null)
        tempMin =
            tempMin == null
                ? tMin
                : tempMin < tMin
                ? tempMin
                : tMin;
      if (tMax != null)
        tempMax =
            tempMax == null
                ? tMax
                : tempMax > tMax
                ? tempMax
                : tMax;
      if (temp != null) {
        tempSum += temp;
        tempCount++;
      }

      final pop = item['pop'] as num?;
      if (pop != null) {
        final p = pop.toDouble();
        pops.add(p);
        if (p > popMax) popMax = p;
      }

      final hum = main?['humidity'] as num?;
      if (hum != null) {
        humiditySum += hum;
        humidityCount++;
      }

      final vis = item['visibility'] as num?;
      if (vis != null) {
        visibilitySum += vis;
        visibilityCount++;
      }

      final clouds =
          item['clouds'] is Map ? (item['clouds']['all'] as num?) : null;
      if (clouds != null) {
        cloudsSum += clouds;
        cloudsCount++;
      }

      final wind = item['wind'] as Map?;
      final speed = wind?['speed'] as num?;
      if (speed != null && speed > windSpeedMax) windSpeedMax = speed;
      windDeg ??= wind?['deg'] as int?;

      if (firstWeather == null) {
        final wArr = item['weather'] as List?;
        if (wArr != null && wArr.isNotEmpty && wArr.first is Map) {
          firstWeather = Map<String, dynamic>.from(wArr.first as Map);
        }
      }
    }

    final avgTemp = tempCount > 0 ? tempSum / tempCount : null;
    final avgHumidity = humidityCount > 0 ? humiditySum / humidityCount : null;
    final avgClouds = cloudsCount > 0 ? cloudsSum / cloudsCount : null;
    final avgVisibility =
        visibilityCount > 0 ? visibilitySum / visibilityCount : null;

    // Probability of any precipitation during the day: 1 - Π(1 - pop_i)
    double popAny = popMax.toDouble();
    if (pops.isNotEmpty) {
      double product = 1.0;
      for (final p in pops) {
        final pc = p.clamp(0.0, 1.0);
        product *= (1 - pc);
      }
      popAny = (1 - product).clamp(0.0, 1.0);
    }

    // Use the first item's dt as representative.
    final firstDt = items.first['dt'] as num?;

    daily.add({
      'dt': firstDt,
      'temp': {'min': tempMin, 'max': tempMax, 'day': avgTemp},
      'pop': popAny, // probability of precipitation (0-1)
      'uvi': 0,
      'humidity': avgHumidity,
      'visibility': avgVisibility,
      'sunrise': null,
      'sunset': null,
      'moon_phase': null,
      'wind_speed': windSpeedMax,
      'wind_deg': windDeg,
      'clouds': avgClouds,
      'weather': firstWeather != null ? [firstWeather] : [],
      'hourly': items, // attach 3-hour slices for this date
    });
  }

  // Sort by date ascending
  daily.sort((a, b) {
    final adt = (a['dt'] as num?)?.toInt() ?? 0;
    final bdt = (b['dt'] as num?)?.toInt() ?? 0;
    return adt.compareTo(bdt);
  });

  return daily;
}
