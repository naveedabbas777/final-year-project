import 'package:flutter/material.dart';
import 'package:mockup_app/services/admin_api_service.dart';
import 'package:mockup_app/services/market_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class AdminRatesScreen extends StatefulWidget {
  const AdminRatesScreen({super.key});

  @override
  State<AdminRatesScreen> createState() => _AdminRatesScreenState();
}

class _AdminRatesScreenState extends State<AdminRatesScreen> {
  final _api = AdminApiService();
  Future<List<CropRateDto>>? _future;

  String _t(BuildContext context, String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = _api.fetchRates(limit: 200));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CropRateDto>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AsyncLoadingWidget(
            message: _t(context, 'Loading rates...', 'ریٹس لوڈ ہو رہے ہیں...'),
          );
        }
        if (snapshot.hasError) {
          return AsyncErrorWidget(
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final rows = snapshot.data ?? const <CropRateDto>[];
        if (rows.isEmpty) {
          return AsyncEmptyWidget(
            message: _t(context, 'No rates found', 'کوئی ریٹ نہیں ملا'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final row = rows[index];
              return Card(
                child: ListTile(
                  title: Text('${row.cropName} • ${row.marketName}'),
                  subtitle: Text('${row.district} • ${row.sourceName}'),
                  trailing: Text(
                    '${row.minPrice.toStringAsFixed(0)}-${row.maxPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
