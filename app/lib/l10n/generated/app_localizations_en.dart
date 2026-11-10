// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Khidma';

  @override
  String get tagline => 'Trusted professionals, close to you.';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get priceOnQuote => 'On quote';

  @override
  String professionalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count professionals',
      one: '1 professional',
      zero: 'No professionals',
    );
    return '$_temp0';
  }

  @override
  String get phoneInvalid =>
      'Invalid Tunisian number. Example: +216 20 123 456';
}
