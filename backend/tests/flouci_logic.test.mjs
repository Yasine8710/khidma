import test from 'node:test';
import assert from 'node:assert/strict';
import {
  authHeader, buildGenerateBody, hmacHex, interpretVerify, isHttpsUrl, parseWebhook, verifySignature,
} from '../supabase/functions/flouci-payments/logic.mjs';

const SECRET = 'flouci-private-secret';
const sign = async (body, t) => `t=${t},v1=${await hmacHex(SECRET, `${t}.${body}`)}`;
const body = JSON.stringify({ event: 'payment.succeeded', event_id: 'e1', payment_id: 'P1', amount: 20000, currency: 'TND' });

test('the payment request carries millimes as a string, the order id and the signed webhook v2', () => {
  const b = buildGenerateBody({
    order: { id: 'order-1', amount_millimes: 20000 },
    webhookUrl: 'https://x.test/hook', successUrl: 'https://x.test/ok', failUrl: 'https://x.test/ko',
  });
  assert.equal(b.amount, '20000');
  assert.equal(b.developer_tracking_id, 'order-1');
  assert.equal(b.webhook_version, 2);
  assert.equal(b.webhook, 'https://x.test/hook');
});

test('the authorization header is Bearer public:private', () => {
  assert.equal(authHeader('pk', 'sk'), 'Bearer pk:sk');
});

test('a correct, recent signature is accepted', async () => {
  const now = 1_800_000_000;
  assert.equal(await verifySignature({ header: await sign(body, now), rawBody: body, secret: SECRET, nowSeconds: now + 30 }), true);
});

test('a changed body, wrong secret, stale or malformed header is refused', async () => {
  const now = 1_800_000_000;
  const good = await sign(body, now);
  assert.equal(await verifySignature({ header: good, rawBody: body + ' ', secret: SECRET, nowSeconds: now }), false);
  assert.equal(await verifySignature({ header: good, rawBody: body, secret: 'another-secret', nowSeconds: now }), false);
  assert.equal(await verifySignature({ header: good, rawBody: body, secret: SECRET, nowSeconds: now + 301 }), false);
  assert.equal(await verifySignature({ header: good, rawBody: body, secret: SECRET, nowSeconds: now - 301 }), false);
  for (const h of ['', 'v1=abc', 't=abc,v1=abc', `t=${now}`, `t=${now},v1=`, null]) {
    assert.equal(await verifySignature({ header: h, rawBody: body, secret: SECRET, nowSeconds: now }), false, String(h));
  }
  assert.equal(await verifySignature({ header: good, rawBody: body, secret: '', nowSeconds: now }), false);
});

test('only the two known events with ids are parsed', () => {
  assert.deepEqual(parseWebhook(body), { event: 'payment.succeeded', eventId: 'e1', paymentId: 'P1', trackingId: null });
  assert.equal(parseWebhook('not json'), null);
  assert.equal(parseWebhook(JSON.stringify({ event: 'refund.created', event_id: 'x', payment_id: 'y' })), null);
  assert.equal(parseWebhook(JSON.stringify({ event: 'payment.failed', payment_id: 'y' })), null);
  assert.equal(parseWebhook('null'), null);
});

test('verify_payment counts as paid only for success true and status SUCCESS', () => {
  assert.deepEqual(interpretVerify({ success: true, result: { status: 'SUCCESS', amount: 20000, developer_tracking_id: 'o' } }),
    { paid: true, amountMillimes: 20000, trackingId: 'o' });
  for (const status of ['PENDING', 'EXPIRED', 'FAILURE', 'PREAUTH_SUCCESS', 'SYSTEM_FAILURE']) {
    assert.equal(interpretVerify({ success: true, result: { status, amount: 20000 } }).paid, false, status);
  }
  assert.equal(interpretVerify({ success: false, result: { status: 'SUCCESS', amount: 1 } }).paid, false);
  assert.equal(interpretVerify(null).paid, false);
  assert.equal(interpretVerify({ success: true, result: { status: 'SUCCESS', amount: '20000' } }).amountMillimes, null);
});

test('return pages must be https', () => {
  assert.equal(isHttpsUrl('https://khidma.example/ok'), true);
  assert.equal(isHttpsUrl('http://khidma.example/ok'), false);
  assert.equal(isHttpsUrl('tn.khidma.app://payment'), false);
  assert.equal(isHttpsUrl(''), false);
});
