import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/theme/app_colors.dart';
import 'package:khidma/core/theme/app_theme.dart';
import 'package:khidma/core/theme/app_typography.dart';

double _ratio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  test('text pairs meet WCAG AA 4.5:1', () {
    final pairs = <String, double>{
      'primary/surface': _ratio(AppColors.primary, AppColors.surface),
      'ink/background': _ratio(AppColors.ink, AppColors.background),
      'muted/background': _ratio(AppColors.muted, AppColors.background),
      'primary/tint': _ratio(AppColors.primary, AppColors.primaryTint),
      'dark ink/bg': _ratio(AppColors.darkInk, AppColors.darkBackground),
      'dark primary/surface': _ratio(
        AppColors.darkPrimary,
        AppColors.darkSurface,
      ),
      'dark muted/surface': _ratio(AppColors.darkMuted, AppColors.darkSurface),
      'ink on saffron': _ratio(AppColors.ink, AppColors.saffron),
    };
    pairs.forEach((k, v) => expect(v, greaterThanOrEqualTo(4.5), reason: k));
  });

  test('saffron is not usable for text on white', () {
    expect(_ratio(AppColors.saffron, AppColors.surface), lessThan(3));
  });

  test('arabic locale selects Arabic font family', () {
    expect(
      AppTheme.light(const Locale('ar')).textTheme.bodyMedium!.fontFamily,
      AppTypography.arabicFamily,
    );
    expect(
      AppTheme.dark(const Locale('ar')).textTheme.titleLarge!.fontFamily,
      AppTypography.arabicFamily,
    );
  });

  test('Latin locales use the platform font, never Tajawal', () {
    // No family is forced, so Flutter uses the platform's own font (San
    // Francisco on iOS, Roboto on Android).
    expect(AppTypography.familyFor(const Locale('fr')), isNull);
    expect(AppTypography.familyFor(const Locale('en')), isNull);
    for (final lang in ['fr', 'en']) {
      for (final theme in [
        AppTheme.light(Locale(lang)),
        AppTheme.dark(Locale(lang)),
      ]) {
        final family = theme.textTheme.bodyMedium!.fontFamily;
        expect(family, isNot(AppTypography.arabicFamily), reason: lang);
        expect(
          family,
          anyOf(isNull, 'Roboto', 'CupertinoSystemText', '.SF Pro Text'),
          reason: lang,
        );
      }
    }
  });
}
