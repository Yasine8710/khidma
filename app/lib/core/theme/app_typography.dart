import 'package:flutter/material.dart';

/// Latin: Zilla Slab for headings (a workshop-sign slab serif), Lato for
/// reading and controls. Arabic: IBM Plex Sans Arabic throughout, with extra
/// line height for its taller ascenders and diacritics.
abstract final class AppTypography {
  static const headingFamily = 'ZillaSlab';
  static const latinFamily = 'Lato';
  static const arabicFamily = 'IBMPlexSansArabic';

  static String familyFor(Locale locale) =>
      locale.languageCode == 'ar' ? arabicFamily : latinFamily;

  static String headingFor(Locale locale) =>
      locale.languageCode == 'ar' ? arabicFamily : headingFamily;

  static TextTheme textTheme(Locale locale, Color color) {
    final ar = locale.languageCode == 'ar';
    final body = familyFor(locale);
    final head = headingFor(locale);
    TextStyle s(String family, double size, FontWeight w, double h) =>
        TextStyle(
          fontFamily: family,
          fontSize: size,
          fontWeight: w,
          height: ar ? h + 0.15 : h,
          letterSpacing: 0,
          color: color,
        );
    return TextTheme(
      displaySmall: s(head, 34, FontWeight.w700, 1.1),
      headlineMedium: s(head, 28, FontWeight.w700, 1.15),
      headlineSmall: s(head, 23, FontWeight.w600, 1.2),
      titleLarge: s(head, 20, FontWeight.w600, 1.25),
      titleMedium: s(body, 16, FontWeight.w700, 1.35),
      titleSmall: s(body, 14, FontWeight.w700, 1.35),
      bodyLarge: s(body, 16, FontWeight.w400, 1.5),
      bodyMedium: s(body, 14, FontWeight.w400, 1.45),
      bodySmall: s(body, 12.5, FontWeight.w400, 1.4),
      labelLarge: s(body, 15, FontWeight.w700, 1.2),
      labelMedium: s(body, 13, FontWeight.w700, 1.2),
      labelSmall: s(body, 11.5, FontWeight.w700, 1.2),
    );
  }
}
