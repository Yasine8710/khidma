import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_provider.dart';

const _prefsKey = 'themeMode';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// Follows the system by default; the user can force light or dark.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.read(keyValueStoreProvider).getString(_prefsKey);
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
          .read(keyValueStoreProvider)
          .setString(_prefsKey, mode.name);
    } catch (_) {
      return false;
    }
  }
}
