// Push texts per notification kind and language. Built from the kind only:
// a notification never carries the content of a message, a name or a number.

export const LANGUAGES = ['fr', 'ar', 'en'];

export const KINDS = [
  'offer_received', 'offer_accepted', 'message',
  'job_started', 'job_done', 'job_completed', 'job_cancelled',
  'report_actioned', 'report_dismissed', 'account_suspended', 'account_restored',
  'appeal_rejected', 'verification_expired', 'listing_held', 'listing_released',
];

const TEXTS = {
  offer_received: {
    fr: ['Nouvelle offre', 'Un professionnel a répondu à votre demande.'],
    ar: ['عرض جديد', 'ردّ أحد الحرفيين على طلبك.'],
    en: ['New offer', 'A professional answered your request.'],
  },
  offer_accepted: {
    fr: ['Offre acceptée', 'Un client a accepté votre offre.'],
    ar: ['تم قبول عرضك', 'قبل أحد الزبائن عرضك.'],
    en: ['Offer accepted', 'A customer accepted your offer.'],
  },
  message: {
    fr: ['Nouveau message', 'Vous avez reçu un message.'],
    ar: ['رسالة جديدة', 'وصلتك رسالة.'],
    en: ['New message', 'You have a new message.'],
  },
  job_started: {
    fr: ['Chantier démarré', 'Le professionnel a commencé le travail.'],
    ar: ['بدأ العمل', 'بدأ الحرفي العمل.'],
    en: ['Job started', 'The professional has started the work.'],
  },
  job_done: {
    fr: ['Travail terminé ?', 'Le professionnel indique avoir terminé. Confirmez-vous ?'],
    ar: ['هل انتهى العمل؟', 'يقول الحرفي إنه أنهى العمل. هل تؤكد؟'],
    en: ['Work done?', 'The professional says the work is done. Do you confirm?'],
  },
  job_completed: {
    fr: ['Chantier terminé', 'Le client a confirmé la fin du chantier.'],
    ar: ['اكتمل العمل', 'أكد الزبون انتهاء العمل.'],
    en: ['Job completed', 'The customer confirmed the job is done.'],
  },
  job_cancelled: {
    fr: ['Chantier annulé', 'L’autre partie a annulé le chantier.'],
    ar: ['أُلغي العمل', 'ألغى الطرف الآخر العمل.'],
    en: ['Job cancelled', 'The other party cancelled the job.'],
  },
  report_actioned: {
    fr: ['Signalement traité', 'Merci. Nous avons pris des mesures suite à votre signalement.'],
    ar: ['تمت معالجة البلاغ', 'شكرًا. اتخذنا إجراءً بعد بلاغك.'],
    en: ['Report handled', 'Thank you. We took action after your report.'],
  },
  report_dismissed: {
    fr: ['Signalement examiné', 'Merci. Après examen, aucune mesure n’a été nécessaire.'],
    ar: ['تمت مراجعة البلاغ', 'شكرًا. بعد المراجعة، لم يكن أي إجراء ضروريًا.'],
    en: ['Report reviewed', 'Thank you. After review, no action was needed.'],
  },
  account_suspended: {
    fr: ['Compte suspendu', 'Votre profil professionnel est suspendu. Ouvrez l’app pour voir pourquoi.'],
    ar: ['تم تعليق الحساب', 'تم تعليق ملفك المهني. افتح التطبيق لمعرفة السبب.'],
    en: ['Account suspended', 'Your professional profile is suspended. Open the app to see why.'],
  },
  account_restored: {
    fr: ['Suspension levée', 'Votre profil peut de nouveau être publié.'],
    ar: ['تم رفع التعليق', 'يمكنك نشر ملفك من جديد.'],
    en: ['Suspension lifted', 'Your profile can be published again.'],
  },
  appeal_rejected: {
    fr: ['Recours refusé', 'Votre recours a été examiné et refusé.'],
    ar: ['رُفض الطعن', 'تمت مراجعة طعنك ورفضه.'],
    en: ['Appeal rejected', 'Your appeal was reviewed and rejected.'],
  },
  verification_expired: {
    fr: ['Badge expiré', 'Votre vérification a expiré. Renouvelez-la pour retrouver le badge.'],
    ar: ['انتهت صلاحية الشارة', 'انتهت صلاحية التحقق. جدّده لاستعادة الشارة.'],
    en: ['Badge expired', 'Your verification expired. Renew it to get the badge back.'],
  },
  listing_held: {
    fr: ['Annonce retirée', 'Votre annonce freelance a été retirée. Ouvrez l’app pour voir pourquoi.'],
    ar: ['تم سحب إعلانك', 'تم سحب إعلانك الحر. افتح التطبيق لمعرفة السبب.'],
    en: ['Listing taken down', 'Your freelance listing was taken down. Open the app to see why.'],
  },
  listing_released: {
    fr: ['Annonce débloquée', 'Vous pouvez de nouveau publier votre annonce freelance.'],
    ar: ['تم رفع الحظر عن إعلانك', 'يمكنك نشر إعلانك الحر من جديد.'],
    en: ['Listing unlocked', 'You can publish your freelance listing again.'],
  },
};

/** The title and body for a kind, in `language` (French when unknown). */
export function notificationText(kind, language) {
  const entry = TEXTS[kind];
  if (!entry) return null;
  const [title, body] = entry[LANGUAGES.includes(language) ? language : 'fr'];
  return { title, body };
}

/** Where tapping the notification goes inside the app (a route, never a URL). */
export function notificationRoute(kind, payload) {
  const p = payload ?? {};
  switch (kind) {
    case 'message':
      return p.conversation_id ? `/messages/${p.conversation_id}` : '/messages';
    case 'offer_received':
      return p.request_id ? `/requests/${p.request_id}` : '/requests';
    case 'offer_accepted':
      return '/pro/jobs';
    case 'job_done':
    case 'job_started':
      return p.request_id ? `/requests/${p.request_id}` : '/requests';
    case 'job_completed':
    case 'job_cancelled':
      return '/pro/jobs';
    case 'account_suspended':
    case 'account_restored':
    case 'appeal_rejected':
      return '/pro';
    case 'verification_expired':
      return '/pro/verification';
    case 'listing_held':
    case 'listing_released':
      return '/pro/freelance';
    default:
      return '/home';
  }
}

/** True when [header] is `Bearer <secret>` for the configured worker secret.
 * Compared in constant time; an empty or missing secret never authorizes. */
export function isAuthorized(header, secret) {
  if (typeof header !== 'string' || typeof secret !== 'string' || secret.length < 16) return false;
  const given = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (given.length !== secret.length) return false;
  let diff = 0;
  for (let i = 0; i < secret.length; i++) diff |= given.charCodeAt(i) ^ secret.charCodeAt(i);
  return diff === 0;
}
