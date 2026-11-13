import 'package:flutter/material.dart';

/// Khidma colours: a calm light app with one violet brand colour, like the
/// service apps people already use. Soft neutrals, no gradients. Every text
/// pair is checked for contrast (see docs/DESIGN.md).
abstract final class AppColors {
  // ---- Brand ----
  static const violet = Color(0xFF5B3CC4); // buttons, links, active tab
  static const violetDark = Color(0xFF3A2589); // text on violetSoft
  static const violetSoft = Color(0xFFEEE9FB); // chips, selected rows, header
  static const violetLight = Color(0xFFA493F0); // brand colour on dark

  // ---- Neutrals (light) ----
  static const ink = Color(0xFF1B1530); // text
  static const paper = Color(0xFFFFFFFF); // cards
  static const ground = Color(0xFFFAF9FC); // app background
  static const sunken = Color(0xFFF3F1F8); // inputs, inset blocks
  static const muted = Color(0xFF6E6A80); // secondary text (>= 4.5:1)
  static const rule = Color(0xFFECE9F3); // hairlines, card borders
  static const control = Color(0xFF8C879D); // outlines of controls (>= 3:1)

  // ---- Neutrals (dark) ----
  static const darkInk = Color(0xFFF1EFF7);
  static const darkGround = Color(0xFF121019);
  static const darkPaper = Color(0xFF1C1926);
  static const darkSunken = Color(0xFF262233);
  static const darkMuted = Color(0xFFA9A4BA);
  static const darkRule = Color(0xFF2D2939);
  static const darkControl = Color(0xFF7D778F);
  static const darkVioletSoft = Color(0xFF2E2650);

  // ---- Status ----
  static const success = Color(0xFF15803D);
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFD12C2C);
  static const darkSuccess = Color(0xFF4ADE80);
  static const darkWarning = Color(0xFFFBBF24);
  static const darkError = Color(0xFFFF8A80);

  /// Rating stars.
  static const star = Color(0xFFF5A524);

  /// Soft tints for category and placeholder tiles (light / dark pairs).
  static const tints = <Color>[
    Color(0xFFE8F1FF),
    Color(0xFFFFF8DB),
    Color(0xFFFFF1E6),
    Color(0xFFFDEBF1),
    Color(0xFFEAF7EE),
    Color(0xFFF3EEFF),
  ];
  static const darkTints = <Color>[
    Color(0xFF1B2433),
    Color(0xFF2D2A17),
    Color(0xFF2A2219),
    Color(0xFF2E1C24),
    Color(0xFF1B2A21),
    Color(0xFF251E33),
  ];

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
  static const primary = violet;
  static const primaryDark = violetDark;
  static const primaryTint = violetSoft;
  static const saffron = star;
  static const yellow = star;
  static const green = success;
  static const greenBright = darkSuccess;
  static const olive = success;
  static const oliveTint = Color(0xFFEAF7EE);
  static const background = ground;
  static const surface = paper;
  static const surfaceAlt = sunken;
  static const border = rule;
  static const mutedStrong = muted;
  static const darkBackground = darkGround;
  static const darkSurface = darkPaper;
  static const darkSurfaceAlt = darkSunken;
  static const darkBorder = darkRule;
  static const darkPrimary = violetLight;
  static const darkPrimaryContainer = darkVioletSoft;
  static const darkOnPrimaryContainer = darkInk;
}

/// The two sections of the app: local trades and digital freelancers. Both
/// share the brand colour; the world only changes what Home shows.
enum AppWorld {
  trades,
  digital;

  Color accent(Brightness b) =>
      b == Brightness.dark ? AppColors.violetLight : AppColors.violet;

  /// Text/icons that sit on [accent].
  Color onAccent(Brightness b) =>
      b == Brightness.dark ? AppColors.ink : Colors.white;
}
