// Push texts per notification kind and language. Built from the kind only:
// a notification never carries the content of a message, a name or a number.

export const LANGUAGES = ['fr', 'ar', 'en'];

export const KINDS = [
  'offer_received', 'offer_accepted', 'message',
  'job_started', 'job_done', 'job_completed', 'job_cancelled',
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
    default:
      return '/home';
  }
}
