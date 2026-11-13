import type { ErrorEvent } from '@sentry/react';

const EMAIL = /[\w.+-]+@[\w-]+\.[\w.-]+/g;
const NUMBER = /\+?\d[\d ]{6,}\d/g;
const TOKEN = /(eyJ[\w-]+\.[\w-]+\.[\w-]+|sb_[a-z]+_[\w-]{8,}|Bearer\s+\S+)/g;

/** E-mails, phone-like numbers and tokens out; capped at 300 characters. */
export function scrubText(text: string): string {
  const out = text.replace(TOKEN, '[token]').replace(EMAIL, '[email]').replace(NUMBER, '[number]');
  return out.length > 300 ? `${out.slice(0, 300)}…` : out;
}

/** What leaves the admin panel: error type, scrubbed texts, stack. */
export function scrubEvent(event: ErrorEvent): ErrorEvent {
  delete event.user;
  delete event.request;
  delete event.breadcrumbs;
  delete event.server_name;
  if (event.message) event.message = scrubText(event.message);
  for (const e of event.exception?.values ?? []) {
    if (e.value) e.value = scrubText(e.value);
  }
  return event;
}

/** Error reporting, only when the build sets VITE_SENTRY_DSN (loaded lazily). */
export async function initMonitoring(dsn: string | undefined): Promise<boolean> {
  if (!dsn) return false;
  const Sentry = await import('@sentry/react');
  Sentry.init({
    dsn,
    environment: 'admin',
    // Collect nothing personal: no user, cookies, headers, query strings or bodies.
    dataCollection: { userInfo: false, cookies: false, httpHeaders: false, httpBodies: [], urlQueryParams: false },
    maxBreadcrumbs: 0,
    tracesSampleRate: 0,
    beforeSend: (event) => scrubEvent(event),
  });
  return true;
}
