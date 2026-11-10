import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:khidma/core/format/dates.dart';
import 'package:khidma/core/format/digits.dart';
import 'package:khidma/core/format/money.dart';
import 'package:khidma/core/format/tunisian_phone.dart';

void main() {
  const fr = Locale('fr');
  const ar = Locale('ar');
  const en = Locale('en');

  group('toWesternDigits', () {
    test('converts Arabic-Indic and Persian digits', () {
      expect(toWesternDigits('٢٠ ١٢٣ ٤٥٦'), '20 123 456');
      expect(toWesternDigits('۲۰۱۲۳۴۵۶'), '20123456');
      expect(toWesternDigits('abc 12'), 'abc 12');
    });
  });

  group('formatTnd', () {
    test('whole amounts have no decimals', () {
      expect(formatTnd(1200, fr), '1 200 DT');
      expect(formatTnd(0, fr), '0 DT');
      expect(formatTnd(999, fr), '999 DT');
      expect(formatTnd(1000000, fr), '1 000 000 DT');
    });
    test('millimes shown only when needed', () {
      expect(formatTnd(12.5, fr), '12,5 DT');
      expect(formatTnd(12.5, en), '12.5 DT');
      expect(formatTnd(1250.125, en), '1,250.125 DT');
    });
    test('arabic uses د.ت with Western digits', () {
      expect(formatTnd(85, ar), '85 د.ت');
    });
    test('negative', () {
      expect(formatTnd(-5, fr), '-5 DT');
      expect(formatTnd(-5, ar), '\u2066-5\u2069 د.ت');
    });
    test('rounding and sign edge cases', () {
      expect(formatTnd(0.9996, fr), '1 DT');
      expect(formatTnd(-0.0004, fr), '0 DT');
      expect(formatTnd(-0.0, fr), '0 DT');
      expect(formatTnd(0.001, en), '0.001 DT');
    });
    test('rejects non-displayable amounts', () {
      expect(() => formatTnd(double.nan, fr), throwsArgumentError);
      expect(() => formatTnd(double.infinity, fr), throwsArgumentError);
      expect(() => formatTnd(1e21, fr), throwsArgumentError);
    });
  });

  group('TunisianPhone', () {
    test('accepts common forms', () {
      for (final s in [
        '20123456',
        '20 123 456',
        '+216 20 123 456',
        '+21620123456',
        '0021620123456',
        '21620123456',
        '20-123-456',
        '٢٠١٢٣٤٥٦',
        '\u200E+216 20 123 456\u200F',
        '\u061C+216 20 123 456',
        '\u2066+216 20 123 456\u2069',
        '\u202A20123456\u202C',
      ]) {
        expect(TunisianPhone.parse(s), '20123456', reason: s);
      }
    });
    test('rejects invalid', () {
      for (final s in [
        '',
        '1234567',
        '123456789',
        '10123456',
        '60123456',
        '80123456',
        '+33 6 12 34 56 78',
        'abcdefgh',
        '+216 20 123 45',
        '+216',
        '00216',
        '216',
      ]) {
        expect(TunisianPhone.isValid(s), isFalse, reason: s);
      }
    });
    test('display, e164 and whatsapp', () {
      expect(TunisianPhone.display('71123456'), '+216 71 123 456');
      expect(TunisianPhone.e164('71123456'), '+21671123456');
      expect(TunisianPhone.whatsapp('71123456'), '21671123456');
      expect(TunisianPhone.display('nope'), isNull);
    });
  });

  group('dates', () {
    setUpAll(() async {
      await initializeDateFormatting('fr');
      await initializeDateFormatting('ar');
      await initializeDateFormatting('en');
    });
    test('Arabic dates use Western digits', () {
      final out = formatDate(DateTime(2026, 11, 12), ar);
      expect(out, contains('2026'));
      expect(out, contains('12'));
      expect(out, isNot(matches(RegExp('[٠-٩]'))));
      expect(formatTime(DateTime(2026, 1, 1, 9, 5), ar), '09:05');
    });
    test('French date', () {
      expect(formatDate(DateTime(2026, 11, 12), fr), contains('2026'));
    });
  });
}
