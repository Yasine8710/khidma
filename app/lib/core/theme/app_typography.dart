import 'package:flutter/material.dart';

/// Poster type. Latin: Anton (tall condensed capitals, like a shop sign) for
/// display, Barlow (a signage grotesque) for reading. Arabic: Lalezar (heavy
/// display) and Tajawal. Display styles are set in capitals in Latin; Arabic
/// has no case so it relies on weight and size. Arabic gets extra line height.
abstract final class AppTypography {
  static const displayFamily = 'Anton';
  static const latinFamily = 'Barlow';
  static const arabicDisplayFamily = 'Lalezar';
  static const arabicFamily = 'Tajawal';

  // Kept for older call sites.
  static const headingFamily = displayFamily;

  static String familyFor(Locale locale) =>
      locale.languageCode == 'ar' ? arabicFamily : latinFamily;

  static String displayFor(Locale locale) =>
      locale.languageCode == 'ar' ? arabicDisplayFamily : displayFamily;

  static String headingFor(Locale locale) => displayFor(locale);

  static TextTheme textTheme(Locale locale, Color color) {
    final ar = locale.languageCode == 'ar';
    final body = familyFor(locale);
    final display = displayFor(locale);
    TextStyle s(
      String family,
      double size,
      FontWeight w,
      double h, {
      double tracking = 0,
    }) => TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: w,
      height: ar ? h + 0.15 : h,
      letterSpacing: ar ? 0 : tracking,
      color: color,
    );
    // Display faces have a single weight: never ask for bold (it would be
    // synthesised and blurry).
    return TextTheme(
      displayLarge: s(display, 64, FontWeight.w400, 0.95, tracking: 0.5),
      displayMedium: s(display, 48, FontWeight.w400, 1.0, tracking: 0.5),
      displaySmall: s(display, 38, FontWeight.w400, 1.0, tracking: 0.5),
      headlineMedium: s(display, 30, FontWeight.w400, 1.05, tracking: 0.4),
      headlineSmall: s(display, 24, FontWeight.w400, 1.1, tracking: 0.3),
      titleLarge: s(display, 20, FontWeight.w400, 1.15, tracking: 0.3),
      titleMedium: s(body, 17, FontWeight.w700, 1.3),
      titleSmall: s(body, 15, FontWeight.w700, 1.3),
      bodyLarge: s(body, 17, FontWeight.w400, 1.45),
      bodyMedium: s(body, 15, FontWeight.w400, 1.45),
      bodySmall: s(body, 13, FontWeight.w500, 1.35),
      labelLarge: s(body, 16, FontWeight.w700, 1.2, tracking: 0.6),
      labelMedium: s(body, 14, FontWeight.w700, 1.2, tracking: 0.5),
      labelSmall: s(body, 12, FontWeight.w700, 1.2, tracking: 0.6),
    );
  }

  /// Display text is set in capitals in Latin, as is on signage.
  static String display(Locale locale, String s) =>
      locale.languageCode == 'ar' ? s : s.toUpperCase();
}
