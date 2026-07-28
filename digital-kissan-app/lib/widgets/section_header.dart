import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Consistent section header used across listing detail, seller profile, etc.
///
/// Usage:
/// ```dart
/// SectionHeader('Description')
/// SectionHeader('Seller Information', icon: Icons.person_outline)
/// SectionHeader('Location', trailing: TextButton(...))
/// ```
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.icon,
    this.trailing,
    this.padding,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primaryMid),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: AppText.heading3,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
