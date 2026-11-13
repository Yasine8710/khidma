import 'package:flutter/material.dart';

/// Maps the icon name stored on a trade category to a line icon. Unknown
/// names fall back to a generic tool, so a new category never breaks the UI.
IconData categoryIcon(String name) => switch (name) {
  'plumbing' => Icons.water_drop_outlined,
  'bolt' => Icons.bolt_outlined,
  'ac_unit' => Icons.ac_unit_outlined,
  'car_repair' => Icons.car_repair_outlined,
  'format_paint' => Icons.format_paint_outlined,
  'carpenter' => Icons.carpenter_outlined,
  'cleaning_services' => Icons.cleaning_services_outlined,
  'kitchen' => Icons.kitchen_outlined,
  'construction' => Icons.construction_outlined,
  'yard' => Icons.yard_outlined,
  'local_shipping' => Icons.local_shipping_outlined,
  _ => Icons.handyman_outlined,
};

/// The same for digital categories (code, design, video...).
IconData digitalCategoryIcon(String name) => switch (name) {
  'code' => Icons.code_rounded,
  'phone_iphone' => Icons.phone_iphone_outlined,
  'brush' => Icons.brush_outlined,
  'movie' => Icons.movie_outlined,
  'campaign' => Icons.campaign_outlined,
  'edit_note' => Icons.edit_note_outlined,
  _ => Icons.laptop_mac_outlined,
};
