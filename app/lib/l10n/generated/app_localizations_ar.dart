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

  @override
  String get onbTitle1 => 'اعثر على حرفيين موثوقين';

  @override
  String get onbBody1 =>
      'سبّاكون وكهربائيون وميكانيكيون وغيرهم: اكتشف حرفيين بالقرب منك مع أعمالهم وتقييماتهم.';

  @override
  String get onbTitle2 => 'قارن واطلب عرض سعر';

  @override
  String get onbBody2 =>
      'صف حاجتك مرة واحدة، واستقبل عروضًا من عدة حرفيين، ثم اختر الأنسب.';

  @override
  String get onbTitle3 => 'تواصل معهم مباشرة';

  @override
  String get onbBody3 =>
      'اتصل بهم أو راسلهم عبر واتساب أو تحدث داخل التطبيق. يتم الدفع مباشرة مع الحرفي.';

  @override
  String get languageStepBody => 'يمكنك تغييرها في أي وقت من حسابي.';

  @override
  String get next => 'التالي';

  @override
  String get start => 'ابدأ';

  @override
  String get skip => 'تخطَّ';

  @override
  String pageOf(int current, int total) {
    return 'الصفحة $current من $total';
  }

  @override
  String get back => 'السابق';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get fullNameLabel => 'الاسم الكامل';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get sendResetLink => 'إرسال الرابط';

  @override
  String get noAccountYet => 'ليس لديك حساب؟';

  @override
  String get haveAccount => 'لديك حساب بالفعل؟';

  @override
  String get signInTitle => 'مرحبًا بعودتك';

  @override
  String get signInSubtitle => 'سجّل الدخول لطلب عروض الأسعار ومتابعة طلباتك.';

  @override
  String get registerTitle => 'أنشئ حسابك';

  @override
  String get registerSubtitle => 'يستغرق الأمر بضع ثوانٍ فقط.';

  @override
  String get forgotTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotSubtitle =>
      'أدخل بريدك الإلكتروني وسنرسل لك رابطًا لاختيار كلمة مرور جديدة.';

  @override
  String get resetSentTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String resetSentBody(String email) {
    return 'إذا كان هناك حساب مرتبط بـ $email، فقد أرسلنا رابط إعادة التعيين.';
  }

  @override
  String get confirmEmailTitle => 'أكّد بريدك الإلكتروني';

  @override
  String confirmEmailBody(String email) {
    return 'أرسلنا رابط التأكيد إلى $email. افتحه لتفعيل حسابك.';
  }

  @override
  String get backToSignIn => 'العودة إلى تسجيل الدخول';

  @override
  String get errEmailRequired => 'أدخل بريدك الإلكتروني.';

  @override
  String get errEmailInvalid => 'بريد إلكتروني غير صالح.';

  @override
  String get errPasswordRequired => 'أدخل كلمة المرور.';

  @override
  String get errPasswordShort => '8 أحرف على الأقل.';

  @override
  String get errPasswordLong => 'كلمة المرور طويلة جدًا.';

  @override
  String get errNameRequired => 'أدخل اسمك.';

  @override
  String get failInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get failEmailNotConfirmed =>
      'أكّد بريدك الإلكتروني أولًا (الرابط في صندوق الوارد).';

  @override
  String get failWeakPassword =>
      'كلمة المرور ضعيفة. اختر كلمة أطول وأقل شيوعًا.';

  @override
  String get failSignUpDisabled => 'التسجيل مغلق حاليًا.';

  @override
  String get failRateLimited => 'محاولات كثيرة. أعد المحاولة بعد بضع دقائق.';

  @override
  String get failNetwork => 'تعذّر الاتصال. تحقق من الشبكة.';

  @override
  String get failNotConfigured =>
      'الحسابات غير متاحة في هذا الإصدار من التطبيق.';

  @override
  String get failUnknown => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get signedOutProfileTitle => 'سجّل الدخول أو أنشئ حسابًا';

  @override
  String get signedOutProfileBody => 'لطلب عروض الأسعار والتواصل مع الحرفيين.';

  @override
  String get requestsSignedOutTitle => 'سجّل الدخول لعرض طلباتك';

  @override
  String get requestsSignedOutBody =>
      'ستظهر هنا طلبات عروض الأسعار والعروض التي تصلك.';

  @override
  String get messagesSignedOutTitle => 'سجّل الدخول للمحادثة';

  @override
  String get messagesSignedOutBody => 'ستظهر هنا محادثاتك مع الحرفيين.';

  @override
  String signedInAs(String email) {
    return 'تم تسجيل الدخول بحساب $email';
  }

  @override
  String get newPasswordTitle => 'كلمة مرور جديدة';

  @override
  String get newPasswordSubtitle =>
      'اختر كلمة مرور لا تستخدمها في أي مكان آخر.';

  @override
  String get savePassword => 'حفظ كلمة المرور';

  @override
  String get passwordUpdated => 'تم تحديث كلمة المرور.';

  @override
  String get linkExpiredTitle => 'الرابط منتهي أو غير صالح';

  @override
  String get linkExpiredBody =>
      'اطلب رابط إعادة تعيين جديدًا من شاشة تسجيل الدخول.';

  @override
  String get accountTypeTitle => 'أريد أن…';

  @override
  String get accountCustomerTitle => 'أجد حرفيًا';

  @override
  String get accountCustomerBody => 'أطلب عروض أسعار وأتواصل مع الحرفيين.';

  @override
  String get accountProfessionalTitle => 'أعرض خدماتي';

  @override
  String get accountProfessionalBody => 'أنشئ ملفًا مهنيًا وأستقبل الطلبات.';

  @override
  String get becomeProfessionalTitle => 'اعرض خدماتك';

  @override
  String get becomeProfessionalBody =>
      'أنشئ ملفك المهني لتستقبل طلبات الزبائن.';

  @override
  String get becomeProfessionalCta => 'أصبح حرفيًا';

  @override
  String get professionalBadge => 'حرفي';

  @override
  String get editProfile => 'تعديل الملف';

  @override
  String get save => 'حفظ';

  @override
  String get phoneLabel => 'الهاتف';

  @override
  String get phoneHelper => 'يظهر لك وحدك.';

  @override
  String get profileSaved => 'تم حفظ الملف.';

  @override
  String get failProfileLoad => 'تعذّر تحميل ملفك.';

  @override
  String get failProfileInvalid => 'بعض المعلومات غير صالحة.';

  @override
  String get continueWithApple => 'المتابعة عبر Apple';

  @override
  String get orSeparator => 'أو';

  @override
  String get deleteAccount => 'حذف حسابي';

  @override
  String get deleteAccountTitle => 'حذف حسابك؟';

  @override
  String get deleteAccountBody =>
      'سيتم حذف ملفك ومعلوماتك والبيانات المرتبطة بها نهائيًا. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get deleteConfirmWord => 'حذف';

  @override
  String deleteTypeToConfirm(String word) {
    return 'اكتب $word للتأكيد';
  }

  @override
  String get cancel => 'إلغاء';

  @override
  String get accountDeleted => 'تم حذف حسابك.';
}
