import 'package:flutter/material.dart';

/// `4,5` in French/Arabic, `4.5` in English. Always Western digits.
/// The value is clamped to 0-5.
String formatRating(double value, Locale locale) {
  final v = value.isNaN ? 0.0 : value.clamp(0.0, 5.0);
  final s = v.toStringAsFixed(1);
  return locale.languageCode == 'en' ? s : s.replaceFirst('.', ',');
}
