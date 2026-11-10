import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/locale_controller.dart';

const _prefsKey = 'themeMode';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// Follows the system by default; the user can force light or dark.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_prefsKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  /// Applies [mode] immediately, then persists it. Returns whether it was
  /// saved; the UI keeps the new mode even when saving fails.
  Future<bool> setMode(ThemeMode mode) async {
    state = mode;
    try {
      return await ref
          .read(sharedPreferencesProvider)
          .setString(_prefsKey, mode.name);
    } catch (_) {
      return false;
    }
  }
}
