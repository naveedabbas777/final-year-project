import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Styled SnackBar helper — replaces plain `ScaffoldMessenger.of(context).showSnackBar(...)`.
///
/// Usage:
/// ```dart
/// AppSnackBar.success(context, 'Listing updated successfully');
/// AppSnackBar.error(context, 'Failed to load data. Please try again.');
/// AppSnackBar.info(context, 'Phone number copied to clipboard');
/// ```
class AppSnackBar {
  AppSnackBar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.primaryMid, Icons.check_circle_outline);

  static void error(BuildContext context, String message) =>
      _show(context, message, AppColors.red, Icons.error_outline);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.blue, Icons.info_outline);

  static void warning(BuildContext context, String message) =>
      _show(context, message, AppColors.statusDisputed, Icons.warning_amber_outlined);

  static void _show(BuildContext context, String message, Color bg, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: AppColors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(message, style: const TextStyle(color: AppColors.white))),
              ],
            ),
            backgroundColor: bg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
  }
}
