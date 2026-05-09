import 'package:flutter/material.dart';
import 'package:mockup_app/services/admin_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  final _api = AdminApiService();
  Future<List<AdminAlertDto>>? _future;

  String _t(BuildContext context, String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = _api.fetchAlerts(limit: 200));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminAlertDto>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AsyncLoadingWidget(
            message: _t(context, 'Loading alerts...', 'الرٹس لوڈ ہو رہے ہیں...'),
          );
        }
        if (snapshot.hasError) {
          return AsyncErrorWidget(
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final rows = snapshot.data ?? const <AdminAlertDto>[];
        if (rows.isEmpty) {
          return AsyncEmptyWidget(
            message: _t(context, 'No alerts found', 'کوئی الرٹ نہیں ملا'),
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
                  leading: Icon(
                    row.read ? Icons.mark_email_read : Icons.notifications_active,
                    color: row.read ? Colors.grey.shade600 : Colors.orange.shade700,
                  ),
                  isThreeLine: true,
                  title: Text(row.title),
                  subtitle: Text(
                    '${row.type} • ${row.address.isEmpty ? row.userId : row.address}\n${row.body}',
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
