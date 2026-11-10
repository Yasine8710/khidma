import 'package:flutter/services.dart';

/// Thin wrapper so haptics are used consistently and never throw
/// (unsupported devices, web, tests).
abstract final class AppHaptics {
  /// Choosing among options: tabs, chips, language, theme.
  static Future<void> selection() => _run(HapticFeedback.selectionClick);

  /// Tapping a primary action.
  static Future<void> light() => _run(HapticFeedback.lightImpact);

  /// Something important completed (e.g. request sent).
  static Future<void> success() => _run(HapticFeedback.mediumImpact);

  static Future<void> _run(Future<void> Function() haptic) async {
    try {
      await haptic();
    } catch (_) {}
  }
}
