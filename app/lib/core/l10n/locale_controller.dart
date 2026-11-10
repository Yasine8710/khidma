import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const supportedLocales = [Locale('fr'), Locale('ar'), Locale('en')];
const defaultLocale = Locale('fr');
const _prefsKey = 'locale';

/// Overridden in `main()` with the real instance, and in tests with a mock.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_prefsKey);
    return supportedLocales.firstWhere(
      (l) => l.languageCode == saved,
      orElse: () => defaultLocale,
    );
  }

  /// Applies [locale] immediately, then persists it. Returns whether the
  /// choice was saved; the UI keeps the new language even when saving fails.
  Future<bool> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return false;
    state = locale;
    try {
      return await ref
          .read(sharedPreferencesProvider)
          .setString(_prefsKey, locale.languageCode);
    } catch (_) {
      return false;
    }
  }
}

extension LocaleDirection on Locale {
  bool get isRtl => languageCode == 'ar';
}
