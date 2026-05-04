import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart'; // Import for SharedPreferences
import 'package:mockup_app/services/weather_service.dart'; // Import WeatherService and DailyForecast
import 'package:mockup_app/screens/detailed_forecast_screen.dart'; // Import DetailedForecastScreen
import 'package:mockup_app/l10n/app_localizations.dart'; // Corrected import
import 'package:mockup_app/utils/error_presenter.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({Key? key}) : super(key: key);

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  double? _latitude;
  double? _longitude;
  Future<List<DailyForecast>>? _dailyForecastFuture;

  Icon _buildWeatherIcon(String iconUrl) {
    final match = RegExp(r"/(\d{2}[dn])@").firstMatch(iconUrl);
    final code = match != null ? match.group(1) ?? '' : '';
    final isNight = code.endsWith('n');

    switch (code.substring(0, 2)) {
      case '01':
        return Icon(
          isNight ? Icons.nightlight_round : Icons.wb_sunny,
          size: 40,
          color: isNight ? Colors.indigo.shade200 : Colors.amber.shade600,
        );
      case '02':
      case '03':
      case '04':
        return Icon(
          Icons.cloud_queue,
          size: 40,
          color: Colors.blueGrey.shade500,
        );
      case '09':
      case '10':
        return Icon(Icons.grain, size: 40, color: Colors.blue.shade500);
      case '11':
        return Icon(
          Icons.thunderstorm,
          size: 40,
          color: Colors.deepPurple.shade400,
        );
      case '13':
        return Icon(Icons.ac_unit, size: 40, color: Colors.lightBlue.shade200);
      case '50':
        return Icon(Icons.foggy, size: 40, color: Colors.grey.shade500);
      default:
        return Icon(Icons.cloud, size: 40, color: Colors.blueGrey.shade400);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadForecastData();
  }

  Future<void> _loadForecastData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _latitude = prefs.getDouble('last_latitude');
      _longitude = prefs.getDouble('last_longitude');
      if (kDebugMode) {
        debugPrint(
          'ForecastScreen: Loaded latitude: $_latitude, longitude: $_longitude',
        );
      }
      if (_latitude != null && _longitude != null) {
        _dailyForecastFuture = WeatherService()
            .fetchWeatherData(_latitude!, _longitude!)
            .then((data) {
              if (kDebugMode) {
                debugPrint('ForecastScreen: WeatherService returned data.');
              }
              final forecastMap = data['forecast'];
              if (forecastMap is Map<String, dynamic>) {
                final daily = forecastMap['daily'];
                if (daily is List) {
                  return daily
                      .where((item) => item is Map<String, dynamic>)
                      .map(
                        (item) => DailyForecast.fromJson(
                          Map<String, dynamic>.from(item as Map),
                        ),
                      )
                      .toList();
                }
                if (kDebugMode) {
                  debugPrint(
                    'ForecastScreen: daily missing or malformed: $daily',
                  );
                }
              } else {
                if (kDebugMode) {
                  debugPrint(
                    'ForecastScreen: forecast map missing or malformed.',
                  );
                }
              }
              return <DailyForecast>[];
            })
            .catchError((error) {
              if (kDebugMode) {
                debugPrint(
                  'ForecastScreen: Error fetching weather data: $error',
                );
              }
              throw error; // Re-throw to propagate the error to FutureBuilder
            });
      } else {
        if (kDebugMode) {
          debugPrint(
            'ForecastScreen: Latitude or longitude is null. Cannot fetch forecast.',
          );
        }
        _dailyForecastFuture = Future.value(
          <DailyForecast>[],
        ); // No location, no forecast
      }
    });
  }

  // Removed dummyForecast as it's no longer needed
  // final List<Map<String, dynamic>> dummyForecast = const [
  //   {
  //     'day': 'Mon',
  //     'icon': Icons.wb_sunny,
  //     'high': 33,
  //     'low': 22,
  //     'rain': '10%',
  //   },
  //   ...
  // ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.forecastTitle),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.green.shade50,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<DailyForecast>>(
          future: _dailyForecastFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ErrorPresenter.present(snapshot.error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _loadForecastData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context)!.noForecastDataAvailable),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadForecastData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              );
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final day = snapshot.data![index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    DetailedForecastScreen(forecast: day),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildWeatherIcon(day.icon),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        day.day,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${AppLocalizations.of(context)!.high}: ${day.maxTemperature.round()}°C | ${AppLocalizations.of(context)!.low}: ${day.minTemperature.round()}°C',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.water_drop,
                                      color: Colors.blue.shade400,
                                      size: 18,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      day.pop >= 0.005
                                          ? '${(day.pop * 100).toStringAsFixed(0)}%'
                                          : day.pop > 0
                                          ? '<1%'
                                          : '0%',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            day.pop > 0.5
                                                ? Colors.red.shade600
                                                : day.pop > 0.3
                                                ? Colors.orange.shade600
                                                : day.pop > 0.1
                                                ? Colors.blue.shade600
                                                : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(height: 1, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.air,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${day.maxWindSpeed.round()} km/h',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.visibility,
                                      size: 16,
                                      color: Colors.teal.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      day.visibilityKm > 0
                                          ? '${day.visibilityKm.toStringAsFixed(1)} km'
                                          : '—',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}
