import 'package:flutter/material.dart';
import 'package:mockup_app/services/admin_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _api = AdminApiService();
  Future<List<AdminOrderDto>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = _api.fetchOrders(limit: 200));
  }

  Future<void> _changeStatus(AdminOrderDto order, String status) async {
    await _api.updateOrderStatus(orderId: order.id, status: status);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminOrderDto>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AsyncLoadingWidget(message: 'Loading orders...');
        }
        if (snapshot.hasError) {
          return AsyncErrorWidget(
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final rows = snapshot.data ?? const <AdminOrderDto>[];
        if (rows.isEmpty) return const AsyncEmptyWidget(message: 'No orders found');
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
                  isThreeLine: true,
                  title: Text('Order ${row.id.substring(0, row.id.length > 12 ? 12 : row.id.length)}'),
                  subtitle: Text(
                    'Buyer: ${row.buyerUid}\nSeller: ${row.sellerUid}\nPKR ${row.finalPrice.toStringAsFixed(0)}',
                  ),
                  trailing: DropdownButton<String>(
                    value: row.status,
                    items: const [
                      DropdownMenuItem(value: 'created', child: Text('created')),
                      DropdownMenuItem(value: 'in_transit', child: Text('in_transit')),
                      DropdownMenuItem(value: 'delivered', child: Text('delivered')),
                      DropdownMenuItem(value: 'completed', child: Text('completed')),
                      DropdownMenuItem(value: 'cancelled', child: Text('cancelled')),
                      DropdownMenuItem(value: 'disputed', child: Text('disputed')),
                    ],
                    onChanged: (value) async {
                      if (value == null || value == row.status) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await _changeStatus(row, value);
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('Order update failed: $e')),
                        );
                      }
                    },
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
