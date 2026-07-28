import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Reusable confirmation dialog — replaces every `showDialog(AlertDialog(...))`
/// used for destructive actions (cancel order, delete listing, etc.).
///
/// Usage:
/// ```dart
/// final confirmed = await ConfirmDialog.show(
///   context,
///   title: 'Cancel Order',
///   message: 'This action cannot be undone.',
///   confirmLabel: 'Yes, Cancel',
///   isDangerous: true,
/// );
/// if (confirmed == true) { ... }
/// ```
class ConfirmDialog {
  ConfirmDialog._();

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel  = 'Cancel',
    bool isDangerous    = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: icon != null
            ? Icon(icon, size: 36, color: isDangerous ? AppColors.red : AppColors.primaryMid)
            : null,
        title: Text(title, style: AppText.heading3, textAlign: TextAlign.center),
        content: Text(message, style: AppText.body, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(100, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 44),
              backgroundColor: isDangerous ? AppColors.red : AppColors.primaryMid,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
