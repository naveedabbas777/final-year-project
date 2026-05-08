import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// App Color Tokens
/// Single source of truth for all colours in Digital Kissan.
/// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Brand greens
  static const Color primary        = Color(0xFF1B5E20); // deep green
  static const Color primaryDark    = Color(0xFF003300);
  static const Color primaryMid     = Color(0xFF2E7D32); // green.800
  static const Color primaryLight   = Color(0xFF388E3C); // green.700
  static const Color primarySurface = Color(0xFFE8F5E9); // green.50
  static const Color primaryBorder  = Color(0xFFC8E6C9); // green.100

  // Status colours
  static const Color statusOpen      = Color(0xFF2E7D32);
  static const Color statusReserved  = Color(0xFFE65100);
  static const Color statusSold      = Color(0xFF546E7A);
  static const Color statusCancelled = Color(0xFFC62828);
  static const Color statusDisputed  = Color(0xFFF57F17);

  // Surfaces
  static const Color background  = Color(0xFFF4F6F4);
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color cardShadow  = Color(0x0A000000);

  // Text
  static const Color textPrimary   = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF616161);
  static const Color textHint      = Color(0xFF9E9E9E);

  // Utility
  static const Color divider = Color(0xFFE0E0E0);
  static const Color amber   = Color(0xFFF59E0B);
  static const Color blue    = Color(0xFF1565C0);
  static const Color red     = Color(0xFFC62828);
  static const Color white   = Color(0xFFFFFFFF);
}

/// ─────────────────────────────────────────────────────────────────────────────
/// App Text Styles
/// ─────────────────────────────────────────────────────────────────────────────
class AppText {
  AppText._();

  static const TextStyle heading1 = TextStyle(
    fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.textPrimary,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.5,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3,
  );
  static const TextStyle priceLarge = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryMid, height: 1,
  );
  static const TextStyle button = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w700,
  );
}

/// ─────────────────────────────────────────────────────────────────────────────
/// App Decoration Helpers
/// ─────────────────────────────────────────────────────────────────────────────
class AppDecorations {
  AppDecorations._();

  static BoxDecoration card = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))],
  );

  static BoxDecoration cardBordered = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.divider),
  );

  static BoxDecoration primaryGradient = const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.primary, AppColors.primaryLight],
    ),
  );

  static BoxDecoration surfaceChip = BoxDecoration(
    color: AppColors.primarySurface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.primaryBorder),
  );

  static InputDecoration inputDecoration(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    prefixIcon: icon != null ? Icon(icon) : null,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primaryMid, width: 2),
    ),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

/// ─────────────────────────────────────────────────────────────────────────────
/// App Theme
/// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryMid,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.white,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryMid,
        foregroundColor: AppColors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: AppText.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryMid,
        side: const BorderSide(color: AppColors.primaryMid),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: AppText.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryMid,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryMid, width: 2),
      ),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.primaryMid,
      contentTextStyle: const TextStyle(color: AppColors.white),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primarySurface,
      labelStyle: AppText.caption.copyWith(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: AppColors.primaryBorder),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: AppColors.white,
      unselectedLabelColor: Color(0xB3FFFFFF),
      indicatorColor: AppColors.white,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );
}
