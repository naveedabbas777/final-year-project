import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:mockup_app/screens/detailed_forecast_screen.dart';
import 'package:mockup_app/services/connectivity_service.dart';
import 'package:mockup_app/services/firebase_service.dart';
import 'package:mockup_app/services/weather_service.dart';
import 'package:mockup_app/utils/error_presenter.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  double? _latitude;
  double? _longitude;
  Future<List<DailyForecast>>? _dailyForecastFuture;
  bool _backendUnreachable = false;

  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

  @override
  void initState() {
    super.initState();
    _loadForecastData();
  }

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
        return Icon(Icons.cloud_queue, size: 40, color: Colors.blueGrey.shade500);
      case '09':
      case '10':
        return Icon(Icons.grain, size: 40, color: Colors.blue.shade500);
      case '11':
        return Icon(Icons.thunderstorm, size: 40, color: Colors.deepPurple.shade400);
      case '13':
        return Icon(Icons.ac_unit, size: 40, color: Colors.lightBlue.shade200);
      case '50':
        return Icon(Icons.foggy, size: 40, color: Colors.grey.shade500);
      default:
        return Icon(Icons.cloud, size: 40, color: Colors.blueGrey.shade400);
    }
  }

  Future<void> _loadForecastData() async {
    final connectivityService = ConnectivityService();
    final isBackendHealthy = await connectivityService.checkBackendHealth();

    if (!isBackendHealthy) {
      if (mounted) {
        setState(() {
          _backendUnreachable = true;
          _dailyForecastFuture = Future.value(<DailyForecast>[]);
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _backendUnreachable = false;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final savedLat = prefs.getDouble('last_latitude');
    final savedLon = prefs.getDouble('last_longitude');

    double? backendLat;
    double? backendLon;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final profile = await FirebaseService().getUserByUid(user.uid);
        backendLat = (profile?['lat'] as num?)?.toDouble();
        backendLon = (profile?['lon'] as num?)?.toDouble();
        if (backendLat != null &&
            backendLon != null &&
            (savedLat != backendLat || savedLon != backendLon)) {
          await prefs.setDouble('last_latitude', backendLat);
          await prefs.setDouble('last_longitude', backendLon);
        }
      } catch (e) {
        debugPrint('Error loading user profile: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _latitude = savedLat ?? backendLat;
      _longitude = savedLon ?? backendLon;
      if (kDebugMode) {
        debugPrint('ForecastScreen: Loaded latitude: $_latitude, longitude: $_longitude');
      }
      if (_latitude != null && _longitude != null) {
        _dailyForecastFuture = WeatherService()
            .fetchWeatherData(_latitude!, _longitude!)
            .then((data) {
              final forecastMap = data['forecast'];
              if (forecastMap is Map<String, dynamic>) {
                final daily = forecastMap['daily'];
                if (daily is List) {
                  return daily
                      .map((item) {
                        if (item is DailyForecast) return item;
                        if (item is Map<String, dynamic>) {
                          return DailyForecast.fromJson(item);
                        }
                        if (item is Map) {
                          return DailyForecast.fromJson(Map<String, dynamic>.from(item));
                        }
                        return null;
                      })
                      .whereType<DailyForecast>()
                      .toList();
                }
              }
              return <DailyForecast>[];
            })
            .catchError((error) {
              if (kDebugMode) {
                debugPrint('ForecastScreen: Error fetching weather data: $error');
              }
              throw error;
            });
      } else {
        _dailyForecastFuture = Future.value(<DailyForecast>[]);
      }
    });
  }

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
      body: DefaultTextStyle.merge(
        style: const TextStyle(color: AppColors.textPrimary),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<List<DailyForecast>>(
            future: _dailyForecastFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AsyncLoadingWidget();
              }

              if (_backendUnreachable) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 48, color: Colors.red.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _t('Backend Unreachable', 'بیک اینڈ دستیاب نہیں'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Unable to connect to the server. Please check your network and try again.',
                          'سرور سے رابطہ نہیں ہو سکا۔ براہ کرم نیٹ ورک چیک کریں اور دوبارہ کوشش کریں۔',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'USB-connected Android devices need adb reverse tcp:5000 tcp:5000, or launch with --dart-define=API_BASE_URL=http://<your-pc-ip>:5000.',
                          'USB سے منسلک اینڈرائیڈ ڈیوائسز کے لیے adb reverse tcp:5000 tcp:5000 چلائیں، یا --dart-define=API_BASE_URL=http://<your-pc-ip>:5000 کے ساتھ لانچ کریں۔',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _loadForecastData,
                            icon: const Icon(Icons.refresh),
                            label: Text(_t('Retry', 'دوبارہ کوشش')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            label: Text(_t('Go Back', 'واپس جائیں')),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                      const SizedBox(height: 16),
                      Text(
                        ErrorPresenter.present(snapshot.error),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _loadForecastData,
                            icon: const Icon(Icons.refresh),
                            label: Text(_t('Retry', 'دوبارہ کوشش')),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            label: Text(_t('Go Back', 'واپس جائیں')),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.noForecastDataAvailable,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadForecastData,
                        icon: const Icon(Icons.refresh),
                        label: Text(_t('Refresh', 'ریفریش')),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final day = snapshot.data![index];
                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailedForecastScreen(forecast: day),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        day.day,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
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
                                    Icon(Icons.water_drop, color: Colors.blue.shade400, size: 18),
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
                                        color: day.pop > 0.5
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
                                    Icon(Icons.air, size: 16, color: Colors.grey.shade600),
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
                                    Icon(Icons.visibility, size: 16, color: Colors.teal.shade600),
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
            },
          ),
        ),
      ),
    );
  }
}
