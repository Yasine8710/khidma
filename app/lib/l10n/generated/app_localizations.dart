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

  /// No description provided for @acctMemberCard.
  ///
  /// In fr, this message translates to:
  /// **'Carte de membre'**
  String get acctMemberCard;

  /// No description provided for @acctAccountType.
  ///
  /// In fr, this message translates to:
  /// **'Type de compte'**
  String get acctAccountType;

  /// No description provided for @acctCustomer.
  ///
  /// In fr, this message translates to:
  /// **'Client'**
  String get acctCustomer;

  /// No description provided for @acctSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get acctSettings;

  /// No description provided for @acctAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get acctAccount;

  /// No description provided for @acctWorkshop.
  ///
  /// In fr, this message translates to:
  /// **'Atelier'**
  String get acctWorkshop;

  /// No description provided for @acctStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get acctStatus;

  /// No description provided for @acctTools.
  ///
  /// In fr, this message translates to:
  /// **'Outils'**
  String get acctTools;

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

  /// No description provided for @discLicenceKicker.
  ///
  /// In fr, this message translates to:
  /// **'Fiche professionnelle'**
  String get discLicenceKicker;

  /// No description provided for @discFactExperience.
  ///
  /// In fr, this message translates to:
  /// **'Expérience'**
  String get discFactExperience;

  /// No description provided for @discFactAvailability.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilité'**
  String get discFactAvailability;

  /// No description provided for @discFactArea.
  ///
  /// In fr, this message translates to:
  /// **'Zone'**
  String get discFactArea;

  /// No description provided for @discHintPlumbing.
  ///
  /// In fr, this message translates to:
  /// **'Fuites, sanitaires, chauffe-eau'**
  String get discHintPlumbing;

  /// No description provided for @discHintElectricity.
  ///
  /// In fr, this message translates to:
  /// **'Installations, pannes, tableaux'**
  String get discHintElectricity;

  /// No description provided for @discHintAirConditioning.
  ///
  /// In fr, this message translates to:
  /// **'Pose, entretien, réparation'**
  String get discHintAirConditioning;

  /// No description provided for @discHintMechanics.
  ///
  /// In fr, this message translates to:
  /// **'Réparation et entretien de véhicules'**
  String get discHintMechanics;

  /// No description provided for @discHintPainting.
  ///
  /// In fr, this message translates to:
  /// **'Intérieur et extérieur'**
  String get discHintPainting;

  /// No description provided for @discHintCarpentry.
  ///
  /// In fr, this message translates to:
  /// **'Meubles, portes, fenêtres en bois'**
  String get discHintCarpentry;

  /// No description provided for @discHintCleaning.
  ///
  /// In fr, this message translates to:
  /// **'Maisons, bureaux, fin de chantier'**
  String get discHintCleaning;

  /// No description provided for @discHintAppliance.
  ///
  /// In fr, this message translates to:
  /// **'Lave-linge, réfrigérateurs, fours'**
  String get discHintAppliance;

  /// No description provided for @discHintConstruction.
  ///
  /// In fr, this message translates to:
  /// **'Maçonnerie, carrelage, rénovation'**
  String get discHintConstruction;

  /// No description provided for @discHintGardening.
  ///
  /// In fr, this message translates to:
  /// **'Jardins et espaces verts'**
  String get discHintGardening;

  /// No description provided for @discHintMoving.
  ///
  /// In fr, this message translates to:
  /// **'Transport et déménagement'**
  String get discHintMoving;

  /// No description provided for @discHintMaintenance.
  ///
  /// In fr, this message translates to:
  /// **'Petits travaux et dépannage'**
  String get discHintMaintenance;

  /// No description provided for @homeQuoteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Besoin d’un service ?'**
  String get homeQuoteTitle;

  /// No description provided for @homeQuoteBody.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez-le une fois et recevez des offres de professionnels.'**
  String get homeQuoteBody;

  /// No description provided for @avatarChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer la photo'**
  String get avatarChange;

  /// No description provided for @avatarChoose.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo'**
  String get avatarChoose;

  /// No description provided for @avatarRemove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo'**
  String get avatarRemove;

  /// No description provided for @avatarFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de mettre à jour votre photo. Essayez une autre image.'**
  String get avatarFailed;

  /// No description provided for @avatarLabel.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil'**
  String get avatarLabel;

  /// No description provided for @statRating.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get statRating;

  /// No description provided for @statReviews.
  ///
  /// In fr, this message translates to:
  /// **'Avis'**
  String get statReviews;

  /// No description provided for @statYears.
  ///
  /// In fr, this message translates to:
  /// **'Années'**
  String get statYears;

  /// No description provided for @billTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement'**
  String get billTitle;

  /// No description provided for @billCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Mon abonnement'**
  String get billCurrent;

  /// No description provided for @billNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun abonnement pour le moment.'**
  String get billNone;

  /// No description provided for @billStatusLabel.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get billStatusLabel;

  /// No description provided for @billStatusActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get billStatusActive;

  /// No description provided for @billStatusPastDue.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get billStatusPastDue;

  /// No description provided for @billStatusExpired.
  ///
  /// In fr, this message translates to:
  /// **'Expiré'**
  String get billStatusExpired;

  /// No description provided for @billStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Résilié'**
  String get billStatusCancelled;

  /// No description provided for @billValidUntil.
  ///
  /// In fr, this message translates to:
  /// **'Valable jusqu\'au'**
  String get billValidUntil;

  /// No description provided for @billDaysLeftLabel.
  ///
  /// In fr, this message translates to:
  /// **'Jours restants'**
  String get billDaysLeftLabel;

  /// No description provided for @billDaysLeft.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Expire aujourd\'hui} =1{1 jour restant} other{{count} jours restants}}'**
  String billDaysLeft(int count);

  /// No description provided for @billChoosePlan.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une formule'**
  String get billChoosePlan;

  /// No description provided for @billPeriod.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 jour} other{{count} jours}}'**
  String billPeriod(int count);

  /// No description provided for @billChooseMethod.
  ///
  /// In fr, this message translates to:
  /// **'Mode de paiement'**
  String get billChooseMethod;

  /// No description provided for @billMethodFlouci.
  ///
  /// In fr, this message translates to:
  /// **'Flouci'**
  String get billMethodFlouci;

  /// No description provided for @billMethodFlouciHint.
  ///
  /// In fr, this message translates to:
  /// **'Paiement en ligne, confirmé automatiquement'**
  String get billMethodFlouciHint;

  /// No description provided for @billMethodD17.
  ///
  /// In fr, this message translates to:
  /// **'D17'**
  String get billMethodD17;

  /// No description provided for @billMethodD17Hint.
  ///
  /// In fr, this message translates to:
  /// **'Envoi depuis votre portefeuille La Poste, confirmé par notre équipe'**
  String get billMethodD17Hint;

  /// No description provided for @billMethodBank.
  ///
  /// In fr, this message translates to:
  /// **'Virement bancaire'**
  String get billMethodBank;

  /// No description provided for @billMethodBankHint.
  ///
  /// In fr, this message translates to:
  /// **'Virement vers notre compte, confirmé par notre équipe'**
  String get billMethodBankHint;

  /// No description provided for @billPay.
  ///
  /// In fr, this message translates to:
  /// **'Payer'**
  String get billPay;

  /// No description provided for @billFlouciOpened.
  ///
  /// In fr, this message translates to:
  /// **'Le paiement s\'est ouvert dans votre navigateur. Revenez ici ensuite.'**
  String get billFlouciOpened;

  /// No description provided for @billMyPayments.
  ///
  /// In fr, this message translates to:
  /// **'Mes paiements'**
  String get billMyPayments;

  /// No description provided for @billNoPayments.
  ///
  /// In fr, this message translates to:
  /// **'Aucun paiement pour le moment.'**
  String get billNoPayments;

  /// No description provided for @billOrderPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get billOrderPending;

  /// No description provided for @billOrderAwaiting.
  ///
  /// In fr, this message translates to:
  /// **'À confirmer'**
  String get billOrderAwaiting;

  /// No description provided for @billOrderPaid.
  ///
  /// In fr, this message translates to:
  /// **'Payé'**
  String get billOrderPaid;

  /// No description provided for @billOrderFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échoué'**
  String get billOrderFailed;

  /// No description provided for @billOrderCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get billOrderCancelled;

  /// No description provided for @billOrderRejected.
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get billOrderRejected;

  /// No description provided for @billInstructionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Instructions de paiement'**
  String get billInstructionsTitle;

  /// No description provided for @billAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get billAmount;

  /// No description provided for @billReference.
  ///
  /// In fr, this message translates to:
  /// **'Référence'**
  String get billReference;

  /// No description provided for @billReferenceHint.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez cette référence dans le motif du virement ou la note D17.'**
  String get billReferenceHint;

  /// No description provided for @billCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get billCopy;

  /// No description provided for @billCopied.
  ///
  /// In fr, this message translates to:
  /// **'Copié'**
  String get billCopied;

  /// No description provided for @billPayTo.
  ///
  /// In fr, this message translates to:
  /// **'Payer à'**
  String get billPayTo;

  /// No description provided for @billBankName.
  ///
  /// In fr, this message translates to:
  /// **'Banque'**
  String get billBankName;

  /// No description provided for @billHolder.
  ///
  /// In fr, this message translates to:
  /// **'Titulaire'**
  String get billHolder;

  /// No description provided for @billRib.
  ///
  /// In fr, this message translates to:
  /// **'RIB'**
  String get billRib;

  /// No description provided for @billD17Number.
  ///
  /// In fr, this message translates to:
  /// **'Numéro D17'**
  String get billD17Number;

  /// No description provided for @billNoDetails.
  ///
  /// In fr, this message translates to:
  /// **'Les coordonnées de paiement ne sont pas encore disponibles.'**
  String get billNoDetails;

  /// No description provided for @billIPaid.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai payé'**
  String get billIPaid;

  /// No description provided for @billPaidTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre paiement'**
  String get billPaidTitle;

  /// No description provided for @billNoteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Note (facultatif)'**
  String get billNoteLabel;

  /// No description provided for @billSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get billSend;

  /// No description provided for @billCancelOrder.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la commande'**
  String get billCancelOrder;

  /// No description provided for @billAwaitingBody.
  ///
  /// In fr, this message translates to:
  /// **'Merci. Notre équipe vérifie votre paiement, votre abonnement démarre dès sa confirmation.'**
  String get billAwaitingBody;

  /// No description provided for @billNotProTitle.
  ///
  /// In fr, this message translates to:
  /// **'Devenez professionnel d\'abord'**
  String get billNotProTitle;

  /// No description provided for @billNotProBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'abonnement est réservé aux professionnels. Créez d\'abord votre profil.'**
  String get billNotProBody;

  /// No description provided for @billNotProCta.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon profil'**
  String get billNotProCta;

  /// No description provided for @billErrNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion. Réessayez.'**
  String get billErrNetwork;

  /// No description provided for @billErrSignedIn.
  ///
  /// In fr, this message translates to:
  /// **'Reconnectez-vous puis réessayez.'**
  String get billErrSignedIn;

  /// No description provided for @billErrRate.
  ///
  /// In fr, this message translates to:
  /// **'Trop de commandes aujourd\'hui. Réessayez demain.'**
  String get billErrRate;

  /// No description provided for @billErrInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande n\'est pas valide.'**
  String get billErrInvalid;

  /// No description provided for @billErrNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Cette commande n\'existe plus.'**
  String get billErrNotFound;

  /// No description provided for @billErrNotConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Les paiements ne sont pas encore disponibles.'**
  String get billErrNotConfigured;

  /// No description provided for @billFlouciUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Flouci n\'est pas encore disponible, utilisez D17 ou le virement.'**
  String get billFlouciUnavailable;

  /// No description provided for @billCannotOpen.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir le lien de paiement.'**
  String get billCannotOpen;

  /// No description provided for @billErrUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get billErrUnknown;

  /// No description provided for @flTitle.
  ///
  /// In fr, this message translates to:
  /// **'Services digitaux'**
  String get flTitle;

  /// No description provided for @flHomeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Développeurs, designers, monteurs, rédacteurs…'**
  String get flHomeSubtitle;

  /// No description provided for @flSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un freelance ou une compétence…'**
  String get flSearchHint;

  /// No description provided for @flCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get flCategories;

  /// No description provided for @flAllCategories.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get flAllCategories;

  /// No description provided for @flResultsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Freelances'**
  String get flResultsTitle;

  /// No description provided for @flEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun freelance trouvé'**
  String get flEmptyTitle;

  /// No description provided for @flEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Essayez un autre mot ou une autre catégorie.'**
  String get flEmptyBody;

  /// No description provided for @flLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les freelances.'**
  String get flLoadFailed;

  /// No description provided for @flPriceFrom.
  ///
  /// In fr, this message translates to:
  /// **'à partir de {price} / {unit}'**
  String flPriceFrom(String price, String unit);

  /// No description provided for @flUnitProject.
  ///
  /// In fr, this message translates to:
  /// **'projet'**
  String get flUnitProject;

  /// No description provided for @flUnitHour.
  ///
  /// In fr, this message translates to:
  /// **'heure'**
  String get flUnitHour;

  /// No description provided for @flUnitDay.
  ///
  /// In fr, this message translates to:
  /// **'jour'**
  String get flUnitDay;

  /// No description provided for @flNotFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Freelance introuvable'**
  String get flNotFoundTitle;

  /// No description provided for @flNotFoundBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette page n’existe plus ou n’est pas publiée.'**
  String get flNotFoundBody;

  /// No description provided for @flFactPrice.
  ///
  /// In fr, this message translates to:
  /// **'Tarif'**
  String get flFactPrice;

  /// No description provided for @flFactLanguages.
  ///
  /// In fr, this message translates to:
  /// **'Langues'**
  String get flFactLanguages;

  /// No description provided for @flSkills.
  ///
  /// In fr, this message translates to:
  /// **'Compétences'**
  String get flSkills;

  /// No description provided for @flPortfolio.
  ///
  /// In fr, this message translates to:
  /// **'Réalisations'**
  String get flPortfolio;

  /// No description provided for @flOpenItem.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir : {title}'**
  String flOpenItem(String title);

  /// No description provided for @flKindImage.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get flKindImage;

  /// No description provided for @flKindClip.
  ///
  /// In fr, this message translates to:
  /// **'Clip vidéo'**
  String get flKindClip;

  /// No description provided for @flKindVideoLink.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo en ligne'**
  String get flKindVideoLink;

  /// No description provided for @flKindLink.
  ///
  /// In fr, this message translates to:
  /// **'Lien'**
  String get flKindLink;

  /// No description provided for @flTestimonials.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages clients'**
  String get flTestimonials;

  /// No description provided for @flTestimonialLabel.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage client'**
  String get flTestimonialLabel;

  /// No description provided for @flTestimonialsNote.
  ///
  /// In fr, this message translates to:
  /// **'Ces témoignages viennent d’anciens clients invités par le freelance. Ils sont différents des avis vérifiés laissés après un travail réalisé via Khidma.'**
  String get flTestimonialsNote;

  /// No description provided for @flTestimonialsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de témoignage.'**
  String get flTestimonialsEmpty;

  /// No description provided for @flTestimonialProject.
  ///
  /// In fr, this message translates to:
  /// **'Projet : {title}'**
  String flTestimonialProject(String title);

  /// No description provided for @flStars.
  ///
  /// In fr, this message translates to:
  /// **'{count} sur 5'**
  String flStars(int count);

  /// No description provided for @flDashRow.
  ///
  /// In fr, this message translates to:
  /// **'Activité freelance'**
  String get flDashRow;

  /// No description provided for @flManageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon activité freelance'**
  String get flManageTitle;

  /// No description provided for @flIntroTitle.
  ///
  /// In fr, this message translates to:
  /// **'Proposez vos services digitaux'**
  String get flIntroTitle;

  /// No description provided for @flIntroBody.
  ///
  /// In fr, this message translates to:
  /// **'Développement, design, montage, marketing, rédaction… Créez une page publique avec vos réalisations et des témoignages clients. Votre identité vérifiée est la même que pour votre profil de métier : une seule vérification suffit.'**
  String get flIntroBody;

  /// No description provided for @flBecome.
  ///
  /// In fr, this message translates to:
  /// **'Devenir freelance'**
  String get flBecome;

  /// No description provided for @flSectionProfile.
  ///
  /// In fr, this message translates to:
  /// **'Ma page'**
  String get flSectionProfile;

  /// No description provided for @flFieldName.
  ///
  /// In fr, this message translates to:
  /// **'Nom affiché'**
  String get flFieldName;

  /// No description provided for @flFieldHeadline.
  ///
  /// In fr, this message translates to:
  /// **'Titre professionnel'**
  String get flFieldHeadline;

  /// No description provided for @flFieldHeadlineHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Développeur Flutter'**
  String get flFieldHeadlineHint;

  /// No description provided for @flFieldCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get flFieldCategory;

  /// No description provided for @flFieldBio.
  ///
  /// In fr, this message translates to:
  /// **'Présentation'**
  String get flFieldBio;

  /// No description provided for @flFieldBioHelp.
  ///
  /// In fr, this message translates to:
  /// **'20 caractères minimum pour publier, 2000 au maximum.'**
  String get flFieldBioHelp;

  /// No description provided for @flFieldSkills.
  ///
  /// In fr, this message translates to:
  /// **'Compétences'**
  String get flFieldSkills;

  /// No description provided for @flFieldSkillsHelp.
  ///
  /// In fr, this message translates to:
  /// **'Séparées par des virgules, 12 au maximum.'**
  String get flFieldSkillsHelp;

  /// No description provided for @flFieldLanguages.
  ///
  /// In fr, this message translates to:
  /// **'Langues'**
  String get flFieldLanguages;

  /// No description provided for @flFieldLanguagesHelp.
  ///
  /// In fr, this message translates to:
  /// **'Séparées par des virgules, 6 au maximum.'**
  String get flFieldLanguagesHelp;

  /// No description provided for @flFieldYears.
  ///
  /// In fr, this message translates to:
  /// **'Années d’expérience'**
  String get flFieldYears;

  /// No description provided for @flFieldPrice.
  ///
  /// In fr, this message translates to:
  /// **'Tarif de départ (DT)'**
  String get flFieldPrice;

  /// No description provided for @flFieldUnit.
  ///
  /// In fr, this message translates to:
  /// **'Par'**
  String get flFieldUnit;

  /// No description provided for @flFieldAvailability.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilité'**
  String get flFieldAvailability;

  /// No description provided for @flErrName.
  ///
  /// In fr, this message translates to:
  /// **'2 à 80 caractères.'**
  String get flErrName;

  /// No description provided for @flErrHeadline.
  ///
  /// In fr, this message translates to:
  /// **'5 à 100 caractères.'**
  String get flErrHeadline;

  /// No description provided for @flErrBio.
  ///
  /// In fr, this message translates to:
  /// **'2000 caractères au maximum.'**
  String get flErrBio;

  /// No description provided for @flErrYears.
  ///
  /// In fr, this message translates to:
  /// **'Entre 0 et 60.'**
  String get flErrYears;

  /// No description provided for @flErrPrice.
  ///
  /// In fr, this message translates to:
  /// **'Montant invalide.'**
  String get flErrPrice;

  /// No description provided for @flErrTags.
  ///
  /// In fr, this message translates to:
  /// **'30 caractères par élément, {max} éléments au plus.'**
  String flErrTags(int max);

  /// No description provided for @flSaved.
  ///
  /// In fr, this message translates to:
  /// **'Page enregistrée.'**
  String get flSaved;

  /// No description provided for @flIdentityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get flIdentityTitle;

  /// No description provided for @flIdentityVerified.
  ///
  /// In fr, this message translates to:
  /// **'Identité vérifiée.'**
  String get flIdentityVerified;

  /// No description provided for @flIdentityNotVerified.
  ///
  /// In fr, this message translates to:
  /// **'Identité pas encore vérifiée.'**
  String get flIdentityNotVerified;

  /// No description provided for @flIdentityShared.
  ///
  /// In fr, this message translates to:
  /// **'Une seule vérification sert à votre profil de métier et à votre page freelance.'**
  String get flIdentityShared;

  /// No description provided for @flPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier ma page'**
  String get flPublish;

  /// No description provided for @flPublishedHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre page est visible dans Services digitaux.'**
  String get flPublishedHint;

  /// No description provided for @flUnpublishedHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre page n’est pas visible pour le moment.'**
  String get flUnpublishedHint;

  /// No description provided for @flPublishBlocked.
  ///
  /// In fr, this message translates to:
  /// **'La publication est bloquée tant que votre identité n’est pas vérifiée.'**
  String get flPublishBlocked;

  /// No description provided for @flErrNotVerified.
  ///
  /// In fr, this message translates to:
  /// **'Votre identité n’est pas encore vérifiée. Faites-la vérifier pour publier.'**
  String get flErrNotVerified;

  /// No description provided for @flErrIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'Page incomplète : ajoutez un numéro de téléphone de contact dans votre profil de métier, puis renseignez nom, titre, catégorie et présentation (20 caractères minimum).'**
  String get flErrIncomplete;

  /// No description provided for @flErrSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte est suspendu : la publication est impossible.'**
  String get flErrSuspended;

  /// No description provided for @flErrGeneric.
  ///
  /// In fr, this message translates to:
  /// **'L’opération a échoué. Vérifiez votre connexion et réessayez.'**
  String get flErrGeneric;

  /// No description provided for @flErrNotConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Le service n’est pas disponible pour le moment.'**
  String get flErrNotConfigured;

  /// No description provided for @flErrInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Certaines informations sont refusées. Vérifiez-les et réessayez.'**
  String get flErrInvalid;

  /// No description provided for @flErrRate.
  ///
  /// In fr, this message translates to:
  /// **'Trop de demandes. Réessayez plus tard.'**
  String get flErrRate;

  /// No description provided for @flPortCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} sur {max} réalisations'**
  String flPortCount(int count, int max);

  /// No description provided for @flPortEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune réalisation pour le moment.'**
  String get flPortEmpty;

  /// No description provided for @flPortAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get flPortAddPhoto;

  /// No description provided for @flPortAddClip.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un clip (30 s max)'**
  String get flPortAddClip;

  /// No description provided for @flPortAddVideoLink.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une vidéo en ligne'**
  String get flPortAddVideoLink;

  /// No description provided for @flPortAddLink.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un lien'**
  String get flPortAddLink;

  /// No description provided for @flPortLimit.
  ///
  /// In fr, this message translates to:
  /// **'Limite de 24 réalisations atteinte.'**
  String get flPortLimit;

  /// No description provided for @flPortTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Fichier trop lourd (25 Mo au maximum).'**
  String get flPortTooLarge;

  /// No description provided for @flPortBadFormat.
  ///
  /// In fr, this message translates to:
  /// **'Format non pris en charge : utilisez un clip mp4 ou webm, ou ajoutez un lien vidéo.'**
  String get flPortBadFormat;

  /// No description provided for @flFieldTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get flFieldTitle;

  /// No description provided for @flFieldDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description (facultatif)'**
  String get flFieldDescription;

  /// No description provided for @flFieldUrl.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du lien'**
  String get flFieldUrl;

  /// No description provided for @flErrTitle.
  ///
  /// In fr, this message translates to:
  /// **'2 à 100 caractères.'**
  String get flErrTitle;

  /// No description provided for @flErrDescription.
  ///
  /// In fr, this message translates to:
  /// **'500 caractères au maximum.'**
  String get flErrDescription;

  /// No description provided for @flErrUrlVideo.
  ///
  /// In fr, this message translates to:
  /// **'Lien https YouTube ou Vimeo uniquement.'**
  String get flErrUrlVideo;

  /// No description provided for @flErrUrlLink.
  ///
  /// In fr, this message translates to:
  /// **'Entrez une adresse https valide.'**
  String get flErrUrlLink;

  /// No description provided for @flSheetAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get flSheetAdd;

  /// No description provided for @flSheetChooseFile.
  ///
  /// In fr, this message translates to:
  /// **'Choisir le fichier'**
  String get flSheetChooseFile;

  /// No description provided for @flItemEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get flItemEdit;

  /// No description provided for @flItemDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get flItemDelete;

  /// No description provided for @flItemDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette réalisation ?'**
  String get flItemDeleteTitle;

  /// No description provided for @flItemDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'Elle ne sera plus visible sur votre page.'**
  String get flItemDeleteBody;

  /// No description provided for @flUploading.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours…'**
  String get flUploading;

  /// No description provided for @flInvTitle.
  ///
  /// In fr, this message translates to:
  /// **'Invitations de témoignage'**
  String get flInvTitle;

  /// No description provided for @flInvHint.
  ///
  /// In fr, this message translates to:
  /// **'Envoyez un lien personnel à un ancien client : il écrit son témoignage sur une page web, sans compte. Le lien est valable 30 jours et ne sert qu’une fois.'**
  String get flInvHint;

  /// No description provided for @flInvCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer un lien d’invitation'**
  String get flInvCreate;

  /// No description provided for @flInvLabelField.
  ///
  /// In fr, this message translates to:
  /// **'Pour qui ? (facultatif)'**
  String get flInvLabelField;

  /// No description provided for @flInvNotConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Les liens de témoignage ne sont pas encore configurés dans cette version de l’application.'**
  String get flInvNotConfigured;

  /// No description provided for @flInvLinkTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lien créé'**
  String get flInvLinkTitle;

  /// No description provided for @flInvLinkWarn.
  ///
  /// In fr, this message translates to:
  /// **'Copiez-le maintenant : il ne sera plus affiché.'**
  String get flInvLinkWarn;

  /// No description provided for @flInvCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien'**
  String get flInvCopy;

  /// No description provided for @flInvCopied.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié.'**
  String get flInvCopied;

  /// No description provided for @flInvShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager par WhatsApp'**
  String get flInvShare;

  /// No description provided for @flInvShareText.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour, pourriez-vous laisser un témoignage sur notre collaboration ? {url}'**
  String flInvShareText(String url);

  /// No description provided for @flInvEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune invitation pour le moment.'**
  String get flInvEmpty;

  /// No description provided for @flInvStatusOpen.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get flInvStatusOpen;

  /// No description provided for @flInvStatusUsed.
  ///
  /// In fr, this message translates to:
  /// **'Utilisée'**
  String get flInvStatusUsed;

  /// No description provided for @flInvStatusExpired.
  ///
  /// In fr, this message translates to:
  /// **'Expirée'**
  String get flInvStatusExpired;

  /// No description provided for @flInvExpires.
  ///
  /// In fr, this message translates to:
  /// **'Expire le {date}'**
  String flInvExpires(String date);

  /// No description provided for @flInvNoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Sans nom'**
  String get flInvNoLabel;

  /// No description provided for @flInvRevoke.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer'**
  String get flInvRevoke;

  /// No description provided for @flInvRevokeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer cette invitation ?'**
  String get flInvRevokeTitle;

  /// No description provided for @flInvRevokeBody.
  ///
  /// In fr, this message translates to:
  /// **'Le lien ne fonctionnera plus.'**
  String get flInvRevokeBody;

  /// No description provided for @flInvLimit.
  ///
  /// In fr, this message translates to:
  /// **'20 invitations en attente au maximum.'**
  String get flInvLimit;

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

  /// No description provided for @regTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil professionnel'**
  String get regTitle;

  /// No description provided for @regStepOf.
  ///
  /// In fr, this message translates to:
  /// **'Étape {current} sur {total}'**
  String regStepOf(int current, int total);

  /// No description provided for @regNext.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get regNext;

  /// No description provided for @regBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get regBack;

  /// No description provided for @regStepBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Votre activité'**
  String get regStepBusiness;

  /// No description provided for @regStepLocation.
  ///
  /// In fr, this message translates to:
  /// **'Où travaillez-vous ?'**
  String get regStepLocation;

  /// No description provided for @regStepAreas.
  ///
  /// In fr, this message translates to:
  /// **'Zones d’intervention'**
  String get regStepAreas;

  /// No description provided for @regStepServices.
  ///
  /// In fr, this message translates to:
  /// **'Autres services'**
  String get regStepServices;

  /// No description provided for @regStepContact.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get regStepContact;

  /// No description provided for @regStepReview.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier et publier'**
  String get regStepReview;

  /// No description provided for @regBusinessName.
  ///
  /// In fr, this message translates to:
  /// **'Nom affiché (entreprise ou personne)'**
  String get regBusinessName;

  /// No description provided for @regYears.
  ///
  /// In fr, this message translates to:
  /// **'Années d’expérience (facultatif)'**
  String get regYears;

  /// No description provided for @regCategory.
  ///
  /// In fr, this message translates to:
  /// **'Métier principal'**
  String get regCategory;

  /// No description provided for @regDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description de vos services'**
  String get regDescription;

  /// No description provided for @regDescriptionHelper.
  ///
  /// In fr, this message translates to:
  /// **'Au moins 20 caractères.'**
  String get regDescriptionHelper;

  /// No description provided for @regGovernorate.
  ///
  /// In fr, this message translates to:
  /// **'Gouvernorat'**
  String get regGovernorate;

  /// No description provided for @regCity.
  ///
  /// In fr, this message translates to:
  /// **'Ville (facultatif)'**
  String get regCity;

  /// No description provided for @regAreasBody.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez les gouvernorats où vous vous déplacez, en plus du vôtre.'**
  String get regAreasBody;

  /// No description provided for @regServicesBody.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez d’autres services que vous proposez.'**
  String get regServicesBody;

  /// No description provided for @regPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone de contact'**
  String get regPhone;

  /// No description provided for @regPhoneHelper.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les membres connectés le voient, et seulement s’ils le demandent.'**
  String get regPhoneHelper;

  /// No description provided for @regPhotoLater.
  ///
  /// In fr, this message translates to:
  /// **'La photo de profil arrive bientôt.'**
  String get regPhotoLater;

  /// No description provided for @regErrName.
  ///
  /// In fr, this message translates to:
  /// **'Entre 2 et 120 caractères.'**
  String get regErrName;

  /// No description provided for @regErrDescription.
  ///
  /// In fr, this message translates to:
  /// **'Entre 20 et 2000 caractères.'**
  String get regErrDescription;

  /// No description provided for @regErrCategory.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un métier.'**
  String get regErrCategory;

  /// No description provided for @regErrGovernorate.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un gouvernorat.'**
  String get regErrGovernorate;

  /// No description provided for @regErrYears.
  ///
  /// In fr, this message translates to:
  /// **'Entre 0 et 60.'**
  String get regErrYears;

  /// No description provided for @regErrPhone.
  ///
  /// In fr, this message translates to:
  /// **'Numéro tunisien invalide (8 chiffres).'**
  String get regErrPhone;

  /// No description provided for @regReviewBody.
  ///
  /// In fr, this message translates to:
  /// **'Voici ce que verront les clients.'**
  String get regReviewBody;

  /// No description provided for @regPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier mon profil'**
  String get regPublish;

  /// No description provided for @regUnpublish.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la liste'**
  String get regUnpublish;

  /// No description provided for @regDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get regDone;

  /// No description provided for @regUsePosition.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser ma position actuelle'**
  String get regUsePosition;

  /// No description provided for @regPositionSet.
  ///
  /// In fr, this message translates to:
  /// **'Position approximative enregistrée (environ 1 km).'**
  String get regPositionSet;

  /// No description provided for @regPositionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Position introuvable. Vérifiez l’autorisation de localisation : sinon la carte utilisera votre gouvernorat.'**
  String get regPositionFailed;

  /// No description provided for @regSaveDraft.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer et quitter'**
  String get regSaveDraft;

  /// No description provided for @regPublished.
  ///
  /// In fr, this message translates to:
  /// **'Votre profil est publié.'**
  String get regPublished;

  /// No description provided for @regDraft.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon : invisible pour les clients.'**
  String get regDraft;

  /// No description provided for @regMissing.
  ///
  /// In fr, this message translates to:
  /// **'Pour publier, il manque : {items}.'**
  String regMissing(String items);

  /// No description provided for @gapName.
  ///
  /// In fr, this message translates to:
  /// **'le nom'**
  String get gapName;

  /// No description provided for @gapCategory.
  ///
  /// In fr, this message translates to:
  /// **'le métier'**
  String get gapCategory;

  /// No description provided for @gapDescription.
  ///
  /// In fr, this message translates to:
  /// **'la description'**
  String get gapDescription;

  /// No description provided for @gapLocation.
  ///
  /// In fr, this message translates to:
  /// **'le gouvernorat'**
  String get gapLocation;

  /// No description provided for @gapPhone.
  ///
  /// In fr, this message translates to:
  /// **'le téléphone'**
  String get gapPhone;

  /// No description provided for @regFailNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vos réponses sont conservées, réessayez.'**
  String get regFailNetwork;

  /// No description provided for @regFailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Certaines informations sont refusées. Vérifiez-les.'**
  String get regFailInvalid;

  /// No description provided for @regFailForbidden.
  ///
  /// In fr, this message translates to:
  /// **'Action non autorisée pour ce compte.'**
  String get regFailForbidden;

  /// No description provided for @regFailGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer. Réessayez.'**
  String get regFailGeneric;

  /// No description provided for @regFailNotConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Le service n’est pas disponible pour le moment.'**
  String get regFailNotConfigured;

  /// No description provided for @proCompleteCta.
  ///
  /// In fr, this message translates to:
  /// **'Compléter mon profil'**
  String get proCompleteCta;

  /// No description provided for @proEditCta.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon profil professionnel'**
  String get proEditCta;

  /// No description provided for @proStatusDraft.
  ///
  /// In fr, this message translates to:
  /// **'Profil non publié'**
  String get proStatusDraft;

  /// No description provided for @proStatusPublished.
  ///
  /// In fr, this message translates to:
  /// **'Profil publié'**
  String get proStatusPublished;

  /// No description provided for @dashTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon espace pro'**
  String get dashTitle;

  /// No description provided for @dashAvailability.
  ///
  /// In fr, this message translates to:
  /// **'Disponibilité'**
  String get dashAvailability;

  /// No description provided for @dashActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activité'**
  String get dashActivity;

  /// No description provided for @dashActivityNote.
  ///
  /// In fr, this message translates to:
  /// **'Chiffres anonymes, avec une heure de décalage : vous ne voyez pas qui a consulté ou enregistré votre profil.'**
  String get dashActivityNote;

  /// No description provided for @dashViews30d.
  ///
  /// In fr, this message translates to:
  /// **'Contacts consultés (30 jours)'**
  String get dashViews30d;

  /// No description provided for @dashViewsTotal.
  ///
  /// In fr, this message translates to:
  /// **'Contacts consultés (total)'**
  String get dashViewsTotal;

  /// No description provided for @dashFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrés en favoris'**
  String get dashFavorites;

  /// No description provided for @dashActivityFailed.
  ///
  /// In fr, this message translates to:
  /// **'Activité indisponible pour le moment.'**
  String get dashActivityFailed;

  /// No description provided for @dashViewPublic.
  ///
  /// In fr, this message translates to:
  /// **'Voir mon profil public'**
  String get dashViewPublic;

  /// No description provided for @dashSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Modification impossible. Réessayez.'**
  String get dashSaveFailed;

  /// No description provided for @dashRefreshFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’actualiser. Les chiffres affichés peuvent être anciens.'**
  String get dashRefreshFailed;

  /// No description provided for @portfolioTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes réalisations'**
  String get portfolioTitle;

  /// No description provided for @portfolioSection.
  ///
  /// In fr, this message translates to:
  /// **'Réalisations'**
  String get portfolioSection;

  /// No description provided for @portfolioAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get portfolioAdd;

  /// No description provided for @portfolioCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} sur {max} photos'**
  String portfolioCount(int count, int max);

  /// No description provided for @portfolioHint.
  ///
  /// In fr, this message translates to:
  /// **'Photos de vos travaux. Elles sont réduites automatiquement et leurs informations (position, appareil) sont retirées.'**
  String get portfolioHint;

  /// No description provided for @portfolioEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune photo pour le moment.'**
  String get portfolioEmpty;

  /// No description provided for @portfolioRemove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo'**
  String get portfolioRemove;

  /// No description provided for @portfolioRemoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette photo ?'**
  String get portfolioRemoveTitle;

  /// No description provided for @portfolioRemoveBody.
  ///
  /// In fr, this message translates to:
  /// **'Elle ne sera plus visible sur votre profil.'**
  String get portfolioRemoveBody;

  /// No description provided for @portfolioPhotoOf.
  ///
  /// In fr, this message translates to:
  /// **'Photo {index} sur {total}'**
  String portfolioPhotoOf(int index, int total);

  /// No description provided for @portfolioFailTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Cette photo est trop lourde, même réduite. Choisissez-en une autre.'**
  String get portfolioFailTooLarge;

  /// No description provided for @portfolioFailNotImage.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n’est pas une photo lisible (JPEG, PNG ou WebP).'**
  String get portfolioFailNotImage;

  /// No description provided for @portfolioFailLimit.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez atteint la limite de 12 photos.'**
  String get portfolioFailLimit;

  /// No description provided for @portfolioFailNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Réessayez.'**
  String get portfolioFailNetwork;

  /// No description provided for @portfolioFailGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de modifier vos photos. Réessayez.'**
  String get portfolioFailGeneric;

  /// No description provided for @portfolioFailNotConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Le service n’est pas disponible pour le moment.'**
  String get portfolioFailNotConfigured;

  /// No description provided for @portfolioPreparing.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de la photo…'**
  String get portfolioPreparing;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @reqNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle demande'**
  String get reqNew;

  /// No description provided for @reqMineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes demandes'**
  String get reqMineTitle;

  /// No description provided for @flowRef.
  ///
  /// In fr, this message translates to:
  /// **'N° {code}'**
  String flowRef(String code);

  /// No description provided for @flowRequestCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 demande} other{{count} demandes}}'**
  String flowRequestCount(int count);

  /// No description provided for @flowSecService.
  ///
  /// In fr, this message translates to:
  /// **'Service'**
  String get flowSecService;

  /// No description provided for @flowSecNeed.
  ///
  /// In fr, this message translates to:
  /// **'Le besoin'**
  String get flowSecNeed;

  /// No description provided for @flowSecWhere.
  ///
  /// In fr, this message translates to:
  /// **'Où'**
  String get flowSecWhere;

  /// No description provided for @flowSecWhen.
  ///
  /// In fr, this message translates to:
  /// **'Quand'**
  String get flowSecWhen;

  /// No description provided for @flowSecPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get flowSecPhotos;

  /// No description provided for @flowFactPlace.
  ///
  /// In fr, this message translates to:
  /// **'Lieu'**
  String get flowFactPlace;

  /// No description provided for @flowFactBudget.
  ///
  /// In fr, this message translates to:
  /// **'Budget indicatif'**
  String get flowFactBudget;

  /// No description provided for @flowFactNeededBy.
  ///
  /// In fr, this message translates to:
  /// **'Souhaité pour le'**
  String get flowFactNeededBy;

  /// No description provided for @flowFactExpires.
  ///
  /// In fr, this message translates to:
  /// **'Expire le'**
  String get flowFactExpires;

  /// No description provided for @reqEmptyCta.
  ///
  /// In fr, this message translates to:
  /// **'Demander un devis'**
  String get reqEmptyCta;

  /// No description provided for @reqStatusOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouverte'**
  String get reqStatusOpen;

  /// No description provided for @reqStatusAwarded.
  ///
  /// In fr, this message translates to:
  /// **'Attribuée'**
  String get reqStatusAwarded;

  /// No description provided for @reqStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get reqStatusCancelled;

  /// No description provided for @reqStatusExpired.
  ///
  /// In fr, this message translates to:
  /// **'Expirée'**
  String get reqStatusExpired;

  /// No description provided for @reqOffers.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune offre} =1{1 offre} other{{count} offres}}'**
  String reqOffers(int count);

  /// No description provided for @reqFormTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get reqFormTitle;

  /// No description provided for @reqFormTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Fuite sous l’évier'**
  String get reqFormTitleHint;

  /// No description provided for @reqFormDescription.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème'**
  String get reqFormDescription;

  /// No description provided for @reqFormDescriptionHelper.
  ///
  /// In fr, this message translates to:
  /// **'Au moins 10 caractères.'**
  String get reqFormDescriptionHelper;

  /// No description provided for @reqFormCategory.
  ///
  /// In fr, this message translates to:
  /// **'Type de service'**
  String get reqFormCategory;

  /// No description provided for @reqFormBudget.
  ///
  /// In fr, this message translates to:
  /// **'Budget indicatif en TND (facultatif)'**
  String get reqFormBudget;

  /// No description provided for @reqFormNeededBy.
  ///
  /// In fr, this message translates to:
  /// **'Pour quand ? (facultatif)'**
  String get reqFormNeededBy;

  /// No description provided for @reqFormNeededByNone.
  ///
  /// In fr, this message translates to:
  /// **'Pas de date'**
  String get reqFormNeededByNone;

  /// No description provided for @reqFormPickDate.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date'**
  String get reqFormPickDate;

  /// No description provided for @reqFormPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos (facultatif)'**
  String get reqFormPhotos;

  /// No description provided for @reqFormAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get reqFormAddPhoto;

  /// No description provided for @reqFormPhotosCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} sur {max} photos'**
  String reqFormPhotosCount(int count, int max);

  /// No description provided for @reqFormRemovePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la photo {index}'**
  String reqFormRemovePhoto(int index);

  /// No description provided for @reqFormSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la demande'**
  String get reqFormSubmit;

  /// No description provided for @reqFormPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Les professionnels verront votre demande et vos photos, jamais votre nom ni votre numéro.'**
  String get reqFormPrivacy;

  /// No description provided for @reqErrTitle.
  ///
  /// In fr, this message translates to:
  /// **'Entre 3 et 120 caractères.'**
  String get reqErrTitle;

  /// No description provided for @reqErrDescription.
  ///
  /// In fr, this message translates to:
  /// **'Entre 10 et 2000 caractères.'**
  String get reqErrDescription;

  /// No description provided for @reqErrCategory.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un type de service.'**
  String get reqErrCategory;

  /// No description provided for @reqErrGovernorate.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un gouvernorat.'**
  String get reqErrGovernorate;

  /// No description provided for @reqErrBudget.
  ///
  /// In fr, this message translates to:
  /// **'Montant invalide (0 à 1 000 000).'**
  String get reqErrBudget;

  /// No description provided for @reqSent.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée.'**
  String get reqSent;

  /// No description provided for @reqSentPhotosFailed.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée, mais certaines photos n’ont pas pu être ajoutées.'**
  String get reqSentPhotosFailed;

  /// No description provided for @reqFailNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Votre saisie est conservée, réessayez.'**
  String get reqFailNetwork;

  /// No description provided for @reqFailRateLimited.
  ///
  /// In fr, this message translates to:
  /// **'Trop de demandes en peu de temps. Réessayez dans une heure.'**
  String get reqFailRateLimited;

  /// No description provided for @reqFailLimit.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà 10 demandes ouvertes. Annulez-en une avant d’en créer une autre.'**
  String get reqFailLimit;

  /// No description provided for @reqFailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Certaines informations sont refusées. Vérifiez-les.'**
  String get reqFailInvalid;

  /// No description provided for @reqFailNotOpen.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande n’est plus ouverte.'**
  String get reqFailNotOpen;

  /// No description provided for @reqFailGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’envoyer la demande. Réessayez.'**
  String get reqFailGeneric;

  /// No description provided for @reqFailNotConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Le service n’est pas disponible pour le moment.'**
  String get reqFailNotConfigured;

  /// No description provided for @reqDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demande'**
  String get reqDetailTitle;

  /// No description provided for @reqNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Demande introuvable.'**
  String get reqNotFound;

  /// No description provided for @reqExpiresOn.
  ///
  /// In fr, this message translates to:
  /// **'Expire le {date}'**
  String reqExpiresOn(String date);

  /// No description provided for @reqNeededBy.
  ///
  /// In fr, this message translates to:
  /// **'Souhaité pour le {date}'**
  String reqNeededBy(String date);

  /// No description provided for @reqBudget.
  ///
  /// In fr, this message translates to:
  /// **'Budget indicatif : {amount}'**
  String reqBudget(String amount);

  /// No description provided for @reqCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get reqCancel;

  /// No description provided for @reqCancelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler cette demande ?'**
  String get reqCancelTitle;

  /// No description provided for @reqCancelBody.
  ///
  /// In fr, this message translates to:
  /// **'Les offres reçues seront refusées. Cette action est définitive.'**
  String get reqCancelBody;

  /// No description provided for @reqCancelKeep.
  ///
  /// In fr, this message translates to:
  /// **'Garder la demande'**
  String get reqCancelKeep;

  /// No description provided for @reqCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Demande annulée.'**
  String get reqCancelled;

  /// No description provided for @reqPhotoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Photo {index} sur {total}'**
  String reqPhotoLabel(int index, int total);

  /// No description provided for @reqPhotosFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les photos.'**
  String get reqPhotosFailed;

  /// No description provided for @proInboxTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demandes ouvertes'**
  String get proInboxTitle;

  /// No description provided for @proInboxMyArea.
  ///
  /// In fr, this message translates to:
  /// **'Dans mon gouvernorat'**
  String get proInboxMyArea;

  /// No description provided for @proInboxAllCategories.
  ///
  /// In fr, this message translates to:
  /// **'Tous les métiers'**
  String get proInboxAllCategories;

  /// No description provided for @proInboxEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande pour le moment'**
  String get proInboxEmptyTitle;

  /// No description provided for @proInboxEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Les nouvelles demandes de clients apparaîtront ici.'**
  String get proInboxEmptyBody;

  /// No description provided for @proInboxNeedsPublished.
  ///
  /// In fr, this message translates to:
  /// **'Publiez votre profil pour voir les demandes et envoyer des offres.'**
  String get proInboxNeedsPublished;

  /// No description provided for @offerStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get offerStatusPending;

  /// No description provided for @offerStatusAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Acceptée'**
  String get offerStatusAccepted;

  /// No description provided for @offerStatusDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Refusée'**
  String get offerStatusDeclined;

  /// No description provided for @offerStatusWithdrawn.
  ///
  /// In fr, this message translates to:
  /// **'Retirée'**
  String get offerStatusWithdrawn;

  /// No description provided for @offerYours.
  ///
  /// In fr, this message translates to:
  /// **'Votre offre : {status}'**
  String offerYours(String status);

  /// No description provided for @offersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes offres'**
  String get offersTitle;

  /// No description provided for @offersEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Vous n’avez pas encore envoyé d’offre.'**
  String get offersEmpty;

  /// No description provided for @jobsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes chantiers'**
  String get jobsTitle;

  /// No description provided for @jobsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun chantier pour le moment. Un chantier naît quand un client accepte votre offre.'**
  String get jobsEmpty;

  /// No description provided for @jobScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Planifié'**
  String get jobScheduled;

  /// No description provided for @jobInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get jobInProgress;

  /// No description provided for @jobPendingConfirmation.
  ///
  /// In fr, this message translates to:
  /// **'En attente de confirmation du client'**
  String get jobPendingConfirmation;

  /// No description provided for @jobCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get jobCompleted;

  /// No description provided for @jobCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get jobCancelled;

  /// No description provided for @jobStart.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer'**
  String get jobStart;

  /// No description provided for @jobDone.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme terminé'**
  String get jobDone;

  /// No description provided for @jobCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler le chantier'**
  String get jobCancel;

  /// No description provided for @jobCancelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ce chantier ?'**
  String get jobCancelTitle;

  /// No description provided for @jobCancelBody.
  ///
  /// In fr, this message translates to:
  /// **'Le client sera informé. Cette action est définitive.'**
  String get jobCancelBody;

  /// No description provided for @jobKeep.
  ///
  /// In fr, this message translates to:
  /// **'Garder le chantier'**
  String get jobKeep;

  /// No description provided for @jobAgreedPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix convenu : {amount}'**
  String jobAgreedPrice(String amount);

  /// No description provided for @offerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre offre'**
  String get offerTitle;

  /// No description provided for @offerPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix en TND'**
  String get offerPrice;

  /// No description provided for @offerMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message au client (facultatif)'**
  String get offerMessage;

  /// No description provided for @offerDays.
  ///
  /// In fr, this message translates to:
  /// **'Délai estimé en jours (facultatif)'**
  String get offerDays;

  /// No description provided for @offerSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer l’offre'**
  String get offerSend;

  /// No description provided for @offerUpdate.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour l’offre'**
  String get offerUpdate;

  /// No description provided for @offerWithdraw.
  ///
  /// In fr, this message translates to:
  /// **'Retirer mon offre'**
  String get offerWithdraw;

  /// No description provided for @offerSent.
  ///
  /// In fr, this message translates to:
  /// **'Offre envoyée.'**
  String get offerSent;

  /// No description provided for @offerWithdrawn.
  ///
  /// In fr, this message translates to:
  /// **'Offre retirée.'**
  String get offerWithdrawn;

  /// No description provided for @offerErrPrice.
  ///
  /// In fr, this message translates to:
  /// **'Entre 1 et 1 000 000 TND.'**
  String get offerErrPrice;

  /// No description provided for @offerErrMessage.
  ///
  /// In fr, this message translates to:
  /// **'1000 caractères au maximum.'**
  String get offerErrMessage;

  /// No description provided for @offerErrDays.
  ///
  /// In fr, this message translates to:
  /// **'Entre 1 et 365 jours.'**
  String get offerErrDays;

  /// No description provided for @offerDeclinedNote.
  ///
  /// In fr, this message translates to:
  /// **'Le client n’a pas retenu votre offre.'**
  String get offerDeclinedNote;

  /// No description provided for @offerAcceptedNote.
  ///
  /// In fr, this message translates to:
  /// **'Votre offre est acceptée : suivez le chantier dans Mes chantiers.'**
  String get offerAcceptedNote;

  /// No description provided for @offerOthers.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune autre offre pour l’instant} =1{1 offre déjà reçue} other{{count} offres déjà reçues}}'**
  String offerOthers(int count);

  /// No description provided for @reqFailOwn.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pouvez pas répondre à votre propre demande.'**
  String get reqFailOwn;

  /// No description provided for @reqFailOfferClosed.
  ///
  /// In fr, this message translates to:
  /// **'Cette offre ne peut plus être modifiée.'**
  String get reqFailOfferClosed;

  /// No description provided for @reqFailTransition.
  ///
  /// In fr, this message translates to:
  /// **'Cette étape n’est plus possible.'**
  String get reqFailTransition;

  /// No description provided for @reqFailForbidden.
  ///
  /// In fr, this message translates to:
  /// **'Publiez d’abord votre profil professionnel.'**
  String get reqFailForbidden;

  /// No description provided for @offerFailLimit.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez 50 offres en attente. Retirez-en une avant d’en envoyer une autre.'**
  String get offerFailLimit;

  /// No description provided for @offersReceived.
  ///
  /// In fr, this message translates to:
  /// **'Offres reçues'**
  String get offersReceived;

  /// No description provided for @offersNoneYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore d’offre. Les professionnels ont jusqu’à l’expiration de la demande pour répondre.'**
  String get offersNoneYet;

  /// No description provided for @sortOffersBy.
  ///
  /// In fr, this message translates to:
  /// **'Trier les offres'**
  String get sortOffersBy;

  /// No description provided for @sortOffersPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get sortOffersPrice;

  /// No description provided for @sortOffersRating.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get sortOffersRating;

  /// No description provided for @sortOffersDelay.
  ///
  /// In fr, this message translates to:
  /// **'Délai'**
  String get sortOffersDelay;

  /// No description provided for @offerLowest.
  ///
  /// In fr, this message translates to:
  /// **'Prix le plus bas'**
  String get offerLowest;

  /// No description provided for @offerDelay.
  ///
  /// In fr, this message translates to:
  /// **'Délai : {count} j'**
  String offerDelay(int count);

  /// No description provided for @offerAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get offerAccept;

  /// No description provided for @offerDecline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get offerDecline;

  /// No description provided for @offerAcceptTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accepter cette offre ?'**
  String get offerAcceptTitle;

  /// No description provided for @offerAcceptBody.
  ///
  /// In fr, this message translates to:
  /// **'{name} réalisera le travail pour {price}. Les autres offres seront refusées et la demande sera attribuée.'**
  String offerAcceptBody(String name, String price);

  /// No description provided for @offerDeclineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Refuser cette offre ?'**
  String get offerDeclineTitle;

  /// No description provided for @offerDeclineBody.
  ///
  /// In fr, this message translates to:
  /// **'Le professionnel ne pourra pas la proposer à nouveau.'**
  String get offerDeclineBody;

  /// No description provided for @offerAcceptedMsg.
  ///
  /// In fr, this message translates to:
  /// **'Offre acceptée.'**
  String get offerAcceptedMsg;

  /// No description provided for @offerDeclinedMsg.
  ///
  /// In fr, this message translates to:
  /// **'Offre refusée.'**
  String get offerDeclinedMsg;

  /// No description provided for @offerProUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Professionnel'**
  String get offerProUnknown;

  /// No description provided for @bookingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Chantier'**
  String get bookingTitle;

  /// No description provided for @bookingConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer que le travail est terminé'**
  String get bookingConfirm;

  /// No description provided for @bookingConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Merci, chantier terminé.'**
  String get bookingConfirmed;

  /// No description provided for @bookingCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Chantier annulé.'**
  String get bookingCancelled;

  /// No description provided for @bookingCancelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ce chantier ?'**
  String get bookingCancelTitle;

  /// No description provided for @bookingCancelBody.
  ///
  /// In fr, this message translates to:
  /// **'Le professionnel sera informé. Cette action est définitive.'**
  String get bookingCancelBody;

  /// No description provided for @bookingWaitingForYou.
  ///
  /// In fr, this message translates to:
  /// **'Le professionnel indique avoir terminé. Le travail est-il bien fait ?'**
  String get bookingWaitingForYou;

  /// No description provided for @chatTitleClient.
  ///
  /// In fr, this message translates to:
  /// **'Client'**
  String get chatTitleClient;

  /// No description provided for @chatInputHint.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez un message…'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get chatSend;

  /// No description provided for @chatAddImage.
  ///
  /// In fr, this message translates to:
  /// **'Joindre une photo'**
  String get chatAddImage;

  /// No description provided for @chatEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message. Dites bonjour !'**
  String get chatEmpty;

  /// No description provided for @chatReadOnly.
  ///
  /// In fr, this message translates to:
  /// **'Cette conversation est terminée : vous pouvez la relire, mais plus y écrire.'**
  String get chatReadOnly;

  /// No description provided for @chatImageSent.
  ///
  /// In fr, this message translates to:
  /// **'Photo envoyée'**
  String get chatImageSent;

  /// No description provided for @chatYouSent.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get chatYouSent;

  /// No description provided for @chatThem.
  ///
  /// In fr, this message translates to:
  /// **'Interlocuteur'**
  String get chatThem;

  /// No description provided for @chatUnread.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{} =1{1 message non lu} other{{count} messages non lus}}'**
  String chatUnread(int count);

  /// No description provided for @chatSendFailed.
  ///
  /// In fr, this message translates to:
  /// **'Message non envoyé. Réessayez.'**
  String get chatSendFailed;

  /// No description provided for @chatRateLimited.
  ///
  /// In fr, this message translates to:
  /// **'Vous écrivez trop vite. Patientez un instant.'**
  String get chatRateLimited;

  /// No description provided for @chatClosed.
  ///
  /// In fr, this message translates to:
  /// **'Cette conversation est terminée.'**
  String get chatClosed;

  /// No description provided for @chatOpenFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’ouvrir la conversation. Réessayez.'**
  String get chatOpenFailed;

  /// No description provided for @chatLiveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour en direct interrompue. Tirez pour actualiser.'**
  String get chatLiveFailed;

  /// No description provided for @chatPhotoFailed.
  ///
  /// In fr, this message translates to:
  /// **'Photo non envoyée. Réessayez.'**
  String get chatPhotoFailed;

  /// No description provided for @chatAskPro.
  ///
  /// In fr, this message translates to:
  /// **'Poser une question'**
  String get chatAskPro;

  /// No description provided for @chatWriteCustomer.
  ///
  /// In fr, this message translates to:
  /// **'Écrire au client'**
  String get chatWriteCustomer;

  /// No description provided for @chatPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get chatPhoto;

  /// No description provided for @notifTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifIntro.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez ce pour quoi vous voulez être prévenu. Les notifications ne contiennent jamais le texte de vos messages.'**
  String get notifIntro;

  /// No description provided for @notifOffers.
  ///
  /// In fr, this message translates to:
  /// **'Offres reçues et acceptées'**
  String get notifOffers;

  /// No description provided for @notifMessages.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux messages'**
  String get notifMessages;

  /// No description provided for @notifJobs.
  ///
  /// In fr, this message translates to:
  /// **'Avancement des chantiers'**
  String get notifJobs;

  /// No description provided for @notifNoPush.
  ///
  /// In fr, this message translates to:
  /// **'Les notifications push ne sont pas encore disponibles sur cet appareil. Vos choix sont enregistrés pour plus tard.'**
  String get notifNoPush;

  /// No description provided for @notifSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer ce choix. Réessayez.'**
  String get notifSaveFailed;

  /// No description provided for @reviewsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Avis'**
  String get reviewsTitle;

  /// No description provided for @reviewsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore d’avis.'**
  String get reviewsEmpty;

  /// No description provided for @reviewsMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus d’avis'**
  String get reviewsMore;

  /// No description provided for @reviewsLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les avis.'**
  String get reviewsLoadFailed;

  /// No description provided for @reviewCta.
  ///
  /// In fr, this message translates to:
  /// **'Laisser un avis'**
  String get reviewCta;

  /// No description provided for @reviewCtaPro.
  ///
  /// In fr, this message translates to:
  /// **'Noter le client'**
  String get reviewCtaPro;

  /// No description provided for @reviewSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre avis'**
  String get reviewSheetTitle;

  /// No description provided for @reviewSheetTitlePro.
  ///
  /// In fr, this message translates to:
  /// **'Votre avis sur le client'**
  String get reviewSheetTitlePro;

  /// No description provided for @reviewRatingHint.
  ///
  /// In fr, this message translates to:
  /// **'Touchez une étoile'**
  String get reviewRatingHint;

  /// No description provided for @reviewStar.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 étoile} other{{count} étoiles}}'**
  String reviewStar(int count);

  /// No description provided for @reviewComment.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire (facultatif)'**
  String get reviewComment;

  /// No description provided for @reviewSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Publier mon avis'**
  String get reviewSubmit;

  /// No description provided for @reviewPublicNote.
  ///
  /// In fr, this message translates to:
  /// **'Votre avis sera public, sans votre nom.'**
  String get reviewPublicNote;

  /// No description provided for @reviewPrivateNote.
  ///
  /// In fr, this message translates to:
  /// **'Cet avis n’est visible que par l’équipe Khidma.'**
  String get reviewPrivateNote;

  /// No description provided for @reviewErrRating.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une note de 1 à 5.'**
  String get reviewErrRating;

  /// No description provided for @reviewThanks.
  ///
  /// In fr, this message translates to:
  /// **'Merci pour votre avis.'**
  String get reviewThanks;

  /// No description provided for @reviewDone.
  ///
  /// In fr, this message translates to:
  /// **'Avis donné'**
  String get reviewDone;

  /// No description provided for @reviewFailAlready.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà donné votre avis sur ce chantier.'**
  String get reviewFailAlready;

  /// No description provided for @reviewFailNotCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Le chantier doit être terminé pour laisser un avis.'**
  String get reviewFailNotCompleted;

  /// No description provided for @reviewFailGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’envoyer l’avis. Réessayez.'**
  String get reviewFailGeneric;

  /// No description provided for @reviewAuthorAnon.
  ///
  /// In fr, this message translates to:
  /// **'Client'**
  String get reviewAuthorAnon;

  /// No description provided for @reviewFailLimit.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà donné trop d’avis sur ce professionnel.'**
  String get reviewFailLimit;

  /// No description provided for @reportAction.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get reportAction;

  /// No description provided for @reportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un problème'**
  String get reportTitle;

  /// No description provided for @reportHint.
  ///
  /// In fr, this message translates to:
  /// **'Notre équipe examine chaque signalement. La personne signalée ne saura pas que c’est vous.'**
  String get reportHint;

  /// No description provided for @reportReasonSpam.
  ///
  /// In fr, this message translates to:
  /// **'Publicité ou spam'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonFake.
  ///
  /// In fr, this message translates to:
  /// **'Faux profil ou faux avis'**
  String get reportReasonFake;

  /// No description provided for @reportReasonAbuse.
  ///
  /// In fr, this message translates to:
  /// **'Harcèlement ou insultes'**
  String get reportReasonAbuse;

  /// No description provided for @reportReasonScam.
  ///
  /// In fr, this message translates to:
  /// **'Arnaque ou demande d’argent suspecte'**
  String get reportReasonScam;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In fr, this message translates to:
  /// **'Contenu inapproprié'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get reportReasonOther;

  /// No description provided for @reportDetailsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Détails (facultatif)'**
  String get reportDetailsLabel;

  /// No description provided for @reportSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le signalement'**
  String get reportSend;

  /// No description provided for @reportSent.
  ///
  /// In fr, this message translates to:
  /// **'Merci. Votre signalement a été envoyé.'**
  String get reportSent;

  /// No description provided for @reportFailAlready.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà signalé cela. Nous l’examinons.'**
  String get reportFailAlready;

  /// No description provided for @reportFailRate.
  ///
  /// In fr, this message translates to:
  /// **'Trop de signalements aujourd’hui. Réessayez demain.'**
  String get reportFailRate;

  /// No description provided for @reportFailGone.
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu n’est plus disponible.'**
  String get reportFailGone;

  /// No description provided for @reportFailGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Le signalement n’a pas pu être envoyé. Vérifiez votre connexion et réessayez.'**
  String get reportFailGeneric;

  /// No description provided for @verifTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification du profil'**
  String get verifTitle;

  /// No description provided for @verifCta.
  ///
  /// In fr, this message translates to:
  /// **'Faire vérifier mon profil'**
  String get verifCta;

  /// No description provided for @verifIntro.
  ///
  /// In fr, this message translates to:
  /// **'Envoyez une photo de votre carte d’identité ou de votre registre de commerce. Après vérification, un badge apparaît sur votre profil.'**
  String get verifIntro;

  /// No description provided for @verifPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Vos documents sont privés : seuls vous et notre équipe de vérification peuvent les voir, et ils sont supprimés dès la décision.'**
  String get verifPrivacy;

  /// No description provided for @verifStatusNone.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore vérifié'**
  String get verifStatusNone;

  /// No description provided for @verifStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En cours de vérification'**
  String get verifStatusPending;

  /// No description provided for @verifStatusApproved.
  ///
  /// In fr, this message translates to:
  /// **'Profil vérifié'**
  String get verifStatusApproved;

  /// No description provided for @verifStatusRejected.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get verifStatusRejected;

  /// No description provided for @verifStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Demande annulée'**
  String get verifStatusCancelled;

  /// No description provided for @verifRejectReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif : {reason}'**
  String verifRejectReason(Object reason);

  /// No description provided for @verifPendingBody.
  ///
  /// In fr, this message translates to:
  /// **'Nous examinons vos documents. Vous serez prévenu de la décision.'**
  String get verifPendingBody;

  /// No description provided for @verifAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get verifAdd;

  /// No description provided for @verifCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} sur {max} documents'**
  String verifCount(Object count, Object max);

  /// No description provided for @verifRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le document {index}'**
  String verifRemove(Object index);

  /// No description provided for @verifSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer pour vérification'**
  String get verifSubmit;

  /// No description provided for @verifCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get verifCancel;

  /// No description provided for @verifSent.
  ///
  /// In fr, this message translates to:
  /// **'Documents envoyés. Nous vous répondons bientôt.'**
  String get verifSent;

  /// No description provided for @verifCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Demande annulée. Vos documents ont été supprimés.'**
  String get verifCancelled;

  /// No description provided for @verifFailPending.
  ///
  /// In fr, this message translates to:
  /// **'Une demande est déjà en cours.'**
  String get verifFailPending;

  /// No description provided for @verifFailVerified.
  ///
  /// In fr, this message translates to:
  /// **'Votre profil est déjà vérifié.'**
  String get verifFailVerified;

  /// No description provided for @verifFailLimit.
  ///
  /// In fr, this message translates to:
  /// **'Trop de demandes ces 30 derniers jours. Réessayez plus tard.'**
  String get verifFailLimit;

  /// No description provided for @verifFailGeneric.
  ///
  /// In fr, this message translates to:
  /// **'L’envoi a échoué. Vérifiez votre connexion et réessayez.'**
  String get verifFailGeneric;

  /// No description provided for @verifFailImage.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n’est pas une photo lisible (JPEG, PNG ou WebP).'**
  String get verifFailImage;
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
