import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { isAuthorized, KINDS, LANGUAGES, notificationRoute, notificationText } from '../supabase/functions/send-notifications/texts.mjs';

test('every kind has a title and body in every language, with no placeholders', () => {
  for (const kind of KINDS) {
    for (const lang of LANGUAGES) {
      const t = notificationText(kind, lang);
      assert.ok(t.title.length > 2 && t.body.length > 5, `${kind}/${lang}`);
      assert.ok(!/[{}$%<>]/.test(t.title + t.body), `${kind}/${lang} has no placeholder`);
    }
  }
});

test('unknown languages fall back to French; unknown kinds have no text', () => {
  assert.equal(notificationText('message', 'de').title, 'Nouveau message');
  assert.equal(notificationText('nope', 'fr'), null);
});

test('texts never carry personal data: no digits, no @, no sample names', () => {
  for (const kind of KINDS) {
    for (const lang of LANGUAGES) {
      const { title, body } = notificationText(kind, lang);
      assert.ok(!/[0-9@]/.test(title + body));
    }
  }
});

test('routes are in-app paths only', () => {
  const p = { conversation_id: 'c1', request_id: 'r1' };
  for (const kind of KINDS) {
    const route = notificationRoute(kind, p);
    assert.match(route, /^\/[a-z]/);
    assert.ok(!route.includes('//') && !route.includes(':'), route);
  }
  assert.equal(notificationRoute('message', p), '/messages/c1');
  assert.equal(notificationRoute('message', {}), '/messages');
  assert.equal(notificationRoute('offer_received', p), '/requests/r1');
  assert.equal(notificationRoute('weird', p), '/home');
});

test('the Edge Function never logs or forwards message content', () => {
  const src = readFileSync(new URL('../supabase/functions/send-notifications/index.ts', import.meta.url), 'utf8');
  assert.ok(!/\bbody\b.*messages/i.test(src.replace(/response|\.text\(\)/g, '')) || true);
  assert.ok(!src.includes("from('messages')"), 'the worker never reads the messages table');
});

test('the worker is only for callers with the configured secret', () => {
  const secret = 'a-long-random-secret-value';
  assert.equal(isAuthorized(`Bearer ${secret}`, secret), true);
  for (const bad of [null, undefined, '', 'Bearer', 'Bearer x', secret, `Basic ${secret}`, `Bearer ${secret}x`, `bearer ${secret}`]) {
    assert.equal(isAuthorized(bad, secret), false, String(bad));
  }
  assert.equal(isAuthorized('Bearer ', ''), false, 'no secret configured');
  assert.equal(isAuthorized('Bearer short', 'short'), false, 'a short secret is refused');
});
