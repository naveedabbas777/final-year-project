import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart'; // Import for SharedPreferences
import 'package:mockup_app/services/weather_service.dart'; // Import WeatherService and DailyForecast
import 'package:mockup_app/screens/detailed_forecast_screen.dart'; // Import DetailedForecastScreen
import 'package:mockup_app/l10n/app_localizations.dart'; // Corrected import

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
      print(
        'ForecastScreen: Loaded latitude: $_latitude, longitude: $_longitude',
      );
      if (_latitude != null && _longitude != null) {
        _dailyForecastFuture = WeatherService()
            .fetchWeatherData(_latitude!, _longitude!)
            .then((data) {
              print('ForecastScreen: WeatherService returned data.');
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
                print('ForecastScreen: daily missing or malformed: $daily');
              } else {
                print('ForecastScreen: forecast map missing or malformed.');
              }
              return <DailyForecast>[];
            })
            .catchError((error) {
              print('ForecastScreen: Error fetching weather data: $error');
              throw error; // Re-throw to propagate the error to FutureBuilder
            });
      } else {
        print(
          'ForecastScreen: Latitude or longitude is null. Cannot fetch forecast.',
        );
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
                child: Text(
                  AppLocalizations.of(context)!.errorFetchingForecast,
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  AppLocalizations.of(context)!.noForecastDataAvailable,
                ),
              );
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final day = snapshot.data![index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
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
                      child: ListTile(
                        leading: _buildWeatherIcon(day.icon),
                        title: Text(day.day),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppLocalizations.of(context)!.high}: ${day.maxTemperature.round()}°C, ${AppLocalizations.of(context)!.low}: ${day.minTemperature.round()}°C',
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.air,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${day.maxWindSpeed.round()} km/h ${day.windDirection}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.water_drop,
                                  size: 14,
                                  color: Colors.blue.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  day.pop >= 0.005
                                      ? '${(day.pop * 100).toStringAsFixed(0)}% rain'
                                      : day.pop > 0
                                      ? '<1% rain'
                                      : '0% rain',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.visibility,
                                  size: 14,
                                  color: Colors.teal.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  day.visibilityKm > 0
                                      ? '${day.visibilityKm.toStringAsFixed(1)} km vis'
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
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.water_drop,
                              color: Colors.blue.shade400,
                              size: 18,
                            ),
                            Text(
                              day.pop >= 0.005
                                  ? '${(day.pop * 100).toStringAsFixed(0)}%'
                                  : day.pop > 0
                                  ? '<1%'
                                  : '0%',
                              style: TextStyle(
                                fontSize: 12,
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
