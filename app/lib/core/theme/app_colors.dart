import 'package:flutter/material.dart';

/// Khidma "Bleu Sidi Bou" palette. Saffron is for fills/icons only:
/// it is 2.16:1 on white, so never use it for text.
abstract final class AppColors {
  static const primary = Color(0xFF1F5AA6);
  static const primaryDark = Color(0xFF163F75);
  static const primaryTint = Color(0xFFE8F0FA);
  static const saffron = Color(0xFFE8A33D);

  static const background = Color(0xFFFAF9F6);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF14181F);
  static const muted = Color(0xFF6B7280);

  /// Hairline for cards, dividers, bars (decorative).
  static const border = Color(0xFFE6E3DC);

  /// Boundary of interactive controls (fields, chips): >= 3:1 on surfaces.
  static const control = Color(0xFF80858E);
  // Darker than [muted]: text on tinted backgrounds (neutral badges).
  static const mutedStrong = Color(0xFF4B5563);

  static const darkBackground = Color(0xFF0E1117);
  static const darkSurface = Color(0xFF171B23);
  static const darkInk = Color(0xFFE8EAED);
  static const darkMuted = Color(0xFF9AA3B2);
  static const darkBorder = Color(0xFF2A303B);
  static const darkControl = Color(0xFF6B7482);
  static const darkPrimary = Color(0xFF7DA8E8);

  static const success = Color(0xFF16794C);
  static const warning = Color(0xFF9A5B00);
  static const error = Color(0xFFB3261E);

  static const darkSuccess = Color(0xFF5DD39E);
  static const darkWarning = Color(0xFFF0B45A);
  static const darkError = Color(0xFFF2B8B5);
}
