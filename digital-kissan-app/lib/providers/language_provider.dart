import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  static const String localeStorageKey = 'app_locale_code';
  Locale _locale;

  LanguageProvider({Locale? initialLocale})
    : _locale =
          (initialLocale != null && L10n.all.contains(initialLocale))
              ? initialLocale
              : const Locale('en', '');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (!L10n.all.contains(locale)) return;
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    _persistLocale(locale.languageCode);
  }

  static Locale resolveLocale(String? languageCode) {
    return L10n.all.firstWhere(
      (locale) => locale.languageCode == languageCode,
      orElse: () => const Locale('en', ''),
    );
  }

  Future<void> _persistLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localeStorageKey, languageCode);
  }
}

class L10n {
  static final all = [const Locale('en', ''), const Locale('ur', '')];
}
