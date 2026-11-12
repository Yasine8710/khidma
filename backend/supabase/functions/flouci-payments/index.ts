// Flouci payments (Supabase Edge Function). Deploy with --no-verify-jwt: the
// webhook has no JWT, and /create checks the caller's JWT itself.
//
// POST /create   {order_id}  (signed-in user) -> {link}
//   Creates the Flouci payment for the user's own pending 'flouci' order and
//   stores Flouci's payment_id on it.
// POST /webhook  (Flouci)    signed with X-Flouci-Signature
//   Verifies the signature, then asks Flouci's verify endpoint (never trusts
//   the webhook body for status or amount) and applies the result through
//   service_apply_flouci_event (idempotent on event_id).
//
// STATUS: written and unit-tested for logic only. It has never talked to
// Flouci: it needs the owner's Flouci account (issue #42). Secrets:
//   FLOUCI_PUBLIC, FLOUCI_PRIVATE   API credentials from the Flouci dashboard
//   FLOUCI_SUCCESS_URL, FLOUCI_FAIL_URL   https pages the customer returns to
//   FLOUCI_API (optional)           override the base URL (test/production)
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY  (provided)
import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  authHeader, buildGenerateBody, FLOUCI_API, interpretVerify, isHttpsUrl, parseWebhook, verifySignature,
} from './logic.mjs';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const pub = Deno.env.get('FLOUCI_PUBLIC') ?? '';
const priv = Deno.env.get('FLOUCI_PRIVATE') ?? '';
const api = Deno.env.get('FLOUCI_API') ?? FLOUCI_API;
const successUrl = Deno.env.get('FLOUCI_SUCCESS_URL') ?? '';
const failUrl = Deno.env.get('FLOUCI_FAIL_URL') ?? '';

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

Deno.serve(async (req) => {
  const path = new URL(req.url).pathname.replace(/\/+$/, '');
  if (req.method !== 'POST') return json(405, { error: 'method' });
  if (!pub || !priv) return json(503, { error: 'not_configured' });
  if (path.endsWith('/webhook')) return webhook(req);
  if (path.endsWith('/create')) return create(req);
  return json(404, { error: 'not_found' });
});

async function create(req: Request) {
  const auth = req.headers.get('authorization');
  if (!auth) return json(401, { error: 'auth' });
  if (!isHttpsUrl(successUrl) || !isHttpsUrl(failUrl)) return json(503, { error: 'not_configured' });
  let orderId: unknown;
  try {
    orderId = (await req.json()).order_id;
  } catch {
    return json(400, { error: 'input' });
  }
  if (typeof orderId !== 'string') return json(400, { error: 'input' });

  // As the caller: RLS only shows their own orders.
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: auth } } });
  const { data: order } = await caller
    .from('payment_orders')
    .select('id, amount_millimes, method, status')
    .eq('id', orderId)
    .maybeSingle();
  if (!order || order.method !== 'flouci' || order.status !== 'pending') return json(404, { error: 'order' });

  const res = await fetch(`${api}/generate_payment`, {
    method: 'POST',
    headers: { authorization: authHeader(pub, priv), 'content-type': 'application/json' },
    body: JSON.stringify(buildGenerateBody({
      order,
      successUrl,
      failUrl,
      webhookUrl: `${url}/functions/v1/flouci-payments/webhook`,
    })),
  });
  const body = await res.json().catch(() => null);
  const result = body?.result;
  if (!res.ok || !result?.success || !result.link || !result.payment_id) return json(502, { error: 'provider' });

  const service = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { error } = await service.rpc('service_attach_provider_ref', { p_order: order.id, p_ref: result.payment_id });
  if (error) return json(409, { error: 'order' });
  return json(200, { link: result.link });
}

async function webhook(req: Request) {
  const raw = await req.text();
  const ok = await verifySignature({
    header: req.headers.get('x-flouci-signature') ?? '',
    rawBody: raw,
    secret: priv,
    nowSeconds: Math.floor(Date.now() / 1000),
  });
  if (!ok) return json(400, { error: 'signature' });
  const e = parseWebhook(raw);
  if (!e) return json(400, { error: 'payload' });

  // Never trust the webhook body for the outcome: ask Flouci.
  const check = await fetch(`${api}/verify_payment/${encodeURIComponent(e.paymentId)}`, {
    headers: { authorization: authHeader(pub, priv) },
  });
  if (!check.ok) return json(502, { error: 'verify' }); // Flouci retries
  const verified = interpretVerify(await check.json().catch(() => null));

  const service = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data, error } = await service.rpc('service_apply_flouci_event', {
    p_event_id: e.eventId,
    p_payment_id: e.paymentId,
    p_success: e.event === 'payment.succeeded' && verified.paid,
    p_amount_millimes: verified.amountMillimes,
  });
  if (error) return json(500, { error: 'apply' });
  return json(200, { result: data });
}
