import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Icon + label + value row — used in profile, seller profile, settings, etc.
///
/// Usage:
/// ```dart
/// InfoRow(Icons.phone_outlined, 'Phone', seller.phone)
/// InfoRow(Icons.location_on_outlined, 'District', listing.district, color: AppColors.primaryMid)
/// ```
class InfoRow extends StatelessWidget {
  const InfoRow(
    this.icon,
    this.label,
    this.value, {
    super.key,
    this.color,
    this.labelWidth = 88,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final double labelWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.primaryLight;
    final widget = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          SizedBox(
            width: labelWidth,
            child: Text(label, style: AppText.label),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: AppText.body.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
    if (onTap != null) return GestureDetector(onTap: onTap, child: widget);
    return widget;
  }
}

/// Divider variant for use between InfoRow items inside a card.
class InfoDivider extends StatelessWidget {
  const InfoDivider({super.key});

  @override
  Widget build(BuildContext context) => const Divider(
    height: 16,
    thickness: 1,
    color: AppColors.divider,
  );
}
