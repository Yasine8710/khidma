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

  @override
  String get contactTitle => 'Contact';

  @override
  String get contactShow => 'Show contact';

  @override
  String get contactSignIn => 'Sign in to see the contact';

  @override
  String get contactCall => 'Call';

  @override
  String get contactWhatsApp => 'WhatsApp';

  @override
  String get contactWhy =>
      'The number is shown to signed-in members, to protect professionals from bulk spam.';

  @override
  String get contactDemo => 'Contact is not available with demo data.';

  @override
  String get contactRateLimited =>
      'Too many numbers viewed in a short time. Try again in an hour.';

  @override
  String get contactNotFound => 'This professional is no longer available.';

  @override
  String get contactFailed => 'Couldn’t load the contact. Try again.';

  @override
  String get contactLaunchFailed => 'Couldn’t open the app.';

  @override
  String get servicesTitle => 'Services';

  @override
  String get areasTitle => 'Areas served';

  @override
  String areaWhole(String place) {
    return '$place (whole governorate)';
  }

  @override
  String get favoritesTitle => 'My favorites';

  @override
  String get favoriteAdd => 'Add to favorites';

  @override
  String get favoriteRemove => 'Remove from favorites';

  @override
  String get favoritesEmptyTitle => 'No favorites yet';

  @override
  String get favoritesEmptyBody =>
      'Tap the heart on a profile to find it here.';

  @override
  String get favoritesSignInTitle => 'Keep your favorites';

  @override
  String get favoritesSignInBody =>
      'Sign in to save professionals and find them on all your devices.';

  @override
  String get favoriteLimit => 'You have reached the limit of 200 favorites.';

  @override
  String get favoriteFailed => 'Couldn’t update your favorites. Try again.';

  @override
  String favoriteAddNamed(String name) {
    return 'Add $name to favorites';
  }

  @override
  String favoriteRemoveNamed(String name) {
    return 'Remove $name from favorites';
  }

  @override
  String get nearMe => 'Near me';

  @override
  String get sortNearest => 'Nearest';

  @override
  String get filterRadius => 'Maximum distance';

  @override
  String get filterRadiusAny => 'Any';

  @override
  String get locationDenied => 'Allow location to see professionals near you.';

  @override
  String get locationDeniedForever =>
      'Location is blocked. Allow it in Settings.';

  @override
  String get locationServiceOff => 'Location is turned off on this device.';

  @override
  String get locationUnavailable => 'Couldn’t find your position. Try again.';

  @override
  String get openSettings => 'Settings';

  @override
  String get showMap => 'Show map';

  @override
  String get showList => 'Show list';

  @override
  String get mapNothingTitle => 'Nothing to show on the map';

  @override
  String get mapNothingBody =>
      'None of these professionals has a known position.';

  @override
  String get regTitle => 'Professional profile';

  @override
  String regStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get regNext => 'Continue';

  @override
  String get regBack => 'Back';

  @override
  String get regStepBusiness => 'Your business';

  @override
  String get regStepLocation => 'Where do you work?';

  @override
  String get regStepAreas => 'Areas you serve';

  @override
  String get regStepServices => 'Other services';

  @override
  String get regStepContact => 'Contact';

  @override
  String get regStepReview => 'Review and publish';

  @override
  String get regBusinessName => 'Display name (business or person)';

  @override
  String get regYears => 'Years of experience (optional)';

  @override
  String get regCategory => 'Main trade';

  @override
  String get regDescription => 'Describe your services';

  @override
  String get regDescriptionHelper => 'At least 20 characters.';

  @override
  String get regGovernorate => 'Governorate';

  @override
  String get regCity => 'City (optional)';

  @override
  String get regAreasBody =>
      'Choose the governorates you travel to, besides your own.';

  @override
  String get regServicesBody => 'Add other services you offer.';

  @override
  String get regPhone => 'Contact phone';

  @override
  String get regPhoneHelper =>
      'Only signed-in members see it, and only when they ask.';

  @override
  String get regPhotoLater => 'Profile photos are coming soon.';

  @override
  String get regErrName => 'Between 2 and 120 characters.';

  @override
  String get regErrDescription => 'Between 20 and 2000 characters.';

  @override
  String get regErrCategory => 'Choose a trade.';

  @override
  String get regErrGovernorate => 'Choose a governorate.';

  @override
  String get regErrYears => 'Between 0 and 60.';

  @override
  String get regErrPhone => 'Invalid Tunisian number (8 digits).';

  @override
  String get regReviewBody => 'This is what customers will see.';

  @override
  String get regPublish => 'Publish my profile';

  @override
  String get regUnpublish => 'Remove from listings';

  @override
  String get regSaveDraft => 'Save and leave';

  @override
  String get regPublished => 'Your profile is published.';

  @override
  String get regDraft => 'Draft: not visible to customers.';

  @override
  String regMissing(String items) {
    return 'To publish, you still need: $items.';
  }

  @override
  String get gapName => 'the name';

  @override
  String get gapCategory => 'the trade';

  @override
  String get gapDescription => 'the description';

  @override
  String get gapLocation => 'the governorate';

  @override
  String get gapPhone => 'the phone';

  @override
  String get regFailNetwork =>
      'No connection. Your answers are kept, try again.';

  @override
  String get regFailInvalid => 'Some details were refused. Please check them.';

  @override
  String get regFailForbidden => 'This account is not allowed to do that.';

  @override
  String get regFailGeneric => 'Couldn’t save. Try again.';

  @override
  String get regFailNotConfigured => 'The service is not available right now.';

  @override
  String get proCompleteCta => 'Complete my profile';

  @override
  String get proEditCta => 'Edit my professional profile';

  @override
  String get proStatusDraft => 'Profile not published';

  @override
  String get proStatusPublished => 'Profile published';

  @override
  String get dashTitle => 'My pro space';

  @override
  String get dashAvailability => 'Availability';

  @override
  String get dashActivity => 'Activity';

  @override
  String get dashActivityNote =>
      'Anonymous counts, one hour behind: you cannot see who viewed or saved your profile.';

  @override
  String get dashViews30d => 'Contacts viewed (30 days)';

  @override
  String get dashViewsTotal => 'Contacts viewed (total)';

  @override
  String get dashFavorites => 'Saved as favorite';

  @override
  String get dashActivityFailed => 'Activity is unavailable right now.';

  @override
  String get dashViewPublic => 'View my public profile';

  @override
  String get dashSaveFailed => 'Couldn’t change that. Try again.';

  @override
  String get dashRefreshFailed =>
      'Couldn’t refresh. What you see may be out of date.';

  @override
  String get portfolioTitle => 'My work photos';

  @override
  String get portfolioSection => 'Work photos';

  @override
  String get portfolioAdd => 'Add a photo';

  @override
  String portfolioCount(int count, int max) {
    return '$count of $max photos';
  }

  @override
  String get portfolioHint =>
      'Photos of your work. They are shrunk automatically and their information (location, device) is removed.';

  @override
  String get portfolioEmpty => 'No photos yet.';

  @override
  String get portfolioRemove => 'Delete photo';

  @override
  String get portfolioRemoveTitle => 'Delete this photo?';

  @override
  String get portfolioRemoveBody => 'It will no longer show on your profile.';

  @override
  String portfolioPhotoOf(int index, int total) {
    return 'Photo $index of $total';
  }

  @override
  String get portfolioFailTooLarge =>
      'This photo is too heavy, even shrunk. Choose another.';

  @override
  String get portfolioFailNotImage =>
      'This file is not a readable photo (JPEG, PNG or WebP).';

  @override
  String get portfolioFailLimit => 'You have reached the limit of 12 photos.';

  @override
  String get portfolioFailNetwork => 'No connection. Try again.';

  @override
  String get portfolioFailGeneric => 'Couldn’t change your photos. Try again.';

  @override
  String get portfolioFailNotConfigured =>
      'The service is not available right now.';

  @override
  String get portfolioPreparing => 'Preparing the photo…';

  @override
  String get close => 'Close';

  @override
  String get reqNew => 'New request';

  @override
  String get reqMineTitle => 'My requests';

  @override
  String get reqEmptyCta => 'Ask for a quote';

  @override
  String get reqStatusOpen => 'Open';

  @override
  String get reqStatusAwarded => 'Awarded';

  @override
  String get reqStatusCancelled => 'Cancelled';

  @override
  String get reqStatusExpired => 'Expired';

  @override
  String reqOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offers',
      one: '1 offer',
      zero: 'No offers',
    );
    return '$_temp0';
  }

  @override
  String get reqFormTitle => 'Title';

  @override
  String get reqFormTitleHint => 'E.g. Leak under the sink';

  @override
  String get reqFormDescription => 'Describe the problem';

  @override
  String get reqFormDescriptionHelper => 'At least 10 characters.';

  @override
  String get reqFormCategory => 'Type of service';

  @override
  String get reqFormBudget => 'Rough budget in TND (optional)';

  @override
  String get reqFormNeededBy => 'By when? (optional)';

  @override
  String get reqFormNeededByNone => 'No date';

  @override
  String get reqFormPickDate => 'Pick a date';

  @override
  String get reqFormPhotos => 'Photos (optional)';

  @override
  String get reqFormAddPhoto => 'Add a photo';

  @override
  String reqFormPhotosCount(int count, int max) {
    return '$count of $max photos';
  }

  @override
  String reqFormRemovePhoto(int index) {
    return 'Remove photo $index';
  }

  @override
  String get reqFormSubmit => 'Send request';

  @override
  String get reqFormPrivacy =>
      'Professionals will see your request and photos, never your name or number.';

  @override
  String get reqErrTitle => 'Between 3 and 120 characters.';

  @override
  String get reqErrDescription => 'Between 10 and 2000 characters.';

  @override
  String get reqErrCategory => 'Choose a type of service.';

  @override
  String get reqErrGovernorate => 'Choose a governorate.';

  @override
  String get reqErrBudget => 'Invalid amount (0 to 1,000,000).';

  @override
  String get reqSent => 'Request sent.';

  @override
  String get reqSentPhotosFailed =>
      'Request sent, but some photos could not be added.';

  @override
  String get reqFailNetwork =>
      'No connection. Your answers are kept, try again.';

  @override
  String get reqFailRateLimited =>
      'Too many requests in a short time. Try again in an hour.';

  @override
  String get reqFailLimit =>
      'You already have 10 open requests. Cancel one before creating another.';

  @override
  String get reqFailInvalid => 'Some details were refused. Please check them.';

  @override
  String get reqFailNotOpen => 'This request is no longer open.';

  @override
  String get reqFailGeneric => 'Couldn’t send the request. Try again.';

  @override
  String get reqFailNotConfigured => 'The service is not available right now.';

  @override
  String get reqDetailTitle => 'Request';

  @override
  String get reqNotFound => 'Request not found.';

  @override
  String reqExpiresOn(String date) {
    return 'Expires on $date';
  }

  @override
  String reqNeededBy(String date) {
    return 'Wanted by $date';
  }

  @override
  String reqBudget(String amount) {
    return 'Rough budget: $amount';
  }

  @override
  String get reqCancel => 'Cancel request';

  @override
  String get reqCancelTitle => 'Cancel this request?';

  @override
  String get reqCancelBody =>
      'Offers received will be declined. This cannot be undone.';

  @override
  String get reqCancelKeep => 'Keep request';

  @override
  String get reqCancelled => 'Request cancelled.';

  @override
  String get reqOffersSoon => 'Comparing offers is coming soon.';

  @override
  String reqPhotoLabel(int index, int total) {
    return 'Photo $index of $total';
  }

  @override
  String get reqPhotosFailed => 'Couldn’t load the photos.';

  @override
  String get proInboxTitle => 'Open requests';

  @override
  String get proInboxMyArea => 'In my governorate';

  @override
  String get proInboxAllCategories => 'All trades';

  @override
  String get proInboxEmptyTitle => 'No requests right now';

  @override
  String get proInboxEmptyBody => 'New customer requests will show up here.';

  @override
  String get proInboxNeedsPublished =>
      'Publish your profile to see requests and send offers.';

  @override
  String get offerStatusPending => 'Pending';

  @override
  String get offerStatusAccepted => 'Accepted';

  @override
  String get offerStatusDeclined => 'Declined';

  @override
  String get offerStatusWithdrawn => 'Withdrawn';

  @override
  String offerYours(String status) {
    return 'Your offer: $status';
  }

  @override
  String get offersTitle => 'My offers';

  @override
  String get offersEmpty => 'You haven’t sent any offers yet.';

  @override
  String get jobsTitle => 'My jobs';

  @override
  String get jobsEmpty =>
      'No jobs yet. A job starts when a customer accepts your offer.';

  @override
  String get jobScheduled => 'Scheduled';

  @override
  String get jobInProgress => 'In progress';

  @override
  String get jobPendingConfirmation => 'Waiting for the customer to confirm';

  @override
  String get jobCompleted => 'Completed';

  @override
  String get jobCancelled => 'Cancelled';

  @override
  String get jobStart => 'Start';

  @override
  String get jobDone => 'Mark as done';

  @override
  String get jobCancel => 'Cancel job';

  @override
  String get jobCancelTitle => 'Cancel this job?';

  @override
  String get jobCancelBody =>
      'The customer will be told. This cannot be undone.';

  @override
  String get jobKeep => 'Keep job';

  @override
  String jobAgreedPrice(String amount) {
    return 'Agreed price: $amount';
  }

  @override
  String get offerTitle => 'Your offer';

  @override
  String get offerPrice => 'Price in TND';

  @override
  String get offerMessage => 'Message to the customer (optional)';

  @override
  String get offerDays => 'Estimated days (optional)';

  @override
  String get offerSend => 'Send offer';

  @override
  String get offerUpdate => 'Update offer';

  @override
  String get offerWithdraw => 'Withdraw my offer';

  @override
  String get offerSent => 'Offer sent.';

  @override
  String get offerWithdrawn => 'Offer withdrawn.';

  @override
  String get offerErrPrice => 'Between 1 and 1,000,000 TND.';

  @override
  String get offerErrMessage => '1000 characters at most.';

  @override
  String get offerErrDays => 'Between 1 and 365 days.';

  @override
  String get offerDeclinedNote => 'The customer did not choose your offer.';

  @override
  String get offerAcceptedNote =>
      'Your offer was accepted: follow the job in My jobs.';

  @override
  String offerOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offers already received',
      one: '1 offer already received',
      zero: 'No other offers yet',
    );
    return '$_temp0';
  }

  @override
  String get reqFailOwn => 'You cannot answer your own request.';

  @override
  String get reqFailOfferClosed => 'This offer can no longer be changed.';

  @override
  String get reqFailTransition => 'That step is no longer possible.';

  @override
  String get reqFailForbidden => 'Publish your professional profile first.';

  @override
  String get offerFailLimit =>
      'You have 50 pending offers. Withdraw one before sending another.';
}
