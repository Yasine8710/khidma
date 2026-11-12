import 'package:flutter/material.dart';

/// Type: the phone's own font for Latin text (San Francisco on iOS, Roboto on
/// Android), so the app feels native. Arabic uses Tajawal on every platform
/// for a consistent, modern Arabic. Weights do the hierarchy, not exotic
/// faces. Arabic gets extra line height.
abstract final class AppTypography {
  static const arabicFamily = 'Tajawal';

  // Kept for older call sites (null = the platform font).
  static const String? latinFamily = null;
  static const String? displayFamily = null;
  static const arabicDisplayFamily = arabicFamily;

  /// null = the platform font.
  static String? familyFor(Locale locale) =>
      locale.languageCode == 'ar' ? arabicFamily : null;

  // Kept for older call sites: headings use the same family as body text.
  static String? displayFor(Locale locale) => familyFor(locale);
  static String? headingFor(Locale locale) => familyFor(locale);

  static TextTheme textTheme(Locale locale, Color color) {
    final ar = locale.languageCode == 'ar';
    final family = familyFor(locale);
    TextStyle s(double size, FontWeight w, double h, {double tracking = 0}) =>
        TextStyle(
          fontFamily: family,
          fontSize: size,
          fontWeight: w,
          height: ar ? h + 0.15 : h,
          letterSpacing: ar ? 0 : tracking,
          color: color,
        );
    return TextTheme(
      displayLarge: s(40, FontWeight.w700, 1.1, tracking: -0.8),
      displayMedium: s(34, FontWeight.w700, 1.12, tracking: -0.6),
      displaySmall: s(28, FontWeight.w700, 1.15, tracking: -0.4),
      headlineMedium: s(24, FontWeight.w700, 1.2, tracking: -0.3),
      headlineSmall: s(22, FontWeight.w700, 1.22, tracking: -0.2),
      titleLarge: s(19, FontWeight.w700, 1.25, tracking: -0.2),
      titleMedium: s(16, FontWeight.w600, 1.3),
      titleSmall: s(14, FontWeight.w600, 1.3),
      bodyLarge: s(16, FontWeight.w400, 1.45),
      bodyMedium: s(14, FontWeight.w400, 1.45),
      bodySmall: s(12.5, FontWeight.w400, 1.4),
      labelLarge: s(15, FontWeight.w600, 1.2),
      labelMedium: s(13, FontWeight.w600, 1.2),
      labelSmall: s(11, FontWeight.w500, 1.2),
    );
  }

  /// Kept for older call sites: text is no longer forced to capitals.
  static String display(Locale locale, String s) => s;
}
