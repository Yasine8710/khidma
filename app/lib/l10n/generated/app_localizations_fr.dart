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

  @override
  String get accountTypeTitle => 'Je souhaite…';

  @override
  String get accountCustomerTitle => 'Trouver un professionnel';

  @override
  String get accountCustomerBody =>
      'Demander des devis et contacter des artisans.';

  @override
  String get accountProfessionalTitle => 'Proposer mes services';

  @override
  String get accountProfessionalBody =>
      'Créer un profil professionnel et recevoir des demandes.';

  @override
  String get becomeProfessionalTitle => 'Proposez vos services';

  @override
  String get becomeProfessionalBody =>
      'Créez votre profil professionnel pour recevoir des demandes de clients.';

  @override
  String get becomeProfessionalCta => 'Devenir professionnel';

  @override
  String get professionalBadge => 'Professionnel';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get save => 'Enregistrer';

  @override
  String get phoneLabel => 'Téléphone';

  @override
  String get phoneHelper => 'Visible uniquement par vous.';

  @override
  String get profileSaved => 'Profil enregistré.';

  @override
  String get failProfileLoad => 'Impossible de charger votre profil.';

  @override
  String get failProfileInvalid => 'Certaines informations sont invalides.';

  @override
  String get continueWithApple => 'Continuer avec Apple';

  @override
  String get orSeparator => 'ou';

  @override
  String get deleteAccount => 'Supprimer mon compte';

  @override
  String get deleteAccountTitle => 'Supprimer votre compte ?';

  @override
  String get deleteAccountBody =>
      'Votre profil, vos informations et vos données associées seront supprimés définitivement. Cette action est irréversible.';

  @override
  String get deleteConfirmWord => 'SUPPRIMER';

  @override
  String deleteTypeToConfirm(String word) {
    return 'Saisissez $word pour confirmer';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get accountDeleted => 'Votre compte a été supprimé.';

  @override
  String get homeGreeting => 'Bonjour';

  @override
  String homeGreetingNamed(String name) {
    return 'Bonjour, $name';
  }

  @override
  String get homeSubtitle => 'De quel service avez-vous besoin ?';

  @override
  String get searchHint => 'Rechercher un métier, un nom, une ville…';

  @override
  String get placeAll => 'Toute la Tunisie';

  @override
  String get placeChoose => 'Choisir une zone';

  @override
  String get placeGovernorate => 'Gouvernorat';

  @override
  String get placeWholeGovernorate => 'Tout le gouvernorat';

  @override
  String get sectionCategories => 'Catégories';

  @override
  String get sectionTopRated => 'Les mieux notés';

  @override
  String get sectionInYourArea => 'Dans votre zone';

  @override
  String get sectionInYourAreaPrompt =>
      'Choisissez une zone pour voir les professionnels autour de vous.';

  @override
  String get sectionRecent => 'Consultés récemment';

  @override
  String get seeAll => 'Voir tout';

  @override
  String get noProfessionalsTitle => 'Aucun professionnel pour le moment';

  @override
  String get noProfessionalsBody =>
      'Ils apparaîtront ici dès qu\'ils auront rejoint Khidma.';

  @override
  String get noProfessionalsInArea =>
      'Aucun professionnel dans cette zone pour le moment.';

  @override
  String get demoBannerTitle => 'Données de démonstration';

  @override
  String get demoBannerBody =>
      'Les professionnels, notes et badges affichés sont fictifs.';

  @override
  String get availabilityAvailable => 'Disponible';

  @override
  String get availabilityBusy => 'Occupé';

  @override
  String get availabilityOffline => 'Hors ligne';

  @override
  String yearsExperience(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ans d\'expérience',
      one: '1 an d\'expérience',
    );
    return '$_temp0';
  }

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String get failLoadProfessionals =>
      'Impossible de charger les professionnels.';

  @override
  String get failForbidden =>
      'L\'accès aux données est refusé. Réessayez plus tard.';

  @override
  String get professionalNotFoundTitle => 'Profil introuvable';

  @override
  String get professionalNotFoundBody =>
      'Ce professionnel n\'est plus disponible.';

  @override
  String get searchTitle => 'Recherche';

  @override
  String get searchNoResultsTitle => 'Aucun résultat';

  @override
  String get searchNoResultsBody => 'Essayez un autre mot ou une autre zone.';

  @override
  String get searchStartTitle => 'Que cherchez-vous ?';

  @override
  String get searchStartBody => 'Tapez un métier, un nom ou une ville.';

  @override
  String get aboutLabel => 'À propos';

  @override
  String get inCategory => 'Catégorie';

  @override
  String get filtersTitle => 'Filtres';

  @override
  String get filtersAction => 'Filtrer';

  @override
  String get filterCategory => 'Catégorie';

  @override
  String get filterAllCategories => 'Toutes';

  @override
  String get filterMinRating => 'Note minimale';

  @override
  String get filterRatingAny => 'Toutes';

  @override
  String filterRatingAtLeast(String value) {
    return '$value+';
  }

  @override
  String get filterAvailableOnly => 'Disponibles uniquement';

  @override
  String get sortBy => 'Trier par';

  @override
  String get sortRating => 'Mieux notés';

  @override
  String get sortReviews => 'Plus d’avis';

  @override
  String get filtersApply => 'Appliquer';

  @override
  String get filtersReset => 'Réinitialiser';

  @override
  String get loadMore => 'Voir plus';

  @override
  String filtersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Filtres, $count actifs',
      one: 'Filtres, 1 actif',
      zero: 'Filtres',
    );
    return '$_temp0';
  }

  @override
  String get contactTitle => 'Contact';

  @override
  String get contactShow => 'Afficher le contact';

  @override
  String get contactSignIn => 'Connectez-vous pour voir le contact';

  @override
  String get contactCall => 'Appeler';

  @override
  String get contactWhatsApp => 'WhatsApp';

  @override
  String get contactWhy =>
      'Le numéro est affiché aux membres connectés, pour protéger les professionnels du démarchage abusif.';

  @override
  String get contactDemo =>
      'Le contact n’est pas disponible avec les données de démonstration.';

  @override
  String get contactRateLimited =>
      'Trop de numéros consultés en peu de temps. Réessayez dans une heure.';

  @override
  String get contactNotFound => 'Ce professionnel n’est plus disponible.';

  @override
  String get contactFailed => 'Impossible de charger le contact. Réessayez.';

  @override
  String get contactLaunchFailed => 'Impossible d’ouvrir l’application.';

  @override
  String get servicesTitle => 'Services';

  @override
  String get areasTitle => 'Zones d’intervention';

  @override
  String areaWhole(String place) {
    return '$place (tout le gouvernorat)';
  }

  @override
  String get favoritesTitle => 'Mes favoris';

  @override
  String get favoriteAdd => 'Ajouter aux favoris';

  @override
  String get favoriteRemove => 'Retirer des favoris';

  @override
  String get favoritesEmptyTitle => 'Aucun favori';

  @override
  String get favoritesEmptyBody =>
      'Touchez le cœur sur un profil pour le retrouver ici.';

  @override
  String get favoritesSignInTitle => 'Retrouvez vos favoris';

  @override
  String get favoritesSignInBody =>
      'Connectez-vous pour enregistrer des professionnels et les retrouver sur tous vos appareils.';

  @override
  String get favoriteLimit => 'Vous avez atteint la limite de 200 favoris.';

  @override
  String get favoriteFailed => 'Impossible de modifier vos favoris. Réessayez.';

  @override
  String favoriteAddNamed(String name) {
    return 'Ajouter $name aux favoris';
  }

  @override
  String favoriteRemoveNamed(String name) {
    return 'Retirer $name des favoris';
  }

  @override
  String get nearMe => 'Près de moi';

  @override
  String get sortNearest => 'Plus proches';

  @override
  String get filterRadius => 'Distance maximale';

  @override
  String get filterRadiusAny => 'Peu importe';

  @override
  String get locationDenied =>
      'Autorisez la localisation pour voir les professionnels près de vous.';

  @override
  String get locationDeniedForever =>
      'La localisation est bloquée. Autorisez-la dans les réglages.';

  @override
  String get locationServiceOff =>
      'La localisation est désactivée sur cet appareil.';

  @override
  String get locationUnavailable => 'Position introuvable. Réessayez.';

  @override
  String get openSettings => 'Réglages';

  @override
  String get showMap => 'Afficher la carte';

  @override
  String get showList => 'Afficher la liste';

  @override
  String get mapNothingTitle => 'Rien à placer sur la carte';

  @override
  String get mapNothingBody =>
      'Aucun de ces professionnels n’a de position connue.';
}
