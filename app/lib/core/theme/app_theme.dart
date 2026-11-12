import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The Khidma theme: calm light surfaces, one violet brand colour, soft
/// rounded cards with hairline borders, the platform font. [world] is kept
/// for API compatibility; both worlds share the brand colour.
abstract final class AppTheme {
  static ThemeData light(Locale locale, {AppWorld world = AppWorld.trades}) =>
      _build(locale, Brightness.light);

  static ThemeData dark(Locale locale, {AppWorld world = AppWorld.trades}) =>
      _build(locale, Brightness.dark);

  static ThemeData _build(Locale locale, Brightness b) {
    final dark = b == Brightness.dark;
    final ink = dark ? AppColors.darkInk : AppColors.ink;
    final paper = dark ? AppColors.darkPaper : AppColors.paper;
    final ground = dark ? AppColors.darkGround : AppColors.ground;
    final sunken = dark ? AppColors.darkSunken : AppColors.sunken;
    final muted = dark ? AppColors.darkMuted : AppColors.muted;
    final rule = dark ? AppColors.darkRule : AppColors.rule;
    final control = dark ? AppColors.darkControl : AppColors.control;
    final brand = dark ? AppColors.violetLight : AppColors.violet;
    final onBrand = dark ? AppColors.ink : Colors.white;
    final soft = dark ? AppColors.darkVioletSoft : AppColors.violetSoft;
    final onSoft = dark ? AppColors.darkInk : AppColors.violetDark;

    final cs = ColorScheme(
      brightness: b,
      primary: brand,
      onPrimary: onBrand,
      primaryContainer: soft,
      onPrimaryContainer: onSoft,
      secondary: brand,
      onSecondary: onBrand,
      secondaryContainer: sunken,
      onSecondaryContainer: ink,
      tertiary: AppColors.star,
      onTertiary: AppColors.ink,
      tertiaryContainer: dark ? const Color(0xFF3A2E10) : const Color(0xFFFFF4D6),
      onTertiaryContainer: dark ? AppColors.darkWarning : AppColors.warning,
      error: dark ? AppColors.darkError : AppColors.error,
      onError: dark ? AppColors.ink : Colors.white,
      errorContainer: dark ? const Color(0xFF3B1D1D) : const Color(0xFFFDECEC),
      onErrorContainer: dark ? AppColors.darkError : AppColors.error,
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
      shadow: Colors.black,
      inverseSurface: dark ? AppColors.darkInk : AppColors.ink,
      onInverseSurface: dark ? AppColors.ink : AppColors.paper,
      inversePrimary: dark ? AppColors.violet : AppColors.violetLight,
    );

    final text = AppTypography.textTheme(locale, ink);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: c, width: w),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: cs,
      scaffoldBackgroundColor: ground,
      fontFamily: AppTypography.familyFor(locale),
      textTheme: text,
      dividerColor: rule,
      dividerTheme: DividerThemeData(color: rule, thickness: 1, space: 1),
      splashFactory: InkSparkle.splashFactory,
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
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: rule,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: rule),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: paper,
        selectedColor: soft,
        secondarySelectedColor: soft,
        side: BorderSide(color: rule),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: text.labelMedium?.copyWith(color: ink),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: onSoft),
        checkmarkColor: onSoft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: brand,
          foregroundColor: onBrand,
          disabledBackgroundColor: sunken,
          disabledForegroundColor: muted,
          shape: buttonShape,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: brand,
          foregroundColor: onBrand,
          shape: buttonShape,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: paper,
          foregroundColor: ink,
          shape: buttonShape,
          side: BorderSide(color: rule),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: ink),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: paper,
          foregroundColor: muted,
          selectedBackgroundColor: brand,
          selectedForegroundColor: onBrand,
          side: BorderSide(color: rule),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: text.labelMedium,
          minimumSize: const Size(0, 44),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onBrand : control,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? brand : sunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? brand : control,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ink,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(color: muted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ink,
        unselectedLabelColor: muted,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
        indicatorColor: brand,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: rule,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: rule,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brand,
        linearTrackColor: sunken,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        hintStyle: text.bodyLarge?.copyWith(color: muted),
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        border: border(rule),
        enabledBorder: border(rule),
        focusedBorder: border(brand, 1.5),
        errorBorder: border(cs.error),
        focusedErrorBorder: border(cs.error, 1.5),
      ),
    );
  }
}
