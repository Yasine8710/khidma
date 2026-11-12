import 'package:flutter/material.dart';

/// Khidma "Signal": the colours of workshop signage. Hard black ink on flat
/// colour fields, one loud colour per world: mimosa yellow for the trades,
/// zellij green for the digital services. No gradients, no blur, no pastel.
/// Every text pair is checked for contrast (see docs/DESIGN.md).
abstract final class AppColors {
  // ---- Worlds (the loud colour of each section) ----
  /// Local trades: signage yellow. Always carries ink text, never used as text.
  static const yellow = Color(0xFFF5C400);

  /// Digital services: deep zellij green. Carries white text.
  static const green = Color(0xFF0B6B4D);
  static const greenBright = Color(0xFF30C48D); // green on dark surfaces

  // ---- Neutrals ----
  static const ink = Color(0xFF0E0E0E);
  static const paper = Color(0xFFFFFFFF);
  static const ground = Color(0xFFEDEDE8); // app background
  static const sunken = Color(0xFFDFDFD8); // inset blocks
  static const muted = Color(0xFF55554F);
  static const rule = Color(0xFFBDBDB4); // hairlines, decorative
  static const control = Color(0xFF6F6F68); // outlines of controls (>= 3:1)

  static const darkInk = Color(0xFFF4F4EE);
  static const darkGround = Color(0xFF0B0B0B);
  static const darkPaper = Color(0xFF171717);
  static const darkSunken = Color(0xFF242424);
  static const darkMuted = Color(0xFFB4B4AC);
  static const darkRule = Color(0xFF3C3C3C);
  static const darkControl = Color(0xFF8A8A82);

  // ---- Status ----
  static const success = green;
  static const warning = Color(0xFF8A5A00);
  static const error = Color(0xFFC0261C);
  static const darkSuccess = greenBright;
  static const darkWarning = Color(0xFFF5C400);
  static const darkError = Color(0xFFFF8A80);

  /// Stars: the yellow, with an ink outline where it sits on paper.
  static const star = yellow;

  // Compatibility names for older call sites.
  static const primary = ink;
  static const primaryDark = ink;
  static const primaryTint = yellow;
  static const saffron = yellow;
  static const olive = green;
  static const oliveTint = Color(0xFFD5E8DF);
  static const background = ground;
  static const surface = paper;
  static const surfaceAlt = sunken;
  static const border = rule;
  static const mutedStrong = muted;
  static const darkBackground = darkGround;
  static const darkSurface = darkPaper;
  static const darkSurfaceAlt = darkSunken;
  static const darkBorder = darkRule;
  static const darkPrimary = darkInk;
  static const darkPrimaryContainer = yellow;
  static const darkOnPrimaryContainer = ink;
  static const brandGradient = LinearGradient(colors: [yellow, yellow]);
  static const softShadow = <BoxShadow>[];
}

/// The two sections of the app. Switching the world recolours everything.
enum AppWorld {
  trades,
  digital;

  Color accent(Brightness b) => switch (this) {
    AppWorld.trades => AppColors.yellow,
    AppWorld.digital =>
      b == Brightness.dark ? AppColors.greenBright : AppColors.green,
  };

  /// Text/icons that sit on [accent].
  Color onAccent(Brightness b) => switch (this) {
    AppWorld.trades => AppColors.ink,
    AppWorld.digital => b == Brightness.dark ? AppColors.ink : Colors.white,
  };
}
