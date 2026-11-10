import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'digits.dart';

/// Localized date such as `12 nov. 2026`, always with Western digits.
String formatDate(DateTime date, Locale locale) =>
    toWesternDigits(DateFormat.yMMMd(locale.languageCode).format(date));

/// Localized time `HH:mm`, always with Western digits.
String formatTime(DateTime date, Locale locale) =>
    toWesternDigits(DateFormat.Hm(locale.languageCode).format(date));

/// "novembre 2026" / "November 2026": month and year, always Western digits.
String formatMonthYear(DateTime date, Locale locale) =>
    toWesternDigits(DateFormat.yMMMM(locale.languageCode).format(date));
