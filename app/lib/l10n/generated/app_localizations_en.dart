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

  @override
  String get verified => 'Verified';

  @override
  String get ratingNone => 'No reviews yet';

  @override
  String ratingSummary(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
    );
    return 'Rated $value out of 5, $_temp0';
  }

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get errorBody => 'Check your connection and try again.';

  @override
  String get retry => 'Try again';

  @override
  String get loading => 'Loading…';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get onbTitle1 => 'Find trusted professionals';

  @override
  String get onbBody1 =>
      'Plumbers, electricians, mechanics and more: discover craftspeople near you, with their work and reviews.';

  @override
  String get onbTitle2 => 'Compare and request quotes';

  @override
  String get onbBody2 =>
      'Describe your need once, receive offers from several professionals and pick the best one.';

  @override
  String get onbTitle3 => 'Contact them directly';

  @override
  String get onbBody3 =>
      'Call, message on WhatsApp or chat in the app. Payment is arranged directly with the professional.';

  @override
  String get languageStepBody => 'You can change it any time in Profile.';

  @override
  String get next => 'Next';

  @override
  String get start => 'Get started';

  @override
  String get skip => 'Skip';

  @override
  String pageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get back => 'Previous';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get signOut => 'Sign out';

  @override
  String get emailLabel => 'Email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get noAccountYet => 'No account yet?';

  @override
  String get haveAccount => 'Already have an account?';

  @override
  String get signInTitle => 'Welcome back';

  @override
  String get signInSubtitle =>
      'Sign in to request quotes and follow your requests.';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get registerSubtitle => 'It only takes a few seconds.';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotSubtitle =>
      'Enter your email and we\'ll send you a link to choose a new password.';

  @override
  String get resetSentTitle => 'Check your email';

  @override
  String resetSentBody(String email) {
    return 'If an account exists for $email, we have just sent a reset link.';
  }

  @override
  String get confirmEmailTitle => 'Confirm your email address';

  @override
  String confirmEmailBody(String email) {
    return 'We sent a confirmation link to $email. Open it to activate your account.';
  }

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get errEmailRequired => 'Enter your email address.';

  @override
  String get errEmailInvalid => 'Invalid email address.';

  @override
  String get errPasswordRequired => 'Enter your password.';

  @override
  String get errPasswordShort => 'At least 8 characters.';

  @override
  String get errPasswordLong => 'Password too long.';

  @override
  String get errNameRequired => 'Enter your name.';

  @override
  String get failInvalidCredentials => 'Incorrect email or password.';

  @override
  String get failEmailNotConfirmed =>
      'Please confirm your email address first (check your inbox).';

  @override
  String get failWeakPassword =>
      'Password too weak. Choose a longer, less common one.';

  @override
  String get failSignUpDisabled => 'Sign-ups are closed at the moment.';

  @override
  String get failRateLimited =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get failNetwork => 'Can\'t connect. Check your network.';

  @override
  String get failNotConfigured =>
      'Accounts are not available in this version of the app.';

  @override
  String get failUnknown => 'Something went wrong. Please try again.';

  @override
  String get signedOutProfileTitle => 'Sign in or create an account';

  @override
  String get signedOutProfileBody =>
      'To request quotes and contact professionals.';

  @override
  String get requestsSignedOutTitle => 'Sign in to see your requests';

  @override
  String get requestsSignedOutBody =>
      'Your quote requests and the offers you receive will appear here.';

  @override
  String get messagesSignedOutTitle => 'Sign in to chat';

  @override
  String get messagesSignedOutBody =>
      'Your conversations with professionals will appear here.';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get newPasswordTitle => 'New password';

  @override
  String get newPasswordSubtitle =>
      'Choose a password you do not use anywhere else.';

  @override
  String get savePassword => 'Save password';

  @override
  String get passwordUpdated => 'Password updated.';

  @override
  String get linkExpiredTitle => 'Link expired or invalid';

  @override
  String get linkExpiredBody =>
      'Request a new reset link from the sign-in screen.';

  @override
  String get accountTypeTitle => 'I want to…';

  @override
  String get accountCustomerTitle => 'Find a professional';

  @override
  String get accountCustomerBody => 'Request quotes and contact craftspeople.';

  @override
  String get accountProfessionalTitle => 'Offer my services';

  @override
  String get accountProfessionalBody =>
      'Create a professional profile and receive requests.';

  @override
  String get becomeProfessionalTitle => 'Offer your services';

  @override
  String get becomeProfessionalBody =>
      'Create your professional profile to receive customer requests.';

  @override
  String get becomeProfessionalCta => 'Become a professional';

  @override
  String get professionalBadge => 'Professional';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get save => 'Save';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get phoneHelper => 'Only visible to you.';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get failProfileLoad => 'Couldn\'t load your profile.';

  @override
  String get failProfileInvalid => 'Some details are invalid.';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get orSeparator => 'or';

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'Your profile, your details and the data linked to them will be permanently deleted. This cannot be undone.';

  @override
  String get deleteConfirmWord => 'DELETE';

  @override
  String deleteTypeToConfirm(String word) {
    return 'Type $word to confirm';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get accountDeleted => 'Your account has been deleted.';

  @override
  String get homeGreeting => 'Hello';

  @override
  String homeGreetingNamed(String name) {
    return 'Hello, $name';
  }

  @override
  String get homeSubtitle => 'What service do you need?';

  @override
  String get searchHint => 'Search a trade, a name, a city…';

  @override
  String get placeAll => 'All of Tunisia';

  @override
  String get placeChoose => 'Choose an area';

  @override
  String get placeGovernorate => 'Governorate';

  @override
  String get placeWholeGovernorate => 'Whole governorate';

  @override
  String get sectionCategories => 'Categories';

  @override
  String get sectionTopRated => 'Top rated';

  @override
  String get sectionInYourArea => 'In your area';

  @override
  String get sectionInYourAreaPrompt =>
      'Choose an area to see professionals around you.';

  @override
  String get sectionRecent => 'Recently viewed';

  @override
  String get seeAll => 'See all';

  @override
  String get noProfessionalsTitle => 'No professionals yet';

  @override
  String get noProfessionalsBody =>
      'They will appear here as soon as they join Khidma.';

  @override
  String get noProfessionalsInArea => 'No professionals in this area yet.';

  @override
  String get demoBannerTitle => 'Demo data';

  @override
  String get demoBannerBody =>
      'The professionals, ratings and badges shown are made up.';

  @override
  String get availabilityAvailable => 'Available';

  @override
  String get availabilityBusy => 'Busy';

  @override
  String get availabilityOffline => 'Offline';

  @override
  String yearsExperience(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years of experience',
      one: '1 year of experience',
    );
    return '$_temp0';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get failLoadProfessionals => 'Couldn\'t load professionals.';

  @override
  String get failForbidden =>
      'Access to the data was refused. Try again later.';

  @override
  String get professionalNotFoundTitle => 'Profile not found';

  @override
  String get professionalNotFoundBody =>
      'This professional is no longer available.';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchNoResultsTitle => 'No results';

  @override
  String get searchNoResultsBody => 'Try another word or area.';

  @override
  String get searchStartTitle => 'What are you looking for?';

  @override
  String get searchStartBody => 'Type a trade, a name or a city.';

  @override
  String get aboutLabel => 'About';

  @override
  String get inCategory => 'Category';

  @override
  String get filtersTitle => 'Filters';

  @override
  String get filtersAction => 'Filter';

  @override
  String get filterCategory => 'Category';

  @override
  String get filterAllCategories => 'All';

  @override
  String get filterMinRating => 'Minimum rating';

  @override
  String get filterRatingAny => 'Any';

  @override
  String filterRatingAtLeast(String value) {
    return '$value+';
  }

  @override
  String get filterAvailableOnly => 'Available only';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortRating => 'Top rated';

  @override
  String get sortReviews => 'Most reviewed';

  @override
  String get filtersApply => 'Apply';

  @override
  String get filtersReset => 'Reset';

  @override
  String get loadMore => 'Show more';

  @override
  String filtersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Filters, $count active',
      one: 'Filters, 1 active',
      zero: 'Filters',
    );
    return '$_temp0';
  }
}
