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

  @override
  String get navHome => 'Accueil';

  @override
  String get navRequests => 'Demandes';

  @override
  String get navMessages => 'Messages';

  @override
  String get navProfile => 'Profil';

  @override
  String get homeEmptyTitle => 'Les professionnels arrivent bientôt';

  @override
  String get homeEmptyBody =>
      'La recherche et les catégories de services seront disponibles ici.';

  @override
  String get requestsEmptyTitle => 'Aucune demande pour l\'instant';

  @override
  String get requestsEmptyBody => 'Vos demandes de devis apparaîtront ici.';

  @override
  String get messagesEmptyTitle => 'Aucun message';

  @override
  String get messagesEmptyBody =>
      'Vos conversations avec les professionnels apparaîtront ici.';

  @override
  String get themeTitle => 'Apparence';

  @override
  String get themeSystem => 'Automatique';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get notFoundTitle => 'Page introuvable';

  @override
  String get notFoundBody => 'Cette page n\'existe pas ou a été déplacée.';

  @override
  String get backToHome => 'Retour à l\'accueil';
}
