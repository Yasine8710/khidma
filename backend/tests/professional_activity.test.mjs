import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, anon, user, anonymousAuthUser, denies, DENIED } from './harness.mjs';

async function publishedPro(db, name) {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  await user(db, id).query(
    `update public.professional_profiles
        set business_name = $2, primary_category_id = 1, description = 'Plombier avec dix ans d experience.',
            governorate_id = 11, contact_phone = '+21620123456', is_published = true
      where user_id = $1`, [id, name]);
  return id;
}
const activity = async (db, who) => (await user(db, who).query('select * from public.get_my_activity()')).rows[0];

describe('get_my_activity', () => {
  let db, pro, other, v1, v2;
  before(async () => {
    db = await newDb();
    pro = await publishedPro(db, 'Pro One');
    other = await publishedPro(db, 'Pro Two');
    v1 = await createUser(db);
    v2 = await createUser(db);
    await user(db, v1).query('select public.reveal_professional_contact($1)', [pro]);
    await user(db, v2).query('select public.reveal_professional_contact($1)', [pro]);
    await user(db, v1).query('select public.reveal_professional_contact($1)', [other]);
    await user(db, v1).query('insert into public.favorites (user_id, professional_id) values ($1, $2)', [v1, pro]);
  });

  test('the last hour is not shown yet (no pinning one visitor to a moment)', async () => {
    assert.deepEqual(await activity(db, pro), { reveals_30d: 0, reveals_total: 0, favorites_count: 0 });
    await db.query(`update public.contact_reveals set created_at = now() - interval '2 hours'`);
    await db.query(`update public.favorites set created_at = now() - interval '2 hours'`);
  });

  test('counts only my own reveals and saves', async () => {
    assert.deepEqual(await activity(db, pro), { reveals_30d: 2, reveals_total: 2, favorites_count: 1 });
    assert.deepEqual(await activity(db, other), { reveals_30d: 1, reveals_total: 1, favorites_count: 0 });
  });

  test('old reveals leave the 30-day count but stay in the total', async () => {
    await db.query(`update public.contact_reveals set created_at = now() - interval '40 days' where professional_id = $1 and user_id = $2`, [pro, v1]);
    assert.deepEqual(await activity(db, pro), { reveals_30d: 1, reveals_total: 2, favorites_count: 1 });
  });

  test('exposes numbers only: no identities in the result', async () => {
    const r = await user(db, pro).query('select * from public.get_my_activity()');
    assert.deepEqual(r.fields.map((f) => f.name), ['reveals_30d', 'reveals_total', 'favorites_count']);
  });

  test('not available to anon, anonymous-auth users or non-professionals', async () => {
    await denies(anon(db).query('select * from public.get_my_activity()'), DENIED);
    await denies(anonymousAuthUser(db, pro).query('select * from public.get_my_activity()'), DENIED);
    await denies(user(db, v2).query('select * from public.get_my_activity()'), DENIED);
  });
});
