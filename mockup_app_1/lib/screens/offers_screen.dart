import 'package:flutter/material.dart';

import '../services/market_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _service = MarketApiService();

  bool _loading = false;
  String? _error;
  List<OfferDto> _myOffers = const [];
  List<OfferDto> _incoming = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.fetchMyOffers(),
        _service.fetchIncomingOffers(),
      ]);
      if (!mounted) return;
      setState(() {
        _myOffers = results[0];
        _incoming = results[1];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _accept(OfferDto offer) async {
    try {
      await _service.acceptOffer(offer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Offer accepted and order created'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Future<void> _reject(OfferDto offer) async {
    try {
      await _service.rejectOffer(offer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
        content: const Text('Offer rejected'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancel(OfferDto offer) async {
    try {
      await _service.cancelOffer(offer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
        content: const Text('Offer cancelled'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // Status badge data
  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'accepted':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'cancelled':
        return Icons.block_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Declined';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  Widget _buildOfferCard(OfferDto offer, {bool incoming = false}) {
    final listing = offer.listing;
    final statusColor = _statusColor(offer.status);
    final hasImage = listing != null && listing.imageUrls.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: statusColor.withOpacity(0.8),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Listing image thumbnail
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      listing!.imageUrls.first,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.agriculture, color: Colors.green.shade400, size: 24),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.agriculture, color: Colors.green.shade400, size: 24),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing != null ? listing.cropName : 'Listing ${offer.listingId.substring(0, offer.listingId.length > 8 ? 8 : offer.listingId.length)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      if (listing != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Text(
                                listing.district,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              if (listing.qualityGrade.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.amber.shade200, width: 0.5),
                                  ),
                                  child: Text(
                                    'Grade ${listing.qualityGrade}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber.shade800),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'PKR ',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Text(
                            offer.offerPrice.toStringAsFixed(0),
                            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.green.shade700, fontSize: 16),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '× ${offer.quantity.toStringAsFixed(0)} ${listing?.unit ?? ''}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge with icon
                _buildStatusBadge(offer.status),
              ],
            ),
            if (offer.status == 'pending') ...[
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
              if (incoming)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildActionButton(
                      label: 'Reject',
                      icon: Icons.close_rounded,
                      color: Colors.red.shade600,
                      isOutlined: true,
                      onPressed: () => _reject(offer),
                    ),
                    const SizedBox(width: 10),
                    _buildActionButton(
                      label: 'Accept',
                      icon: Icons.check_rounded,
                      color: Colors.green.shade700,
                      isOutlined: false,
                      onPressed: () => _accept(offer),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildActionButton(
                      label: 'Cancel Offer',
                      icon: Icons.close_rounded,
                      color: Colors.grey.shade600,
                      isOutlined: true,
                      onPressed: () => _cancel(offer),
                    ),
                  ],
                ),
            ] else ...[
              // For non-pending: show a subtle timestamp row
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeAgo(offer.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            _statusLabel(status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isOutlined,
    required VoidCallback onPressed,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );
    }
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingMyCount = _myOffers.where((o) => o.status == 'pending').length;
    final pendingInCount = _incoming.where((o) => o.status == 'pending').length;

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
              child: const Icon(Icons.local_offer_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Offers',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.3),
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
        bottom: TabBar(
          controller: _tab,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 15),
                  const SizedBox(width: 6),
                  const Text('Sent'),
                  if (pendingMyCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingMyCount',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_downward_rounded, size: 15),
                  const SizedBox(width: 6),
                  const Text('Received'),
                  if (pendingInCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingInCount',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body:
          _loading
              ? const AsyncLoadingWidget()
              : _error != null
              ? Center(
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
                        child: Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Something went wrong',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
              : TabBarView(
                controller: _tab,
                children: [
                  RefreshIndicator(
                    color: Colors.green.shade700,
                    onRefresh: _load,
                    child: _myOffers.isEmpty
                        ? _buildEmptyState('No offers sent yet', 'Start making offers on\nlisting you\'re interested in.', Icons.send_rounded)
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: _myOffers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _buildOfferCard(_myOffers[i]),
                          ),
                  ),
                  RefreshIndicator(
                    color: Colors.green.shade700,
                    onRefresh: _load,
                    child: _incoming.isEmpty
                        ? _buildEmptyState('No offers received', 'When buyers make offers on\nyour listings, they\'ll appear here.', Icons.inbox_rounded)
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: _incoming.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _buildOfferCard(_incoming[i], incoming: true),
                          ),
                  ),
                ],
              ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
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
                child: Icon(icon, size: 56, color: Colors.green.shade300),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
