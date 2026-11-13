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

/// Soft, friendly corners.
abstract final class AppRadius {
  static const double sm = 10; // chips, small tiles
  static const double md = 14; // inputs, buttons
  static const double lg = 18; // cards
  static const double xl = 24; // sheets, hero cards
  static const double pill = 999;
}

/// Card outline. Kept under its old name for older call sites: a 1 px
/// hairline and no hard shadow ([offset] is 0).
abstract final class AppInk {
  static const double border = 1;
  static const double offset = 0;
}
