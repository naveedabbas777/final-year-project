import 'package:flutter/material.dart';

import '../services/market_api_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _service = MarketApiService();

  bool _loading = false;
  String? _error;
  List<OrderDto> _orders = const [];

  static const List<String> _statuses = [
    'created',
    'in_transit',
    'delivered',
    'completed',
    'cancelled',
    'disputed',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _service.fetchMyOrders();
      if (!mounted) return;
      setState(() => _orders = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(OrderDto order, String nextStatus) async {
    try {
      await _service.updateOrderStatus(orderId: order.id, status: nextStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order status updated')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child:
                    _orders.isEmpty
                        ? ListView(
                          children: const [
                            SizedBox(height: 140),
                            Center(child: Text('No orders found.')),
                          ],
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _orders.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final row = _orders[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order ${row.id.substring(0, row.id.length > 8 ? 8 : row.id.length)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Price: PKR ${row.finalPrice.toStringAsFixed(0)}',
                                    ),
                                    Text(
                                      'Quantity: ${row.quantity.toStringAsFixed(0)} ${row.unit}',
                                    ),
                                    Text('Status: ${row.status}'),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children:
                                          _statuses
                                              .map(
                                                (s) => ChoiceChip(
                                                  label: Text(s),
                                                  selected: row.status == s,
                                                  onSelected:
                                                      row.status == s
                                                          ? null
                                                          : (_) =>
                                                              _changeStatus(
                                                                row,
                                                                s,
                                                              ),
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
    );
  }
}
