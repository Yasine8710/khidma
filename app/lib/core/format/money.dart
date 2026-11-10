import 'package:flutter/material.dart';

/// Formats Tunisian dinar amounts. TND has 3 decimals (millimes); decimals
/// are shown only when needed. Western digits in every language.
String formatTnd(num amount, Locale locale) {
  final negative = amount < 0;
  final fixed = amount.abs().toStringAsFixed(3);
  final parts = fixed.split('.');
  final decimals = parts[1].replaceFirst(RegExp(r'0+$'), '');

  final en = locale.languageCode == 'en';
  final groupSep = en ? ',' : ' ';
  final decSep = en ? '.' : ',';

  final digits = parts[0];
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(groupSep);
    grouped.write(digits[i]);
  }

  final number = decimals.isEmpty
      ? grouped.toString()
      : '$grouped$decSep$decimals';
  final symbol = locale.languageCode == 'ar' ? 'د.ت' : 'DT';
  return '${negative ? '-' : ''}$number $symbol';
}
