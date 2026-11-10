import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In fr, this message translates to:
  /// **'Khidma'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In fr, this message translates to:
  /// **'Des professionnels de confiance, près de chez vous.'**
  String get tagline;

  /// No description provided for @chooseLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la langue'**
  String get chooseLanguage;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageArabic.
  ///
  /// In fr, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @priceOnQuote.
  ///
  /// In fr, this message translates to:
  /// **'Sur devis'**
  String get priceOnQuote;

  /// No description provided for @professionalsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun professionnel} =1{1 professionnel} other{{count} professionnels}}'**
  String professionalsCount(int count);

  /// No description provided for @phoneInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Numéro tunisien invalide. Exemple : +216 20 123 456'**
  String get phoneInvalid;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes'**
  String get navRequests;

  /// No description provided for @navMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Les professionnels arrivent bientôt'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'La recherche et les catégories de services seront disponibles ici.'**
  String get homeEmptyBody;

  /// No description provided for @requestsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande pour l\'instant'**
  String get requestsEmptyTitle;

  /// No description provided for @requestsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos demandes de devis apparaîtront ici.'**
  String get requestsEmptyBody;

  /// No description provided for @messagesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message'**
  String get messagesEmptyTitle;

  /// No description provided for @messagesEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos conversations avec les professionnels apparaîtront ici.'**
  String get messagesEmptyBody;

  /// No description provided for @themeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get themeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @notFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Page introuvable'**
  String get notFoundTitle;

  /// No description provided for @notFoundBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette page n\'existe pas ou a été déplacée.'**
  String get notFoundBody;

  /// No description provided for @backToHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get backToHome;

  /// No description provided for @verified.
  ///
  /// In fr, this message translates to:
  /// **'Vérifié'**
  String get verified;

  /// No description provided for @ratingNone.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore d\'avis'**
  String get ratingNone;

  /// No description provided for @ratingSummary.
  ///
  /// In fr, this message translates to:
  /// **'Note {value} sur 5, {count, plural, =1{1 avis} other{{count} avis}}'**
  String ratingSummary(String value, int count);

  /// No description provided for @errorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get errorTitle;

  /// No description provided for @errorBody.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre connexion et réessayez.'**
  String get errorBody;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get loading;

  /// No description provided for @showPassword.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le mot de passe'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le mot de passe'**
  String get hidePassword;

  /// No description provided for @onbTitle1.
  ///
  /// In fr, this message translates to:
  /// **'Trouvez des professionnels de confiance'**
  String get onbTitle1;

  /// No description provided for @onbBody1.
  ///
  /// In fr, this message translates to:
  /// **'Plombiers, électriciens, mécaniciens… découvrez des artisans près de chez vous, avec leurs réalisations et leurs avis.'**
  String get onbBody1;

  /// No description provided for @onbTitle2.
  ///
  /// In fr, this message translates to:
  /// **'Comparez et demandez un devis'**
  String get onbTitle2;

  /// No description provided for @onbBody2.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre besoin une fois, recevez des offres de plusieurs professionnels et choisissez la meilleure.'**
  String get onbBody2;

  /// No description provided for @onbTitle3.
  ///
  /// In fr, this message translates to:
  /// **'Contactez-les directement'**
  String get onbTitle3;

  /// No description provided for @onbBody3.
  ///
  /// In fr, this message translates to:
  /// **'Appelez, écrivez sur WhatsApp ou discutez dans l\'application. Le paiement se règle directement avec le professionnel.'**
  String get onbBody3;

  /// No description provided for @languageStepBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez la changer à tout moment dans Profil.'**
  String get languageStepBody;

  /// No description provided for @next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get next;

  /// No description provided for @start.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get start;

  /// No description provided for @skip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get skip;

  /// No description provided for @pageOf.
  ///
  /// In fr, this message translates to:
  /// **'Page {current} sur {total}'**
  String pageOf(int current, int total);

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get back;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccount;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOut;

  /// No description provided for @emailLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordLabel;

  /// No description provided for @fullNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get fullNameLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgotPassword;

  /// No description provided for @sendResetLink.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien'**
  String get sendResetLink;

  /// No description provided for @noAccountYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
  String get noAccountYet;

  /// No description provided for @haveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Déjà un compte ?'**
  String get haveAccount;

  /// No description provided for @signInTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bon retour'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour demander des devis et suivre vos demandes.'**
  String get signInSubtitle;

  /// No description provided for @registerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre compte'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Quelques secondes suffisent.'**
  String get registerSubtitle;

  /// No description provided for @forgotTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser le mot de passe'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre e-mail : nous vous envoyons un lien pour choisir un nouveau mot de passe.'**
  String get forgotSubtitle;

  /// No description provided for @resetSentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez vos e-mails'**
  String get resetSentTitle;

  /// No description provided for @resetSentBody.
  ///
  /// In fr, this message translates to:
  /// **'Si un compte existe pour {email}, un lien de réinitialisation vient d\'être envoyé.'**
  String resetSentBody(String email);

  /// No description provided for @confirmEmailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez votre adresse e-mail'**
  String get confirmEmailTitle;

  /// No description provided for @confirmEmailBody.
  ///
  /// In fr, this message translates to:
  /// **'Nous avons envoyé un lien de confirmation à {email}. Ouvrez-le pour activer votre compte.'**
  String confirmEmailBody(String email);

  /// No description provided for @backToSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Retour à la connexion'**
  String get backToSignIn;

  /// No description provided for @errEmailRequired.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre adresse e-mail.'**
  String get errEmailRequired;

  /// No description provided for @errEmailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail invalide.'**
  String get errEmailInvalid;

  /// No description provided for @errPasswordRequired.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre mot de passe.'**
  String get errPasswordRequired;

  /// No description provided for @errPasswordShort.
  ///
  /// In fr, this message translates to:
  /// **'8 caractères minimum.'**
  String get errPasswordShort;

  /// No description provided for @errPasswordLong.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe trop long.'**
  String get errPasswordLong;

  /// No description provided for @errNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre nom.'**
  String get errNameRequired;

  /// No description provided for @failInvalidCredentials.
  ///
  /// In fr, this message translates to:
  /// **'E-mail ou mot de passe incorrect.'**
  String get failInvalidCredentials;

  /// No description provided for @failEmailNotConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez d\'abord votre adresse e-mail (lien reçu par e-mail).'**
  String get failEmailNotConfirmed;

  /// No description provided for @failWeakPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe trop faible. Choisissez-en un plus long et moins courant.'**
  String get failWeakPassword;

  /// No description provided for @failSignUpDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Les inscriptions sont fermées pour le moment.'**
  String get failSignUpDisabled;

  /// No description provided for @failRateLimited.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessayez dans quelques minutes.'**
  String get failRateLimited;

  /// No description provided for @failNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez votre réseau.'**
  String get failNetwork;

  /// No description provided for @failNotConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Les comptes ne sont pas disponibles dans cette version de l\'application.'**
  String get failNotConfigured;

  /// No description provided for @failUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get failUnknown;

  /// No description provided for @signedOutProfileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous ou créez un compte'**
  String get signedOutProfileTitle;

  /// No description provided for @signedOutProfileBody.
  ///
  /// In fr, this message translates to:
  /// **'Pour demander un devis et contacter des professionnels.'**
  String get signedOutProfileBody;

  /// No description provided for @requestsSignedOutTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour voir vos demandes'**
  String get requestsSignedOutTitle;

  /// No description provided for @requestsSignedOutBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos demandes de devis et les offres reçues apparaîtront ici.'**
  String get requestsSignedOutBody;

  /// No description provided for @messagesSignedOutTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour discuter'**
  String get messagesSignedOutTitle;

  /// No description provided for @messagesSignedOutBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos conversations avec les professionnels apparaîtront ici.'**
  String get messagesSignedOutBody;

  /// No description provided for @signedInAs.
  ///
  /// In fr, this message translates to:
  /// **'Connecté en tant que {email}'**
  String signedInAs(String email);

  /// No description provided for @newPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get newPasswordTitle;

  /// No description provided for @newPasswordSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un mot de passe que vous n\'utilisez nulle part ailleurs.'**
  String get newPasswordSubtitle;

  /// No description provided for @savePassword.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le mot de passe'**
  String get savePassword;

  /// No description provided for @passwordUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe mis à jour.'**
  String get passwordUpdated;

  /// No description provided for @linkExpiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lien expiré ou invalide'**
  String get linkExpiredTitle;

  /// No description provided for @linkExpiredBody.
  ///
  /// In fr, this message translates to:
  /// **'Demandez un nouveau lien de réinitialisation depuis l\'écran de connexion.'**
  String get linkExpiredBody;

  /// No description provided for @accountTypeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Je souhaite…'**
  String get accountTypeTitle;

  /// No description provided for @accountCustomerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trouver un professionnel'**
  String get accountCustomerTitle;

  /// No description provided for @accountCustomerBody.
  ///
  /// In fr, this message translates to:
  /// **'Demander des devis et contacter des artisans.'**
  String get accountCustomerBody;

  /// No description provided for @accountProfessionalTitle.
  ///
  /// In fr, this message translates to:
  /// **'Proposer mes services'**
  String get accountProfessionalTitle;

  /// No description provided for @accountProfessionalBody.
  ///
  /// In fr, this message translates to:
  /// **'Créer un profil professionnel et recevoir des demandes.'**
  String get accountProfessionalBody;

  /// No description provided for @becomeProfessionalTitle.
  ///
  /// In fr, this message translates to:
  /// **'Proposez vos services'**
  String get becomeProfessionalTitle;

  /// No description provided for @becomeProfessionalBody.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre profil professionnel pour recevoir des demandes de clients.'**
  String get becomeProfessionalBody;

  /// No description provided for @becomeProfessionalCta.
  ///
  /// In fr, this message translates to:
  /// **'Devenir professionnel'**
  String get becomeProfessionalCta;

  /// No description provided for @professionalBadge.
  ///
  /// In fr, this message translates to:
  /// **'Professionnel'**
  String get professionalBadge;

  /// No description provided for @editProfile.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get editProfile;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @phoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get phoneLabel;

  /// No description provided for @phoneHelper.
  ///
  /// In fr, this message translates to:
  /// **'Visible uniquement par vous.'**
  String get phoneHelper;

  /// No description provided for @profileSaved.
  ///
  /// In fr, this message translates to:
  /// **'Profil enregistré.'**
  String get profileSaved;

  /// No description provided for @failProfileLoad.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger votre profil.'**
  String get failProfileLoad;

  /// No description provided for @failProfileInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Certaines informations sont invalides.'**
  String get failProfileInvalid;

  /// No description provided for @continueWithApple.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Apple'**
  String get continueWithApple;

  /// No description provided for @orSeparator.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get orSeparator;

  /// No description provided for @deleteAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer votre compte ?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre profil, vos informations et vos données associées seront supprimés définitivement. Cette action est irréversible.'**
  String get deleteAccountBody;

  /// No description provided for @deleteConfirmWord.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get deleteConfirmWord;

  /// No description provided for @deleteTypeToConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez {word} pour confirmer'**
  String deleteTypeToConfirm(String word);

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @accountDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte a été supprimé.'**
  String get accountDeleted;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
