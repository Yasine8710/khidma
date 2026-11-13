// Pure helpers for the Flouci Edge Function (tested in backend/tests).
// Flouci API v2 (https://docs.flouci.com): amounts are millimes; the webhook
// is a signed POST (webhook_version 2) with header
// `X-Flouci-Signature: t=<unix seconds>,v1=<hex HMAC-SHA256(private, "<t>.<raw body>")>`.

export const FLOUCI_API = 'https://developers.flouci.com/api/v2';

/** Body for POST /generate_payment. Amount is a string of millimes. */
export function buildGenerateBody({ order, webhookUrl, successUrl, failUrl }) {
  return {
    amount: String(order.amount_millimes),
    developer_tracking_id: order.id,
    accept_card: true,
    success_link: successUrl,
    fail_link: failUrl,
    webhook: webhookUrl,
    webhook_version: 2,
    session_timeout_secs: 1800,
  };
}

/** `Bearer <public>:<private>` */
export const authHeader = (pub, priv) => `Bearer ${pub}:${priv}`;

function hex(bytes) {
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function constantTimeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function hmacHex(secret, message) {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return hex(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message)));
}

/** True when the signature header matches the raw body and is recent. */
export async function verifySignature({ header, rawBody, secret, nowSeconds, toleranceSeconds = 300 }) {
  if (typeof header !== 'string' || typeof rawBody !== 'string' || typeof secret !== 'string' || secret.length < 8) {
    return false;
  }
  const parts = Object.fromEntries(
    header.split(',').map((p) => p.trim().split('=')).filter((p) => p.length === 2));
  const t = Number(parts.t);
  if (!Number.isInteger(t) || typeof parts.v1 !== 'string') return false;
  if (Math.abs(nowSeconds - t) > toleranceSeconds) return false;
  return constantTimeEqual(await hmacHex(secret, `${t}.${rawBody}`), parts.v1.toLowerCase());
}

/** Parses a webhook v2 body; null when it is not one we understand. */
export function parseWebhook(rawBody) {
  let e;
  try { e = JSON.parse(rawBody); } catch { return null; }
  if (!e || typeof e !== 'object') return null;
  if (e.event !== 'payment.succeeded' && e.event !== 'payment.failed') return null;
  if (typeof e.event_id !== 'string' || typeof e.payment_id !== 'string') return null;
  return { event: e.event, eventId: e.event_id, paymentId: e.payment_id, trackingId: e.developer_tracking_id ?? null };
}

/** The verify_payment answer says "paid" only for success === true and SUCCESS. */
export function interpretVerify(body) {
  const ok = body && body.success === true && body.result && body.result.status === 'SUCCESS';
  return {
    paid: Boolean(ok),
    amountMillimes: Number.isInteger(body?.result?.amount) ? body.result.amount : null,
    trackingId: body?.result?.developer_tracking_id ?? null,
  };
}

/** The redirect landing pages must be https and are configured, never guessed. */
export function isHttpsUrl(u) {
  try { return new URL(u).protocol === 'https:'; } catch { return false; }
}
