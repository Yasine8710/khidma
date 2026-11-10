import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_provider.dart';

const supportedLocales = [Locale('fr'), Locale('ar'), Locale('en')];
const defaultLocale = Locale('fr');
const _prefsKey = 'locale';

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final saved = ref.read(keyValueStoreProvider).getString(_prefsKey);
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
          .read(keyValueStoreProvider)
          .setString(_prefsKey, locale.languageCode);
    } catch (_) {
      return false;
    }
  }
}

extension LocaleDirection on Locale {
  bool get isRtl => languageCode == 'ar';
}
