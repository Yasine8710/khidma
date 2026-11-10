import 'package:flutter/material.dart';

/// Inter for Latin, IBM Plex Sans Arabic for Arabic. Arabic gets extra
/// line height because its glyphs carry taller ascenders and diacritics.
abstract final class AppTypography {
  static const latinFamily = 'Inter';
  static const arabicFamily = 'IBMPlexSansArabic';

  static String familyFor(Locale locale) =>
      locale.languageCode == 'ar' ? arabicFamily : latinFamily;

  static TextTheme textTheme(Locale locale, Color color) {
    final ar = locale.languageCode == 'ar';
    final family = familyFor(locale);
    TextStyle s(double size, FontWeight w, double h) => TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: w,
      height: ar ? h + 0.15 : h,
      letterSpacing: ar ? 0 : (size >= 24 ? -0.4 : 0),
      color: color,
    );
    return TextTheme(
      displaySmall: s(32, FontWeight.w700, 1.15),
      headlineMedium: s(26, FontWeight.w700, 1.2),
      headlineSmall: s(22, FontWeight.w600, 1.25),
      titleLarge: s(20, FontWeight.w600, 1.3),
      titleMedium: s(16, FontWeight.w600, 1.35),
      titleSmall: s(14, FontWeight.w600, 1.35),
      bodyLarge: s(16, FontWeight.w400, 1.5),
      bodyMedium: s(14, FontWeight.w400, 1.45),
      bodySmall: s(12, FontWeight.w400, 1.4),
      labelLarge: s(15, FontWeight.w600, 1.2),
      labelMedium: s(13, FontWeight.w500, 1.2),
      labelSmall: s(11, FontWeight.w500, 1.2),
    );
  }
}
