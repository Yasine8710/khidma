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

  @override
  String get regTitle => 'Profil professionnel';

  @override
  String regStepOf(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get regNext => 'Continuer';

  @override
  String get regBack => 'Retour';

  @override
  String get regStepBusiness => 'Votre activité';

  @override
  String get regStepLocation => 'Où travaillez-vous ?';

  @override
  String get regStepAreas => 'Zones d’intervention';

  @override
  String get regStepServices => 'Autres services';

  @override
  String get regStepContact => 'Contact';

  @override
  String get regStepReview => 'Vérifier et publier';

  @override
  String get regBusinessName => 'Nom affiché (entreprise ou personne)';

  @override
  String get regYears => 'Années d’expérience (facultatif)';

  @override
  String get regCategory => 'Métier principal';

  @override
  String get regDescription => 'Description de vos services';

  @override
  String get regDescriptionHelper => 'Au moins 20 caractères.';

  @override
  String get regGovernorate => 'Gouvernorat';

  @override
  String get regCity => 'Ville (facultatif)';

  @override
  String get regAreasBody =>
      'Choisissez les gouvernorats où vous vous déplacez, en plus du vôtre.';

  @override
  String get regServicesBody => 'Ajoutez d’autres services que vous proposez.';

  @override
  String get regPhone => 'Téléphone de contact';

  @override
  String get regPhoneHelper =>
      'Seuls les membres connectés le voient, et seulement s’ils le demandent.';

  @override
  String get regPhotoLater => 'La photo de profil arrive bientôt.';

  @override
  String get regErrName => 'Entre 2 et 120 caractères.';

  @override
  String get regErrDescription => 'Entre 20 et 2000 caractères.';

  @override
  String get regErrCategory => 'Choisissez un métier.';

  @override
  String get regErrGovernorate => 'Choisissez un gouvernorat.';

  @override
  String get regErrYears => 'Entre 0 et 60.';

  @override
  String get regErrPhone => 'Numéro tunisien invalide (8 chiffres).';

  @override
  String get regReviewBody => 'Voici ce que verront les clients.';

  @override
  String get regPublish => 'Publier mon profil';

  @override
  String get regUnpublish => 'Retirer de la liste';

  @override
  String get regSaveDraft => 'Enregistrer et quitter';

  @override
  String get regPublished => 'Votre profil est publié.';

  @override
  String get regDraft => 'Brouillon : invisible pour les clients.';

  @override
  String regMissing(String items) {
    return 'Pour publier, il manque : $items.';
  }

  @override
  String get gapName => 'le nom';

  @override
  String get gapCategory => 'le métier';

  @override
  String get gapDescription => 'la description';

  @override
  String get gapLocation => 'le gouvernorat';

  @override
  String get gapPhone => 'le téléphone';

  @override
  String get regFailNetwork =>
      'Connexion impossible. Vos réponses sont conservées, réessayez.';

  @override
  String get regFailInvalid =>
      'Certaines informations sont refusées. Vérifiez-les.';

  @override
  String get regFailForbidden => 'Action non autorisée pour ce compte.';

  @override
  String get regFailGeneric => 'Impossible d’enregistrer. Réessayez.';

  @override
  String get regFailNotConfigured =>
      'Le service n’est pas disponible pour le moment.';

  @override
  String get proCompleteCta => 'Compléter mon profil';

  @override
  String get proEditCta => 'Modifier mon profil professionnel';

  @override
  String get proStatusDraft => 'Profil non publié';

  @override
  String get proStatusPublished => 'Profil publié';

  @override
  String get dashTitle => 'Mon espace pro';

  @override
  String get dashAvailability => 'Disponibilité';

  @override
  String get dashActivity => 'Activité';

  @override
  String get dashActivityNote =>
      'Chiffres anonymes, avec une heure de décalage : vous ne voyez pas qui a consulté ou enregistré votre profil.';

  @override
  String get dashViews30d => 'Contacts consultés (30 jours)';

  @override
  String get dashViewsTotal => 'Contacts consultés (total)';

  @override
  String get dashFavorites => 'Enregistrés en favoris';

  @override
  String get dashActivityFailed => 'Activité indisponible pour le moment.';

  @override
  String get dashViewPublic => 'Voir mon profil public';

  @override
  String get dashSaveFailed => 'Modification impossible. Réessayez.';

  @override
  String get dashRefreshFailed =>
      'Impossible d’actualiser. Les chiffres affichés peuvent être anciens.';

  @override
  String get portfolioTitle => 'Mes réalisations';

  @override
  String get portfolioSection => 'Réalisations';

  @override
  String get portfolioAdd => 'Ajouter une photo';

  @override
  String portfolioCount(int count, int max) {
    return '$count sur $max photos';
  }

  @override
  String get portfolioHint =>
      'Photos de vos travaux. Elles sont réduites automatiquement et leurs informations (position, appareil) sont retirées.';

  @override
  String get portfolioEmpty => 'Aucune photo pour le moment.';

  @override
  String get portfolioRemove => 'Supprimer la photo';

  @override
  String get portfolioRemoveTitle => 'Supprimer cette photo ?';

  @override
  String get portfolioRemoveBody =>
      'Elle ne sera plus visible sur votre profil.';

  @override
  String portfolioPhotoOf(int index, int total) {
    return 'Photo $index sur $total';
  }

  @override
  String get portfolioFailTooLarge =>
      'Cette photo est trop lourde, même réduite. Choisissez-en une autre.';

  @override
  String get portfolioFailNotImage =>
      'Ce fichier n’est pas une photo lisible (JPEG, PNG ou WebP).';

  @override
  String get portfolioFailLimit => 'Vous avez atteint la limite de 12 photos.';

  @override
  String get portfolioFailNetwork => 'Connexion impossible. Réessayez.';

  @override
  String get portfolioFailGeneric =>
      'Impossible de modifier vos photos. Réessayez.';

  @override
  String get portfolioFailNotConfigured =>
      'Le service n’est pas disponible pour le moment.';

  @override
  String get portfolioPreparing => 'Préparation de la photo…';

  @override
  String get close => 'Fermer';

  @override
  String get reqNew => 'Nouvelle demande';

  @override
  String get reqMineTitle => 'Mes demandes';

  @override
  String get reqEmptyCta => 'Demander un devis';

  @override
  String get reqStatusOpen => 'Ouverte';

  @override
  String get reqStatusAwarded => 'Attribuée';

  @override
  String get reqStatusCancelled => 'Annulée';

  @override
  String get reqStatusExpired => 'Expirée';

  @override
  String reqOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offres',
      one: '1 offre',
      zero: 'Aucune offre',
    );
    return '$_temp0';
  }

  @override
  String get reqFormTitle => 'Titre';

  @override
  String get reqFormTitleHint => 'Ex. Fuite sous l’évier';

  @override
  String get reqFormDescription => 'Décrivez le problème';

  @override
  String get reqFormDescriptionHelper => 'Au moins 10 caractères.';

  @override
  String get reqFormCategory => 'Type de service';

  @override
  String get reqFormBudget => 'Budget indicatif en TND (facultatif)';

  @override
  String get reqFormNeededBy => 'Pour quand ? (facultatif)';

  @override
  String get reqFormNeededByNone => 'Pas de date';

  @override
  String get reqFormPickDate => 'Choisir une date';

  @override
  String get reqFormPhotos => 'Photos (facultatif)';

  @override
  String get reqFormAddPhoto => 'Ajouter une photo';

  @override
  String reqFormPhotosCount(int count, int max) {
    return '$count sur $max photos';
  }

  @override
  String reqFormRemovePhoto(int index) {
    return 'Retirer la photo $index';
  }

  @override
  String get reqFormSubmit => 'Envoyer la demande';

  @override
  String get reqFormPrivacy =>
      'Les professionnels verront votre demande et vos photos, jamais votre nom ni votre numéro.';

  @override
  String get reqErrTitle => 'Entre 3 et 120 caractères.';

  @override
  String get reqErrDescription => 'Entre 10 et 2000 caractères.';

  @override
  String get reqErrCategory => 'Choisissez un type de service.';

  @override
  String get reqErrGovernorate => 'Choisissez un gouvernorat.';

  @override
  String get reqErrBudget => 'Montant invalide (0 à 1 000 000).';

  @override
  String get reqSent => 'Demande envoyée.';

  @override
  String get reqSentPhotosFailed =>
      'Demande envoyée, mais certaines photos n’ont pas pu être ajoutées.';

  @override
  String get reqFailNetwork =>
      'Connexion impossible. Votre saisie est conservée, réessayez.';

  @override
  String get reqFailRateLimited =>
      'Trop de demandes en peu de temps. Réessayez dans une heure.';

  @override
  String get reqFailLimit =>
      'Vous avez déjà 10 demandes ouvertes. Annulez-en une avant d’en créer une autre.';

  @override
  String get reqFailInvalid =>
      'Certaines informations sont refusées. Vérifiez-les.';

  @override
  String get reqFailNotOpen => 'Cette demande n’est plus ouverte.';

  @override
  String get reqFailGeneric => 'Impossible d’envoyer la demande. Réessayez.';

  @override
  String get reqFailNotConfigured =>
      'Le service n’est pas disponible pour le moment.';

  @override
  String get reqDetailTitle => 'Demande';

  @override
  String get reqNotFound => 'Demande introuvable.';

  @override
  String reqExpiresOn(String date) {
    return 'Expire le $date';
  }

  @override
  String reqNeededBy(String date) {
    return 'Souhaité pour le $date';
  }

  @override
  String reqBudget(String amount) {
    return 'Budget indicatif : $amount';
  }

  @override
  String get reqCancel => 'Annuler la demande';

  @override
  String get reqCancelTitle => 'Annuler cette demande ?';

  @override
  String get reqCancelBody =>
      'Les offres reçues seront refusées. Cette action est définitive.';

  @override
  String get reqCancelKeep => 'Garder la demande';

  @override
  String get reqCancelled => 'Demande annulée.';

  @override
  String reqPhotoLabel(int index, int total) {
    return 'Photo $index sur $total';
  }

  @override
  String get reqPhotosFailed => 'Impossible de charger les photos.';

  @override
  String get proInboxTitle => 'Demandes ouvertes';

  @override
  String get proInboxMyArea => 'Dans mon gouvernorat';

  @override
  String get proInboxAllCategories => 'Tous les métiers';

  @override
  String get proInboxEmptyTitle => 'Aucune demande pour le moment';

  @override
  String get proInboxEmptyBody =>
      'Les nouvelles demandes de clients apparaîtront ici.';

  @override
  String get proInboxNeedsPublished =>
      'Publiez votre profil pour voir les demandes et envoyer des offres.';

  @override
  String get offerStatusPending => 'En attente';

  @override
  String get offerStatusAccepted => 'Acceptée';

  @override
  String get offerStatusDeclined => 'Refusée';

  @override
  String get offerStatusWithdrawn => 'Retirée';

  @override
  String offerYours(String status) {
    return 'Votre offre : $status';
  }

  @override
  String get offersTitle => 'Mes offres';

  @override
  String get offersEmpty => 'Vous n’avez pas encore envoyé d’offre.';

  @override
  String get jobsTitle => 'Mes chantiers';

  @override
  String get jobsEmpty =>
      'Aucun chantier pour le moment. Un chantier naît quand un client accepte votre offre.';

  @override
  String get jobScheduled => 'Planifié';

  @override
  String get jobInProgress => 'En cours';

  @override
  String get jobPendingConfirmation => 'En attente de confirmation du client';

  @override
  String get jobCompleted => 'Terminé';

  @override
  String get jobCancelled => 'Annulé';

  @override
  String get jobStart => 'Démarrer';

  @override
  String get jobDone => 'Marquer comme terminé';

  @override
  String get jobCancel => 'Annuler le chantier';

  @override
  String get jobCancelTitle => 'Annuler ce chantier ?';

  @override
  String get jobCancelBody =>
      'Le client sera informé. Cette action est définitive.';

  @override
  String get jobKeep => 'Garder le chantier';

  @override
  String jobAgreedPrice(String amount) {
    return 'Prix convenu : $amount';
  }

  @override
  String get offerTitle => 'Votre offre';

  @override
  String get offerPrice => 'Prix en TND';

  @override
  String get offerMessage => 'Message au client (facultatif)';

  @override
  String get offerDays => 'Délai estimé en jours (facultatif)';

  @override
  String get offerSend => 'Envoyer l’offre';

  @override
  String get offerUpdate => 'Mettre à jour l’offre';

  @override
  String get offerWithdraw => 'Retirer mon offre';

  @override
  String get offerSent => 'Offre envoyée.';

  @override
  String get offerWithdrawn => 'Offre retirée.';

  @override
  String get offerErrPrice => 'Entre 1 et 1 000 000 TND.';

  @override
  String get offerErrMessage => '1000 caractères au maximum.';

  @override
  String get offerErrDays => 'Entre 1 et 365 jours.';

  @override
  String get offerDeclinedNote => 'Le client n’a pas retenu votre offre.';

  @override
  String get offerAcceptedNote =>
      'Votre offre est acceptée : suivez le chantier dans Mes chantiers.';

  @override
  String offerOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offres déjà reçues',
      one: '1 offre déjà reçue',
      zero: 'Aucune autre offre pour l’instant',
    );
    return '$_temp0';
  }

  @override
  String get reqFailOwn =>
      'Vous ne pouvez pas répondre à votre propre demande.';

  @override
  String get reqFailOfferClosed => 'Cette offre ne peut plus être modifiée.';

  @override
  String get reqFailTransition => 'Cette étape n’est plus possible.';

  @override
  String get reqFailForbidden => 'Publiez d’abord votre profil professionnel.';

  @override
  String get offerFailLimit =>
      'Vous avez 50 offres en attente. Retirez-en une avant d’en envoyer une autre.';

  @override
  String get offersReceived => 'Offres reçues';

  @override
  String get offersNoneYet =>
      'Pas encore d’offre. Les professionnels ont jusqu’à l’expiration de la demande pour répondre.';

  @override
  String get sortOffersBy => 'Trier les offres';

  @override
  String get sortOffersPrice => 'Prix';

  @override
  String get sortOffersRating => 'Note';

  @override
  String get sortOffersDelay => 'Délai';

  @override
  String get offerLowest => 'Prix le plus bas';

  @override
  String offerDelay(int count) {
    return 'Délai : $count j';
  }

  @override
  String get offerAccept => 'Accepter';

  @override
  String get offerDecline => 'Refuser';

  @override
  String get offerAcceptTitle => 'Accepter cette offre ?';

  @override
  String offerAcceptBody(String name, String price) {
    return '$name réalisera le travail pour $price. Les autres offres seront refusées et la demande sera attribuée.';
  }

  @override
  String get offerDeclineTitle => 'Refuser cette offre ?';

  @override
  String get offerDeclineBody =>
      'Le professionnel ne pourra pas la proposer à nouveau.';

  @override
  String get offerAcceptedMsg => 'Offre acceptée.';

  @override
  String get offerDeclinedMsg => 'Offre refusée.';

  @override
  String get offerProUnknown => 'Professionnel';

  @override
  String get bookingTitle => 'Chantier';

  @override
  String get bookingConfirm => 'Confirmer que le travail est terminé';

  @override
  String get bookingConfirmed => 'Merci, chantier terminé.';

  @override
  String get bookingCancelled => 'Chantier annulé.';

  @override
  String get bookingCancelTitle => 'Annuler ce chantier ?';

  @override
  String get bookingCancelBody =>
      'Le professionnel sera informé. Cette action est définitive.';

  @override
  String get bookingWaitingForYou =>
      'Le professionnel indique avoir terminé. Le travail est-il bien fait ?';

  @override
  String get chatTitleClient => 'Client';

  @override
  String get chatInputHint => 'Écrivez un message…';

  @override
  String get chatSend => 'Envoyer';

  @override
  String get chatAddImage => 'Joindre une photo';

  @override
  String get chatEmpty => 'Aucun message. Dites bonjour !';

  @override
  String get chatReadOnly =>
      'Cette conversation est terminée : vous pouvez la relire, mais plus y écrire.';

  @override
  String get chatImageSent => 'Photo envoyée';

  @override
  String get chatYouSent => 'Vous';

  @override
  String get chatThem => 'Interlocuteur';

  @override
  String chatUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages non lus',
      one: '1 message non lu',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get chatSendFailed => 'Message non envoyé. Réessayez.';

  @override
  String get chatRateLimited => 'Vous écrivez trop vite. Patientez un instant.';

  @override
  String get chatClosed => 'Cette conversation est terminée.';

  @override
  String get chatOpenFailed =>
      'Impossible d’ouvrir la conversation. Réessayez.';

  @override
  String get chatLiveFailed =>
      'Mise à jour en direct interrompue. Tirez pour actualiser.';

  @override
  String get chatPhotoFailed => 'Photo non envoyée. Réessayez.';

  @override
  String get chatAskPro => 'Poser une question';

  @override
  String get chatWriteCustomer => 'Écrire au client';

  @override
  String get chatPhoto => 'Photo';
}
