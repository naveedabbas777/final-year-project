import 'package:flutter/material.dart';

import 'admin_alerts_screen.dart';
import 'admin_listings_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_ops_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_rates_screen.dart';
import 'admin_users_screen.dart';

class AdminConsoleShell extends StatefulWidget {
  const AdminConsoleShell({super.key});

  @override
  State<AdminConsoleShell> createState() => _AdminConsoleShellState();
}

class _AdminConsoleShellState extends State<AdminConsoleShell> {
  int _index = 0;

  String _t(BuildContext context, String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  late final List<Widget> _screens = const [
    AdminOverviewScreen(),
    AdminUsersScreen(),
    AdminListingsScreen(),
    AdminOrdersScreen(),
    AdminAlertsScreen(),
    AdminNotificationsScreen(),
    AdminRatesScreen(),
    AdminOpsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context, 'Admin Console', 'ایڈمن کنسول')),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard),
            label: _t(context, 'Overview', 'جائزہ'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.people),
            label: _t(context, 'Users', 'صارفین'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.storefront),
            label: _t(context, 'Listings', 'لسٹنگز'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long),
            label: _t(context, 'Orders', 'آرڈرز'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications),
            label: _t(context, 'Alerts', 'الرٹس'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.send),
            label: _t(context, 'Notify', 'اطلاع'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.trending_up),
            label: _t(context, 'Rates', 'ریٹس'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune),
            label: _t(context, 'Ops', 'آپریشنز'),
          ),
        ],
      ),
    );
  }
}
