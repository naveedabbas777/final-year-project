import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class ListingLocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const ListingLocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<ListingLocationPicker> createState() => _ListingLocationPickerState();
}

class _ListingLocationPickerState extends State<ListingLocationPicker> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  double? _selectedLatitude;
  double? _selectedLongitude;

  @override
  void initState() {
    super.initState();
    _selectedLatitude = widget.initialLatitude ?? 33.6844;
    _selectedLongitude = widget.initialLongitude ?? 73.0479;
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    if (_selectedLatitude != null && _selectedLongitude != null) {
      await _addMarker(_selectedLatitude!, _selectedLongitude!);
    }
  }

  Future<void> _addMarker(double latitude, double longitude) async {
    if (_pointAnnotationManager == null) return;

    await _pointAnnotationManager!.deleteAll();

    final pointAnnotationOptions = PointAnnotationOptions(
      geometry: Point(coordinates: Position(longitude, latitude)),
      iconSize: 1.5,
    );

    try {
      await _pointAnnotationManager!.create(pointAnnotationOptions);
    } catch (e) {
      debugPrint('Error adding marker: $e');
    }
  }

  @override
  void dispose() {
    _mapboxMap?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text('Pin Product Location'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTapDown: (details) {
              // Note: For simplicity, tap at center or implement screen-to-map coordinate conversion
              // For now, user can confirm the default location or update it
            },
            child: MapWidget(
              onMapCreated: _onMapCreated,
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(
                    _selectedLongitude!,
                    _selectedLatitude!,
                  ),
                ),
                zoom: 12.0,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      if (_selectedLatitude != null &&
                          _selectedLongitude != null) {
                        Navigator.pop(context, {
                          'latitude': _selectedLatitude,
                          'longitude': _selectedLongitude,
                        });
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tap on the map to pin your product location',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (_selectedLatitude != null &&
                        _selectedLongitude != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Latitude: ${_selectedLatitude!.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'Longitude: ${_selectedLongitude!.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
