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
  String get acctMemberCard => 'Member card';

  @override
  String get acctAccountType => 'Account type';

  @override
  String get acctCustomer => 'Customer';

  @override
  String get acctSettings => 'Settings';

  @override
  String get acctAccount => 'Account';

  @override
  String get acctWorkshop => 'Workshop';

  @override
  String get acctStatus => 'Status';

  @override
  String get acctTools => 'Tools';

  @override
  String get profileHelp => 'Help';

  @override
  String get profileHelpTitle => 'How Khidma works';

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
  String get navExplore => 'Explore';

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
  String get discLicenceKicker => 'Trade record';

  @override
  String get discFactExperience => 'Experience';

  @override
  String get discFactAvailability => 'Availability';

  @override
  String get discFactArea => 'Area';

  @override
  String get discHintPlumbing => 'Leaks, bathrooms, water heaters';

  @override
  String get discHintElectricity => 'Wiring, faults, fuse boxes';

  @override
  String get discHintAirConditioning => 'Fitting, servicing, repairs';

  @override
  String get discHintMechanics => 'Vehicle repair and servicing';

  @override
  String get discHintPainting => 'Interior and exterior';

  @override
  String get discHintCarpentry => 'Wooden furniture, doors, windows';

  @override
  String get discHintCleaning => 'Homes, offices, after building work';

  @override
  String get discHintAppliance => 'Washing machines, fridges, ovens';

  @override
  String get discHintConstruction => 'Masonry, tiling, renovation';

  @override
  String get discHintGardening => 'Gardens and green spaces';

  @override
  String get discHintMoving => 'Transport and house moves';

  @override
  String get discHintMaintenance => 'Small jobs and home repairs';

  @override
  String get homeQuoteTitle => 'Need a job done?';

  @override
  String get homeQuoteBody =>
      'Describe it once and receive offers from professionals.';

  @override
  String get avatarChange => 'Change photo';

  @override
  String get avatarChoose => 'Choose a photo';

  @override
  String get avatarRemove => 'Remove photo';

  @override
  String get avatarFailed => 'Could not update your photo. Try another image.';

  @override
  String get avatarLabel => 'Profile photo';

  @override
  String get statRating => 'Rating';

  @override
  String get statReviews => 'Reviews';

  @override
  String get statYears => 'Years';

  @override
  String get billTitle => 'Subscription';

  @override
  String get billCurrent => 'My subscription';

  @override
  String get billNone => 'No subscription yet.';

  @override
  String get billStatusLabel => 'Status';

  @override
  String get billStatusActive => 'Active';

  @override
  String get billStatusPastDue => 'Past due';

  @override
  String get billStatusExpired => 'Expired';

  @override
  String get billStatusCancelled => 'Cancelled';

  @override
  String get billValidUntil => 'Valid until';

  @override
  String get billDaysLeftLabel => 'Days left';

  @override
  String billDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
      zero: 'Expires today',
    );
    return '$_temp0';
  }

  @override
  String get billChoosePlan => 'Choose a plan';

  @override
  String billPeriod(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get billChooseMethod => 'Payment method';

  @override
  String get billMethodFlouci => 'Flouci';

  @override
  String get billMethodFlouciHint => 'Online payment, confirmed automatically';

  @override
  String get billMethodD17 => 'D17';

  @override
  String get billMethodD17Hint =>
      'Sent from your La Poste wallet, confirmed by our team';

  @override
  String get billMethodBank => 'Bank transfer';

  @override
  String get billMethodBankHint =>
      'Transfer to our account, confirmed by our team';

  @override
  String get billPay => 'Pay';

  @override
  String get billFlouciOpened =>
      'The payment opened in your browser. Come back here afterwards.';

  @override
  String get billMyPayments => 'My payments';

  @override
  String get billNoPayments => 'No payments yet.';

  @override
  String get billOrderPending => 'Pending';

  @override
  String get billOrderAwaiting => 'To confirm';

  @override
  String get billOrderPaid => 'Paid';

  @override
  String get billOrderFailed => 'Failed';

  @override
  String get billOrderCancelled => 'Cancelled';

  @override
  String get billOrderRejected => 'Rejected';

  @override
  String get billInstructionsTitle => 'Payment instructions';

  @override
  String get billAmount => 'Amount';

  @override
  String get billReference => 'Reference';

  @override
  String get billReferenceHint =>
      'Write this reference in the transfer reason or the D17 note.';

  @override
  String get billCopy => 'Copy';

  @override
  String get billCopied => 'Copied';

  @override
  String get billPayTo => 'Pay to';

  @override
  String get billBankName => 'Bank';

  @override
  String get billHolder => 'Account holder';

  @override
  String get billRib => 'RIB';

  @override
  String get billD17Number => 'D17 number';

  @override
  String get billNoDetails => 'The payment details are not available yet.';

  @override
  String get billIPaid => 'I have paid';

  @override
  String get billPaidTitle => 'Your payment';

  @override
  String get billNoteLabel => 'Note (optional)';

  @override
  String get billSend => 'Send';

  @override
  String get billCancelOrder => 'Cancel the order';

  @override
  String get billAwaitingBody =>
      'Thank you. Our team is checking your payment; your subscription starts once it is confirmed.';

  @override
  String get billNotProTitle => 'Become a professional first';

  @override
  String get billNotProBody =>
      'Subscriptions are for professionals. Create your profile first.';

  @override
  String get billNotProCta => 'Create my profile';

  @override
  String get billErrNetwork => 'No connection. Try again.';

  @override
  String get billErrSignedIn => 'Sign in again, then try again.';

  @override
  String get billErrRate => 'Too many orders today. Try again tomorrow.';

  @override
  String get billErrInvalid => 'This request is not valid.';

  @override
  String get billErrNotFound => 'This order no longer exists.';

  @override
  String get billErrNotConfigured => 'Payments are not available yet.';

  @override
  String get billFlouciUnavailable =>
      'Flouci is not available yet, use D17 or a bank transfer.';

  @override
  String get billCannotOpen => 'The payment link could not be opened.';

  @override
  String get billErrUnknown => 'Something went wrong. Try again.';

  @override
  String get flTitle => 'Digital services';

  @override
  String get flHomeSubtitle => 'Developers, designers, editors, writers…';

  @override
  String get flSearchHint => 'Search for a freelancer or a skill…';

  @override
  String get flCategories => 'Categories';

  @override
  String get flAllCategories => 'All';

  @override
  String get flResultsTitle => 'Freelancers';

  @override
  String get flEmptyTitle => 'No freelancers found';

  @override
  String get flEmptyBody => 'Try another word or category.';

  @override
  String get flLoadFailed => 'Could not load the freelancers.';

  @override
  String flPriceFrom(String price, String unit) {
    return 'from $price / $unit';
  }

  @override
  String get flUnitProject => 'project';

  @override
  String get flUnitHour => 'hour';

  @override
  String get flUnitDay => 'day';

  @override
  String get flNotFoundTitle => 'Freelancer not found';

  @override
  String get flNotFoundBody =>
      'This page no longer exists or is not published.';

  @override
  String get flFactPrice => 'Rate';

  @override
  String get flFactLanguages => 'Languages';

  @override
  String get flSkills => 'Skills';

  @override
  String get flPortfolio => 'Work';

  @override
  String flOpenItem(String title) {
    return 'Open: $title';
  }

  @override
  String get flKindImage => 'Photo';

  @override
  String get flKindClip => 'Video clip';

  @override
  String get flKindVideoLink => 'Online video';

  @override
  String get flKindLink => 'Link';

  @override
  String get flTestimonials => 'Client testimonials';

  @override
  String get flTestimonialLabel => 'Client testimonial';

  @override
  String get flTestimonialsNote =>
      'These testimonials come from past clients invited by the freelancer. They are different from the verified reviews left after a job done through Khidma.';

  @override
  String get flTestimonialsEmpty => 'No testimonials yet.';

  @override
  String flTestimonialProject(String title) {
    return 'Project: $title';
  }

  @override
  String flStars(int count) {
    return '$count out of 5';
  }

  @override
  String get flDashRow => 'Freelance activity';

  @override
  String get flManageTitle => 'My freelance activity';

  @override
  String get flIntroTitle => 'Offer your digital services';

  @override
  String get flIntroBody =>
      'Development, design, editing, marketing, writing… Create a public page with your work and client testimonials. Your identity check is the same as for your trade profile: one check is enough.';

  @override
  String get flBecome => 'Become a freelancer';

  @override
  String get flSectionProfile => 'My page';

  @override
  String get flFieldName => 'Display name';

  @override
  String get flFieldHeadline => 'Professional headline';

  @override
  String get flFieldHeadlineHint => 'e.g. Flutter developer';

  @override
  String get flFieldCategory => 'Category';

  @override
  String get flFieldBio => 'About you';

  @override
  String get flFieldBioHelp =>
      'At least 20 characters to publish, 2000 at most.';

  @override
  String get flFieldSkills => 'Skills';

  @override
  String get flFieldSkillsHelp => 'Separated by commas, 12 at most.';

  @override
  String get flFieldLanguages => 'Languages';

  @override
  String get flFieldLanguagesHelp => 'Separated by commas, 6 at most.';

  @override
  String get flFieldYears => 'Years of experience';

  @override
  String get flFieldPrice => 'Starting price (TND)';

  @override
  String get flFieldUnit => 'Per';

  @override
  String get flFieldAvailability => 'Availability';

  @override
  String get flErrName => '2 to 80 characters.';

  @override
  String get flErrHeadline => '5 to 100 characters.';

  @override
  String get flErrBio => '2000 characters at most.';

  @override
  String get flErrYears => 'Between 0 and 60.';

  @override
  String get flErrPrice => 'Invalid amount.';

  @override
  String flErrTags(int max) {
    return '30 characters per item, $max items at most.';
  }

  @override
  String get flSaved => 'Page saved.';

  @override
  String get flIdentityTitle => 'Identity';

  @override
  String get flIdentityVerified => 'Identity verified.';

  @override
  String get flIdentityNotVerified => 'Identity not verified yet.';

  @override
  String get flIdentityShared =>
      'One check covers both your trade profile and your freelance page.';

  @override
  String get flPublish => 'Publish my page';

  @override
  String get flPublishedHint => 'Your page is visible in Digital services.';

  @override
  String get flUnpublishedHint => 'Your page is not visible right now.';

  @override
  String get flPublishBlocked =>
      'Publishing is blocked until your identity is verified.';

  @override
  String get flErrNotVerified =>
      'Your identity is not verified yet. Get it verified to publish.';

  @override
  String get flErrIncomplete =>
      'Page incomplete: add a contact phone number in your trade profile, then fill in name, headline, category and about text (20 characters minimum).';

  @override
  String get flErrSuspended =>
      'Your account is suspended: publishing is not possible.';

  @override
  String get flErrGeneric =>
      'The action failed. Check your connection and try again.';

  @override
  String get flErrNotConfigured => 'The service is not available right now.';

  @override
  String get flErrInvalid =>
      'Some details were refused. Check them and try again.';

  @override
  String get flErrRate => 'Too many requests. Try again later.';

  @override
  String flPortCount(int count, int max) {
    return '$count of $max items';
  }

  @override
  String get flPortEmpty => 'No work added yet.';

  @override
  String get flPortAddPhoto => 'Add a photo';

  @override
  String get flPortAddClip => 'Add a clip (30 s max)';

  @override
  String get flPortAddVideoLink => 'Add an online video';

  @override
  String get flPortAddLink => 'Add a link';

  @override
  String get flPortLimit => 'You reached the limit of 24 items.';

  @override
  String get flPortTooLarge => 'File too large (25 MB at most).';

  @override
  String get flPortBadFormat =>
      'Unsupported format: use an mp4 or webm clip, or add a video link.';

  @override
  String get flFieldTitle => 'Title';

  @override
  String get flFieldDescription => 'Description (optional)';

  @override
  String get flFieldUrl => 'Link address';

  @override
  String get flErrTitle => '2 to 100 characters.';

  @override
  String get flErrDescription => '500 characters at most.';

  @override
  String get flErrUrlVideo => 'Only https YouTube or Vimeo links.';

  @override
  String get flErrUrlLink => 'Enter a valid https address.';

  @override
  String get flSheetAdd => 'Add';

  @override
  String get flSheetChooseFile => 'Choose the file';

  @override
  String get flItemEdit => 'Edit';

  @override
  String get flItemDelete => 'Delete';

  @override
  String get flItemDeleteTitle => 'Delete this item?';

  @override
  String get flItemDeleteBody => 'It will no longer show on your page.';

  @override
  String get flUploading => 'Uploading…';

  @override
  String get flInvTitle => 'Testimonial invitations';

  @override
  String get flInvHint =>
      'Send a personal link to a past client: they write their testimonial on a web page, no account needed. The link is valid for 30 days and works once.';

  @override
  String get flInvCreate => 'Create an invitation link';

  @override
  String get flInvLabelField => 'Who is it for? (optional)';

  @override
  String get flInvNotConfigured =>
      'Testimonial links are not configured yet in this version of the app.';

  @override
  String get flInvLinkTitle => 'Link created';

  @override
  String get flInvLinkWarn => 'Copy it now: it will not be shown again.';

  @override
  String get flInvCopy => 'Copy the link';

  @override
  String get flInvCopied => 'Link copied.';

  @override
  String get flInvShare => 'Share on WhatsApp';

  @override
  String flInvShareText(String url) {
    return 'Hello, could you leave a testimonial about our work together? $url';
  }

  @override
  String get flInvEmpty => 'No invitations yet.';

  @override
  String get flInvStatusOpen => 'Waiting';

  @override
  String get flInvStatusUsed => 'Used';

  @override
  String get flInvStatusExpired => 'Expired';

  @override
  String flInvExpires(String date) {
    return 'Expires on $date';
  }

  @override
  String get flInvNoLabel => 'No name';

  @override
  String get flInvRevoke => 'Revoke';

  @override
  String get flInvRevokeTitle => 'Revoke this invitation?';

  @override
  String get flInvRevokeBody => 'The link will stop working.';

  @override
  String get flInvLimit => '20 open invitations at most.';

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
  String get regDone => 'Done';

  @override
  String get regUsePosition => 'Use my current location';

  @override
  String get regPositionSet => 'Approximate position saved (about 1 km).';

  @override
  String get regPositionFailed =>
      'Could not get your position. Check the location permission: otherwise the map will use your governorate.';

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
  String flowRef(String code) {
    return 'No. $code';
  }

  @override
  String flowRequestCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests',
      one: '1 request',
    );
    return '$_temp0';
  }

  @override
  String get flowSecService => 'Service';

  @override
  String get flowSecNeed => 'What you need';

  @override
  String get flowSecWhere => 'Where';

  @override
  String get flowSecWhen => 'When';

  @override
  String get flowSecPhotos => 'Photos';

  @override
  String get flowFactPlace => 'Location';

  @override
  String get flowFactBudget => 'Rough budget';

  @override
  String get flowFactNeededBy => 'Wanted by';

  @override
  String get flowFactExpires => 'Expires on';

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

  @override
  String get offersReceived => 'Offers received';

  @override
  String get offersNoneYet =>
      'No offers yet. Professionals can answer until the request expires.';

  @override
  String get sortOffersBy => 'Sort offers';

  @override
  String get sortOffersPrice => 'Price';

  @override
  String get sortOffersRating => 'Rating';

  @override
  String get sortOffersDelay => 'Delay';

  @override
  String get offerLowest => 'Lowest price';

  @override
  String offerDelay(int count) {
    return 'Delay: $count d';
  }

  @override
  String get offerAccept => 'Accept';

  @override
  String get offerDecline => 'Decline';

  @override
  String get offerAcceptTitle => 'Accept this offer?';

  @override
  String offerAcceptBody(String name, String price) {
    return '$name will do the work for $price. The other offers will be declined and the request awarded.';
  }

  @override
  String get offerDeclineTitle => 'Decline this offer?';

  @override
  String get offerDeclineBody =>
      'The professional will not be able to offer again.';

  @override
  String get offerAcceptedMsg => 'Offer accepted.';

  @override
  String get offerDeclinedMsg => 'Offer declined.';

  @override
  String get offerProUnknown => 'Professional';

  @override
  String get bookingTitle => 'Job';

  @override
  String get bookingConfirm => 'Confirm the work is done';

  @override
  String get bookingConfirmed => 'Thank you, job completed.';

  @override
  String get bookingCancelled => 'Job cancelled.';

  @override
  String get bookingCancelTitle => 'Cancel this job?';

  @override
  String get bookingCancelBody =>
      'The professional will be told. This cannot be undone.';

  @override
  String get bookingWaitingForYou =>
      'The professional says the work is done. Is it done properly?';

  @override
  String get chatTitleClient => 'Customer';

  @override
  String get chatInputHint => 'Write a message…';

  @override
  String get chatSend => 'Send';

  @override
  String get chatAddImage => 'Attach a photo';

  @override
  String get chatEmpty => 'No messages yet. Say hello!';

  @override
  String get chatReadOnly =>
      'This conversation has ended: you can read it, but not write.';

  @override
  String get chatImageSent => 'Photo sent';

  @override
  String get chatYouSent => 'You';

  @override
  String get chatThem => 'Other person';

  @override
  String chatUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get chatSendFailed => 'Message not sent. Try again.';

  @override
  String get chatRateLimited => 'You are writing too fast. Wait a moment.';

  @override
  String get chatClosed => 'This conversation has ended.';

  @override
  String get chatOpenFailed => 'Couldn’t open the conversation. Try again.';

  @override
  String get chatLiveFailed => 'Live updates stopped. Pull to refresh.';

  @override
  String get chatPhotoFailed => 'Photo not sent. Try again.';

  @override
  String get chatAskPro => 'Ask a question';

  @override
  String get chatWriteCustomer => 'Message the customer';

  @override
  String get chatPhoto => 'Photo';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifIntro =>
      'Choose what you want to be told about. Notifications never contain the text of your messages.';

  @override
  String get notifOffers => 'Offers received and accepted';

  @override
  String get notifMessages => 'New messages';

  @override
  String get notifJobs => 'Job progress';

  @override
  String get notifNoPush =>
      'Push notifications are not available on this device yet. Your choices are saved for later.';

  @override
  String get notifSaveFailed => 'Couldn’t save that choice. Try again.';

  @override
  String get reviewsTitle => 'Reviews';

  @override
  String get reviewsEmpty => 'No reviews yet.';

  @override
  String get reviewsMore => 'Show more reviews';

  @override
  String get reviewsLoadFailed => 'Couldn’t load the reviews.';

  @override
  String get reviewCta => 'Leave a review';

  @override
  String get reviewCtaPro => 'Rate the customer';

  @override
  String get reviewSheetTitle => 'Your review';

  @override
  String get reviewSheetTitlePro => 'Your review of the customer';

  @override
  String get reviewRatingHint => 'Tap a star';

  @override
  String reviewStar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
    );
    return '$_temp0';
  }

  @override
  String get reviewComment => 'Comment (optional)';

  @override
  String get reviewSubmit => 'Publish my review';

  @override
  String get reviewPublicNote =>
      'Your review will be public, without your name.';

  @override
  String get reviewPrivateNote =>
      'This review is only visible to the Khidma team.';

  @override
  String get reviewErrRating => 'Choose a rating from 1 to 5.';

  @override
  String get reviewThanks => 'Thank you for your review.';

  @override
  String get reviewDone => 'Review given';

  @override
  String get reviewFailAlready => 'You already reviewed this job.';

  @override
  String get reviewFailNotCompleted =>
      'The job must be completed to leave a review.';

  @override
  String get reviewFailGeneric => 'Couldn’t send the review. Try again.';

  @override
  String get reviewAuthorAnon => 'Customer';

  @override
  String get reviewFailLimit =>
      'You have already given this professional too many reviews.';

  @override
  String get reportAction => 'Report';

  @override
  String get reportTitle => 'Report a problem';

  @override
  String get reportHint =>
      'Our team reviews every report. The person reported will not know it was you.';

  @override
  String get reportReasonSpam => 'Advertising or spam';

  @override
  String get reportReasonFake => 'Fake profile or review';

  @override
  String get reportReasonAbuse => 'Harassment or insults';

  @override
  String get reportReasonScam => 'Scam or suspicious money request';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportDetailsLabel => 'Details (optional)';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportSent => 'Thank you. Your report was sent.';

  @override
  String get reportFailAlready =>
      'You already reported this. We are looking at it.';

  @override
  String get reportFailRate => 'Too many reports today. Try again tomorrow.';

  @override
  String get reportFailGone => 'This content is no longer available.';

  @override
  String get reportFailGeneric =>
      'The report could not be sent. Check your connection and try again.';

  @override
  String get verifTitle => 'Profile verification';

  @override
  String get verifCta => 'Get my profile verified';

  @override
  String get verifIntro =>
      'Send a photo of your ID card or business registration. Once checked, a badge shows on your profile.';

  @override
  String get verifPrivacy =>
      'Your documents are private: only you and our verification team can see them, and they are deleted as soon as a decision is made.';

  @override
  String get verifStatusNone => 'Not verified yet';

  @override
  String get verifStatusPending => 'Being checked';

  @override
  String get verifStatusApproved => 'Profile verified';

  @override
  String get verifStatusRejected => 'Request declined';

  @override
  String get verifStatusCancelled => 'Request cancelled';

  @override
  String verifRejectReason(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get verifPendingBody =>
      'We are checking your documents. You will be told the decision.';

  @override
  String get verifAdd => 'Add a photo';

  @override
  String verifCount(Object count, Object max) {
    return '$count of $max documents';
  }

  @override
  String verifRemove(Object index) {
    return 'Remove document $index';
  }

  @override
  String get verifSubmit => 'Send for checking';

  @override
  String get verifCancel => 'Cancel the request';

  @override
  String get verifSent => 'Documents sent. We will get back to you soon.';

  @override
  String get verifCancelled =>
      'Request cancelled. Your documents were deleted.';

  @override
  String get verifFailPending => 'A request is already being checked.';

  @override
  String get verifFailVerified => 'Your profile is already verified.';

  @override
  String get verifFailLimit =>
      'Too many requests in the last 30 days. Try again later.';

  @override
  String get verifFailGeneric =>
      'Sending failed. Check your connection and try again.';

  @override
  String get verifFailImage =>
      'This file is not a readable photo (JPEG, PNG or WebP).';

  @override
  String get reqFilterAll => 'All';

  @override
  String get reqFilterOpen => 'Open';

  @override
  String get reqFilterClosed => 'Closed';

  @override
  String get reqFilterEmpty => 'No requests in this list.';

  @override
  String reqFormProgress(int done, int total) {
    return '$done of $total steps filled in';
  }

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get verifStepSend => 'Documents sent';

  @override
  String get verifStepReview => 'Team review';

  @override
  String get verifStepBadge => 'Badge on your profile';

  @override
  String get worldTrades => 'Trades';

  @override
  String get worldDigital => 'Digital freelance';

  @override
  String get homeNearbyTitle => 'Pros near you';

  @override
  String get homeHeroFreelanceBody => 'Show your work and find clients.';

  @override
  String get homeHeroDigitalCta => 'Explore';

  @override
  String priceFromShort(String price) {
    return 'from $price';
  }

  @override
  String get docsVerified => 'Documents verified';

  @override
  String get identityVerified => 'Identity verified';

  @override
  String yearsShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yrs',
      one: '1 yr',
    );
    return '$_temp0';
  }

  @override
  String get welcomeHeadlineStart => 'Find';

  @override
  String get welcomeHeadlineEnd => 'near you.';

  @override
  String get welcomeWordPlumber => 'a plumber';

  @override
  String get welcomeWordElectrician => 'an electrician';

  @override
  String get welcomeWordDeveloper => 'a developer';

  @override
  String get welcomeWordDesigner => 'a designer';

  @override
  String get welcomeWordCarpenter => 'a carpenter';

  @override
  String get welcomeHeadlineA11y =>
      'Find a plumber, an electrician, a developer, a designer or a carpenter near you.';

  @override
  String get welcomeSubtitle =>
      'Compare quotes, chat and book, anywhere in Tunisia.';

  @override
  String get welcomeTrust => 'Verified tradespeople and freelancers';

  @override
  String get welcomeHaveAccount => 'I already have an account';

  @override
  String get welcomeLegal => 'By continuing, you accept the terms of use.';

  @override
  String welcomeLanguageButton(String language) {
    return 'Language: $language';
  }

  @override
  String get welcomeTradePlumber => 'Plumber';

  @override
  String get welcomeTradeDesigner => 'UI designer';

  @override
  String get welcomeTradeElectrician => 'Electrician';

  @override
  String get welcomeTradeDeveloper => 'Developer';

  @override
  String get welcomeTradeCarpenter => 'Carpenter';

  @override
  String get welcomeTradeVideo => 'Video editor';

  @override
  String get reportReasonPayOutside =>
      'Asked to pay in advance or outside the app';

  @override
  String get reportReasonNoShow => 'Did not show up';

  @override
  String get reportMessageAction => 'Report this message';

  @override
  String get reportOfferAction => 'Report this offer';

  @override
  String get chatSafetyTip =>
      'Never pay in advance. Keep your agreements in Khidma.';

  @override
  String get failSuspended =>
      'Your account is suspended: this is not possible.';

  @override
  String get suspendedTitle => 'Account suspended';

  @override
  String suspendedUntil(String date) {
    return 'Your profile is hidden until $date. You cannot send offers or messages.';
  }

  @override
  String get suspendedIndefinite =>
      'Your profile is hidden until the team decides. You cannot send offers or messages.';

  @override
  String suspendedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get appealAction => 'Appeal';

  @override
  String get appealHint => 'Explain why this suspension is a mistake.';

  @override
  String get appealTooShort => 'Write at least 10 characters.';

  @override
  String get appealSend => 'Send appeal';

  @override
  String get appealSent => 'Appeal sent. The team will review it.';

  @override
  String get appealPending => 'Your appeal is being reviewed.';

  @override
  String get appealRejected => 'Your last appeal was rejected.';

  @override
  String get appealFailRate =>
      'Wait a week after a rejection before appealing again.';

  @override
  String get appealFailGeneric => 'The appeal could not be sent. Try again.';

  @override
  String verifiedUntil(String date) {
    return 'Identity verified, valid until $date';
  }
}
