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

  @override
  String get homeGreeting => 'مرحبًا';

  @override
  String homeGreetingNamed(String name) {
    return 'مرحبًا، $name';
  }

  @override
  String get homeSubtitle => 'ما الخدمة التي تحتاجها؟';

  @override
  String get searchHint => 'ابحث عن مهنة أو اسم أو مدينة…';

  @override
  String get placeAll => 'كل تونس';

  @override
  String get placeChoose => 'اختر منطقة';

  @override
  String get placeGovernorate => 'الولاية';

  @override
  String get placeWholeGovernorate => 'كل الولاية';

  @override
  String get sectionCategories => 'الفئات';

  @override
  String get sectionTopRated => 'الأعلى تقييمًا';

  @override
  String get sectionInYourArea => 'في منطقتك';

  @override
  String get sectionInYourAreaPrompt => 'اختر منطقة لرؤية الحرفيين من حولك.';

  @override
  String get sectionRecent => 'شوهدت مؤخرًا';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get noProfessionalsTitle => 'لا يوجد حرفيون حتى الآن';

  @override
  String get noProfessionalsBody => 'سيظهرون هنا بمجرد انضمامهم إلى خدمة.';

  @override
  String get noProfessionalsInArea => 'لا يوجد حرفيون في هذه المنطقة حتى الآن.';

  @override
  String get demoBannerTitle => 'بيانات تجريبية';

  @override
  String get demoBannerBody => 'الحرفيون والتقييمات والشارات المعروضة وهمية.';

  @override
  String get availabilityAvailable => 'متاح';

  @override
  String get availabilityBusy => 'مشغول';

  @override
  String get availabilityOffline => 'غير متصل';

  @override
  String yearsExperience(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'خبرة $count سنة',
      many: 'خبرة $count سنة',
      few: 'خبرة $count سنوات',
      two: 'خبرة سنتين',
      one: 'خبرة سنة واحدة',
    );
    return '$_temp0';
  }

  @override
  String distanceKm(String km) {
    return '$km كم';
  }

  @override
  String get failLoadProfessionals => 'تعذّر تحميل الحرفيين.';

  @override
  String get failForbidden => 'تم رفض الوصول إلى البيانات. حاول لاحقًا.';

  @override
  String get professionalNotFoundTitle => 'الملف غير موجود';

  @override
  String get professionalNotFoundBody => 'هذا الحرفي لم يعد متاحًا.';

  @override
  String get searchTitle => 'بحث';

  @override
  String get searchNoResultsTitle => 'لا توجد نتائج';

  @override
  String get searchNoResultsBody => 'جرّب كلمة أو منطقة أخرى.';

  @override
  String get searchStartTitle => 'عمّ تبحث؟';

  @override
  String get searchStartBody => 'اكتب مهنة أو اسمًا أو مدينة.';

  @override
  String get aboutLabel => 'نبذة';

  @override
  String get inCategory => 'الفئة';

  @override
  String get filtersTitle => 'التصفية';

  @override
  String get filtersAction => 'تصفية';

  @override
  String get filterCategory => 'الفئة';

  @override
  String get filterAllCategories => 'الكل';

  @override
  String get filterMinRating => 'الحد الأدنى للتقييم';

  @override
  String get filterRatingAny => 'أي تقييم';

  @override
  String filterRatingAtLeast(String value) {
    return '$value+';
  }

  @override
  String get filterAvailableOnly => 'المتاحون فقط';

  @override
  String get sortBy => 'ترتيب حسب';

  @override
  String get sortRating => 'الأعلى تقييمًا';

  @override
  String get sortReviews => 'الأكثر تقييمات';

  @override
  String get filtersApply => 'تطبيق';

  @override
  String get filtersReset => 'إعادة ضبط';

  @override
  String get loadMore => 'عرض المزيد';

  @override
  String filtersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'التصفية، $count فلترًا نشطًا',
      few: 'التصفية، $count فلاتر نشطة',
      two: 'التصفية، فلتران نشطان',
      one: 'التصفية، فلتر واحد نشط',
      zero: 'التصفية',
    );
    return '$_temp0';
  }

  @override
  String get contactTitle => 'التواصل';

  @override
  String get contactShow => 'إظهار رقم التواصل';

  @override
  String get contactSignIn => 'سجّل الدخول لعرض رقم التواصل';

  @override
  String get contactCall => 'اتصال';

  @override
  String get contactWhatsApp => 'واتساب';

  @override
  String get contactWhy =>
      'يظهر الرقم للأعضاء المسجلين فقط، لحماية الحرفيين من الإزعاج.';

  @override
  String get contactDemo => 'رقم التواصل غير متاح مع البيانات التجريبية.';

  @override
  String get contactRateLimited =>
      'عدد كبير من الأرقام في وقت قصير. حاول بعد ساعة.';

  @override
  String get contactNotFound => 'هذا الحرفي لم يعد متاحًا.';

  @override
  String get contactFailed => 'تعذّر تحميل رقم التواصل. حاول مجددًا.';

  @override
  String get contactLaunchFailed => 'تعذّر فتح التطبيق.';

  @override
  String get servicesTitle => 'الخدمات';

  @override
  String get areasTitle => 'مناطق التدخل';

  @override
  String areaWhole(String place) {
    return '$place (كل الولاية)';
  }

  @override
  String get favoritesTitle => 'مفضلتي';

  @override
  String get favoriteAdd => 'إضافة إلى المفضلة';

  @override
  String get favoriteRemove => 'إزالة من المفضلة';

  @override
  String get favoritesEmptyTitle => 'لا توجد مفضلات';

  @override
  String get favoritesEmptyBody => 'المس القلب في أي ملف لتجده هنا.';

  @override
  String get favoritesSignInTitle => 'احتفظ بمفضلتك';

  @override
  String get favoritesSignInBody =>
      'سجّل الدخول لحفظ الحرفيين وإيجادهم على كل أجهزتك.';

  @override
  String get favoriteLimit => 'وصلت إلى الحد الأقصى: 200 مفضلة.';

  @override
  String get favoriteFailed => 'تعذّر تحديث المفضلة. حاول مجددًا.';

  @override
  String favoriteAddNamed(String name) {
    return 'إضافة $name إلى المفضلة';
  }

  @override
  String favoriteRemoveNamed(String name) {
    return 'إزالة $name من المفضلة';
  }

  @override
  String get nearMe => 'بالقرب مني';

  @override
  String get sortNearest => 'الأقرب';

  @override
  String get filterRadius => 'أقصى مسافة';

  @override
  String get filterRadiusAny => 'أي مسافة';

  @override
  String get locationDenied => 'اسمح بالموقع لرؤية الحرفيين القريبين منك.';

  @override
  String get locationDeniedForever => 'الموقع محظور. اسمح به من الإعدادات.';

  @override
  String get locationServiceOff => 'خدمة الموقع متوقفة على هذا الجهاز.';

  @override
  String get locationUnavailable => 'تعذّر تحديد موقعك. حاول مجددًا.';

  @override
  String get openSettings => 'الإعدادات';

  @override
  String get showMap => 'عرض الخريطة';

  @override
  String get showList => 'عرض القائمة';

  @override
  String get mapNothingTitle => 'لا شيء لعرضه على الخريطة';

  @override
  String get mapNothingBody => 'لا يملك أيٌّ من هؤلاء الحرفيين موقعًا معروفًا.';

  @override
  String get regTitle => 'الملف المهني';

  @override
  String regStepOf(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get regNext => 'متابعة';

  @override
  String get regBack => 'رجوع';

  @override
  String get regStepBusiness => 'نشاطك';

  @override
  String get regStepLocation => 'أين تعمل؟';

  @override
  String get regStepAreas => 'مناطق التدخل';

  @override
  String get regStepServices => 'خدمات أخرى';

  @override
  String get regStepContact => 'التواصل';

  @override
  String get regStepReview => 'المراجعة والنشر';

  @override
  String get regBusinessName => 'الاسم المعروض (مؤسسة أو شخص)';

  @override
  String get regYears => 'سنوات الخبرة (اختياري)';

  @override
  String get regCategory => 'المهنة الرئيسية';

  @override
  String get regDescription => 'صف خدماتك';

  @override
  String get regDescriptionHelper => '20 حرفًا على الأقل.';

  @override
  String get regGovernorate => 'الولاية';

  @override
  String get regCity => 'المدينة (اختياري)';

  @override
  String get regAreasBody =>
      'اختر الولايات التي تتنقل إليها، إضافة إلى ولايتك.';

  @override
  String get regServicesBody => 'أضف خدمات أخرى تقدمها.';

  @override
  String get regPhone => 'هاتف التواصل';

  @override
  String get regPhoneHelper =>
      'لا يراه إلا الأعضاء المسجلون، وعند طلبهم له فقط.';

  @override
  String get regPhotoLater => 'الصورة الشخصية قادمة قريبًا.';

  @override
  String get regErrName => 'بين 2 و120 حرفًا.';

  @override
  String get regErrDescription => 'بين 20 و2000 حرف.';

  @override
  String get regErrCategory => 'اختر مهنة.';

  @override
  String get regErrGovernorate => 'اختر ولاية.';

  @override
  String get regErrYears => 'بين 0 و60.';

  @override
  String get regErrPhone => 'رقم تونسي غير صالح (8 أرقام).';

  @override
  String get regReviewBody => 'هذا ما سيراه الزبائن.';

  @override
  String get regPublish => 'نشر ملفي';

  @override
  String get regUnpublish => 'إزالة من القائمة';

  @override
  String get regSaveDraft => 'حفظ ومغادرة';

  @override
  String get regPublished => 'ملفك منشور.';

  @override
  String get regDraft => 'مسودة: غير ظاهرة للزبائن.';

  @override
  String regMissing(String items) {
    return 'للنشر ينقصك: $items.';
  }

  @override
  String get gapName => 'الاسم';

  @override
  String get gapCategory => 'المهنة';

  @override
  String get gapDescription => 'الوصف';

  @override
  String get gapLocation => 'الولاية';

  @override
  String get gapPhone => 'الهاتف';

  @override
  String get regFailNetwork => 'لا يوجد اتصال. إجاباتك محفوظة، أعد المحاولة.';

  @override
  String get regFailInvalid => 'تم رفض بعض البيانات. تحقق منها.';

  @override
  String get regFailForbidden => 'هذا الحساب غير مسموح له بذلك.';

  @override
  String get regFailGeneric => 'تعذّر الحفظ. حاول مجددًا.';

  @override
  String get regFailNotConfigured => 'الخدمة غير متاحة حاليًا.';

  @override
  String get proCompleteCta => 'أكمل ملفي';

  @override
  String get proEditCta => 'تعديل ملفي المهني';

  @override
  String get proStatusDraft => 'الملف غير منشور';

  @override
  String get proStatusPublished => 'الملف منشور';

  @override
  String get dashTitle => 'فضائي المهني';

  @override
  String get dashAvailability => 'التوفر';

  @override
  String get dashActivity => 'النشاط';

  @override
  String get dashActivityNote =>
      'أرقام مجهولة بتأخير ساعة: لا ترى من اطّلع على ملفك أو حفظه.';

  @override
  String get dashViews30d => 'أرقام التواصل المعروضة (30 يومًا)';

  @override
  String get dashViewsTotal => 'أرقام التواصل المعروضة (المجموع)';

  @override
  String get dashFavorites => 'محفوظ في المفضلة';

  @override
  String get dashActivityFailed => 'النشاط غير متاح حاليًا.';

  @override
  String get dashViewPublic => 'عرض ملفي العام';

  @override
  String get dashSaveFailed => 'تعذّر التغيير. حاول مجددًا.';

  @override
  String get dashRefreshFailed =>
      'تعذّر التحديث. قد تكون البيانات المعروضة قديمة.';

  @override
  String get portfolioTitle => 'صور أعمالي';

  @override
  String get portfolioSection => 'صور الأعمال';

  @override
  String get portfolioAdd => 'إضافة صورة';

  @override
  String portfolioCount(int count, int max) {
    return '$count من $max صور';
  }

  @override
  String get portfolioHint =>
      'صور من أعمالك. يتم تصغيرها تلقائيًا وتُحذف منها معلوماتها (الموقع، الجهاز).';

  @override
  String get portfolioEmpty => 'لا توجد صور بعد.';

  @override
  String get portfolioRemove => 'حذف الصورة';

  @override
  String get portfolioRemoveTitle => 'حذف هذه الصورة؟';

  @override
  String get portfolioRemoveBody => 'لن تظهر بعد الآن في ملفك.';

  @override
  String portfolioPhotoOf(int index, int total) {
    return 'الصورة $index من $total';
  }

  @override
  String get portfolioFailTooLarge =>
      'هذه الصورة ثقيلة جدًا حتى بعد التصغير. اختر غيرها.';

  @override
  String get portfolioFailNotImage =>
      'هذا الملف ليس صورة قابلة للقراءة (JPEG أو PNG أو WebP).';

  @override
  String get portfolioFailLimit => 'وصلت إلى الحد الأقصى: 12 صورة.';

  @override
  String get portfolioFailNetwork => 'لا يوجد اتصال. حاول مجددًا.';

  @override
  String get portfolioFailGeneric => 'تعذّر تعديل صورك. حاول مجددًا.';

  @override
  String get portfolioFailNotConfigured => 'الخدمة غير متاحة حاليًا.';

  @override
  String get portfolioPreparing => 'جارٍ تجهيز الصورة…';

  @override
  String get close => 'إغلاق';

  @override
  String get reqNew => 'طلب جديد';

  @override
  String get reqMineTitle => 'طلباتي';

  @override
  String get reqEmptyCta => 'اطلب عرض سعر';

  @override
  String get reqStatusOpen => 'مفتوح';

  @override
  String get reqStatusAwarded => 'تمّ إسناده';

  @override
  String get reqStatusCancelled => 'ملغى';

  @override
  String get reqStatusExpired => 'منتهي';

  @override
  String reqOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عرض',
      many: '$count عرضًا',
      few: '$count عروض',
      two: 'عرضان',
      one: 'عرض واحد',
      zero: 'لا توجد عروض',
    );
    return '$_temp0';
  }

  @override
  String get reqFormTitle => 'العنوان';

  @override
  String get reqFormTitleHint => 'مثال: تسرب تحت المغسلة';

  @override
  String get reqFormDescription => 'صف المشكلة';

  @override
  String get reqFormDescriptionHelper => '10 أحرف على الأقل.';

  @override
  String get reqFormCategory => 'نوع الخدمة';

  @override
  String get reqFormBudget => 'ميزانية تقريبية بالدينار (اختياري)';

  @override
  String get reqFormNeededBy => 'لأي موعد؟ (اختياري)';

  @override
  String get reqFormNeededByNone => 'بدون موعد';

  @override
  String get reqFormPickDate => 'اختر تاريخًا';

  @override
  String get reqFormPhotos => 'صور (اختياري)';

  @override
  String get reqFormAddPhoto => 'إضافة صورة';

  @override
  String reqFormPhotosCount(int count, int max) {
    return '$count من $max صور';
  }

  @override
  String reqFormRemovePhoto(int index) {
    return 'إزالة الصورة $index';
  }

  @override
  String get reqFormSubmit => 'إرسال الطلب';

  @override
  String get reqFormPrivacy =>
      'سيرى الحرفيون طلبك وصورك، ولن يروا اسمك ولا رقمك أبدًا.';

  @override
  String get reqErrTitle => 'بين 3 و120 حرفًا.';

  @override
  String get reqErrDescription => 'بين 10 و2000 حرف.';

  @override
  String get reqErrCategory => 'اختر نوع الخدمة.';

  @override
  String get reqErrGovernorate => 'اختر ولاية.';

  @override
  String get reqErrBudget => 'مبلغ غير صالح (من 0 إلى 1,000,000).';

  @override
  String get reqSent => 'تم إرسال الطلب.';

  @override
  String get reqSentPhotosFailed =>
      'تم إرسال الطلب، لكن تعذّر إضافة بعض الصور.';

  @override
  String get reqFailNetwork => 'لا يوجد اتصال. بياناتك محفوظة، أعد المحاولة.';

  @override
  String get reqFailRateLimited => 'طلبات كثيرة في وقت قصير. حاول بعد ساعة.';

  @override
  String get reqFailLimit =>
      'لديك 10 طلبات مفتوحة بالفعل. ألغِ طلبًا قبل إنشاء آخر.';

  @override
  String get reqFailInvalid => 'تم رفض بعض البيانات. تحقق منها.';

  @override
  String get reqFailNotOpen => 'هذا الطلب لم يعد مفتوحًا.';

  @override
  String get reqFailGeneric => 'تعذّر إرسال الطلب. حاول مجددًا.';

  @override
  String get reqFailNotConfigured => 'الخدمة غير متاحة حاليًا.';

  @override
  String get reqDetailTitle => 'الطلب';

  @override
  String get reqNotFound => 'الطلب غير موجود.';

  @override
  String reqExpiresOn(String date) {
    return 'ينتهي في $date';
  }

  @override
  String reqNeededBy(String date) {
    return 'مطلوب قبل $date';
  }

  @override
  String reqBudget(String amount) {
    return 'ميزانية تقريبية: $amount';
  }

  @override
  String get reqCancel => 'إلغاء الطلب';

  @override
  String get reqCancelTitle => 'إلغاء هذا الطلب؟';

  @override
  String get reqCancelBody => 'سيتم رفض العروض المستلمة. لا يمكن التراجع.';

  @override
  String get reqCancelKeep => 'الإبقاء على الطلب';

  @override
  String get reqCancelled => 'تم إلغاء الطلب.';

  @override
  String reqPhotoLabel(int index, int total) {
    return 'الصورة $index من $total';
  }

  @override
  String get reqPhotosFailed => 'تعذّر تحميل الصور.';

  @override
  String get proInboxTitle => 'الطلبات المفتوحة';

  @override
  String get proInboxMyArea => 'في ولايتي';

  @override
  String get proInboxAllCategories => 'كل المهن';

  @override
  String get proInboxEmptyTitle => 'لا توجد طلبات حاليًا';

  @override
  String get proInboxEmptyBody => 'ستظهر هنا طلبات الزبائن الجديدة.';

  @override
  String get proInboxNeedsPublished => 'انشر ملفك لرؤية الطلبات وإرسال العروض.';

  @override
  String get offerStatusPending => 'قيد الانتظار';

  @override
  String get offerStatusAccepted => 'مقبول';

  @override
  String get offerStatusDeclined => 'مرفوض';

  @override
  String get offerStatusWithdrawn => 'مسحوب';

  @override
  String offerYours(String status) {
    return 'عرضك: $status';
  }

  @override
  String get offersTitle => 'عروضي';

  @override
  String get offersEmpty => 'لم ترسل أي عرض بعد.';

  @override
  String get jobsTitle => 'أعمالي';

  @override
  String get jobsEmpty => 'لا توجد أعمال بعد. يبدأ العمل عندما يقبل زبون عرضك.';

  @override
  String get jobScheduled => 'مجدول';

  @override
  String get jobInProgress => 'قيد التنفيذ';

  @override
  String get jobPendingConfirmation => 'بانتظار تأكيد الزبون';

  @override
  String get jobCompleted => 'مكتمل';

  @override
  String get jobCancelled => 'ملغى';

  @override
  String get jobStart => 'ابدأ';

  @override
  String get jobDone => 'تحديد كمنجز';

  @override
  String get jobCancel => 'إلغاء العمل';

  @override
  String get jobCancelTitle => 'إلغاء هذا العمل؟';

  @override
  String get jobCancelBody => 'سيتم إعلام الزبون. لا يمكن التراجع.';

  @override
  String get jobKeep => 'الإبقاء على العمل';

  @override
  String jobAgreedPrice(String amount) {
    return 'السعر المتفق عليه: $amount';
  }

  @override
  String get offerTitle => 'عرضك';

  @override
  String get offerPrice => 'السعر بالدينار';

  @override
  String get offerMessage => 'رسالة للزبون (اختياري)';

  @override
  String get offerDays => 'المدة المقدّرة بالأيام (اختياري)';

  @override
  String get offerSend => 'إرسال العرض';

  @override
  String get offerUpdate => 'تحديث العرض';

  @override
  String get offerWithdraw => 'سحب عرضي';

  @override
  String get offerSent => 'تم إرسال العرض.';

  @override
  String get offerWithdrawn => 'تم سحب العرض.';

  @override
  String get offerErrPrice => 'بين 1 و1,000,000 دينار.';

  @override
  String get offerErrMessage => '1000 حرف كحد أقصى.';

  @override
  String get offerErrDays => 'بين 1 و365 يومًا.';

  @override
  String get offerDeclinedNote => 'لم يختر الزبون عرضك.';

  @override
  String get offerAcceptedNote => 'تم قبول عرضك: تابع العمل في «أعمالي».';

  @override
  String offerOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عرض مستلم',
      many: '$count عرضًا مستلمًا',
      few: '$count عروض مستلمة',
      two: 'عرضان مستلمان',
      one: 'عرض واحد مستلم',
      zero: 'لا توجد عروض أخرى حاليًا',
    );
    return '$_temp0';
  }

  @override
  String get reqFailOwn => 'لا يمكنك الرد على طلبك الخاص.';

  @override
  String get reqFailOfferClosed => 'لم يعد بالإمكان تعديل هذا العرض.';

  @override
  String get reqFailTransition => 'هذه الخطوة لم تعد ممكنة.';

  @override
  String get reqFailForbidden => 'انشر ملفك المهني أولًا.';

  @override
  String get offerFailLimit =>
      'لديك 50 عرضًا قيد الانتظار. اسحب عرضًا قبل إرسال آخر.';

  @override
  String get offersReceived => 'العروض المستلمة';

  @override
  String get offersNoneYet =>
      'لا توجد عروض بعد. يمكن للحرفيين الرد إلى أن ينتهي الطلب.';

  @override
  String get sortOffersBy => 'ترتيب العروض';

  @override
  String get sortOffersPrice => 'السعر';

  @override
  String get sortOffersRating => 'التقييم';

  @override
  String get sortOffersDelay => 'المدة';

  @override
  String get offerLowest => 'أقل سعر';

  @override
  String offerDelay(int count) {
    return 'المدة: $count يوم';
  }

  @override
  String get offerAccept => 'قبول';

  @override
  String get offerDecline => 'رفض';

  @override
  String get offerAcceptTitle => 'قبول هذا العرض؟';

  @override
  String offerAcceptBody(String name, String price) {
    return 'سينجز $name العمل مقابل $price. سيتم رفض العروض الأخرى وإسناد الطلب.';
  }

  @override
  String get offerDeclineTitle => 'رفض هذا العرض؟';

  @override
  String get offerDeclineBody => 'لن يتمكن الحرفي من تقديمه مجددًا.';

  @override
  String get offerAcceptedMsg => 'تم قبول العرض.';

  @override
  String get offerDeclinedMsg => 'تم رفض العرض.';

  @override
  String get offerProUnknown => 'حرفي';

  @override
  String get bookingTitle => 'العمل';

  @override
  String get bookingConfirm => 'تأكيد أن العمل انتهى';

  @override
  String get bookingConfirmed => 'شكرًا، اكتمل العمل.';

  @override
  String get bookingCancelled => 'تم إلغاء العمل.';

  @override
  String get bookingCancelTitle => 'إلغاء هذا العمل؟';

  @override
  String get bookingCancelBody => 'سيتم إعلام الحرفي. لا يمكن التراجع.';

  @override
  String get bookingWaitingForYou =>
      'يقول الحرفي إنه أنهى العمل. هل أُنجز كما يجب؟';

  @override
  String get chatTitleClient => 'الزبون';

  @override
  String get chatInputHint => 'اكتب رسالة…';

  @override
  String get chatSend => 'إرسال';

  @override
  String get chatAddImage => 'إرفاق صورة';

  @override
  String get chatEmpty => 'لا توجد رسائل. ابدأ بالتحية!';

  @override
  String get chatReadOnly =>
      'انتهت هذه المحادثة: يمكنك قراءتها لكن لا يمكنك الكتابة.';

  @override
  String get chatImageSent => 'تم إرسال صورة';

  @override
  String get chatYouSent => 'أنت';

  @override
  String get chatThem => 'الطرف الآخر';

  @override
  String chatUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة غير مقروءة',
      few: '$count رسائل غير مقروءة',
      two: 'رسالتان غير مقروءتين',
      one: 'رسالة غير مقروءة',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get chatSendFailed => 'لم تُرسل الرسالة. حاول مجددًا.';

  @override
  String get chatRateLimited => 'تكتب بسرعة كبيرة. انتظر لحظة.';

  @override
  String get chatClosed => 'انتهت هذه المحادثة.';

  @override
  String get chatOpenFailed => 'تعذّر فتح المحادثة. حاول مجددًا.';

  @override
  String get chatLiveFailed => 'توقف التحديث المباشر. اسحب للتحديث.';

  @override
  String get chatPhotoFailed => 'لم تُرسل الصورة. حاول مجددًا.';

  @override
  String get chatAskPro => 'اطرح سؤالًا';

  @override
  String get chatWriteCustomer => 'راسل الزبون';

  @override
  String get chatPhoto => 'صورة';

  @override
  String get notifTitle => 'الإشعارات';

  @override
  String get notifIntro =>
      'اختر ما تريد أن يتم إشعارك به. لا تحتوي الإشعارات أبدًا على نص رسائلك.';

  @override
  String get notifOffers => 'العروض المستلمة والمقبولة';

  @override
  String get notifMessages => 'الرسائل الجديدة';

  @override
  String get notifJobs => 'تقدّم الأعمال';

  @override
  String get notifNoPush =>
      'الإشعارات غير متاحة على هذا الجهاز بعد. اختياراتك محفوظة لوقت لاحق.';

  @override
  String get notifSaveFailed => 'تعذّر حفظ هذا الاختيار. حاول مجددًا.';

  @override
  String get reviewsTitle => 'التقييمات';

  @override
  String get reviewsEmpty => 'لا توجد تقييمات بعد.';

  @override
  String get reviewsMore => 'عرض المزيد من التقييمات';

  @override
  String get reviewsLoadFailed => 'تعذّر تحميل التقييمات.';

  @override
  String get reviewCta => 'اترك تقييمًا';

  @override
  String get reviewCtaPro => 'قيّم الزبون';

  @override
  String get reviewSheetTitle => 'تقييمك';

  @override
  String get reviewSheetTitlePro => 'تقييمك للزبون';

  @override
  String get reviewRatingHint => 'المس نجمة';

  @override
  String reviewStar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نجمة',
      few: '$count نجوم',
      two: 'نجمتان',
      one: 'نجمة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get reviewComment => 'تعليق (اختياري)';

  @override
  String get reviewSubmit => 'نشر تقييمي';

  @override
  String get reviewPublicNote => 'سيكون تقييمك علنيًا دون اسمك.';

  @override
  String get reviewPrivateNote => 'هذا التقييم لا يراه إلا فريق خدمة.';

  @override
  String get reviewErrRating => 'اختر تقييمًا من 1 إلى 5.';

  @override
  String get reviewThanks => 'شكرًا على تقييمك.';

  @override
  String get reviewDone => 'تم التقييم';

  @override
  String get reviewFailAlready => 'لقد قيّمت هذا العمل من قبل.';

  @override
  String get reviewFailNotCompleted => 'يجب أن يكتمل العمل لترك تقييم.';

  @override
  String get reviewFailGeneric => 'تعذّر إرسال التقييم. حاول مجددًا.';

  @override
  String get reviewAuthorAnon => 'زبون';

  @override
  String get reviewFailLimit =>
      'لقد قدّمت عددًا كبيرًا من التقييمات لهذا الحرفي.';

  @override
  String get reportAction => 'إبلاغ';

  @override
  String get reportTitle => 'الإبلاغ عن مشكلة';

  @override
  String get reportHint =>
      'يراجع فريقنا كل بلاغ. لن يعرف الشخص المبلّغ عنه أنك أنت من أبلغ.';

  @override
  String get reportReasonSpam => 'إعلانات أو رسائل مزعجة';

  @override
  String get reportReasonFake => 'حساب أو تقييم مزيّف';

  @override
  String get reportReasonAbuse => 'تحرّش أو إساءة';

  @override
  String get reportReasonScam => 'احتيال أو طلب مال مشبوه';

  @override
  String get reportReasonInappropriate => 'محتوى غير لائق';

  @override
  String get reportReasonOther => 'أخرى';

  @override
  String get reportDetailsLabel => 'تفاصيل (اختياري)';

  @override
  String get reportSend => 'إرسال البلاغ';

  @override
  String get reportSent => 'شكرًا لك. تم إرسال بلاغك.';

  @override
  String get reportFailAlready => 'لقد أبلغت عن هذا من قبل. نحن نراجعه.';

  @override
  String get reportFailRate => 'بلاغات كثيرة اليوم. حاول مجددًا غدًا.';

  @override
  String get reportFailGone => 'هذا المحتوى لم يعد متاحًا.';

  @override
  String get reportFailGeneric =>
      'تعذّر إرسال البلاغ. تحقق من اتصالك وحاول مجددًا.';

  @override
  String get verifTitle => 'توثيق الحساب';

  @override
  String get verifCta => 'وثّق حسابي';

  @override
  String get verifIntro =>
      'أرسل صورة لبطاقة هويتك أو سجلّك التجاري. بعد المراجعة تظهر شارة على ملفك.';

  @override
  String get verifPrivacy =>
      'مستنداتك خاصة: أنت وفريق التوثيق فقط من يراها، وتُحذف فور اتخاذ القرار.';

  @override
  String get verifStatusNone => 'لم يتم التوثيق بعد';

  @override
  String get verifStatusPending => 'قيد المراجعة';

  @override
  String get verifStatusApproved => 'الحساب موثّق';

  @override
  String get verifStatusRejected => 'تم رفض الطلب';

  @override
  String get verifStatusCancelled => 'تم إلغاء الطلب';

  @override
  String verifRejectReason(Object reason) {
    return 'السبب: $reason';
  }

  @override
  String get verifPendingBody => 'نراجع مستنداتك. سيتم إعلامك بالقرار.';

  @override
  String get verifAdd => 'إضافة صورة';

  @override
  String verifCount(Object count, Object max) {
    return '$count من $max مستندات';
  }

  @override
  String verifRemove(Object index) {
    return 'إزالة المستند $index';
  }

  @override
  String get verifSubmit => 'إرسال للمراجعة';

  @override
  String get verifCancel => 'إلغاء الطلب';

  @override
  String get verifSent => 'تم إرسال المستندات. سنردّ عليك قريبًا.';

  @override
  String get verifCancelled => 'تم إلغاء الطلب وحذف مستنداتك.';

  @override
  String get verifFailPending => 'يوجد طلب قيد المراجعة بالفعل.';

  @override
  String get verifFailVerified => 'حسابك موثّق بالفعل.';

  @override
  String get verifFailLimit => 'طلبات كثيرة خلال آخر 30 يومًا. حاول لاحقًا.';

  @override
  String get verifFailGeneric => 'فشل الإرسال. تحقق من اتصالك وحاول مجددًا.';

  @override
  String get verifFailImage =>
      'هذا الملف ليس صورة قابلة للقراءة (JPEG أو PNG أو WebP).';
}
