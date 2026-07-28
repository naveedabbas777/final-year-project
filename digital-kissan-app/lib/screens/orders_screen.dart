import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/market_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _service = MarketApiService();
  String? _currentUserUid;
  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

  bool _loading = false;
  String? _error;
  List<OrderDto> _orders = const [];

  // Ordered pipeline steps for the progress stepper
  static const List<String> _pipelineSteps = [
    'created',
    'in_transit',
    'delivered',
    'completed',
  ];

  // Role-based transitions matching the backend state machine exactly.
  // Which transitions the current user can trigger depends on their role
  // in this specific order (buyer vs seller).
  static const Map<String, Map<String, List<String>>> _roleTransitions = {
    'created': {
      'seller': ['in_transit', 'cancelled'],
      'buyer': ['cancelled'],
    },
    'in_transit': {
      'seller': ['delivered'],
      'buyer': ['disputed'],
    },
    'delivered': {
      'seller': [],
      'buyer': ['completed', 'disputed'],
    },
    'completed': {'seller': [], 'buyer': []},
    'cancelled': {'seller': [], 'buyer': []},
    'disputed': {'seller': [], 'buyer': []},
  };

  /// Returns transitions allowed for the current user's role in [order].
  List<String> _getTransitionsForOrder(OrderDto order) {
    final uid = _currentUserUid;
    if (uid == null) return const [];
    final String? role;
    if (uid == order.sellerUid) {
      role = 'seller';
    } else if (uid == order.buyerUid) {
      role = 'buyer';
    } else {
      role = null;
    }
    if (role == null) return const [];
    return _roleTransitions[order.status]?[role] ?? const [];
  }

  @override
  void initState() {
    super.initState();
    _currentUserUid = FirebaseAuth.instance.currentUser?.uid;
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
    // Confirmation dialog for destructive actions
    if (nextStatus == 'cancelled' || nextStatus == 'disputed') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                nextStatus == 'cancelled'
                    ? _t('Cancel Order?', 'آرڈر منسوخ کریں؟')
                    : _t('Dispute Order?', 'آرڈر پر تنازع اٹھائیں؟'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              content: Text(
                nextStatus == 'cancelled'
                    ? _t(
                        'Are you sure you want to cancel this order? This action cannot be undone.',
                        'کیا آپ واقعی یہ آرڈر منسوخ کرنا چاہتے ہیں؟ یہ عمل واپس نہیں ہو سکتا۔',
                      )
                    : _t(
                        'Are you sure you want to raise a dispute for this order?',
                        'کیا آپ واقعی اس آرڈر پر تنازع اٹھانا چاہتے ہیں؟',
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(_t('No, go back', 'نہیں، واپس جائیں')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        nextStatus == 'cancelled'
                            ? Colors.red.shade600
                            : Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    nextStatus == 'cancelled'
                        ? _t('Cancel Order', 'آرڈر منسوخ کریں')
                        : _t('Raise Dispute', 'تنازع اٹھائیں'),
                  ),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
    }

    try {
      await _service.updateOrderStatus(orderId: order.id, status: nextStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t('Order updated to', 'آرڈر اپڈیٹ ہوا')}: ${_statusLabel(nextStatus)}',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // ─── Status helpers ───

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF2E7D32); // deep green
      case 'delivered':
        return const Color(0xFF1565C0); // blue
      case 'in_transit':
        return const Color(0xFF0277BD); // light blue
      case 'cancelled':
        return const Color(0xFFC62828); // red
      case 'disputed':
        return const Color(0xFFE65100); // deep orange
      case 'created':
      default:
        return const Color(0xFFF9A825); // amber
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.verified_rounded;
      case 'delivered':
        return Icons.inventory_2_rounded;
      case 'in_transit':
        return Icons.local_shipping_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'disputed':
        return Icons.gavel_rounded;
      case 'created':
      default:
        return Icons.receipt_long_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'created':
        return _t('Created', 'بنایا گیا');
      case 'in_transit':
        return _t('In Transit', 'راستے میں');
      case 'delivered':
        return _t('Delivered', 'پہنچا دیا گیا');
      case 'completed':
        return _t('Completed', 'مکمل');
      case 'cancelled':
        return _t('Cancelled', 'منسوخ');
      case 'disputed':
        return _t('Disputed', 'متنازع');
      default:
        return status;
    }
  }

  String _actionLabel(String nextStatus) {
    switch (nextStatus.toLowerCase()) {
      case 'in_transit':
        return _t('Ship', 'بھیجیں');
      case 'delivered':
        return _t('Mark Delivered', 'پہنچا دیا نشان کریں');
      case 'completed':
        return _t('Complete', 'مکمل کریں');
      case 'cancelled':
        return _t('Cancel', 'منسوخ');
      case 'disputed':
        return _t('Dispute', 'تنازع');
      default:
        return nextStatus;
    }
  }

  IconData _actionIcon(String nextStatus) {
    switch (nextStatus.toLowerCase()) {
      case 'in_transit':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.verified_outlined;
      case 'cancelled':
        return Icons.close_rounded;
      case 'disputed':
        return Icons.gavel_outlined;
      default:
        return Icons.arrow_forward;
    }
  }

  bool _isDestructive(String status) =>
      status == 'cancelled' || status == 'disputed';

  // ─── Widgets ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              _t('Orders', 'آرڈرز'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade800, Colors.green.shade600],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _loading
              ? const AsyncLoadingWidget()
              : _error != null
              ? RefreshIndicator(
                color: Colors.green.shade700,
                onRefresh: _load,
                child: ListView(
                  children: [
                    const SizedBox(height: 40),
                    _buildErrorState(),
                  ],
                ),
              )
              : RefreshIndicator(
                color: Colors.green.shade700,
                onRefresh: _load,
                child:
                    _orders.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _orders.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 14),
                          itemBuilder:
                              (context, index) =>
                                  _buildOrderCard(_orders[index]),
                        ),
              ),
    );
  }

  Widget _buildOrderCard(OrderDto order) {
    final color = _statusColor(order.status);
    final isTerminal =
        order.status == 'completed' ||
        order.status == 'cancelled' ||
        order.status == 'disputed';
    final transitions = _getTransitionsForOrder(order);
    // Determine role label for UI context
    final uid = _currentUserUid;
    final String roleLabel;
    if (uid == order.sellerUid) {
      roleLabel = _t('Selling', 'فروخت');
    } else if (uid == order.buyerUid) {
      roleLabel = _t('Buying', 'خرید');
    } else {
      roleLabel = '';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(order.status), color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.cropName.isNotEmpty ? order.cropName : 'Order',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        '#${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length).toUpperCase()}'
                        '${roleLabel.isNotEmpty ? ' · $roleLabel' : ''}'
                        ' · ${DateFormat.yMMMd().format(order.createdAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(order.status), size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel(order.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress stepper
                if (!isTerminal || order.status == 'completed')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildProgressStepper(order.status),
                  ),

                // Order details row
                Row(
                  children: [
                    _buildInfoTile(
                      label: _t('Amount', 'رقم'),
                      value: 'PKR ${order.finalPrice.toStringAsFixed(0)}',
                      valueColor: Colors.green.shade700,
                      icon: Icons.payments_outlined,
                    ),
                    const SizedBox(width: 16),
                    _buildInfoTile(
                      label: _t('Quantity', 'مقدار'),
                      value:
                          '${order.quantity.toStringAsFixed(0)} ${order.unit}',
                      icon: Icons.scale_outlined,
                    ),
                  ],
                ),

                // Action buttons
                if (transitions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey.shade200, Colors.transparent],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children:
                        transitions.map((nextStatus) {
                          final destructive = _isDestructive(nextStatus);
                          final btnColor =
                              destructive
                                  ? (nextStatus == 'cancelled'
                                      ? Colors.red.shade600
                                      : Colors.orange.shade700)
                                  : Colors.green.shade700;

                          if (destructive) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: btnColor,
                                  side: BorderSide(
                                    color: btnColor.withOpacity(0.4),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed:
                                    () => _changeStatus(order, nextStatus),
                                icon: Icon(_actionIcon(nextStatus), size: 16),
                                label: Text(
                                  _actionLabel(nextStatus),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: btnColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () => _changeStatus(order, nextStatus),
                              icon: Icon(_actionIcon(nextStatus), size: 16),
                              label: Text(
                                _actionLabel(nextStatus),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper(String currentStatus) {
    final currentIndex = _pipelineSteps.indexOf(currentStatus);
    final effectiveIndex =
        currentStatus == 'completed'
            ? _pipelineSteps.length
            : (currentIndex >= 0 ? currentIndex : 0);

    return Row(
      children: List.generate(_pipelineSteps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepBefore = i ~/ 2;
          final reached = stepBefore < effectiveIndex;
          return Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: reached ? Colors.green.shade600 : Colors.grey.shade200,
              ),
            ),
          );
        }

        // Step dot
        final stepIndex = i ~/ 2;
        final reached = stepIndex < effectiveIndex;
        final isCurrent =
            stepIndex == effectiveIndex && currentStatus != 'completed';
        final step = _pipelineSteps[stepIndex];
        final label = _statusLabel(step);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 28 : 22,
              height: isCurrent ? 28 : 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    reached
                        ? Colors.green.shade600
                        : isCurrent
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                border: Border.all(
                  color:
                      reached
                          ? Colors.green.shade600
                          : isCurrent
                          ? Colors.green.shade600
                          : Colors.grey.shade300,
                  width: isCurrent ? 2.5 : 1.5,
                ),
                boxShadow:
                    isCurrent
                        ? [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.2),
                            blurRadius: 6,
                          ),
                        ]
                        : null,
              ),
              child: Center(
                child:
                    reached
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : isCurrent
                        ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.shade600,
                          ),
                        )
                        : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight:
                    isCurrent || reached ? FontWeight.w700 : FontWeight.w500,
                color:
                    isCurrent || reached
                        ? Colors.green.shade700
                        : Colors.grey.shade500,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    Color? valueColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: valueColor ?? Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 56,
                  color: Colors.green.shade300,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _t('No orders yet', 'ابھی تک کوئی آرڈر نہیں'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'When you accept or place offers,\norders will appear here.',
                  'جب آپ آفر قبول کریں یا بھیجیں گے،\nآرڈرز یہاں نظر آئیں گے۔',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _t('Something went wrong', 'کچھ غلط ہو گیا'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_t('Retry', 'دوبارہ کوشش')),
            ),
          ],
        ),
      ),
    );
  }
}
