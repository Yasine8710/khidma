// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Khidma';

  @override
  String get tagline => 'Des professionnels de confiance, près de chez vous.';

  @override
  String get chooseLanguage => 'Choisir la langue';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get priceOnQuote => 'Sur devis';

  @override
  String professionalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count professionnels',
      one: '1 professionnel',
      zero: 'Aucun professionnel',
    );
    return '$_temp0';
  }

  @override
  String get phoneInvalid =>
      'Numéro tunisien invalide. Exemple : +216 20 123 456';

  @override
  String get navHome => 'Accueil';

  @override
  String get navRequests => 'Demandes';

  @override
  String get navMessages => 'Messages';

  @override
  String get navProfile => 'Profil';

  @override
  String get homeEmptyTitle => 'Les professionnels arrivent bientôt';

  @override
  String get homeEmptyBody =>
      'La recherche et les catégories de services seront disponibles ici.';

  @override
  String get requestsEmptyTitle => 'Aucune demande pour l\'instant';

  @override
  String get requestsEmptyBody => 'Vos demandes de devis apparaîtront ici.';

  @override
  String get messagesEmptyTitle => 'Aucun message';

  @override
  String get messagesEmptyBody =>
      'Vos conversations avec les professionnels apparaîtront ici.';

  @override
  String get themeTitle => 'Apparence';

  @override
  String get themeSystem => 'Automatique';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get notFoundTitle => 'Page introuvable';

  @override
  String get notFoundBody => 'Cette page n\'existe pas ou a été déplacée.';

  @override
  String get backToHome => 'Retour à l\'accueil';

  @override
  String get verified => 'Vérifié';

  @override
  String get ratingNone => 'Pas encore d\'avis';

  @override
  String ratingSummary(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avis',
      one: '1 avis',
    );
    return 'Note $value sur 5, $_temp0';
  }

  @override
  String get errorTitle => 'Une erreur est survenue';

  @override
  String get errorBody => 'Vérifiez votre connexion et réessayez.';

  @override
  String get retry => 'Réessayer';

  @override
  String get loading => 'Chargement…';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get onbTitle1 => 'Trouvez des professionnels de confiance';

  @override
  String get onbBody1 =>
      'Plombiers, électriciens, mécaniciens… découvrez des artisans près de chez vous, avec leurs réalisations et leurs avis.';

  @override
  String get onbTitle2 => 'Comparez et demandez un devis';

  @override
  String get onbBody2 =>
      'Décrivez votre besoin une fois, recevez des offres de plusieurs professionnels et choisissez la meilleure.';

  @override
  String get onbTitle3 => 'Contactez-les directement';

  @override
  String get onbBody3 =>
      'Appelez, écrivez sur WhatsApp ou discutez dans l\'application. Le paiement se règle directement avec le professionnel.';

  @override
  String get languageStepBody =>
      'Vous pourrez la changer à tout moment dans Profil.';

  @override
  String get next => 'Suivant';

  @override
  String get start => 'Commencer';

  @override
  String get skip => 'Passer';

  @override
  String pageOf(int current, int total) {
    return 'Page $current sur $total';
  }

  @override
  String get back => 'Précédent';

  @override
  String get signIn => 'Se connecter';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get emailLabel => 'Adresse e-mail';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get fullNameLabel => 'Nom complet';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get sendResetLink => 'Envoyer le lien';

  @override
  String get noAccountYet => 'Pas encore de compte ?';

  @override
  String get haveAccount => 'Déjà un compte ?';

  @override
  String get signInTitle => 'Bon retour';

  @override
  String get signInSubtitle =>
      'Connectez-vous pour demander des devis et suivre vos demandes.';

  @override
  String get registerTitle => 'Créez votre compte';

  @override
  String get registerSubtitle => 'Quelques secondes suffisent.';

  @override
  String get forgotTitle => 'Réinitialiser le mot de passe';

  @override
  String get forgotSubtitle =>
      'Entrez votre e-mail : nous vous envoyons un lien pour choisir un nouveau mot de passe.';

  @override
  String get resetSentTitle => 'Vérifiez vos e-mails';

  @override
  String resetSentBody(String email) {
    return 'Si un compte existe pour $email, un lien de réinitialisation vient d\'être envoyé.';
  }

  @override
  String get confirmEmailTitle => 'Confirmez votre adresse e-mail';

  @override
  String confirmEmailBody(String email) {
    return 'Nous avons envoyé un lien de confirmation à $email. Ouvrez-le pour activer votre compte.';
  }

  @override
  String get backToSignIn => 'Retour à la connexion';

  @override
  String get errEmailRequired => 'Saisissez votre adresse e-mail.';

  @override
  String get errEmailInvalid => 'Adresse e-mail invalide.';

  @override
  String get errPasswordRequired => 'Saisissez votre mot de passe.';

  @override
  String get errPasswordShort => '8 caractères minimum.';

  @override
  String get errPasswordLong => 'Mot de passe trop long.';

  @override
  String get errNameRequired => 'Saisissez votre nom.';

  @override
  String get failInvalidCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get failEmailNotConfirmed =>
      'Confirmez d\'abord votre adresse e-mail (lien reçu par e-mail).';

  @override
  String get failWeakPassword =>
      'Mot de passe trop faible. Choisissez-en un plus long et moins courant.';

  @override
  String get failSignUpDisabled =>
      'Les inscriptions sont fermées pour le moment.';

  @override
  String get failRateLimited =>
      'Trop de tentatives. Réessayez dans quelques minutes.';

  @override
  String get failNetwork => 'Connexion impossible. Vérifiez votre réseau.';

  @override
  String get failNotConfigured =>
      'Les comptes ne sont pas disponibles dans cette version de l\'application.';

  @override
  String get failUnknown => 'Une erreur est survenue. Réessayez.';

  @override
  String get signedOutProfileTitle => 'Connectez-vous ou créez un compte';

  @override
  String get signedOutProfileBody =>
      'Pour demander un devis et contacter des professionnels.';

  @override
  String get requestsSignedOutTitle => 'Connectez-vous pour voir vos demandes';

  @override
  String get requestsSignedOutBody =>
      'Vos demandes de devis et les offres reçues apparaîtront ici.';

  @override
  String get messagesSignedOutTitle => 'Connectez-vous pour discuter';

  @override
  String get messagesSignedOutBody =>
      'Vos conversations avec les professionnels apparaîtront ici.';

  @override
  String signedInAs(String email) {
    return 'Connecté en tant que $email';
  }

  @override
  String get newPasswordTitle => 'Nouveau mot de passe';

  @override
  String get newPasswordSubtitle =>
      'Choisissez un mot de passe que vous n\'utilisez nulle part ailleurs.';

  @override
  String get savePassword => 'Enregistrer le mot de passe';

  @override
  String get passwordUpdated => 'Mot de passe mis à jour.';

  @override
  String get linkExpiredTitle => 'Lien expiré ou invalide';

  @override
  String get linkExpiredBody =>
      'Demandez un nouveau lien de réinitialisation depuis l\'écran de connexion.';
}
