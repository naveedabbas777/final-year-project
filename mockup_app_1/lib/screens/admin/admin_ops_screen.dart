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

  String _t(BuildContext context, String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  Future<void> _runWeatherRefresh() async {
    setState(() => _weatherBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await _api.refreshWeather();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _t(context, 'Weather refresh failed: $e', 'موسم ریفریش ناکام: $e'),
          ),
        ),
      );
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _t(context, 'Rates ingestion failed: $e', 'ریٹس انجیژن ناکام: $e'),
          ),
        ),
      );
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
            title: Text(_t(context, 'Refresh weather alerts', 'موسمی الرٹس ریفریش کریں')),
            subtitle: Text(_t(context, 'Run weather sync pipeline now', 'ابھی موسمی سنک پائپ لائن چلائیں')),
            trailing: ElevatedButton(
              onPressed: _weatherBusy ? null : _runWeatherRefresh,
              child: Text(
                _weatherBusy
                    ? _t(context, 'Running...', 'چل رہا ہے...')
                    : _t(context, 'Run', 'چلائیں'),
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.agriculture),
            title: Text(_t(context, 'Ingest official crop rates', 'سرکاری فصل ریٹس انجیست کریں')),
            subtitle: Text(_t(context, 'Pull latest rates from configured source', 'کنفیگر سورس سے تازہ ریٹس لائیں')),
            trailing: ElevatedButton(
              onPressed: _ratesBusy ? null : _runRatesIngestion,
              child: Text(
                _ratesBusy
                    ? _t(context, 'Running...', 'چل رہا ہے...')
                    : _t(context, 'Run', 'چلائیں'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
