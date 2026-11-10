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

  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    state = locale;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_prefsKey, locale.languageCode);
  }
}

extension LocaleDirection on Locale {
  bool get isRtl => languageCode == 'ar';
}
