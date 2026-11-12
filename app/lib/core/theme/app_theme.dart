import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The "Signal" theme. [world] picks the loud colour of the section the
/// person is in (yellow trades / green digital); everything else is ink and
/// paper. Cards and buttons get a heavy ink outline and, through the shared
/// widgets, a hard offset shadow that collapses when pressed.
abstract final class AppTheme {
  static ThemeData light(Locale locale, {AppWorld world = AppWorld.trades}) =>
      _build(locale, Brightness.light, world);

  static ThemeData dark(Locale locale, {AppWorld world = AppWorld.trades}) =>
      _build(locale, Brightness.dark, world);

  static ThemeData _build(Locale locale, Brightness b, AppWorld world) {
    final dark = b == Brightness.dark;
    final ink = dark ? AppColors.darkInk : AppColors.ink;
    final paper = dark ? AppColors.darkPaper : AppColors.paper;
    final ground = dark ? AppColors.darkGround : AppColors.ground;
    final sunken = dark ? AppColors.darkSunken : AppColors.sunken;
    final muted = dark ? AppColors.darkMuted : AppColors.muted;
    final rule = dark ? AppColors.darkRule : AppColors.rule;
    final control = dark ? AppColors.darkControl : AppColors.control;
    final accent = world.accent(b);
    final onAccent = world.onAccent(b);
    final other = world == AppWorld.trades ? AppWorld.digital : AppWorld.trades;

    final cs = ColorScheme(
      brightness: b,
      primary: ink,
      onPrimary: dark ? AppColors.ink : AppColors.paper,
      primaryContainer: accent,
      onPrimaryContainer: onAccent,
      secondary: other.accent(b),
      onSecondary: other.onAccent(b),
      secondaryContainer: sunken,
      onSecondaryContainer: ink,
      tertiary: AppColors.yellow,
      onTertiary: AppColors.ink,
      tertiaryContainer: sunken,
      onTertiaryContainer: ink,
      error: dark ? AppColors.darkError : AppColors.error,
      onError: dark ? AppColors.ink : Colors.white,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerHighest: sunken,
      surfaceContainerHigh: sunken,
      surfaceContainer: ground,
      surfaceContainerLow: ground,
      surfaceContainerLowest: paper,
      outline: control,
      outlineVariant: rule,
      inverseSurface: ink,
      onInverseSurface: dark ? AppColors.ink : AppColors.paper,
    );

    final text = AppTypography.textTheme(locale, ink);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: ink, width: AppInk.border),
    );
    OutlineInputBorder border(Color c, [double w = AppInk.border]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: ground,
      fontFamily: AppTypography.familyFor(locale),
      textTheme: text,
      dividerColor: rule,
      dividerTheme: DividerThemeData(color: rule, thickness: 1, space: 1),
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ground,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        shape: Border(
          bottom: BorderSide(color: ink, width: AppInk.border),
        ),
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: ink, width: AppInk.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: paper,
        selectedColor: accent,
        secondarySelectedColor: accent,
        side: BorderSide(color: ink, width: AppInk.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: onAccent),
        checkmarkColor: onAccent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: sunken,
          disabledForegroundColor: muted,
          shape: shape,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: paper,
          foregroundColor: ink,
          shape: shape,
          side: BorderSide(color: ink, width: AppInk.border),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: text.labelLarge?.copyWith(
            decoration: TextDecoration.underline,
            decorationThickness: 2,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: paper,
          foregroundColor: ink,
          selectedBackgroundColor: accent,
          selectedForegroundColor: onAccent,
          side: BorderSide(color: ink, width: AppInk.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: text.labelLarge,
          minimumSize: const Size(0, 46),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(ink),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : sunken,
        ),
        trackOutlineColor: WidgetStatePropertyAll(ink),
        trackOutlineWidth: const WidgetStatePropertyAll(2),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ink,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(color: muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          side: BorderSide(color: ink, width: AppInk.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ink,
        linearTrackColor: sunken,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        border: border(ink),
        enabledBorder: border(ink),
        focusedBorder: border(ink, 3),
        errorBorder: border(cs.error),
        focusedErrorBorder: border(cs.error, 3),
      ),
    );
  }
}
