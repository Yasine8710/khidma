// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Khidma';

  @override
  String get tagline => 'Des professionnels de confiance, près de chez vous.';

  @override
  String get chooseLanguage => 'Choisir la langue';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get priceOnQuote => 'Sur devis';

  @override
  String professionalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count professionnels',
      one: '1 professionnel',
      zero: 'Aucun professionnel',
    );
    return '$_temp0';
  }

  @override
  String get phoneInvalid =>
      'Numéro tunisien invalide. Exemple : +216 20 123 456';
}
