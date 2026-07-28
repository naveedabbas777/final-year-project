import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Listing status badge — open / reserved / sold / cancelled / disputed.
///
/// Usage:
/// ```dart
/// StatusBadge(status: listing.status)
/// StatusBadge(status: 'open', size: StatusBadgeSize.large)
/// ```
enum StatusBadgeSize { small, medium, large }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.size = StatusBadgeSize.medium,
  });

  final String status;
  final StatusBadgeSize size;

  static Color colorFor(String status) {
    switch (status.toLowerCase()) {
      case 'open':      return AppColors.statusOpen;
      case 'reserved':  return AppColors.statusReserved;
      case 'sold':      return AppColors.statusSold;
      case 'cancelled': return AppColors.statusCancelled;
      case 'disputed':  return AppColors.statusDisputed;
      case 'completed': return AppColors.statusOpen;
      case 'in_transit':return AppColors.blue;
      case 'delivered': return AppColors.primaryLight;
      default:          return AppColors.textSecondary;
    }
  }

  static String labelFor(String status) {
    switch (status.toLowerCase()) {
      case 'open':      return '● Available';
      case 'reserved':  return '● Reserved';
      case 'sold':      return '● Sold';
      case 'cancelled': return '● Cancelled';
      case 'disputed':  return '● Disputed';
      case 'completed': return '● Completed';
      case 'in_transit':return '● In Transit';
      case 'delivered': return '● Delivered';
      default:          return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    final label = labelFor(status);

    final (hPad, vPad, fontSize) = switch (size) {
      StatusBadgeSize.small  => (8.0,  3.0, 11.0),
      StatusBadgeSize.medium => (10.0, 5.0, 12.0),
      StatusBadgeSize.large  => (14.0, 7.0, 13.0),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Order/offer pipeline status — for use in the orders/offers screens.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => StatusBadge(status: status, size: StatusBadgeSize.small);
}
