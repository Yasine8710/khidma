// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'خدمة';

  @override
  String get tagline => 'حرفيون موثوقون، قريبون منك.';

  @override
  String get chooseLanguage => 'اختر اللغة';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get priceOnQuote => 'حسب عرض السعر';

  @override
  String professionalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حرفي',
      many: '$count حرفيًا',
      few: '$count حرفيين',
      two: 'حرفيان',
      one: 'حرفي واحد',
      zero: 'لا يوجد حرفيون',
    );
    return '$_temp0';
  }

  @override
  String get phoneInvalid => 'رقم هاتف تونسي غير صالح. مثال: ‎+216 20 123 456';
}
