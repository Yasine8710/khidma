/// 4-pt spacing scale and radii. Prefer EdgeInsetsDirectional for RTL.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double gutter = 20;
}

/// Almost-square corners: blocks, not bubbles.
abstract final class AppRadius {
  static const double sm = 2;
  static const double md = 3;
  static const double lg = 4;
  static const double xl = 6;
}

/// Heavy ink outline and the hard offset "sticker" shadow of cards and buttons.
abstract final class AppInk {
  static const double border = 2;
  static const double offset = 4; // shadow offset
}
