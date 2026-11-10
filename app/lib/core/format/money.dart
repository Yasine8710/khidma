import 'package:flutter/material.dart';

const _lri = '\u2066';
const _pdi = '\u2069';

/// Formats Tunisian dinar amounts. TND has 3 decimals (millimes); decimals
/// are shown only when needed. Western digits in every language.
///
/// Throws [ArgumentError] for NaN, infinity or amounts of 1e15 and above:
/// those are programming errors, not displayable prices.
String formatTnd(num amount, Locale locale) {
  if (!amount.isFinite || amount.abs() >= 1e15) {
    throw ArgumentError.value(amount, 'amount', 'not a displayable price');
  }
  final fixed = amount.abs().toStringAsFixed(3);
  final parts = fixed.split('.');
  final decimals = parts[1].replaceFirst(RegExp(r'0+$'), '');
  // Sign is decided after rounding, so -0.0004 is "0", not "-0".
  final negative = amount < 0 && fixed != '0.000';

  final en = locale.languageCode == 'en';
  final ar = locale.languageCode == 'ar';
  final groupSep = en ? ',' : ' ';
  final decSep = en ? '.' : ',';

  final digits = parts[0];
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(groupSep);
    grouped.write(digits[i]);
  }

  var number = decimals.isEmpty
      ? grouped.toString()
      : '$grouped$decSep$decimals';
  if (negative) {
    number = '-$number';
    // Isolate the signed number so the minus stays on its left in RTL text.
    if (ar) number = '$_lri$number$_pdi';
  }
  return '$number ${ar ? 'د.ت' : 'DT'}';
}
