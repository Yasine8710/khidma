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

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navRequests => 'طلباتي';

  @override
  String get navMessages => 'الرسائل';

  @override
  String get navProfile => 'حسابي';

  @override
  String get homeEmptyTitle => 'الحرفيون قادمون قريبًا';

  @override
  String get homeEmptyBody => 'سيتوفر البحث وفئات الخدمات هنا.';

  @override
  String get requestsEmptyTitle => 'لا توجد طلبات حتى الآن';

  @override
  String get requestsEmptyBody => 'ستظهر طلبات عروض الأسعار هنا.';

  @override
  String get messagesEmptyTitle => 'لا توجد رسائل';

  @override
  String get messagesEmptyBody => 'ستظهر محادثاتك مع الحرفيين هنا.';

  @override
  String get themeTitle => 'المظهر';

  @override
  String get themeSystem => 'تلقائي';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get notFoundTitle => 'الصفحة غير موجودة';

  @override
  String get notFoundBody => 'هذه الصفحة غير موجودة أو تم نقلها.';

  @override
  String get backToHome => 'العودة إلى الرئيسية';

  @override
  String get verified => 'موثّق';

  @override
  String get ratingNone => 'لا توجد تقييمات بعد';

  @override
  String ratingSummary(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم',
      many: '$count تقييمًا',
      few: '$count تقييمات',
      two: 'تقييمان',
      one: 'تقييم واحد',
    );
    return 'التقييم $value من 5، $_temp0';
  }

  @override
  String get errorTitle => 'حدث خطأ ما';

  @override
  String get errorBody => 'تحقق من اتصالك وأعد المحاولة.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';
}
