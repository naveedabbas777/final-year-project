import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:mockup_app/services/alert_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({Key? key}) : super(key: key);

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertService>().loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.alertsTitle),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.green.shade50,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Consumer<AlertService>(
          builder: (context, service, _) {
            final alerts = service.alerts;
            if (alerts.isEmpty) {
              return Center(
                child: Text(
                  'No alerts yet. Alerts will appear here when weather conditions trigger them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              );
            }

            return ListView.builder(
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: _buildIcon(alert.type),
                    title: Text(
                      alert.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${DateFormat.yMMMd().add_jm().format(alert.createdAt)}\n${alert.body}',
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildIcon(String type) {
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
          child: Icon(Icons.warning, color: Colors.black54),
        );
    }
  }
}
