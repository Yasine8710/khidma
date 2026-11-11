import test from 'node:test';
import assert from 'node:assert/strict';
import { isAuthorized, planBatches, BUCKETS } from '../supabase/functions/storage-cleanup/logic.mjs';

const SECRET = 'a-long-random-secret-value';

test('only the exact bearer secret is accepted', () => {
  assert.equal(isAuthorized(`Bearer ${SECRET}`, SECRET), true);
  assert.equal(isAuthorized(`Bearer ${SECRET}x`, SECRET), false);
  assert.equal(isAuthorized(`bearer ${SECRET}`, SECRET), false);
  assert.equal(isAuthorized(SECRET, SECRET), false);
  assert.equal(isAuthorized(null, SECRET), false);
});

test('a missing or short secret never authorizes, even when matched', () => {
  assert.equal(isAuthorized('Bearer ', ''), false);
  assert.equal(isAuthorized('Bearer short', 'short'), false);
  assert.equal(isAuthorized('Bearer x', undefined), false);
});

test('rows are grouped per bucket, keeping ids and names aligned', () => {
  const plan = planBatches([
    { id: 1, bucket_id: 'portfolio', name: 'u1/a.jpg' },
    { id: 2, bucket_id: 'chat-images', name: 'c1/b.jpg' },
    { id: 3, bucket_id: 'portfolio', name: 'u1/c.jpg' },
  ]);
  assert.deepEqual(plan.find((b) => b.bucket === 'portfolio'), {
    bucket: 'portfolio', ids: [1, 3], names: ['u1/a.jpg', 'u1/c.jpg'],
  });
  assert.equal(plan.length, 2);
});

test('unknown buckets, empty names and path escapes are skipped', () => {
  const plan = planBatches([
    { id: 1, bucket_id: 'avatars', name: 'x.jpg' },
    { id: 2, bucket_id: 'portfolio', name: '' },
    { id: 3, bucket_id: 'portfolio', name: '../other/x.jpg' },
    { id: 4, bucket_id: 'portfolio', name: '/abs.jpg' },
    { id: 5, bucket_id: 'portfolio', name: 'u1/ok.jpg' },
  ]);
  assert.deepEqual(plan, [{ bucket: 'portfolio', ids: [5], names: ['u1/ok.jpg'] }]);
});

test('the total is capped and garbage input is harmless', () => {
  const rows = Array.from({ length: 500 }, (_, i) => ({ id: i, bucket_id: 'portfolio', name: `u/${i}.jpg` }));
  assert.equal(planBatches(rows, 200)[0].ids.length, 200);
  assert.deepEqual(planBatches(null), []);
  assert.deepEqual(planBatches([null, 7]), []);
});

test('the worker covers every bucket the database queues files for', async () => {
  const { readFileSync, readdirSync } = await import('node:fs');
  const dir = new URL('../supabase/migrations/', import.meta.url);
  const sql = readdirSync(dir).map((f) => readFileSync(new URL(f, dir), 'utf8')).join('\n');
  const queued = new Set([...sql.matchAll(/_queue_storage_cleanup\(\s*'([a-z-]+)'/g)].map((m) => m[1]));
  for (const b of queued) assert.ok(BUCKETS.includes(b), `bucket ${b} is queued but not cleaned`);
});
