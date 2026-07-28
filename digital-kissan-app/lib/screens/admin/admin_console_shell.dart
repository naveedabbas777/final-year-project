import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/providers/auth_provider.dart' as app_auth;

import 'admin_alerts_screen.dart';
import 'admin_listings_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_ops_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_users_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_official_rates_screen.dart';

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
    AdminOfficialRatesScreen(),
    AdminOpsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context, 'Admin Console', 'ایڈمن کنسول')),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _t(context, 'Profile', 'پروفائل'),
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
            ),
          ),
          IconButton(
            tooltip: _t(context, 'Sign out', 'سائن آؤٹ'),
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(_t(context, 'Sign out', 'سائن آؤٹ'), style: const TextStyle(color: AppColors.textPrimary)),
                  content: Text(_t(context, 'Are you sure you want to sign out?', 'کیا آپ واقعی سائن آؤٹ کرنا چاہتے ہیں؟'), style: const TextStyle(color: AppColors.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_t(context, 'Cancel', 'منسوخ'), style: const TextStyle(color: AppColors.textPrimary))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(_t(context, 'Sign out', 'سائن آؤٹ')),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
                await auth.signOut();
              }
            },
          ),
        ],
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
            label: _t(context, 'Official Rates', 'سرکاری ریٹس'),
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
