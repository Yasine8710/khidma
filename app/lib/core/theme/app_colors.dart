import 'package:flutter/material.dart';

/// Khidma "Atelier" palette: bone paper, warm ink, one terracotta action
/// colour, olive for trust, ochre only for stars. Flat colours, no gradients
/// or glow. Every text pair is checked for contrast (see docs/DESIGN.md).
abstract final class AppColors {
  // Terracotta (harissa clay): the one colour that says "tap here".
  static const primary = Color(0xFFB0432A);
  static const primaryDark = Color(0xFF6E2614);
  static const primaryTint = Color(0xFFF6E6DE);

  /// Ochre: stars and small marks only (too light for text).
  static const saffron = Color(0xFFC98E1F);

  /// Olive: verified, success, "available".
  static const olive = Color(0xFF46613E);
  static const oliveTint = Color(0xFFDDE5D3);

  static const background = Color(0xFFF4EFE6); // bone paper
  static const surface = Color(0xFFFFFCF6); // card paper
  static const surfaceAlt = Color(0xFFEAE2D3); // sunken blocks
  static const ink = Color(0xFF1F1B16);
  static const muted = Color(0xFF6B6257);

  /// Hairline rules between rows and around cards (decorative).
  static const border = Color(0xFFD9CFBD);

  /// Boundary of interactive controls (fields, chips): >= 3:1 on paper.
  static const control = Color(0xFF8A8070);
  static const mutedStrong = Color(0xFF4F483F);

  static const darkBackground = Color(0xFF16130F);
  static const darkSurface = Color(0xFF201C17);
  static const darkSurfaceAlt = Color(0xFF2A251E);
  static const darkInk = Color(0xFFEEE7DA);
  static const darkMuted = Color(0xFFB3A896);
  static const darkBorder = Color(0xFF3A3328);
  static const darkControl = Color(0xFF7F7566);
  static const darkPrimary = Color(0xFFE07A5F);
  static const darkPrimaryContainer = Color(0xFF4A2418);
  static const darkOnPrimaryContainer = Color(0xFFF6D6CB);

  static const success = olive;
  static const warning = Color(0xFF8A5A00);
  static const error = Color(0xFFA12A1F);

  static const darkSuccess = Color(0xFFA9C39A);
  static const darkWarning = Color(0xFFE6B45C);
  static const darkError = Color(0xFFF2B8B5);

  /// Kept for older call sites: flat terracotta, no colour sweep.
  static const brandGradient = LinearGradient(
    colors: [primary, primary],
  );

  /// Kept for older call sites: the Atelier look has no drop shadows.
  static const softShadow = <BoxShadow>[];
}
