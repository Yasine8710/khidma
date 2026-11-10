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

  @override
  String get navHome => 'Home';

  @override
  String get navRequests => 'Requests';

  @override
  String get navMessages => 'Messages';

  @override
  String get navProfile => 'Profile';

  @override
  String get homeEmptyTitle => 'Professionals are coming soon';

  @override
  String get homeEmptyBody =>
      'Search and service categories will be available here.';

  @override
  String get requestsEmptyTitle => 'No requests yet';

  @override
  String get requestsEmptyBody => 'Your quote requests will appear here.';

  @override
  String get messagesEmptyTitle => 'No messages';

  @override
  String get messagesEmptyBody =>
      'Your conversations with professionals will appear here.';

  @override
  String get themeTitle => 'Appearance';

  @override
  String get themeSystem => 'Automatic';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundBody => 'This page doesn\'t exist or has moved.';

  @override
  String get backToHome => 'Back to home';
}
