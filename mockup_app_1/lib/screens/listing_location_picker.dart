import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class ListingLocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLocationName;

  const ListingLocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialLocationName,
  });

  @override
  State<ListingLocationPicker> createState() => _ListingLocationPickerState();
}

class _ListingLocationPickerState extends State<ListingLocationPicker> {
  PointAnnotationManager? _pointAnnotationManager;
  double _selectedLatitude = 33.6844; // Default: Islamabad, Pakistan
  double _selectedLongitude = 73.0479;
  String? _selectedLocationName;
  String? _selectedDistrict;
  bool _loadingLocationName = false;

  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

  @override
  void initState() {
    super.initState();
    _selectedLatitude = widget.initialLatitude ?? 33.6844;
    _selectedLongitude = widget.initialLongitude ?? 73.0479;
    _selectedLocationName = widget.initialLocationName;
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    await _addMarker(_selectedLatitude, _selectedLongitude);
  }

  Future<void> _addMarker(double latitude, double longitude) async {
    if (_pointAnnotationManager == null) return;
    try {
      await _pointAnnotationManager!.deleteAll();
      await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(longitude, latitude)),
          iconSize: 1.5,
        ),
      );
    } catch (e) {
      debugPrint('[LocationPicker] Error adding marker: $e');
    }
  }

  /// Reverse geocode coordinates to get location name/address
  Future<void> _fetchLocationName(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _loadingLocationName = true);

    try {
      final List<Placemark> placemarks =
          await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final pm = placemarks.first;
        final addressParts = <String>[];
        if (pm.name?.isNotEmpty ?? false) addressParts.add(pm.name!);
        if (pm.administrativeArea?.isNotEmpty ?? false)
          addressParts.add(pm.administrativeArea!);
        if (pm.country?.isNotEmpty ?? false) addressParts.add(pm.country!);

        final locationName = addressParts.join(', ');
        setState(() {
          _selectedLocationName = locationName.isNotEmpty ? locationName : null;
          _selectedDistrict = pm.administrativeArea?.isNotEmpty ?? false ? pm.administrativeArea : null;
        });
      }
    } catch (e) {
      debugPrint('[LocationPicker] Error fetching location name: $e');
    } finally {
      if (mounted) setState(() => _loadingLocationName = false);
    }
  }

  /// Called when the user taps anywhere on the map.
  Future<void> _onMapTap(MapContentGestureContext gestureContext) async {
    try {
      final lat = gestureContext.point.coordinates.lat.toDouble();
      final lng = gestureContext.point.coordinates.lng.toDouble();

      if (!mounted) return;
      setState(() {
        _selectedLatitude = lat;
        _selectedLongitude = lng;
        _selectedLocationName = null; // Reset while fetching
      });
      await _addMarker(lat, lng);
      await _fetchLocationName(lat, lng);
    } catch (e) {
      debugPrint('[LocationPicker] Error handling map tap: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: Text(_t('Pin Product Location', 'پروڈکٹ کا مقام پن کریں')),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ── Mapbox map fills the whole body ──────────────────────────────
          MapWidget(
            onMapCreated: _onMapCreated,
            onTapListener: _onMapTap,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(
                  _selectedLongitude,
                  _selectedLatitude,
                ),
              ),
              zoom: 12.0,
            ),
          ),

          // ── Info card at the top ─────────────────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.touch_app, size: 16, color: Colors.green),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _t('Tap on the map to pin your product location', 'اپنی پروڈکٹ کا مقام پن کرنے کے لیے نقشے پر ٹیپ کریں'),
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 14, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Lat: ${_selectedLatitude.toStringAsFixed(5)}  '
                            'Lng: ${_selectedLongitude.toStringAsFixed(5)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedLocationName != null && _selectedLocationName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.place_outlined, size: 14, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _selectedLocationName!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_loadingLocationName)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Cancel / Confirm buttons at the bottom ───────────────────────
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: Text(_t('Cancel', 'منسوخ')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, {
                        'latitude': _selectedLatitude,
                        'longitude': _selectedLongitude,
                        'locationName': _selectedLocationName,
                        'district': _selectedDistrict,
                      });
                    },
                    icon: const Icon(Icons.check),
                    label: Text(_t('Confirm', 'تصدیق')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
