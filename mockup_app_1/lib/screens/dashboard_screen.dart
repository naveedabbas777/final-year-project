import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/tip_card.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:mockup_app/screens/profile_screen.dart';
import 'package:mockup_app/services/weather_service.dart'; // Import WeatherService
import 'package:mockup_app/services/connectivity_service.dart';
import 'package:mockup_app/screens/location_screen.dart';
import 'package:mockup_app/screens/detailed_forecast_screen.dart';
import 'package:mockup_app/screens/alerts_screen.dart';
import 'package:mockup_app/services/alert_service.dart';
import 'package:mockup_app/screens/plant_disease_screen.dart';
import 'package:provider/provider.dart';
import 'package:mockup_app/services/firebase_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _locationName = 'Loading...';
  double? _latitude;
  double? _longitude;
  Future<CurrentWeather?>? _currentWeatherFuture;
  Future<List<DailyForecast>>? _todayForecastFuture;
  bool _backendUnreachable = false;
  String? _profilePhotoUrl;
  String? _profileDisplayName;
  final PageController _tipsPageController = PageController(
    viewportFraction: 0.78,
  );
  Timer? _tipsAutoScrollTimer;
  Timer? _alertTimer;
  bool _userTipsInteracting = false;
  int _tipsPageIndex = 0;
  final List<String> _tipKeys = [
    'avoidPesticide',
    'irrigateFields',
    'checkSoilMoisture',
    'delayFertilizer',
    'harvestEarly',
  ];

  Icon _buildWeatherIcon(String iconUrl, {int? cloudCover}) {
    // Extract code like "10d" or "01n" from the OpenWeather icon URL.
    final match = RegExp(r"/(\d{2}[dn])@").firstMatch(iconUrl);
    final code = match != null ? match.group(1) ?? '' : '';
    final isNight = code.endsWith('n');

    Color pickColor(Color light, Color mid, Color heavy) {
      final cc = cloudCover ?? 0;
      if (cc > 70) return heavy;
      if (cc > 30) return mid;
      return light;
    }

    switch (code.substring(0, 2)) {
      case '01':
        return Icon(
          isNight ? Icons.nightlight_round : Icons.wb_sunny,
          size: 50,
          color: isNight ? Colors.indigo.shade200 : Colors.amber.shade600,
        );
      case '02':
      case '03':
      case '04':
        return Icon(
          isNight ? Icons.cloudy_snowing : Icons.cloud_queue,
          size: 50,
          color: pickColor(
            Colors.blueGrey.shade300,
            Colors.blueGrey.shade500,
            Colors.blueGrey.shade700,
          ),
        );
      case '09':
      case '10':
        return Icon(Icons.grain, size: 50, color: Colors.blue.shade500);
      case '11':
        return Icon(
          Icons.thunderstorm,
          size: 50,
          color: Colors.deepPurple.shade400,
        );
      case '13':
        return Icon(Icons.ac_unit, size: 50, color: Colors.lightBlue.shade200);
      case '50':
        return Icon(Icons.foggy, size: 50, color: Colors.grey.shade500);
      default:
        return Icon(Icons.cloud, size: 50, color: Colors.blueGrey.shade400);
    }
  }

  Widget _buildAlertIcon(String? type) {
    switch (type) {
      case 'rain':
        return const CircleAvatar(
          backgroundColor: Color(0xFFE3F2FD),
          child: Icon(Icons.grain, color: Colors.blue),
        );
      case 'heat':
        return const CircleAvatar(
          backgroundColor: Color(0xFFFFF3E0),
          child: Icon(Icons.wb_sunny, color: Colors.orange),
        );
      case 'cold':
        return const CircleAvatar(
          backgroundColor: Color(0xFFE0F7FA),
          child: Icon(Icons.ac_unit, color: Colors.teal),
        );
      case 'wind':
        return const CircleAvatar(
          backgroundColor: Color(0xFFE8EAF6),
          child: Icon(Icons.air, color: Colors.indigo),
        );
      default:
        return const CircleAvatar(
          backgroundColor: Color(0xFFE0E0E0),
          child: Icon(Icons.notifications, color: Colors.black54),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData(); // Call a single method to load all dashboard data
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTipsAutoScroll());
  }

  @override
  void dispose() {
    _tipsAutoScrollTimer?.cancel();
    _alertTimer?.cancel();
    _tipsPageController.dispose();
    super.dispose();
  }

  void _startTipsAutoScroll() {
    _tipsAutoScrollTimer?.cancel();
    _tipsAutoScrollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _autoScrollTips(_tipKeys.length),
    );
  }

  void _autoScrollTips(int itemCount) {
    if (!_tipsPageController.hasClients ||
        _userTipsInteracting ||
        itemCount == 0) {
      return;
    }

    final nextPage = (_tipsPageIndex + 1) % itemCount;
    _tipsPageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
    _tipsPageIndex = nextPage;
  }

  void _onTipsScrollStart() {
    _userTipsInteracting = true;
    _tipsAutoScrollTimer?.cancel();
  }

  void _onTipsScrollEnd() {
    _userTipsInteracting = false;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_userTipsInteracting) {
        _startTipsAutoScroll();
      }
    });
  }

  Future<void> _loadDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _locationName = 'No location set';
          _currentWeatherFuture = Future.value(null);
          _todayForecastFuture = Future.value(<DailyForecast>[]);
          _backendUnreachable = false;
          _profilePhotoUrl = null;
          _profileDisplayName = null;
        });
      }
      return;
    }

    try {
      // Check backend connectivity first
      final connectivityService = ConnectivityService();
      final isBackendHealthy = await connectivityService.checkBackendHealth();

      if (!isBackendHealthy) {
        // Try to load from cache (SharedPreferences)
        try {
          final prefs = await SharedPreferences.getInstance();
          final lat = prefs.getDouble('last_latitude');
          final lng = prefs.getDouble('last_longitude');
          final address = prefs.getString('last_address');

          _latitude = lat;
          _longitude = lng;
          _locationName = address ?? 'No location set';
        } catch (_) {
          _locationName = 'No location set';
          _latitude = null;
          _longitude = null;
        }

        if (mounted) {
          setState(() {
            _backendUnreachable = true;
            // Keep FutureBuilder stable; unreachable state is handled by _backendUnreachable UI branch.
            _currentWeatherFuture = Future.value(null);
            _todayForecastFuture = Future.value(<DailyForecast>[]);
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _backendUnreachable = false;
        });
      }

      final profile = await FirebaseService().getUserByUid(user.uid);
      _profilePhotoUrl =
          (profile?['photoUrl'] ?? profile?['photo'] ?? '').toString().trim();
      if (_profilePhotoUrl != null && _profilePhotoUrl!.isEmpty) {
        _profilePhotoUrl = null;
      }
      _profileDisplayName =
          (profile?['displayName'] ?? profile?['name'] ?? '').toString().trim();
      if (_profileDisplayName != null && _profileDisplayName!.isEmpty) {
        _profileDisplayName = null;
      }
      final address = profile?['address'] as String?;
      _latitude = (profile?['lat'] as num?)?.toDouble();
      _longitude = (profile?['lon'] as num?)?.toDouble();
      _locationName =
          address?.trim().isNotEmpty == true
              ? address!.trim()
              : 'No location set';

      // If backend profile has no location yet, fall back to last local selection.
      if (_latitude == null || _longitude == null) {
        final prefs = await SharedPreferences.getInstance();
        _latitude ??= prefs.getDouble('last_latitude');
        _longitude ??= prefs.getDouble('last_longitude');
        final cachedAddress = prefs.getString('last_address');
        if ((_locationName == 'No location set' ||
                _locationName.trim().isEmpty) &&
            cachedAddress != null &&
            cachedAddress.trim().isNotEmpty) {
          _locationName = cachedAddress.trim();
        }
      }

      final service = WeatherService();
      final fetch =
          _latitude != null && _longitude != null
              ? service.fetchWeatherData(_latitude, _longitude)
              : service.fetchWeatherData();
      fetch.then(_processAlertsFromData).catchError((_) {});
      _currentWeatherFuture = fetch.then(
        (data) => CurrentWeather.fromJson(
          data['current'] as Map<String, dynamic>? ?? {},
        ),
      );
      _todayForecastFuture = fetch.then((data) {
        final daily = data['forecast']?['daily'] as List<dynamic>?;
        if (daily != null && daily.isNotEmpty) {
          final first = daily.first;
          if (first is DailyForecast) {
            return [first];
          }
          if (first is Map<String, dynamic>) {
            return [DailyForecast.fromJson(first)];
          }
          if (first is Map) {
            return [DailyForecast.fromJson(Map<String, dynamic>.from(first))];
          }
        }
        return <DailyForecast>[];
      });
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // Keep last known local location when backend calls fail.
        _locationName =
            _locationName.trim().isNotEmpty ? _locationName : 'No location set';
        _currentWeatherFuture = Future.value(null);
        _todayForecastFuture = Future.value(<DailyForecast>[]);
        _backendUnreachable = true;
      });
    }
  }

  Future<void> _processAlertsFromData(Map<String, dynamic> data) async {
    final alertService = Provider.of<AlertService>(context, listen: false);

    final current =
        data['current'] is Map<String, dynamic>
            ? CurrentWeather.fromJson(data['current'] as Map<String, dynamic>)
            : null;
    DailyForecast? todayForecast;
    final daily = data['forecast']?['daily'] as List<dynamic>?;
    if (daily != null &&
        daily.isNotEmpty &&
        daily.first is Map<String, dynamic>) {
      todayForecast = DailyForecast.fromJson(
        daily.first as Map<String, dynamic>,
      );
    }

    await alertService.processWeather(current, todayForecast);
  }

  @override
  Widget build(BuildContext context) {
    final effectivePhotoUrl =
        _profilePhotoUrl?.trim().isNotEmpty == true
            ? _profilePhotoUrl!.trim()
            : FirebaseAuth.instance.currentUser?.photoURL;
    final effectiveName =
        _profileDisplayName?.trim().isNotEmpty == true
            ? _profileDisplayName!.trim()
            : FirebaseAuth.instance.currentUser?.displayName?.trim();
    final effectiveEmail = FirebaseAuth.instance.currentUser?.email?.trim();
    final initial =
        (effectiveName?.isNotEmpty == true
                ? effectiveName![0]
                : (effectiveEmail?.isNotEmpty == true
                    ? effectiveEmail![0]
                    : 'U'))
            .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dashboard),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                // Reload so avatar/name update if profile was edited
                if (mounted) await _loadDashboardData();
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.green.shade100,
                  backgroundImage:
                      effectivePhotoUrl != null && effectivePhotoUrl.isNotEmpty
                          ? NetworkImage(effectivePhotoUrl)
                          : null,
                  child:
                      effectivePhotoUrl == null || effectivePhotoUrl.isEmpty
                          ? Text(
                            initial,
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          )
                          : null,
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.green.shade50,
      body: RefreshIndicator(
        color: Colors.green.shade700,
        onRefresh: _loadDashboardData,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              FutureBuilder<CurrentWeather?>(
                future: _currentWeatherFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const SizedBox.shrink();
                  }
                  final cw = snapshot.data!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        _InfoChip(
                          icon: Icons.wb_sunny_outlined,
                          label: 'Sunrise',
                          value: cw.sunrise.isNotEmpty ? cw.sunrise : '—',
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.nightlight_round,
                          label: 'Sunset',
                          value: cw.sunset.isNotEmpty ? cw.sunset : '—',
                          color: Colors.indigo.shade300,
                        ),
                      ],
                    ),
                  );
                },
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LocationScreen()),
                  );
                  if (mounted) {
                    await _loadDashboardData();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.location,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.edit_location_alt,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 32.0),
                        child: Text(
                          _locationName,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FutureBuilder<CurrentWeather?>(
                future: _currentWeatherFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AsyncLoadingWidget();
                  } else if (_backendUnreachable) {
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 48,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Backend Unreachable',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                             'Unable to connect to the server. Please check your internet connection and try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                _loadDashboardData();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.orange.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.errorFetchingWeather,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                _loadDashboardData();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data == null) {
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          AppLocalizations.of(context)!.noWeatherDataAvailable,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    );
                  } else {
                    final currentWeather = snapshot.data!;
                    return FutureBuilder<List<DailyForecast>>(
                      future: _todayForecastFuture,
                      builder: (context, forecastSnapshot) {
                        final todayForecast =
                            forecastSnapshot.data?.isNotEmpty == true
                                ? forecastSnapshot.data!.first
                                : null;
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap:
                                todayForecast == null
                                    ? null
                                    : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => DetailedForecastScreen(
                                                forecast: todayForecast,
                                              ),
                                        ),
                                      );
                                    },
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Stack(
                                children: [
                                  // Weather data layout: Temperature | Icon + Status | Rain Expectancy
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      20,
                                      8,
                                      20,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // First: Temperature
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.thermostat,
                                                size: 24,
                                                color: Colors.orange.shade600,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${currentWeather.temperature.round()}°C',
                                                style: const TextStyle(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Second: Weather icon with status below
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: Column(
                                            children: [
                                              // Weather icon from service
                                              _buildWeatherIcon(
                                                currentWeather.icon,
                                                cloudCover:
                                                    currentWeather.cloudCover,
                                              ),
                                              const SizedBox(height: 8),
                                              // Weather status below icon
                                              Text(
                                                currentWeather.description,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Third: Rain expectancy (will be positioned by Stack)
                                      ],
                                    ),
                                  ),
                                  // Add some bottom padding to make room for the rain expectancy
                                  const SizedBox(height: 50),
                                  // Rain info positioned in bottom right corner
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: FutureBuilder<CurrentWeather?>(
                                      future: _currentWeatherFuture,
                                      builder: (context, currentSnapshot) {
                                        return FutureBuilder<
                                          List<DailyForecast>
                                        >(
                                          future: _todayForecastFuture,
                                          builder: (context, forecastSnapshot) {
                                            final currentWeather =
                                                currentSnapshot.data;
                                            final todayForecast =
                                                forecastSnapshot
                                                            .data
                                                            ?.isNotEmpty ==
                                                        true
                                                    ? forecastSnapshot
                                                        .data!
                                                        .first
                                                    : null;

                                            final rainChance =
                                                todayForecast != null
                                                    ? (todayForecast.pop * 100)
                                                        .round()
                                                    : 0;

                                            final cloudCoverage =
                                                currentWeather?.cloudCover ?? 0;

                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                // Rain expectancy
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      'Rain Expectancy',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Colors
                                                                .blue
                                                                .shade500,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.water_drop,
                                                          size: 16,
                                                          color:
                                                              rainChance > 30
                                                                  ? Colors
                                                                      .red
                                                                      .shade600
                                                                  : rainChance >
                                                                      10
                                                                  ? Colors
                                                                      .orange
                                                                      .shade600
                                                                  : Colors
                                                                      .blue
                                                                      .shade600,
                                                        ),
                                                        const SizedBox(
                                                          width: 3,
                                                        ),
                                                        Text(
                                                          '$rainChance%',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            color:
                                                                rainChance > 30
                                                                    ? Colors
                                                                        .red
                                                                        .shade600
                                                                    : rainChance >
                                                                        10
                                                                    ? Colors
                                                                        .orange
                                                                        .shade600
                                                                    : Colors
                                                                        .blue
                                                                        .shade600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                // Cloud coverage
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      'Cloud Coverage',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade500,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.cloud,
                                                          size: 16,
                                                          color:
                                                              cloudCoverage > 70
                                                                  ? Colors
                                                                      .grey
                                                                      .shade700
                                                                  : cloudCoverage >
                                                                      30
                                                                  ? Colors
                                                                      .grey
                                                                      .shade600
                                                                  : Colors
                                                                      .grey
                                                                      .shade400,
                                                        ),
                                                        const SizedBox(
                                                          width: 3,
                                                        ),
                                                        Text(
                                                          '$cloudCoverage%',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            color:
                                                                cloudCoverage >
                                                                        70
                                                                    ? Colors
                                                                        .grey
                                                                        .shade700
                                                                    : cloudCoverage >
                                                                        30
                                                                    ? Colors
                                                                        .grey
                                                                        .shade600
                                                                    : Colors
                                                                        .grey
                                                                        .shade400,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
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
              const SizedBox(height: 20),
              Consumer<AlertService>(
                builder: (context, alertService, _) {
                  final alerts = alertService.alerts;
                  final now = DateTime.now();
                  final start = DateTime(now.year, now.month, now.day);
                  final end = start.add(const Duration(days: 1));
                  final todays = alerts.where(
                    (a) =>
                        !a.createdAt.isBefore(start) &&
                        a.createdAt.isBefore(end),
                  );
                  final latestToday = todays.isNotEmpty ? todays.first : null;

                  return Card(
                    color:
                        latestToday == null
                            ? Colors.green.shade50
                            : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AlertsScreen(),
                          ),
                        );
                      },
                      child: ListTile(
                        leading: _buildAlertIcon(latestToday?.type),
                        title: Text(
                          latestToday?.title ?? 'Today weather is normal',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          latestToday?.body ??
                              'No alerts for your location today. Tap to view all alerts.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.quickTips,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification &&
                      notification.dragDetails != null) {
                    _onTipsScrollStart();
                  } else if (notification is ScrollEndNotification) {
                    _onTipsScrollEnd();
                  }
                  return false;
                },
                child: SizedBox(
                  height: 110,
                  child: PageView.builder(
                    controller: _tipsPageController,
                    onPageChanged: (index) => _tipsPageIndex = index,
                    itemCount: _tipKeys.length,
                    itemBuilder: (context, index) {
                      final loc = AppLocalizations.of(context)!;
                      final texts = [
                        loc.avoidPesticide,
                        loc.irrigateFields,
                        loc.checkSoilMoisture,
                        loc.delayFertilizer,
                        loc.harvestEarly,
                      ];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Align(
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 260,
                              maxWidth: 320,
                            ),
                            child: TipCard(text: texts[index]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: const Text('Open Plant Disease Detector'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PlantDiseaseScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),   // RefreshIndicator close
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
