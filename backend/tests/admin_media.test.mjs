import test from 'node:test';
import assert from 'node:assert/strict';
import { chatImagePaths, corsHeaders, KINDS, parseRequest, safePaths } from '../supabase/functions/admin-media/logic.mjs';

const id = '3f2b8c1e-5d4a-4b7e-9c0d-1a2b3c4d5e6f';

test('requests: only the two kinds with a uuid id', () => {
  assert.deepEqual(parseRequest({ kind: 'verification', id }), { kind: 'verification', id });
  assert.deepEqual(parseRequest({ kind: 'chat', id }), { kind: 'chat', id });
  for (const bad of [null, 'x', {}, { kind: 'other', id }, { kind: 'chat', id: 'nope' }, { kind: 'chat', id: `${id}/../x` }, { kind: 'chat' }, { id }, { kind: 'chat', id: 5 }]) {
    assert.equal(parseRequest(bad), null, JSON.stringify(bad));
  }
});

test('buckets are fixed per kind and links are short-lived', () => {
  assert.equal(KINDS.verification.bucket, 'verification-docs');
  assert.equal(KINDS.chat.bucket, 'chat-images');
  for (const k of Object.values(KINDS)) assert.ok(k.seconds <= 300);
});

test('paths: only well-formed storage paths survive', () => {
  const ok = `${id}/a.jpg`;
  assert.deepEqual(safePaths([ok, `${id}/../b.jpg`, '../x.jpg', `${id}/c.exe`, 5, null, `${id}/d.pdf`]), [ok, `${id}/d.pdf`]);
  assert.deepEqual(safePaths(null), []);
});

test('chat context: image paths only, deduplicated, bad ones dropped', () => {
  const a = `${id}/a.jpg`;
  const ctx = { messages: [{ image_path: a }, { image_path: null }, { body: 'x' }, { image_path: a }, { image_path: '../evil.jpg' }, null] };
  assert.deepEqual(chatImagePaths(ctx), [a]);
  assert.deepEqual(chatImagePaths(null), []);
  assert.deepEqual(chatImagePaths({ messages: 'x' }), []);
});

test('cors: only the configured origin is allowed', () => {
  assert.equal(corsHeaders('https://admin.khidma.tn', 'https://admin.khidma.tn')['Access-Control-Allow-Origin'], 'https://admin.khidma.tn');
  assert.equal(corsHeaders('https://evil.example', 'https://admin.khidma.tn')['Access-Control-Allow-Origin'], undefined);
  assert.equal(corsHeaders('https://admin.khidma.tn', '')['Access-Control-Allow-Origin'], undefined);
  assert.equal(corsHeaders(null, 'https://admin.khidma.tn')['Access-Control-Allow-Origin'], undefined);
});
