import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';
import '../services/firebase_service.dart';
import '../services/weather_service.dart';
import '../utils/error_presenter.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with WidgetsBindingObserver {
  String? _currentAddress;
  bool _isFetchingGps = false;
  bool _isSearching = false;
  bool _isSavingLocation = false;
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  Uint8List? _markerImage;
  late TextEditingController _textController;
  double? _lastLat;
  double? _lastLng;
  bool _didRequestSettings = false;
  bool _isSatelliteView = false;

  bool get _isBusy => _isFetchingGps || _isSearching || _isSavingLocation;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _loadLastLocation();
    _loadMarkerImage();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapboxMap?.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _didRequestSettings) {
      _didRequestSettings = false;
      final serviceEnabled =
          await geolocator.Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        _getCurrentPosition();
      }
    }
  }

  Future<void> _loadMarkerImage() async {
    final ByteData byteData = await rootBundle.load('assets/marker.png');
    setState(() {
      _markerImage = byteData.buffer.asUint8List();
    });
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    geolocator.LocationPermission permission;

    serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _didRequestSettings = true;
      await geolocator.Geolocator.openLocationSettings();
      return false;
    }

    permission = await geolocator.Geolocator.checkPermission();
    if (permission == geolocator.LocationPermission.denied) {
      permission = await geolocator.Geolocator.requestPermission();
      if (permission == geolocator.LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.locationPermissionsDenied,
            ),
          ),
        );
        return false;
      }
    }

    if (permission == geolocator.LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.locationPermissionsPermanentlyDenied,
          ),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.settingsButtonLabel,
            onPressed: () {
              geolocator.Geolocator.openAppSettings();
            },
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    if (mounted) {
      setState(() => _isFetchingGps = true);
    }

    try {
      geolocator.Position position = await geolocator
          .Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
      );
      await _updateLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        final message = ErrorPresenter.present(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingGps = false;
        });
      }
    }
  }

  Future<void> _loadLastLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _getCurrentPosition();
      return;
    }

    try {
      final doc = await FirebaseService().getUserByUid(user.uid);
      final lat = (doc?['lat'] as num?)?.toDouble();
      final lng = (doc?['lon'] as num?)?.toDouble();
      final address = doc?['address'] as String?;

      if (lat != null && lng != null && address != null && address.isNotEmpty) {
        if (mounted) {
          setState(() {
            _lastLat = lat;
            _lastLng = lng;
            _currentAddress = address;
          });
        }
        _centerMapOnLocation(lat, lng);
        _addMarker(Point(coordinates: Position(lng, lat)));
        return;
      }
    } catch (e) {
      debugPrint(
        'Failed to load from Firebase: $e. Trying SharedPreferences...',
      );
    }

    // Fallback: Try to load from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('last_latitude');
      final lng = prefs.getDouble('last_longitude');
      final address = prefs.getString('last_address');

      if (lat != null && lng != null && address != null && address.isNotEmpty) {
        if (mounted) {
          setState(() {
            _lastLat = lat;
            _lastLng = lng;
            _currentAddress = address;
          });
        }
        _centerMapOnLocation(lat, lng);
        _addMarker(Point(coordinates: Position(lng, lat)));
        return;
      }
    } catch (e) {
      debugPrint('Failed to load from SharedPreferences: $e');
    }

    // If no saved location, get current position
    _getCurrentPosition();
  }

  Future<void> _searchAndSaveLocation(String address) async {
    if (address.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(
        address,
      );

      if (locations.isNotEmpty) {
        final location = locations.first;
        await _updateLocation(location.latitude, location.longitude);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.locationNotFound),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorPresenter.present(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _updateLocation(
    double lat,
    double lng, {
    bool shouldCenterMap = true,
  }) async {
    try {
      List<geocoding.Placemark> placemarks = await geocoding
          .placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;

        final addressParts = [
          placemark.subLocality,
          placemark.locality,
          placemark.subAdministrativeArea,
          placemark.administrativeArea,
        ];

        final address = addressParts
            .where((part) => part != null && part.isNotEmpty)
            .join(', ');

        if (mounted) {
          setState(() {
            _currentAddress = address;
            _textController.clear();
            _lastLat = lat;
            _lastLng = lng;
          });
        }

        if (shouldCenterMap) {
          _centerMapOnLocation(lat, lng);
        }

        _addMarker(Point(coordinates: Position(lng, lat)));

        await _saveLocation(
          address,
          geolocator.Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
        );
      } else {
        if (mounted) {
          setState(() {
            _currentAddress = AppLocalizations.of(context)!.couldNotGetAddress;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      if (mounted) {
        setState(() {
          _currentAddress = AppLocalizations.of(context)!.couldNotGetAddress;
        });
      }
    }
  }

  Future<void> _saveLocation(
    String address,
    geolocator.Position position,
  ) async {
    if (mounted) {
      setState(() => _isSavingLocation = true);
    }

    // Always save locally first so user sees an immediate result.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_latitude', position.latitude);
      await prefs.setDouble('last_longitude', position.longitude);
      await prefs.setString('last_address', address);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.location} saved locally',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving location locally: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorPresenter.present(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (mounted) {
        setState(() => _isSavingLocation = false);
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isSavingLocation = false);
      }
      return;
    }

    try {
      await FirebaseService().updateUserLocation(
        user.uid,
        address: address,
        lat: position.latitude,
        lon: position.longitude,
      );

      try {
        await WeatherService().fetchWeatherData(
          position.latitude,
          position.longitude,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)!.location} synced to server and weather updated',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('Weather fetch after sync failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location synced, but weather refresh failed. ${ErrorPresenter.present(e)}',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to sync location to backend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved locally. Server sync failed: ${ErrorPresenter.present(e)}',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingLocation = false);
      }
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    _pointAnnotationManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();

    if (_lastLat != null && _lastLng != null) {
      _centerMapOnLocation(_lastLat!, _lastLng!);
      // Corrected Point creation with explicit double casting
      _addMarker(
        Point(
          coordinates: Position(_lastLng!.toDouble(), _lastLat!.toDouble()),
        ),
      );
    }
  }

  // Changed signature to directly receive MapContentGestureContext
  void _onMapTap(MapContentGestureContext context) async {
    if (_isBusy) return;
    final point = context.point; // Extract Point from context
    final lat = point.coordinates.lat.toDouble(); // Ensure double type
    final lng = point.coordinates.lng.toDouble(); // Ensure double type
    await _updateLocation(lat, lng);
  }

  void _addMarker(Point point) {
    if (_pointAnnotationManager == null || _markerImage == null) return;

    _pointAnnotationManager!.deleteAll();
    _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: point,
        image: _markerImage!,
        iconSize: 2.0,
      ),
    );
  }

  void _centerMapOnLocation(double lat, double lng) {
    if (_mapboxMap == null) return;

    _mapboxMap!.flyTo(
      // Corrected Point creation with explicit double casting
      CameraOptions(
        center: Point(coordinates: Position(lng.toDouble(), lat.toDouble())),
        zoom: 14,
      ),
      null,
    );
  }

  void _toggleMapStyle() {
    setState(() {
      _isSatelliteView = !_isSatelliteView;
      final newStyle =
          _isSatelliteView
              ? MapboxStyles.SATELLITE_STREETS
              : MapboxStyles.MAPBOX_STREETS;

      _mapboxMap?.loadStyleURI(newStyle);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.setUpdateLocation),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSatelliteView ? Icons.map : Icons.satellite,
              color: Colors.white,
            ),
            onPressed: _toggleMapStyle,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppLocalizations.of(context)!.chooseLocationOption,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isBusy ? null : _getCurrentPosition,
                      icon:
                          _isFetchingGps || _isSavingLocation
                              ? const CompactLoadingIndicator(
                                  size: 18,
                                  color: Colors.white,
                                )
                              : const Icon(Icons.gps_fixed),
                      label: Text(
                        _isFetchingGps
                            ? AppLocalizations.of(context)!.gettingLocation
                            : _isSavingLocation
                            ? 'Saving location...'
                            : AppLocalizations.of(
                              context,
                            )!.useCurrentGpsLocation,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    AppLocalizations.of(context)!.orEnterLocationManually,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _textController,
                    onSubmitted: _searchAndSaveLocation,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.edit_location_alt),
                      hintText:
                          AppLocalizations.of(context)!.searchOrEnterLocation,
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                      ),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon:
                            _isSearching
                                ? const CompactLoadingIndicator(size: 18)
                                : const Icon(Icons.search),
                        onPressed:
                            _isBusy
                                ? null
                                : () {
                                  FocusScope.of(context).unfocus();
                                  _searchAndSaveLocation(_textController.text);
                                },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    AppLocalizations.of(context)!.orTapOnMapToSelect,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 300,
                    child: MapWidget(
                      key: const ValueKey("mapWidget"),
                      onMapCreated: _onMapCreated,
                      styleUri: MapboxStyles.MAPBOX_STREETS,
                      onTapListener: _onMapTap,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Text(
                    AppLocalizations.of(context)!.currentSelectedLocation,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentAddress ??
                              AppLocalizations.of(
                                context,
                              )!.noLocationSelectedYet,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green.shade800,
                          ),
                        ),

                        if (_lastLat != null && _lastLng != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${AppLocalizations.of(context)!.coordinates} ${_lastLat!.toStringAsFixed(4)}, ${_lastLng!.toStringAsFixed(4)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
