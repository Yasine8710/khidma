import 'package:flutter/material.dart';

/// Maps the icon name stored on a category to a Material icon. Unknown names
/// fall back to a generic tool, so a new category never breaks the UI.
IconData categoryIcon(String name) => switch (name) {
  'plumbing' => Icons.plumbing_rounded,
  'bolt' => Icons.bolt_rounded,
  'ac_unit' => Icons.ac_unit_rounded,
  'car_repair' => Icons.car_repair_rounded,
  'format_paint' => Icons.format_paint_rounded,
  'carpenter' => Icons.carpenter_rounded,
  'cleaning_services' => Icons.cleaning_services_rounded,
  'kitchen' => Icons.kitchen_rounded,
  'construction' => Icons.construction_rounded,
  'yard' => Icons.yard_rounded,
  'local_shipping' => Icons.local_shipping_rounded,
  _ => Icons.handyman_rounded,
};
