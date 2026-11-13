import 'package:flutter/material.dart';

/// Khidma colours: black and white, like the everyday apps people trust
/// (Uber, Bolt). Black for actions, white surfaces, soft greys for structure;
/// colour comes only from content: avatars, rating stars, the green
/// "verified" tick, status. No gradients. Every text pair is checked for
/// contrast (see docs/DESIGN.md).
abstract final class AppColors {
  // ---- Brand ----
  static const brand = Color(0xFF141414); // buttons, active tab, hero cards
  static const brandDark = Color(0xFF141414); // text on brandSoft
  static const brandSoft = Color(0xFFF2F2F2); // chips, selected rows, header
  static const brandLight = Color(0xFFF2F2F2); // brand colour on dark

  // ---- Neutrals (light) ----
  static const ink = Color(0xFF141414); // text
  static const paper = Color(0xFFFFFFFF); // cards
  static const ground = Color(0xFFFFFFFF); // app background
  static const sunken = Color(0xFFF4F4F4); // inputs, inset blocks
  static const muted = Color(0xFF6B6B6B); // secondary text (>= 4.5:1)
  static const rule = Color(0xFFEAEAEA); // hairlines, card borders
  static const control = Color(0xFF8A8A8A); // outlines of controls (>= 3:1)

  // ---- Neutrals (dark) ----
  static const darkInk = Color(0xFFF2F2F2);
  static const darkGround = Color(0xFF0E0E0E);
  static const darkPaper = Color(0xFF1A1A1A);
  static const darkSunken = Color(0xFF242424);
  static const darkMuted = Color(0xFFA8A8A8);
  static const darkRule = Color(0xFF2C2C2C);
  static const darkControl = Color(0xFF7A7A7A);
  static const darkBrandSoft = Color(0xFF262626);

  // ---- Status ----
  static const success = Color(0xFF0E7A55); // also the "verified" tick
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFD12C2C);
  static const darkSuccess = Color(0xFF34D399);
  static const darkWarning = Color(0xFFFBBF24);
  static const darkError = Color(0xFFFF8A80);

  /// Rating stars.
  static const star = Color(0xFFE8A317);

  /// Category and placeholder tiles: one quiet grey (icons carry the
  /// meaning). Kept as lists so call sites can index by category.
  static const tints = <Color>[Color(0xFFF3F3F3)];
  static const darkTints = <Color>[Color(0xFF242424)];

  /// Avatar colours for initials (white text >= 4.5:1 on all of them).
  static const avatars = <Color>[
    Color(0xFF2F6FDB),
    Color(0xFFB45309),
    Color(0xFF9333EA),
    Color(0xFF15803D),
    Color(0xFFDB2777),
    Color(0xFF0E7490),
  ];

  static Color tint(int i, Brightness b) {
    final list = b == Brightness.dark ? darkTints : tints;
    return list[i.abs() % list.length];
  }

  static Color avatar(int i) => avatars[i.abs() % avatars.length];

  // Compatibility names for older call sites.
  static const primary = brand;
  static const primaryDark = brandDark;
  static const primaryTint = brandSoft;
  static const saffron = star;
  static const yellow = star;
  static const green = success;
  static const greenBright = darkSuccess;
  static const olive = success;
  static const oliveTint = Color(0xFFE7F4EE);
  static const background = ground;
  static const surface = paper;
  static const surfaceAlt = sunken;
  static const border = rule;
  static const mutedStrong = muted;
  static const darkBackground = darkGround;
  static const darkSurface = darkPaper;
  static const darkSurfaceAlt = darkSunken;
  static const darkBorder = darkRule;
  static const darkPrimary = brandLight;
  static const darkPrimaryContainer = darkBrandSoft;
  static const darkOnPrimaryContainer = darkInk;
}

/// The two sections of the app: local trades and digital freelancers. Both
/// share the brand colour; the world only changes what Home shows.
enum AppWorld {
  trades,
  digital;

  Color accent(Brightness b) =>
      b == Brightness.dark ? AppColors.brandLight : AppColors.brand;

  /// Text/icons that sit on [accent].
  Color onAccent(Brightness b) =>
      b == Brightness.dark ? AppColors.ink : Colors.white;
}
