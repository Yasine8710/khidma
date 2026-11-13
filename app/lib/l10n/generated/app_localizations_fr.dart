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
  String get acctMemberCard => 'Carte de membre';

  @override
  String get acctAccountType => 'Type de compte';

  @override
  String get acctCustomer => 'Client';

  @override
  String get acctSettings => 'Réglages';

  @override
  String get acctAccount => 'Compte';

  @override
  String get acctWorkshop => 'Atelier';

  @override
  String get acctStatus => 'Statut';

  @override
  String get acctTools => 'Outils';

  @override
  String get profileHelp => 'Aide';

  @override
  String get profileHelpTitle => 'Comment ça marche';

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
  String get navExplore => 'Explorer';

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
  String get discLicenceKicker => 'Fiche professionnelle';

  @override
  String get discFactExperience => 'Expérience';

  @override
  String get discFactAvailability => 'Disponibilité';

  @override
  String get discFactArea => 'Zone';

  @override
  String get discHintPlumbing => 'Fuites, sanitaires, chauffe-eau';

  @override
  String get discHintElectricity => 'Installations, pannes, tableaux';

  @override
  String get discHintAirConditioning => 'Pose, entretien, réparation';

  @override
  String get discHintMechanics => 'Réparation et entretien de véhicules';

  @override
  String get discHintPainting => 'Intérieur et extérieur';

  @override
  String get discHintCarpentry => 'Meubles, portes, fenêtres en bois';

  @override
  String get discHintCleaning => 'Maisons, bureaux, fin de chantier';

  @override
  String get discHintAppliance => 'Lave-linge, réfrigérateurs, fours';

  @override
  String get discHintConstruction => 'Maçonnerie, carrelage, rénovation';

  @override
  String get discHintGardening => 'Jardins et espaces verts';

  @override
  String get discHintMoving => 'Transport et déménagement';

  @override
  String get discHintMaintenance => 'Petits travaux et dépannage';

  @override
  String get homeQuoteTitle => 'Besoin d’un service ?';

  @override
  String get homeQuoteBody =>
      'Décrivez-le une fois et recevez des offres de professionnels.';

  @override
  String get avatarChange => 'Changer la photo';

  @override
  String get avatarChoose => 'Choisir une photo';

  @override
  String get avatarRemove => 'Supprimer la photo';

  @override
  String get avatarFailed =>
      'Impossible de mettre à jour votre photo. Essayez une autre image.';

  @override
  String get avatarLabel => 'Photo de profil';

  @override
  String get statRating => 'Note';

  @override
  String get statReviews => 'Avis';

  @override
  String get statYears => 'Années';

  @override
  String get billTitle => 'Abonnement';

  @override
  String get billCurrent => 'Mon abonnement';

  @override
  String get billNone => 'Aucun abonnement pour le moment.';

  @override
  String get billStatusLabel => 'Statut';

  @override
  String get billStatusActive => 'Actif';

  @override
  String get billStatusPastDue => 'En retard';

  @override
  String get billStatusExpired => 'Expiré';

  @override
  String get billStatusCancelled => 'Résilié';

  @override
  String get billValidUntil => 'Valable jusqu\'au';

  @override
  String get billDaysLeftLabel => 'Jours restants';

  @override
  String billDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours restants',
      one: '1 jour restant',
      zero: 'Expire aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String get billChoosePlan => 'Choisir une formule';

  @override
  String billPeriod(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get billChooseMethod => 'Mode de paiement';

  @override
  String get billMethodFlouci => 'Flouci';

  @override
  String get billMethodFlouciHint =>
      'Paiement en ligne, confirmé automatiquement';

  @override
  String get billMethodD17 => 'D17';

  @override
  String get billMethodD17Hint =>
      'Envoi depuis votre portefeuille La Poste, confirmé par notre équipe';

  @override
  String get billMethodBank => 'Virement bancaire';

  @override
  String get billMethodBankHint =>
      'Virement vers notre compte, confirmé par notre équipe';

  @override
  String get billPay => 'Payer';

  @override
  String get billFlouciOpened =>
      'Le paiement s\'est ouvert dans votre navigateur. Revenez ici ensuite.';

  @override
  String get billMyPayments => 'Mes paiements';

  @override
  String get billNoPayments => 'Aucun paiement pour le moment.';

  @override
  String get billOrderPending => 'En attente';

  @override
  String get billOrderAwaiting => 'À confirmer';

  @override
  String get billOrderPaid => 'Payé';

  @override
  String get billOrderFailed => 'Échoué';

  @override
  String get billOrderCancelled => 'Annulé';

  @override
  String get billOrderRejected => 'Refusé';

  @override
  String get billInstructionsTitle => 'Instructions de paiement';

  @override
  String get billAmount => 'Montant';

  @override
  String get billReference => 'Référence';

  @override
  String get billReferenceHint =>
      'Écrivez cette référence dans le motif du virement ou la note D17.';

  @override
  String get billCopy => 'Copier';

  @override
  String get billCopied => 'Copié';

  @override
  String get billPayTo => 'Payer à';

  @override
  String get billBankName => 'Banque';

  @override
  String get billHolder => 'Titulaire';

  @override
  String get billRib => 'RIB';

  @override
  String get billD17Number => 'Numéro D17';

  @override
  String get billNoDetails =>
      'Les coordonnées de paiement ne sont pas encore disponibles.';

  @override
  String get billIPaid => 'J\'ai payé';

  @override
  String get billPaidTitle => 'Votre paiement';

  @override
  String get billNoteLabel => 'Note (facultatif)';

  @override
  String get billSend => 'Envoyer';

  @override
  String get billCancelOrder => 'Annuler la commande';

  @override
  String get billAwaitingBody =>
      'Merci. Notre équipe vérifie votre paiement, votre abonnement démarre dès sa confirmation.';

  @override
  String get billNotProTitle => 'Devenez professionnel d\'abord';

  @override
  String get billNotProBody =>
      'L\'abonnement est réservé aux professionnels. Créez d\'abord votre profil.';

  @override
  String get billNotProCta => 'Créer mon profil';

  @override
  String get billErrNetwork => 'Pas de connexion. Réessayez.';

  @override
  String get billErrSignedIn => 'Reconnectez-vous puis réessayez.';

  @override
  String get billErrRate => 'Trop de commandes aujourd\'hui. Réessayez demain.';

  @override
  String get billErrInvalid => 'Cette demande n\'est pas valide.';

  @override
  String get billErrNotFound => 'Cette commande n\'existe plus.';

  @override
  String get billErrNotConfigured =>
      'Les paiements ne sont pas encore disponibles.';

  @override
  String get billFlouciUnavailable =>
      'Flouci n\'est pas encore disponible, utilisez D17 ou le virement.';

  @override
  String get billCannotOpen => 'Impossible d\'ouvrir le lien de paiement.';

  @override
  String get billErrUnknown => 'Une erreur est survenue. Réessayez.';

  @override
  String get flTitle => 'Services digitaux';

  @override
  String get flHomeSubtitle => 'Développeurs, designers, monteurs, rédacteurs…';

  @override
  String get flSearchHint => 'Rechercher un freelance ou une compétence…';

  @override
  String get flCategories => 'Catégories';

  @override
  String get flAllCategories => 'Toutes';

  @override
  String get flResultsTitle => 'Freelances';

  @override
  String get flEmptyTitle => 'Aucun freelance trouvé';

  @override
  String get flEmptyBody => 'Essayez un autre mot ou une autre catégorie.';

  @override
  String get flLoadFailed => 'Impossible de charger les freelances.';

  @override
  String flPriceFrom(String price, String unit) {
    return 'à partir de $price / $unit';
  }

  @override
  String get flUnitProject => 'projet';

  @override
  String get flUnitHour => 'heure';

  @override
  String get flUnitDay => 'jour';

  @override
  String get flNotFoundTitle => 'Freelance introuvable';

  @override
  String get flNotFoundBody => 'Cette page n’existe plus ou n’est pas publiée.';

  @override
  String get flFactPrice => 'Tarif';

  @override
  String get flFactLanguages => 'Langues';

  @override
  String get flSkills => 'Compétences';

  @override
  String get flPortfolio => 'Réalisations';

  @override
  String flOpenItem(String title) {
    return 'Ouvrir : $title';
  }

  @override
  String get flKindImage => 'Photo';

  @override
  String get flKindClip => 'Clip vidéo';

  @override
  String get flKindVideoLink => 'Vidéo en ligne';

  @override
  String get flKindLink => 'Lien';

  @override
  String get flTestimonials => 'Témoignages clients';

  @override
  String get flTestimonialLabel => 'Témoignage client';

  @override
  String get flTestimonialsNote =>
      'Ces témoignages viennent d’anciens clients invités par le freelance. Ils sont différents des avis vérifiés laissés après un travail réalisé via Khidma.';

  @override
  String get flTestimonialsEmpty => 'Pas encore de témoignage.';

  @override
  String flTestimonialProject(String title) {
    return 'Projet : $title';
  }

  @override
  String flStars(int count) {
    return '$count sur 5';
  }

  @override
  String get flDashRow => 'Activité freelance';

  @override
  String get flManageTitle => 'Mon activité freelance';

  @override
  String get flIntroTitle => 'Proposez vos services digitaux';

  @override
  String get flIntroBody =>
      'Développement, design, montage, marketing, rédaction… Créez une page publique avec vos réalisations et des témoignages clients. Votre identité vérifiée est la même que pour votre profil de métier : une seule vérification suffit.';

  @override
  String get flBecome => 'Devenir freelance';

  @override
  String get flSectionProfile => 'Ma page';

  @override
  String get flFieldName => 'Nom affiché';

  @override
  String get flFieldHeadline => 'Titre professionnel';

  @override
  String get flFieldHeadlineHint => 'Ex. Développeur Flutter';

  @override
  String get flFieldCategory => 'Catégorie';

  @override
  String get flFieldBio => 'Présentation';

  @override
  String get flFieldBioHelp =>
      '20 caractères minimum pour publier, 2000 au maximum.';

  @override
  String get flFieldSkills => 'Compétences';

  @override
  String get flFieldSkillsHelp => 'Séparées par des virgules, 12 au maximum.';

  @override
  String get flFieldLanguages => 'Langues';

  @override
  String get flFieldLanguagesHelp => 'Séparées par des virgules, 6 au maximum.';

  @override
  String get flFieldYears => 'Années d’expérience';

  @override
  String get flFieldPrice => 'Tarif de départ (DT)';

  @override
  String get flFieldUnit => 'Par';

  @override
  String get flFieldAvailability => 'Disponibilité';

  @override
  String get flErrName => '2 à 80 caractères.';

  @override
  String get flErrHeadline => '5 à 100 caractères.';

  @override
  String get flErrBio => '2000 caractères au maximum.';

  @override
  String get flErrYears => 'Entre 0 et 60.';

  @override
  String get flErrPrice => 'Montant invalide.';

  @override
  String flErrTags(int max) {
    return '30 caractères par élément, $max éléments au plus.';
  }

  @override
  String get flSaved => 'Page enregistrée.';

  @override
  String get flIdentityTitle => 'Identité';

  @override
  String get flIdentityVerified => 'Identité vérifiée.';

  @override
  String get flIdentityNotVerified => 'Identité pas encore vérifiée.';

  @override
  String get flIdentityShared =>
      'Une seule vérification sert à votre profil de métier et à votre page freelance.';

  @override
  String get flPublish => 'Publier ma page';

  @override
  String get flPublishedHint =>
      'Votre page est visible dans Services digitaux.';

  @override
  String get flUnpublishedHint =>
      'Votre page n’est pas visible pour le moment.';

  @override
  String get flPublishBlocked =>
      'La publication est bloquée tant que votre identité n’est pas vérifiée.';

  @override
  String get flErrNotVerified =>
      'Votre identité n’est pas encore vérifiée. Faites-la vérifier pour publier.';

  @override
  String get flErrIncomplete =>
      'Page incomplète : ajoutez un numéro de téléphone de contact dans votre profil de métier, puis renseignez nom, titre, catégorie et présentation (20 caractères minimum).';

  @override
  String get flErrSuspended =>
      'Votre compte est suspendu : la publication est impossible.';

  @override
  String get flErrGeneric =>
      'L’opération a échoué. Vérifiez votre connexion et réessayez.';

  @override
  String get flErrNotConfigured =>
      'Le service n’est pas disponible pour le moment.';

  @override
  String get flErrInvalid =>
      'Certaines informations sont refusées. Vérifiez-les et réessayez.';

  @override
  String get flErrRate => 'Trop de demandes. Réessayez plus tard.';

  @override
  String flPortCount(int count, int max) {
    return '$count sur $max réalisations';
  }

  @override
  String get flPortEmpty => 'Aucune réalisation pour le moment.';

  @override
  String get flPortAddPhoto => 'Ajouter une photo';

  @override
  String get flPortAddClip => 'Ajouter un clip (30 s max)';

  @override
  String get flPortAddVideoLink => 'Ajouter une vidéo en ligne';

  @override
  String get flPortAddLink => 'Ajouter un lien';

  @override
  String get flPortLimit => 'Limite de 24 réalisations atteinte.';

  @override
  String get flPortTooLarge => 'Fichier trop lourd (25 Mo au maximum).';

  @override
  String get flPortBadFormat =>
      'Format non pris en charge : utilisez un clip mp4 ou webm, ou ajoutez un lien vidéo.';

  @override
  String get flFieldTitle => 'Titre';

  @override
  String get flFieldDescription => 'Description (facultatif)';

  @override
  String get flFieldUrl => 'Adresse du lien';

  @override
  String get flErrTitle => '2 à 100 caractères.';

  @override
  String get flErrDescription => '500 caractères au maximum.';

  @override
  String get flErrUrlVideo => 'Lien https YouTube ou Vimeo uniquement.';

  @override
  String get flErrUrlLink => 'Entrez une adresse https valide.';

  @override
  String get flSheetAdd => 'Ajouter';

  @override
  String get flSheetChooseFile => 'Choisir le fichier';

  @override
  String get flItemEdit => 'Modifier';

  @override
  String get flItemDelete => 'Supprimer';

  @override
  String get flItemDeleteTitle => 'Supprimer cette réalisation ?';

  @override
  String get flItemDeleteBody => 'Elle ne sera plus visible sur votre page.';

  @override
  String get flUploading => 'Envoi en cours…';

  @override
  String get flInvTitle => 'Invitations de témoignage';

  @override
  String get flInvHint =>
      'Envoyez un lien personnel à un ancien client : il écrit son témoignage sur une page web, sans compte. Le lien est valable 30 jours et ne sert qu’une fois.';

  @override
  String get flInvCreate => 'Créer un lien d’invitation';

  @override
  String get flInvLabelField => 'Pour qui ? (facultatif)';

  @override
  String get flInvNotConfigured =>
      'Les liens de témoignage ne sont pas encore configurés dans cette version de l’application.';

  @override
  String get flInvLinkTitle => 'Lien créé';

  @override
  String get flInvLinkWarn => 'Copiez-le maintenant : il ne sera plus affiché.';

  @override
  String get flInvCopy => 'Copier le lien';

  @override
  String get flInvCopied => 'Lien copié.';

  @override
  String get flInvShare => 'Partager par WhatsApp';

  @override
  String flInvShareText(String url) {
    return 'Bonjour, pourriez-vous laisser un témoignage sur notre collaboration ? $url';
  }

  @override
  String get flInvEmpty => 'Aucune invitation pour le moment.';

  @override
  String get flInvStatusOpen => 'En attente';

  @override
  String get flInvStatusUsed => 'Utilisée';

  @override
  String get flInvStatusExpired => 'Expirée';

  @override
  String flInvExpires(String date) {
    return 'Expire le $date';
  }

  @override
  String get flInvNoLabel => 'Sans nom';

  @override
  String get flInvRevoke => 'Révoquer';

  @override
  String get flInvRevokeTitle => 'Révoquer cette invitation ?';

  @override
  String get flInvRevokeBody => 'Le lien ne fonctionnera plus.';

  @override
  String get flInvLimit => '20 invitations en attente au maximum.';

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
  String get regDone => 'Terminer';

  @override
  String get regUsePosition => 'Utiliser ma position actuelle';

  @override
  String get regPositionSet =>
      'Position approximative enregistrée (environ 1 km).';

  @override
  String get regPositionFailed =>
      'Position introuvable. Vérifiez l’autorisation de localisation : sinon la carte utilisera votre gouvernorat.';

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
  String flowRef(String code) {
    return 'N° $code';
  }

  @override
  String flowRequestCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes',
      one: '1 demande',
    );
    return '$_temp0';
  }

  @override
  String get flowSecService => 'Service';

  @override
  String get flowSecNeed => 'Le besoin';

  @override
  String get flowSecWhere => 'Où';

  @override
  String get flowSecWhen => 'Quand';

  @override
  String get flowSecPhotos => 'Photos';

  @override
  String get flowFactPlace => 'Lieu';

  @override
  String get flowFactBudget => 'Budget indicatif';

  @override
  String get flowFactNeededBy => 'Souhaité pour le';

  @override
  String get flowFactExpires => 'Expire le';

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

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifIntro =>
      'Choisissez ce pour quoi vous voulez être prévenu. Les notifications ne contiennent jamais le texte de vos messages.';

  @override
  String get notifOffers => 'Offres reçues et acceptées';

  @override
  String get notifMessages => 'Nouveaux messages';

  @override
  String get notifJobs => 'Avancement des chantiers';

  @override
  String get notifNoPush =>
      'Les notifications push ne sont pas encore disponibles sur cet appareil. Vos choix sont enregistrés pour plus tard.';

  @override
  String get notifSaveFailed => 'Impossible d’enregistrer ce choix. Réessayez.';

  @override
  String get reviewsTitle => 'Avis';

  @override
  String get reviewsEmpty => 'Pas encore d’avis.';

  @override
  String get reviewsMore => 'Voir plus d’avis';

  @override
  String get reviewsLoadFailed => 'Impossible de charger les avis.';

  @override
  String get reviewCta => 'Laisser un avis';

  @override
  String get reviewCtaPro => 'Noter le client';

  @override
  String get reviewSheetTitle => 'Votre avis';

  @override
  String get reviewSheetTitlePro => 'Votre avis sur le client';

  @override
  String get reviewRatingHint => 'Touchez une étoile';

  @override
  String reviewStar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étoiles',
      one: '1 étoile',
    );
    return '$_temp0';
  }

  @override
  String get reviewComment => 'Commentaire (facultatif)';

  @override
  String get reviewSubmit => 'Publier mon avis';

  @override
  String get reviewPublicNote => 'Votre avis sera public, sans votre nom.';

  @override
  String get reviewPrivateNote =>
      'Cet avis n’est visible que par l’équipe Khidma.';

  @override
  String get reviewErrRating => 'Choisissez une note de 1 à 5.';

  @override
  String get reviewThanks => 'Merci pour votre avis.';

  @override
  String get reviewDone => 'Avis donné';

  @override
  String get reviewFailAlready =>
      'Vous avez déjà donné votre avis sur ce chantier.';

  @override
  String get reviewFailNotCompleted =>
      'Le chantier doit être terminé pour laisser un avis.';

  @override
  String get reviewFailGeneric => 'Impossible d’envoyer l’avis. Réessayez.';

  @override
  String get reviewAuthorAnon => 'Client';

  @override
  String get reviewFailLimit =>
      'Vous avez déjà donné trop d’avis sur ce professionnel.';

  @override
  String get reportAction => 'Signaler';

  @override
  String get reportTitle => 'Signaler un problème';

  @override
  String get reportHint =>
      'Notre équipe examine chaque signalement. La personne signalée ne saura pas que c’est vous.';

  @override
  String get reportReasonSpam => 'Publicité ou spam';

  @override
  String get reportReasonFake => 'Faux profil ou faux avis';

  @override
  String get reportReasonAbuse => 'Harcèlement ou insultes';

  @override
  String get reportReasonScam => 'Arnaque ou demande d’argent suspecte';

  @override
  String get reportReasonInappropriate => 'Contenu inapproprié';

  @override
  String get reportReasonOther => 'Autre';

  @override
  String get reportDetailsLabel => 'Détails (facultatif)';

  @override
  String get reportSend => 'Envoyer le signalement';

  @override
  String get reportSent => 'Merci. Votre signalement a été envoyé.';

  @override
  String get reportFailAlready =>
      'Vous avez déjà signalé cela. Nous l’examinons.';

  @override
  String get reportFailRate =>
      'Trop de signalements aujourd’hui. Réessayez demain.';

  @override
  String get reportFailGone => 'Ce contenu n’est plus disponible.';

  @override
  String get reportFailGeneric =>
      'Le signalement n’a pas pu être envoyé. Vérifiez votre connexion et réessayez.';

  @override
  String get verifTitle => 'Vérification du profil';

  @override
  String get verifCta => 'Faire vérifier mon profil';

  @override
  String get verifIntro =>
      'Envoyez une photo de votre carte d’identité ou de votre registre de commerce. Après vérification, un badge apparaît sur votre profil.';

  @override
  String get verifPrivacy =>
      'Vos documents sont privés : seuls vous et notre équipe de vérification peuvent les voir, et ils sont supprimés dès la décision.';

  @override
  String get verifStatusNone => 'Pas encore vérifié';

  @override
  String get verifStatusPending => 'En cours de vérification';

  @override
  String get verifStatusApproved => 'Profil vérifié';

  @override
  String get verifStatusRejected => 'Demande refusée';

  @override
  String get verifStatusCancelled => 'Demande annulée';

  @override
  String verifRejectReason(Object reason) {
    return 'Motif : $reason';
  }

  @override
  String get verifPendingBody =>
      'Nous examinons vos documents. Vous serez prévenu de la décision.';

  @override
  String get verifAdd => 'Ajouter une photo';

  @override
  String verifCount(Object count, Object max) {
    return '$count sur $max documents';
  }

  @override
  String verifRemove(Object index) {
    return 'Retirer le document $index';
  }

  @override
  String get verifSubmit => 'Envoyer pour vérification';

  @override
  String get verifCancel => 'Annuler la demande';

  @override
  String get verifSent => 'Documents envoyés. Nous vous répondons bientôt.';

  @override
  String get verifCancelled =>
      'Demande annulée. Vos documents ont été supprimés.';

  @override
  String get verifFailPending => 'Une demande est déjà en cours.';

  @override
  String get verifFailVerified => 'Votre profil est déjà vérifié.';

  @override
  String get verifFailLimit =>
      'Trop de demandes ces 30 derniers jours. Réessayez plus tard.';

  @override
  String get verifFailGeneric =>
      'L’envoi a échoué. Vérifiez votre connexion et réessayez.';

  @override
  String get verifFailImage =>
      'Ce fichier n’est pas une photo lisible (JPEG, PNG ou WebP).';

  @override
  String get reqFilterAll => 'Toutes';

  @override
  String get reqFilterOpen => 'Ouvertes';

  @override
  String get reqFilterClosed => 'Terminées';

  @override
  String get reqFilterEmpty => 'Aucune demande dans cette liste.';

  @override
  String reqFormProgress(int done, int total) {
    return '$done sur $total étapes remplies';
  }

  @override
  String get chatToday => 'Aujourd’hui';

  @override
  String get chatYesterday => 'Hier';

  @override
  String get verifStepSend => 'Documents envoyés';

  @override
  String get verifStepReview => 'Examen par l’équipe';

  @override
  String get verifStepBadge => 'Badge sur votre profil';

  @override
  String get worldTrades => 'Artisans';

  @override
  String get worldDigital => 'Freelance digital';

  @override
  String get homeNearbyTitle => 'Pros près de vous';

  @override
  String get homeHeroFreelanceBody =>
      'Montrez vos réalisations et trouvez des clients.';

  @override
  String get homeHeroDigitalCta => 'Découvrir';

  @override
  String priceFromShort(String price) {
    return 'dès $price';
  }

  @override
  String get docsVerified => 'Documents vérifiés';

  @override
  String get identityVerified => 'Identité vérifiée';

  @override
  String yearsShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ans',
      one: '1 an',
    );
    return '$_temp0';
  }

  @override
  String get welcomeHeadlineStart => 'Trouvez un';

  @override
  String get welcomeHeadlineEnd => 'près de chez vous.';

  @override
  String get welcomeWordPlumber => 'plombier';

  @override
  String get welcomeWordElectrician => 'électricien';

  @override
  String get welcomeWordDeveloper => 'développeur';

  @override
  String get welcomeWordDesigner => 'designer';

  @override
  String get welcomeWordCarpenter => 'menuisier';

  @override
  String get welcomeHeadlineA11y =>
      'Trouvez un plombier, un électricien, un développeur, un designer ou un menuisier près de chez vous.';

  @override
  String get welcomeSubtitle =>
      'Comparez les devis, discutez et réservez, partout en Tunisie.';

  @override
  String get welcomeTrust => 'Artisans et freelances vérifiés';

  @override
  String get welcomeHaveAccount => 'J\'ai déjà un compte';

  @override
  String get welcomeLegal =>
      'En continuant, vous acceptez les conditions d\'utilisation.';

  @override
  String welcomeLanguageButton(String language) {
    return 'Langue : $language';
  }

  @override
  String get welcomeTradePlumber => 'Plombier';

  @override
  String get welcomeTradeDesigner => 'Designer UI';

  @override
  String get welcomeTradeElectrician => 'Électricien';

  @override
  String get welcomeTradeDeveloper => 'Développeuse';

  @override
  String get welcomeTradeCarpenter => 'Menuisier';

  @override
  String get welcomeTradeVideo => 'Monteuse vidéo';

  @override
  String get reportReasonPayOutside =>
      'Demande de paiement d’avance ou hors de l’app';

  @override
  String get reportReasonNoShow => 'Ne s’est pas présenté';

  @override
  String get reportMessageAction => 'Signaler ce message';

  @override
  String get reportOfferAction => 'Signaler cette offre';

  @override
  String get chatSafetyTip =>
      'Ne payez jamais d’avance. Gardez vos accords dans Khidma.';

  @override
  String get failSuspended =>
      'Votre compte est suspendu : cette action n’est pas possible.';

  @override
  String get suspendedTitle => 'Compte suspendu';

  @override
  String suspendedUntil(String date) {
    return 'Votre profil est masqué jusqu’au $date. Vous ne pouvez pas envoyer d’offres ni de messages.';
  }

  @override
  String get suspendedIndefinite =>
      'Votre profil est masqué jusqu’à la décision de l’équipe. Vous ne pouvez pas envoyer d’offres ni de messages.';

  @override
  String suspendedReason(String reason) {
    return 'Motif : $reason';
  }

  @override
  String get appealAction => 'Faire un recours';

  @override
  String get appealHint =>
      'Expliquez pourquoi cette suspension est une erreur.';

  @override
  String get appealTooShort => 'Écrivez au moins 10 caractères.';

  @override
  String get appealSend => 'Envoyer le recours';

  @override
  String get appealSent => 'Recours envoyé. L’équipe va l’examiner.';

  @override
  String get appealPending => 'Votre recours est en cours d’examen.';

  @override
  String get appealRejected => 'Votre dernier recours a été refusé.';

  @override
  String get appealFailRate =>
      'Attendez une semaine après un refus avant un nouveau recours.';

  @override
  String get appealFailGeneric =>
      'Le recours n’a pas pu être envoyé. Réessayez.';

  @override
  String verifiedUntil(String date) {
    return 'Identité vérifiée, valable jusqu’au $date';
  }

  @override
  String get flPolicyTitle => 'Services interdits';

  @override
  String get flPolicyIntro =>
      'Une annonce qui propose l’un de ces services est retirée, et le compte peut être suspendu.';

  @override
  String get flPolicyIllegal =>
      'Tout service illégal en Tunisie, ou qui aide à contourner la loi.';

  @override
  String get flPolicyAcademic =>
      'Faire à la place d’un élève ou d’un étudiant un devoir, un mémoire ou un examen.';

  @override
  String get flPolicyDocuments =>
      'Faux documents : diplômes, attestations, pièces d’identité, factures.';

  @override
  String get flPolicyPlagiarism =>
      'Un portfolio avec le travail de quelqu’un d’autre présenté comme le vôtre.';

  @override
  String get flPolicyAccounts =>
      'Vente de comptes, de faux avis, d’abonnés ou de « likes ».';

  @override
  String get flPolicyAccept => 'J’accepte et je publie';

  @override
  String get flPolicyLink => 'Voir les services interdits';

  @override
  String get flOnHoldTitle => 'Annonce retirée par l’équipe';

  @override
  String flOnHoldReason(String reason) {
    return 'Motif : $reason. Corrigez votre annonce puis contactez le support pour la remettre en ligne.';
  }

  @override
  String get flErrOnHold =>
      'Votre annonce est retirée : elle ne peut pas être publiée pour l’instant.';

  @override
  String get billAttachProof => 'Joindre un justificatif';

  @override
  String get billProofHint =>
      'Facultatif : une photo du reçu aide à confirmer plus vite.';

  @override
  String billProofCount(int count) {
    return '$count sur 3 justificatifs joints.';
  }

  @override
  String get billProofLimit => 'Vous avez déjà joint 3 justificatifs.';

  @override
  String billRejectedNote(String note) {
    return 'Paiement refusé : $note';
  }

  @override
  String get listingHiddenTitle => 'Profil masqué';

  @override
  String get listingHiddenBody =>
      'Votre abonnement n’est pas réglé : les clients ne voient plus votre profil et vous ne pouvez pas envoyer d’offres. Vos chantiers en cours continuent. Le profil réapparaît dès le paiement.';

  @override
  String get listingTrialTitle => 'Essai gratuit';

  @override
  String listingTrialBody(String date) {
    return 'Votre profil est visible gratuitement jusqu’au $date. Abonnez-vous avant pour rester visible.';
  }

  @override
  String get listingPay => 'Régler mon abonnement';

  @override
  String get reqFailSubscription =>
      'Votre abonnement n’est pas réglé : vous ne pouvez pas envoyer d’offre pour l’instant.';

  @override
  String get projNewTitle => 'Projet en ligne';

  @override
  String get projNewCta => 'Publier un projet en ligne';

  @override
  String get projMine => 'Mes projets en ligne';

  @override
  String get projFieldTitle => 'Titre du projet';

  @override
  String get projFieldCategory => 'Type de travail';

  @override
  String get projFieldBrief => 'Brief : décrivez le besoin';

  @override
  String get projFieldDeliverables => 'Livrables attendus';

  @override
  String get projDeliverablesHint => 'Ex. : logo en PNG et SVG, 3 propositions';

  @override
  String get projFieldBudgetMin => 'Budget min (TND)';

  @override
  String get projFieldBudgetMax => 'Budget max (TND)';

  @override
  String get projFieldDeadline => 'Date limite (facultatif)';

  @override
  String get projFieldLink => 'Lien de référence (https)';

  @override
  String get projAddLink => 'Ajouter un lien';

  @override
  String get projErrLink => 'Seuls les liens https:// sont acceptés.';

  @override
  String get projErrBudget =>
      'Le budget max doit être supérieur ou égal au min.';

  @override
  String get projErrRequired => '3 caractères minimum.';

  @override
  String get projErrBrief => '10 caractères minimum.';

  @override
  String get projErrCategory => 'Choisissez un type de travail.';

  @override
  String get projSubmit => 'Publier le projet';

  @override
  String get projCreated =>
      'Projet publié. Les freelances peuvent vous faire des offres.';

  @override
  String get projEmpty => 'Aucun projet en ligne pour l’instant.';

  @override
  String get projEmptyOpen => 'Aucun projet ouvert pour le moment.';

  @override
  String get projRemote => 'À distance';

  @override
  String projBudget(String range) {
    return 'Budget : $range';
  }

  @override
  String projDeadline(String date) {
    return 'À livrer avant le $date';
  }

  @override
  String get projDeliverables => 'Livrables';

  @override
  String get projLinks => 'Références';

  @override
  String get projTerms =>
      'Khidma ne détient pas l’argent : le paiement se règle directement entre vous et le freelance. Mettez-vous d’accord dans la conversation et ne payez jamais tout d’avance.';

  @override
  String get projOpenTitle => 'Projets ouverts';

  @override
  String get projOfferTitle => 'Votre offre';

  @override
  String get projOfferPrice => 'Prix (TND)';

  @override
  String get projOfferDays => 'Délai de livraison (jours)';

  @override
  String get projOfferRevisions => 'Révisions incluses';

  @override
  String get projOfferMessage => 'Message (facultatif)';

  @override
  String get projOfferSend => 'Envoyer l’offre';

  @override
  String get projOfferSent => 'Offre envoyée.';

  @override
  String get projErrOffer =>
      'Prix ≥ 1, délai de 1 à 365 jours, 0 à 20 révisions.';

  @override
  String projRevisionsIncluded(int count) {
    return '$count révision(s) incluse(s)';
  }

  @override
  String get projDeliverTitle => 'Livrer le travail';

  @override
  String get projDeliverNote => 'Message de livraison';

  @override
  String get projDeliverLink => 'Lien (Drive, WeTransfer, Figma…)';

  @override
  String get projDeliverAddPhoto => 'Ajouter une image';

  @override
  String projDeliverPhotos(int count) {
    return '$count image(s) jointe(s)';
  }

  @override
  String get projDeliverSend => 'Livrer';

  @override
  String get projDelivered => 'Travail livré. Le client va vérifier.';

  @override
  String get projDeliverEmpty => 'Ajoutez un message, un lien ou une image.';

  @override
  String get projDeliveriesTitle => 'Livraisons';

  @override
  String projDeliveryFile(int n) {
    return 'Fichier $n';
  }

  @override
  String get projNoDelivery => 'Rien n’a encore été livré.';

  @override
  String get projRevisionAsk => 'Demander une révision';

  @override
  String get projRevisionHint => 'Ce qu’il faut changer';

  @override
  String projRevisionLeft(int count) {
    return '$count révision(s) restante(s)';
  }

  @override
  String get projRevisionSent => 'Demande de révision envoyée.';

  @override
  String get projOpenFileFailed => 'Le fichier n’a pas pu être ouvert.';

  @override
  String get projStartJob => 'Commencer le travail';
}
