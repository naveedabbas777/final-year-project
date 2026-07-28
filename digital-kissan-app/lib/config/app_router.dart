import 'package:flutter/material.dart';

/// Shared page transitions for Digital Kissan.
/// Use these instead of bare [MaterialPageRoute] for consistent animations.
class AppRoutes {
  AppRoutes._();

  /// Smooth fade transition (default for most screens).
  static Route<T> fade<T>(Widget page) => PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  /// Slide-up transition (use for bottom-sheet-style screens like detail views).
  static Route<T> slideUp<T>(Widget page) => PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final tween = Tween(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: animation.drive(tween), child: child),
          );
        },
      );

  /// Slide-right transition (use for drill-down navigation).
  static Route<T> slideRight<T>(Widget page) => PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final tween = Tween(
            begin: const Offset(0.1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: animation.drive(tween), child: child),
          );
        },
      );
}
