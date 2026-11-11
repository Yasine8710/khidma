import 'package:flutter/material.dart';

/// Khidma "Bleu Sidi Bou" palette. Saffron is for fills/icons only:
/// it is 2.16:1 on white, so never use it for text.
abstract final class AppColors {
  /// Brand gradient for heroes and the main action (deep to bright blue).
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryBright],
  );

  /// Soft blue-tinted shadow for floating surfaces (cards, nav, search).
  static const softShadow = [
    BoxShadow(color: Color(0x1A123D78), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0D123D78), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const primary = Color(0xFF1F5AA6);
  static const primaryDark = Color(0xFF123D78);
  static const primaryBright = Color(0xFF2F7DE1);
  static const primaryTint = Color(0xFFE8F0FA);
  static const saffron = Color(0xFFE8A33D);

  static const background = Color(0xFFF4F7FC);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F1B2D);
  static const muted = Color(0xFF586A82);

  /// Hairline for cards, dividers, bars (decorative).
  static const border = Color(0xFFE1E8F3);

  /// Boundary of interactive controls (fields, chips): >= 3:1 on surfaces.
  static const control = Color(0xFF7A8AA3);
  // Darker than [muted]: text on tinted backgrounds (neutral badges).
  static const mutedStrong = Color(0xFF445670);

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
