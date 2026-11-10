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

  /// No description provided for @homeGreeting.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get homeGreeting;

  /// No description provided for @homeGreetingNamed.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour, {name}'**
  String homeGreetingNamed(String name);

  /// No description provided for @homeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'De quel service avez-vous besoin ?'**
  String get homeSubtitle;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un métier, un nom, une ville…'**
  String get searchHint;

  /// No description provided for @placeAll.
  ///
  /// In fr, this message translates to:
  /// **'Toute la Tunisie'**
  String get placeAll;

  /// No description provided for @placeChoose.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une zone'**
  String get placeChoose;

  /// No description provided for @placeGovernorate.
  ///
  /// In fr, this message translates to:
  /// **'Gouvernorat'**
  String get placeGovernorate;

  /// No description provided for @placeWholeGovernorate.
  ///
  /// In fr, this message translates to:
  /// **'Tout le gouvernorat'**
  String get placeWholeGovernorate;

  /// No description provided for @sectionCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get sectionCategories;

  /// No description provided for @sectionTopRated.
  ///
  /// In fr, this message translates to:
  /// **'Les mieux notés'**
  String get sectionTopRated;

  /// No description provided for @sectionInYourArea.
  ///
  /// In fr, this message translates to:
  /// **'Dans votre zone'**
  String get sectionInYourArea;

  /// No description provided for @sectionInYourAreaPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une zone pour voir les professionnels autour de vous.'**
  String get sectionInYourAreaPrompt;

  /// No description provided for @sectionRecent.
  ///
  /// In fr, this message translates to:
  /// **'Consultés récemment'**
  String get sectionRecent;

  /// No description provided for @seeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get seeAll;

  /// No description provided for @noProfessionalsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun professionnel pour le moment'**
  String get noProfessionalsTitle;

  /// No description provided for @noProfessionalsBody.
  ///
  /// In fr, this message translates to:
  /// **'Ils apparaîtront ici dès qu\'ils auront rejoint Khidma.'**
  String get noProfessionalsBody;

  /// No description provided for @noProfessionalsInArea.
  ///
  /// In fr, this message translates to:
  /// **'Aucun professionnel dans cette zone pour le moment.'**
  String get noProfessionalsInArea;

  /// No description provided for @demoBannerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Données de démonstration'**
  String get demoBannerTitle;

  /// No description provided for @demoBannerBody.
  ///
  /// In fr, this message translates to:
  /// **'Les professionnels, notes et badges affichés sont fictifs.'**
  String get demoBannerBody;

  /// No description provided for @availabilityAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Disponible'**
  String get availabilityAvailable;

  /// No description provided for @availabilityBusy.
  ///
  /// In fr, this message translates to:
  /// **'Occupé'**
  String get availabilityBusy;

  /// No description provided for @availabilityOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get availabilityOffline;

  /// No description provided for @yearsExperience.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 an d\'expérience} other{{count} ans d\'expérience}}'**
  String yearsExperience(int count);

  /// No description provided for @distanceKm.
  ///
  /// In fr, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @failLoadProfessionals.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les professionnels.'**
  String get failLoadProfessionals;

  /// No description provided for @failForbidden.
  ///
  /// In fr, this message translates to:
  /// **'L\'accès aux données est refusé. Réessayez plus tard.'**
  String get failForbidden;

  /// No description provided for @professionalNotFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil introuvable'**
  String get professionalNotFoundTitle;

  /// No description provided for @professionalNotFoundBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce professionnel n\'est plus disponible.'**
  String get professionalNotFoundBody;

  /// No description provided for @searchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get searchTitle;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNoResultsBody.
  ///
  /// In fr, this message translates to:
  /// **'Essayez un autre mot ou une autre zone.'**
  String get searchNoResultsBody;

  /// No description provided for @searchStartTitle.
  ///
  /// In fr, this message translates to:
  /// **'Que cherchez-vous ?'**
  String get searchStartTitle;

  /// No description provided for @searchStartBody.
  ///
  /// In fr, this message translates to:
  /// **'Tapez un métier, un nom ou une ville.'**
  String get searchStartBody;

  /// No description provided for @aboutLabel.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get aboutLabel;

  /// No description provided for @inCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get inCategory;

  /// No description provided for @filtersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get filtersTitle;

  /// No description provided for @filtersAction.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer'**
  String get filtersAction;

  /// No description provided for @filterCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get filterCategory;

  /// No description provided for @filterAllCategories.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get filterAllCategories;

  /// No description provided for @filterMinRating.
  ///
  /// In fr, this message translates to:
  /// **'Note minimale'**
  String get filterMinRating;

  /// No description provided for @filterRatingAny.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get filterRatingAny;

  /// No description provided for @filterRatingAtLeast.
  ///
  /// In fr, this message translates to:
  /// **'{value}+'**
  String filterRatingAtLeast(String value);

  /// No description provided for @filterAvailableOnly.
  ///
  /// In fr, this message translates to:
  /// **'Disponibles uniquement'**
  String get filterAvailableOnly;

  /// No description provided for @sortBy.
  ///
  /// In fr, this message translates to:
  /// **'Trier par'**
  String get sortBy;

  /// No description provided for @sortRating.
  ///
  /// In fr, this message translates to:
  /// **'Mieux notés'**
  String get sortRating;

  /// No description provided for @sortReviews.
  ///
  /// In fr, this message translates to:
  /// **'Plus d’avis'**
  String get sortReviews;

  /// No description provided for @filtersApply.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get filtersApply;

  /// No description provided for @filtersReset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get filtersReset;

  /// No description provided for @loadMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get loadMore;

  /// No description provided for @filtersActive.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Filtres} =1{Filtres, 1 actif} other{Filtres, {count} actifs}}'**
  String filtersActive(int count);

  /// No description provided for @contactTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get contactTitle;

  /// No description provided for @contactShow.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le contact'**
  String get contactShow;

  /// No description provided for @contactSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour voir le contact'**
  String get contactSignIn;

  /// No description provided for @contactCall.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get contactCall;

  /// No description provided for @contactWhatsApp.
  ///
  /// In fr, this message translates to:
  /// **'WhatsApp'**
  String get contactWhatsApp;

  /// No description provided for @contactWhy.
  ///
  /// In fr, this message translates to:
  /// **'Le numéro est affiché aux membres connectés, pour protéger les professionnels du démarchage abusif.'**
  String get contactWhy;

  /// No description provided for @contactDemo.
  ///
  /// In fr, this message translates to:
  /// **'Le contact n’est pas disponible avec les données de démonstration.'**
  String get contactDemo;

  /// No description provided for @contactRateLimited.
  ///
  /// In fr, this message translates to:
  /// **'Trop de numéros consultés en peu de temps. Réessayez dans une heure.'**
  String get contactRateLimited;

  /// No description provided for @contactNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Ce professionnel n’est plus disponible.'**
  String get contactNotFound;

  /// No description provided for @contactFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le contact. Réessayez.'**
  String get contactFailed;

  /// No description provided for @contactLaunchFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’ouvrir l’application.'**
  String get contactLaunchFailed;

  /// No description provided for @servicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Services'**
  String get servicesTitle;

  /// No description provided for @areasTitle.
  ///
  /// In fr, this message translates to:
  /// **'Zones d’intervention'**
  String get areasTitle;

  /// No description provided for @areaWhole.
  ///
  /// In fr, this message translates to:
  /// **'{place} (tout le gouvernorat)'**
  String areaWhole(String place);

  /// No description provided for @favoritesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes favoris'**
  String get favoritesTitle;

  /// No description provided for @favoriteAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get favoriteAdd;

  /// No description provided for @favoriteRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des favoris'**
  String get favoriteRemove;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun favori'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Touchez le cœur sur un profil pour le retrouver ici.'**
  String get favoritesEmptyBody;

  /// No description provided for @favoritesSignInTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retrouvez vos favoris'**
  String get favoritesSignInTitle;

  /// No description provided for @favoritesSignInBody.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour enregistrer des professionnels et les retrouver sur tous vos appareils.'**
  String get favoritesSignInBody;

  /// No description provided for @favoriteLimit.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez atteint la limite de 200 favoris.'**
  String get favoriteLimit;

  /// No description provided for @favoriteFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de modifier vos favoris. Réessayez.'**
  String get favoriteFailed;

  /// No description provided for @favoriteAddNamed.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter {name} aux favoris'**
  String favoriteAddNamed(String name);

  /// No description provided for @favoriteRemoveNamed.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name} des favoris'**
  String favoriteRemoveNamed(String name);

  /// No description provided for @nearMe.
  ///
  /// In fr, this message translates to:
  /// **'Près de moi'**
  String get nearMe;

  /// No description provided for @sortNearest.
  ///
  /// In fr, this message translates to:
  /// **'Plus proches'**
  String get sortNearest;

  /// No description provided for @filterRadius.
  ///
  /// In fr, this message translates to:
  /// **'Distance maximale'**
  String get filterRadius;

  /// No description provided for @filterRadiusAny.
  ///
  /// In fr, this message translates to:
  /// **'Peu importe'**
  String get filterRadiusAny;

  /// No description provided for @locationDenied.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez la localisation pour voir les professionnels près de vous.'**
  String get locationDenied;

  /// No description provided for @locationDeniedForever.
  ///
  /// In fr, this message translates to:
  /// **'La localisation est bloquée. Autorisez-la dans les réglages.'**
  String get locationDeniedForever;

  /// No description provided for @locationServiceOff.
  ///
  /// In fr, this message translates to:
  /// **'La localisation est désactivée sur cet appareil.'**
  String get locationServiceOff;

  /// No description provided for @locationUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Position introuvable. Réessayez.'**
  String get locationUnavailable;

  /// No description provided for @openSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get openSettings;

  /// No description provided for @showMap.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la carte'**
  String get showMap;

  /// No description provided for @showList.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la liste'**
  String get showList;

  /// No description provided for @mapNothingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rien à placer sur la carte'**
  String get mapNothingTitle;

  /// No description provided for @mapNothingBody.
  ///
  /// In fr, this message translates to:
  /// **'Aucun de ces professionnels n’a de position connue.'**
  String get mapNothingBody;
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
