import 'package:flutter/material.dart';

import 'package:mockup_app/services/admin_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminApiService _adminApi = AdminApiService();

  Future<AdminOverviewDto>? _overviewFuture;
  Future<List<AdminUserDto>>? _usersFuture;
  Future<List<AdminUserDto>>? _sellersFuture;
  Future<List<AdminUserDto>>? _buyersFuture;
  Future<List<AdminOrderDto>>? _ordersFuture;
  Future<List<AdminAlertDto>>? _alertsFuture;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  void _reloadAll() {
    setState(() {
      _overviewFuture = _adminApi.fetchOverview();
      _usersFuture = _adminApi.fetchUsers(limit: 100);
      _sellersFuture = _adminApi.fetchUsers(limit: 100, role: 'farmer');
      _buyersFuture = _adminApi.fetchUsers(limit: 100, role: 'buyer');
      _ordersFuture = _adminApi.fetchOrders(limit: 150);
      _alertsFuture = _adminApi.fetchAlerts(limit: 100);
    });
  }

  Future<void> _refreshWeather() async {
    await _adminApi.refreshWeather();
    _reloadAll();
  }

  Future<void> _ingestRates() async {
    await _adminApi.ingestOfficialRates();
    _reloadAll();
  }

  Future<void> _changeUserRole(AdminUserDto user, String newRole) async {
    await _adminApi.updateUserRole(userId: user.firebaseUid, role: newRole);
    _reloadAll();
  }

  Future<void> _changeOrderStatus(AdminOrderDto order, String newStatus) async {
    await _adminApi.updateOrderStatus(orderId: order.id, status: newStatus);
    _reloadAll();
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTile(AdminUserDto user) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isAdmin ? Colors.red.shade100 : Colors.green.shade100,
          child: Icon(user.isAdmin ? Icons.shield : Icons.person, color: user.isAdmin ? Colors.red.shade700 : Colors.green.shade700),
        ),
        title: Text(user.name.isNotEmpty ? user.name : user.firebaseUid),
        subtitle: Text(
          '${user.role} • ${user.district.isNotEmpty ? user.district : 'No district'}${user.isOnline ? ' • online' : ''}',
        ),
        trailing: DropdownButton<String>(
          value: user.role,
          items: const [
            DropdownMenuItem(value: 'farmer', child: Text('farmer')),
            DropdownMenuItem(value: 'buyer', child: Text('buyer')),
            DropdownMenuItem(value: 'admin', child: Text('admin')),
          ],
          onChanged: (value) {
            if (value == null || value == user.role) return;
            _changeUserRole(user, value);
          },
        ),
      ),
    );
  }

  Widget _buildOrderTile(AdminOrderDto order) {
    return Card(
      child: ListTile(
        title: Text('Order ${order.id.substring(0, order.id.length > 10 ? 10 : order.id.length)}'),
        subtitle: Text(
          'Buyer: ${order.buyerUid}\nSeller: ${order.sellerUid}\n${order.quantity.toStringAsFixed(0)} ${order.unit} • PKR ${order.finalPrice.toStringAsFixed(0)}',
        ),
        isThreeLine: true,
        trailing: DropdownButton<String>(
          value: order.status,
          items: const [
            DropdownMenuItem(value: 'created', child: Text('created')),
            DropdownMenuItem(value: 'in_transit', child: Text('in_transit')),
            DropdownMenuItem(value: 'delivered', child: Text('delivered')),
            DropdownMenuItem(value: 'completed', child: Text('completed')),
            DropdownMenuItem(value: 'cancelled', child: Text('cancelled')),
            DropdownMenuItem(value: 'disputed', child: Text('disputed')),
          ],
          onChanged: (value) async {
            if (value == null || value == order.status) return;
            try {
              await _changeOrderStatus(order, value);
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Order update failed: $e')),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildAlertTile(AdminAlertDto alert) {
    return Card(
      child: ListTile(
        leading: Icon(
          alert.read ? Icons.mark_email_read : Icons.notifications_active,
          color: alert.read ? Colors.grey.shade600 : Colors.orange.shade700,
        ),
        title: Text(alert.title),
        subtitle: Text(
          '${alert.type} • ${alert.address.isNotEmpty ? alert.address : alert.userId}\n${alert.body}',
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: Colors.green.shade50,
        appBar: AppBar(
          title: const Text('Admin Console'),
          backgroundColor: Colors.green.shade800,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Refresh all',
              onPressed: _reloadAll,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'All Users'),
              Tab(text: 'Sellers'),
              Tab(text: 'Buyers'),
              Tab(text: 'Orders'),
              Tab(text: 'Alerts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FutureBuilder<AdminOverviewDto>(
              future: _overviewFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AsyncLoadingWidget(message: 'Loading admin overview...');
                }
                if (snapshot.hasError) {
                  return AsyncErrorWidget(
                    error: snapshot.error.toString(),
                    onRetry: _reloadAll,
                  );
                }
                final overview = snapshot.data;
                if (overview == null) {
                  return const AsyncEmptyWidget(message: 'No admin metrics available');
                }

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Row(
                      children: [
                        _metricCard('Users', overview.users.toString(), Icons.people, Colors.green.shade700),
                        const SizedBox(width: 10),
                        _metricCard('Admins', overview.admins.toString(), Icons.admin_panel_settings, Colors.red.shade700),
                      ],
                    ),
                    Row(
                      children: [
                        _metricCard('Listings', overview.listings.toString(), Icons.storefront, Colors.blue.shade700),
                        const SizedBox(width: 10),
                        _metricCard('Open', overview.openListings.toString(), Icons.inventory_2, Colors.teal.shade700),
                      ],
                    ),
                    Row(
                      children: [
                        _metricCard('Orders', overview.orders.toString(), Icons.receipt_long, Colors.orange.shade700),
                        const SizedBox(width: 10),
                        _metricCard('Offers', overview.offers.toString(), Icons.local_offer, Colors.purple.shade700),
                      ],
                    ),
                    Row(
                      children: [
                        _metricCard('Rates', overview.rates.toString(), Icons.trending_up, Colors.brown.shade700),
                        const SizedBox(width: 10),
                        _metricCard('Online', overview.onlineUsers.toString(), Icons.circle, Colors.cyan.shade700),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.cloud_sync),
                        title: const Text('Weather refresh'),
                        subtitle: Text('${overview.recentAlerts} recent weather alerts tracked'),
                        trailing: ElevatedButton(
                          onPressed: _refreshWeather,
                          child: const Text('Refresh now'),
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.agriculture),
                        title: const Text('Official crop rates'),
                        subtitle: const Text('Ingest the latest market rates from the configured source'),
                        trailing: ElevatedButton(
                          onPressed: _ingestRates,
                          child: const Text('Ingest'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            FutureBuilder<List<AdminUserDto>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AsyncLoadingWidget(message: 'Loading users...');
                }
                if (snapshot.hasError) {
                  return AsyncErrorWidget(
                    error: snapshot.error.toString(),
                    onRetry: _reloadAll,
                  );
                }
                final users = snapshot.data ?? const [];
                if (users.isEmpty) {
                  return const AsyncEmptyWidget(message: 'No users found');
                }
                return RefreshIndicator(
                  onRefresh: () async => _reloadAll(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _buildUserTile(users[index]),
                  ),
                );
              },
            ),
            FutureBuilder<List<AdminUserDto>>(
              future: _sellersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AsyncLoadingWidget(message: 'Loading sellers...');
                }
                if (snapshot.hasError) {
                  return AsyncErrorWidget(
                    error: snapshot.error.toString(),
                    onRetry: _reloadAll,
                  );
                }
                final users = snapshot.data ?? const [];
                if (users.isEmpty) return const AsyncEmptyWidget(message: 'No sellers found');
                return RefreshIndicator(
                  onRefresh: () async => _reloadAll(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _buildUserTile(users[index]),
                  ),
                );
              },
            ),
            FutureBuilder<List<AdminUserDto>>(
              future: _buyersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AsyncLoadingWidget(message: 'Loading buyers...');
                }
                if (snapshot.hasError) {
                  return AsyncErrorWidget(
                    error: snapshot.error.toString(),
                    onRetry: _reloadAll,
                  );
                }
                final users = snapshot.data ?? const [];
                if (users.isEmpty) return const AsyncEmptyWidget(message: 'No buyers found');
                return RefreshIndicator(
                  onRefresh: () async => _reloadAll(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _buildUserTile(users[index]),
                  ),
                );
              },
            ),
            FutureBuilder<List<AdminOrderDto>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AsyncLoadingWidget(message: 'Loading orders...');
                }
                if (snapshot.hasError) {
                  return AsyncErrorWidget(
                    error: snapshot.error.toString(),
                    onRetry: _reloadAll,
                  );
                }
                final orders = snapshot.data ?? const [];
                if (orders.isEmpty) {
                  return const AsyncEmptyWidget(message: 'No orders found');
                }
                return RefreshIndicator(
                  onRefresh: () async => _reloadAll(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _buildOrderTile(orders[index]),
                  ),
                );
              },
            ),
            FutureBuilder<List<AdminAlertDto>>(
              future: _alertsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AsyncLoadingWidget(message: 'Loading alerts...');
                }
                if (snapshot.hasError) {
                  return AsyncErrorWidget(
                    error: snapshot.error.toString(),
                    onRetry: _reloadAll,
                  );
                }
                final alerts = snapshot.data ?? const [];
                if (alerts.isEmpty) {
                  return const AsyncEmptyWidget(message: 'No alerts found');
                }
                return RefreshIndicator(
                  onRefresh: () async => _reloadAll(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: alerts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _buildAlertTile(alerts[index]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
