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
        title: const Text('Admin Console'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.storefront), label: 'Listings'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.send), label: 'Notify'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: 'Rates'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Ops'),
        ],
      ),
    );
  }
}
