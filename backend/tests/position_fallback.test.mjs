import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, anon, user } from './harness.mjs';

describe('position fallback (migration 1600)', () => {
  let db, u, id;
  const pos = async () =>
    (await db.query('select latitude, longitude from public.professional_profiles where user_id = $1', [id])).rows[0];
  before(async () => {
    db = await newDb();
    id = await createUser(db);
    u = user(db, id);
    await u.query('select public.become_professional()');
  });

  test('every governorate has a centre inside Tunisia, rounded to 2 decimals', async () => {
    const r = await db.query('select id, latitude, longitude from public.governorates');
    assert.equal(r.rows.length, 24);
    for (const g of r.rows) {
      assert.ok(g.latitude > 30 && g.latitude < 38 && g.longitude > 7 && g.longitude < 12, `gov ${g.id}`);
      assert.equal(Math.round(g.latitude * 100) / 100, g.latitude);
      assert.equal(Math.round(g.longitude * 100) / 100, g.longitude);
    }
  });

  test('no governorate: no position', async () => {
    assert.deepEqual(await pos(), { latitude: null, longitude: null });
  });

  test('choosing a governorate places the profile at its centre', async () => {
    await u.query('update public.professional_profiles set governorate_id = 61 where user_id = $1', [id]);
    assert.deepEqual(await pos(), { latitude: 34.74, longitude: 10.76 });
  });

  test('a position the owner sends is kept, rounded to ~1 km', async () => {
    await u.query('update public.professional_profiles set latitude = 36.8431, longitude = 10.3171 where user_id = $1', [id]);
    assert.deepEqual(await pos(), { latitude: 36.84, longitude: 10.32 });
    await u.query('update public.professional_profiles set availability = $2 where user_id = $1', [id, 'busy']);
    assert.deepEqual(await pos(), { latitude: 36.84, longitude: 10.32 }, 'unrelated updates do not move it');
  });

  test('sending null again re-places it from the (new) governorate', async () => {
    await u.query('update public.professional_profiles set governorate_id = 51, latitude = null, longitude = null where user_id = $1', [id]);
    assert.deepEqual(await pos(), { latitude: 35.83, longitude: 10.64 });
  });

  test('clearing the governorate leaves no position behind', async () => {
    await u.query('update public.professional_profiles set governorate_id = null, latitude = null, longitude = null where user_id = $1', [id]);
    assert.deepEqual(await pos(), { latitude: null, longitude: null });
  });

  test('the trigger function is not callable by clients', async () => {
    for (const role of ['anon', 'authenticated']) {
      const r = await db.query(`select has_function_privilege($1, 'public.fill_professional_position()', 'execute') as v`, [role]);
      assert.equal(r.rows[0].v, false, role);
    }
  });

  test('anonymous visitors can read the governorate centres', async () => {
    const r = await anon(db).query('select latitude from public.governorates where id = 11');
    assert.equal(r.rows[0].latitude, 36.81);
  });
});
