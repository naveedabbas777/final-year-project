import 'package:flutter/material.dart';
import 'package:mockup_app/services/weather_service.dart'; // Import DailyForecast model

class DetailedForecastScreen extends StatelessWidget {
  final DailyForecast forecast;

  const DetailedForecastScreen({Key? key, required this.forecast})
    : super(key: key);

  Icon _buildWeatherIcon(String iconUrl, {double size = 100}) {
    final match = RegExp(r"/(\d{2}[dn])@").firstMatch(iconUrl);
    final code = match != null ? match.group(1) ?? '' : '';
    final isNight = code.endsWith('n');

    Color baseSun = Colors.amber.shade600;
    Color baseMoon = Colors.indigo.shade200;

    switch (code.substring(0, 2)) {
      case '01':
        return Icon(
          isNight ? Icons.nightlight_round : Icons.wb_sunny,
          size: size,
          color: isNight ? baseMoon : baseSun,
        );
      case '02':
      case '03':
      case '04':
        return Icon(
          Icons.cloud_queue,
          size: size,
          color: Colors.blueGrey.shade500,
        );
      case '09':
      case '10':
        return Icon(Icons.grain, size: size, color: Colors.blue.shade500);
      case '11':
        return Icon(
          Icons.thunderstorm,
          size: size,
          color: Colors.deepPurple.shade400,
        );
      case '13':
        return Icon(
          Icons.ac_unit,
          size: size,
          color: Colors.lightBlue.shade200,
        );
      case '50':
        return Icon(Icons.foggy, size: size, color: Colors.grey.shade500);
      default:
        return Icon(Icons.cloud, size: size, color: Colors.blueGrey.shade400);
    }
  }

  String _visibilityStatus(double km) {
    if (km <= 0) return 'No data';
    if (km >= 10) return 'Excellent';
    if (km >= 6) return 'Good';
    if (km >= 3) return 'Moderate';
    if (km >= 1) return 'Poor';
    return 'Very Poor';
  }

  Color _visibilityColor(double km) {
    if (km >= 10) return Colors.green.shade600;
    if (km >= 6) return Colors.lightGreen.shade700;
    if (km >= 3) return Colors.orange.shade700;
    if (km >= 1) return Colors.deepOrange.shade700;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(forecast.day),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.green.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      _buildWeatherIcon(forecast.icon, size: 100),
                      const SizedBox(height: 10),
                      Text(
                        forecast.description,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Max: ${forecast.maxTemperature.round()}°C / Min: ${forecast.minTemperature.round()}°C',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Avg Temp: ${forecast.avgTemperature.round()}°C',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        forecast.pop >= 0.01
                            ? 'Chance of Rain: ${(forecast.pop * 100).toStringAsFixed(0)}%'
                            : 'Chance of Rain: <1%',
                        style: TextStyle(
                          fontSize: 18,
                          color:
                              forecast.pop > 0.3
                                  ? Colors.red.shade600
                                  : forecast.pop > 0.1
                                  ? Colors.orange.shade600
                                  : Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const Divider(height: 20),
                    _buildDetailRow('UV Index', forecast.uv.toString()),
                    _buildDetailRow(
                      'Avg Humidity',
                      '${forecast.avgHumidity.round()}%',
                    ),
                    _buildDetailRow(
                      'Chance of Rain',
                      forecast.pop >= 0.005
                          ? '${(forecast.pop * 100).toStringAsFixed(0)}%'
                          : forecast.pop > 0
                          ? '<1%'
                          : '0%',
                    ),
                    _buildVisibilityRow(forecast.visibilityKm),
                    _buildDetailRow(
                      'Max Wind Speed',
                      '${forecast.maxWindSpeed.round()} km/h',
                    ),
                    _buildDetailRow(
                      'Wind Direction',
                      '${forecast.windDirection} (${forecast.windDegree}°)',
                    ),
                    if (forecast.sunrise.isNotEmpty)
                      _buildDetailRow('Sunrise', forecast.sunrise),
                    if (forecast.sunset.isNotEmpty)
                      _buildDetailRow('Sunset', forecast.sunset),
                    if (forecast.moonPhase.isNotEmpty)
                      _buildDetailRow('Moon Phase', forecast.moonPhase),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Hourly Forecast',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 180, // Increased height to prevent overflow
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: forecast.hourlyForecasts.length,
                itemBuilder: (context, index) {
                  final hourly = forecast.hourlyForecasts[index];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(
                      right: 8,
                    ), // Add spacing between cards
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center, // Changed from spaceAround
                          children: [
                            Text(
                              hourly.time,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            _buildWeatherIcon(hourly.icon, size: 35),
                            const SizedBox(height: 4),
                            Text(
                              '${hourly.temperature.round()}°C',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (hourly.chanceOfRain > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      hourly.chanceOfRain > 0.3
                                          ? Colors.blue.shade100
                                          : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hourly.chanceOfRain >= 0.01
                                      ? '${(hourly.chanceOfRain * 100).toStringAsFixed(0)}%'
                                      : '<1%',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        hourly.chanceOfRain > 0.3
                                            ? Colors.blue.shade800
                                            : Colors.blue.shade600,
                                  ),
                                ),
                              ),
                            Flexible(
                              // Added Flexible to prevent overflow
                              child: Text(
                                hourly.description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize:
                                      hourly.chanceOfRain > 0
                                          ? 9
                                          : 10, // Smaller if rain chance shown
                                  color: Colors.grey.shade600,
                                ),
                                maxLines:
                                    hourly.chanceOfRain > 0
                                        ? 1
                                        : 2, // Fewer lines if rain chance shown
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityRow(double rawVisibility) {
    // Some feeds provide meters; normalize to km when value looks like meters.
    final double km = rawVisibility > 100 ? rawVisibility / 1000.0 : rawVisibility;
    final hasData = km > 0;
    final status = _visibilityStatus(km);
    final color = hasData ? _visibilityColor(km) : Colors.grey.shade600;
    final valueText = hasData ? '${km.toStringAsFixed(1)} km' : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.visibility, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                'Visibility',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
