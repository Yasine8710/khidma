// Delivery worker for the notification outbox (Supabase Edge Function).
//
// STATUS: written but NOT run: it needs a Firebase project (FCM) and APNs
// credentials that do not exist yet (issue #26). The database side (outbox,
// claim/complete functions, retries, dedup) is tested in backend/tests; the
// texts and routes are tested in backend/tests/notification_texts.test.mjs.
//
// Run it on a schedule (e.g. every minute via pg_cron + pg_net, or a Supabase
// scheduled function). Secrets (never in the repo):
//   FIREBASE_SERVICE_ACCOUNT  JSON of a service account allowed to send FCM
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (provided by Supabase)
//
// Flow: claim_notifications() -> for each token send via FCM HTTP v1 ->
// complete_notification(id, attempt, delivered, error); the attempt number
// fences stale reports. Tokens FCM reports as unregistered are removed with
// forget_device_token(). Known limit: a row counts as delivered when at least
// one of the account's devices accepted it.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { notificationRoute, notificationText } from './texts.mjs';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);
const account = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}');

async function accessToken(): Promise<string> {
  // Google OAuth2 service-account flow (JWT bearer), scope firebase.messaging.
  const now = Math.floor(Date.now() / 1000);
  const enc = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
  const header = enc({ alg: 'RS256', typ: 'JWT' });
  const claims = enc({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  });
  const key = await crypto.subtle.importKey(
    'pkcs8',
    Uint8Array.from(atob(account.private_key.replace(/-----[^-]+-----|\s/g, '')), (c) => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`)));
  const jwt = `${header}.${claims}.${btoa(String.fromCharCode(...sig)).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_')}`;
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }),
  });
  return (await r.json()).access_token;
}

Deno.serve(async () => {
  const { data: rows, error } = await supabase.rpc('claim_notifications', { p_limit: 100 });
  if (error) return new Response(error.message, { status: 500 });
  if (!rows?.length) return new Response('nothing to send');
  const bearer = await accessToken();
  let sent = 0;
  for (const row of rows) {
    const text = notificationText(row.kind, row.language);
    if (!text || !row.tokens?.length) {
      // Nothing to send to (no device): done, so it is not retried forever.
      await supabase.rpc('complete_notification', { p_id: row.id, p_attempt: row.attempt, p_delivered: true });
      continue;
    }
    let delivered = false;
    let lastError = '';
    for (const { token } of row.tokens) {
      try {
      const r = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
        method: 'POST',
        headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: text.title, body: text.body },
            data: { route: notificationRoute(row.kind, row.payload) },
          },
        }),
      });
      if (r.ok) {
        delivered = true;
      } else {
        const body = await r.text();
        lastError = `${r.status} ${body}`.slice(0, 300);
        if (r.status === 404 || body.includes('UNREGISTERED')) {
          await supabase.rpc('forget_device_token', { p_token: token });
        }
      }
      } catch (e) {
        // A network error on one device must not crash the whole batch.
        lastError = String(e).slice(0, 300);
      }
    }
    await supabase.rpc('complete_notification', {
      p_id: row.id,
      p_attempt: row.attempt,
      p_delivered: delivered,
      p_error: delivered ? null : lastError || 'no delivery',
    });
    if (delivered) sent++;
  }
  return new Response(`sent ${sent} of ${rows.length}`);
});
