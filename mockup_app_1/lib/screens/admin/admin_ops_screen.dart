import 'package:flutter/material.dart';
import 'package:mockup_app/services/admin_api_service.dart';

class AdminOpsScreen extends StatefulWidget {
  const AdminOpsScreen({super.key});

  @override
  State<AdminOpsScreen> createState() => _AdminOpsScreenState();
}

class _AdminOpsScreenState extends State<AdminOpsScreen> {
  final _api = AdminApiService();
  bool _weatherBusy = false;
  bool _ratesBusy = false;

  Future<void> _runWeatherRefresh() async {
    setState(() => _weatherBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await _api.refreshWeather();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Weather refresh failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _weatherBusy = false);
      }
    }
  }

  Future<void> _runRatesIngestion() async {
    setState(() => _ratesBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await _api.ingestOfficialRates();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Rates ingestion failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _ratesBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('Refresh weather alerts'),
            subtitle: const Text('Run weather sync pipeline now'),
            trailing: ElevatedButton(
              onPressed: _weatherBusy ? null : _runWeatherRefresh,
              child: Text(_weatherBusy ? 'Running...' : 'Run'),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.agriculture),
            title: const Text('Ingest official crop rates'),
            subtitle: const Text('Pull latest rates from configured source'),
            trailing: ElevatedButton(
              onPressed: _ratesBusy ? null : _runRatesIngestion,
              child: Text(_ratesBusy ? 'Running...' : 'Run'),
            ),
          ),
        ),
      ],
    );
  }
}
