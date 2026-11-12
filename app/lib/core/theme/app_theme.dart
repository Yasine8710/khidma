import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The "Atelier" theme: flat paper surfaces separated by hairline rules,
/// small corner radii, no shadows, one terracotta action colour.
abstract final class AppTheme {
  static ThemeData light(Locale locale) => _build(
    locale,
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryTint,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.olive,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.oliveTint,
      onSecondaryContainer: AppColors.olive,
      tertiary: AppColors.saffron,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.surfaceAlt,
      onTertiaryContainer: AppColors.ink,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerHighest: AppColors.surfaceAlt,
      surfaceContainerHigh: AppColors.surfaceAlt,
      surfaceContainer: AppColors.background,
      surfaceContainerLow: AppColors.background,
      surfaceContainerLowest: AppColors.surface,
      outline: AppColors.control,
      outlineVariant: AppColors.border,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.background,
    ),
    AppColors.background,
  );

  static ThemeData dark(Locale locale) => _build(
    locale,
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.ink,
      primaryContainer: AppColors.darkPrimaryContainer,
      onPrimaryContainer: AppColors.darkOnPrimaryContainer,
      secondary: AppColors.darkSuccess,
      onSecondary: AppColors.ink,
      secondaryContainer: Color(0xFF2C3A27),
      onSecondaryContainer: AppColors.darkSuccess,
      tertiary: AppColors.saffron,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.darkSurfaceAlt,
      onTertiaryContainer: AppColors.darkInk,
      error: AppColors.darkError,
      onError: AppColors.ink,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
      onSurfaceVariant: AppColors.darkMuted,
      surfaceContainerHighest: AppColors.darkSurfaceAlt,
      surfaceContainerHigh: AppColors.darkSurfaceAlt,
      surfaceContainer: AppColors.darkBackground,
      surfaceContainerLow: AppColors.darkBackground,
      surfaceContainerLowest: AppColors.darkSurface,
      outline: AppColors.darkControl,
      outlineVariant: AppColors.darkBorder,
      inverseSurface: AppColors.darkInk,
      onInverseSurface: AppColors.darkBackground,
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
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surface,
        selectedColor: cs.onSurface,
        secondarySelectedColor: cs.onSurface,
        side: BorderSide(color: cs.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: cs.surface),
        checkmarkColor: cs.surface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          side: BorderSide(color: cs.onSurface, width: 1.2),
          foregroundColor: cs.onSurface,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: text.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          selectedBackgroundColor: cs.onSurface,
          selectedForegroundColor: cs.surface,
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: text.labelLarge,
          minimumSize: const Size(0, 44),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cs.onSurface,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: cs.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.outlineVariant,
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
        focusedBorder: border(cs.onSurface, 1.6),
      ),
    );
  }
}
