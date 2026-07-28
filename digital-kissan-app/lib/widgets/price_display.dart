import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Standardised PKR price display used across market, listing detail, etc.
///
/// Usage:
/// ```dart
/// PriceDisplay(amount: listing.askingPrice, unit: listing.unit)
/// PriceDisplay(amount: 3500, unit: 'kg', size: PriceDisplaySize.large)
/// ```
enum PriceDisplaySize { small, medium, large }

class PriceDisplay extends StatelessWidget {
  const PriceDisplay({
    super.key,
    required this.amount,
    required this.unit,
    this.size = PriceDisplaySize.medium,
    this.color,
  });

  final double amount;
  final String unit;
  final PriceDisplaySize size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final priceColor = color ?? AppColors.primaryMid;

    final (currFontSize, amountFontSize, unitFontSize) = switch (size) {
      PriceDisplaySize.small  => (12.0, 16.0, 11.0),
      PriceDisplaySize.medium => (14.0, 22.0, 13.0),
      PriceDisplaySize.large  => (16.0, 32.0, 15.0),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PKR ',
          style: TextStyle(fontSize: currFontSize, fontWeight: FontWeight.w600, color: priceColor),
        ),
        Text(
          _formatAmount(amount),
          style: TextStyle(fontSize: amountFontSize, fontWeight: FontWeight.w900, color: priceColor, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 2, left: 4),
          child: Text(
            '/ $unit',
            style: TextStyle(fontSize: unitFontSize, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  String _formatAmount(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

/// A compact green price chip (used in listing cards).
class PriceChip extends StatelessWidget {
  const PriceChip({super.key, required this.amount, required this.unit});
  final double amount;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Text(
        'PKR ${amount.toStringAsFixed(0)}/$unit',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryMid,
        ),
      ),
    );
  }
}
