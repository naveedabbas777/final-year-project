import 'package:flutter/material.dart';
import 'package:mockup_app/services/admin_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  final _api = AdminApiService();
  Future<AdminOverviewDto>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = _api.fetchOverview());
  }

  Widget _metric(String label, int value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminOverviewDto>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AsyncLoadingWidget(message: 'Loading overview...');
        }
        if (snapshot.hasError) {
          return AsyncErrorWidget(
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const AsyncEmptyWidget(message: 'No overview available');
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _metric('Users', data.users, Icons.people, Colors.green.shade700),
              _metric(
                'Admins',
                data.admins,
                Icons.admin_panel_settings,
                Colors.red.shade700,
              ),
              _metric(
                'Listings',
                data.listings,
                Icons.storefront,
                Colors.blue.shade700,
              ),
              _metric(
                'Open Listings',
                data.openListings,
                Icons.inventory,
                Colors.teal.shade700,
              ),
              _metric(
                'Orders',
                data.orders,
                Icons.receipt_long,
                Colors.orange.shade700,
              ),
              _metric(
                'Offers',
                data.offers,
                Icons.local_offer,
                Colors.purple.shade700,
              ),
              _metric('Rates', data.rates, Icons.trending_up, Colors.brown.shade700),
              _metric(
                'Online Users',
                data.onlineUsers,
                Icons.circle,
                Colors.cyan.shade700,
              ),
              _metric(
                'Recent Alerts',
                data.recentAlerts,
                Icons.warning_amber,
                Colors.deepOrange.shade700,
              ),
            ],
          ),
        );
      },
    );
  }
}
