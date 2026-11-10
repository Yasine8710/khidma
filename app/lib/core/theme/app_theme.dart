import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light(Locale locale) => _build(
    locale,
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryTint,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.saffron,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.primaryTint,
      onSecondaryContainer: AppColors.primaryDark,
      tertiary: AppColors.primary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.primaryTint,
      onTertiaryContainer: AppColors.primaryDark,
      secondaryFixed: AppColors.primaryTint,
      secondaryFixedDim: AppColors.primaryTint,
      onSecondaryFixed: AppColors.primaryDark,
      onSecondaryFixedVariant: AppColors.primaryDark,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.control,
      outlineVariant: AppColors.border,
    ),
    AppColors.background,
  );

  static ThemeData dark(Locale locale) => _build(
    locale,
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkBackground,
      primaryContainer: AppColors.primaryDark,
      onPrimaryContainer: AppColors.darkInk,
      secondary: AppColors.saffron,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.primaryDark,
      onSecondaryContainer: AppColors.darkInk,
      tertiary: AppColors.darkPrimary,
      onTertiary: AppColors.darkBackground,
      tertiaryContainer: AppColors.primaryDark,
      onTertiaryContainer: AppColors.darkInk,
      secondaryFixed: AppColors.primaryDark,
      secondaryFixedDim: AppColors.primaryDark,
      onSecondaryFixed: AppColors.darkInk,
      onSecondaryFixedVariant: AppColors.darkInk,
      error: Color(0xFFF2B8B5),
      onError: AppColors.ink,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
      onSurfaceVariant: AppColors.darkMuted,
      outline: AppColors.darkControl,
      outlineVariant: AppColors.darkBorder,
    ),
    AppColors.darkBackground,
  );

  static ThemeData _build(Locale locale, ColorScheme cs, Color background) {
    final text = AppTypography.textTheme(locale, cs.onSurface);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: c, width: w),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: background,
      fontFamily: AppTypography.familyFor(locale),
      textTheme: text,
      dividerColor: cs.outlineVariant,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          side: BorderSide(color: cs.outline),
          textStyle: text.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          selectedBackgroundColor: cs.primaryContainer,
          selectedForegroundColor: cs.onPrimaryContainer,
          side: BorderSide(color: cs.outline),
          textStyle: text.labelLarge,
          minimumSize: const Size(0, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surface,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        border: border(cs.outline),
        enabledBorder: border(cs.outline),
        focusedBorder: border(cs.primary, 1.6),
      ),
    );
  }
}
