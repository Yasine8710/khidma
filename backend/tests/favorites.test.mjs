import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, anon, user, anonymousAuthUser, denies, DENIED } from './harness.mjs';

async function publishedPro(db, name = 'Pro') {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  await user(db, id).query(
    `update public.professional_profiles
        set business_name = $2, primary_category_id = 1, description = 'Plombier avec dix ans d experience.',
            governorate_id = 11, contact_phone = '+21620123456', is_published = true
      where user_id = $1`, [id, name]);
  return id;
}
const save = (db, who, pro) => user(db, who).query('insert into public.favorites (user_id, professional_id) values ($1, $2)', [who, pro]);
const mine = async (db, who) => (await user(db, who).query('select professional_id from public.favorites order by created_at')).rows.map((r) => r.professional_id);

describe('favorites', () => {
  let db, alice, bob, pro, pro2, draft;
  before(async () => {
    db = await newDb();
    alice = await createUser(db);
    bob = await createUser(db);
    pro = await publishedPro(db, 'Pro A');
    pro2 = await publishedPro(db, 'Pro B');
    draft = await createUser(db);
    await user(db, draft).query('select public.become_professional()'); // never published
  });

  test('a registered user saves and removes; duplicates are refused', async () => {
    await save(db, alice, pro);
    await denies(save(db, alice, pro), '23505');
    await save(db, alice, pro2);
    assert.deepEqual((await mine(db, alice)).sort(), [pro, pro2].sort());
    await user(db, alice).query('delete from public.favorites where professional_id = $1', [pro]);
    assert.deepEqual(await mine(db, alice), [pro2]);
  });

  test('favorites are private: others see none and cannot delete them', async () => {
    assert.deepEqual(await mine(db, bob), []);
    await user(db, bob).query('delete from public.favorites where user_id = $1', [alice]);
    assert.deepEqual(await mine(db, alice), [pro2], 'still there');
    assert.deepEqual(await mine(db, pro2), [], 'the saved professional cannot see who saved them');
  });

  test('cannot save as someone else', async () => {
    await denies(user(db, bob).query('insert into public.favorites (user_id, professional_id) values ($1, $2)', [alice, pro]), DENIED);
  });

  test('anon and anonymous-auth users cannot read or save', async () => {
    await denies(anon(db).query('select * from public.favorites'), DENIED);
    await denies(anonymousAuthUser(db, bob).query('insert into public.favorites (user_id, professional_id) values ($1, $2)', [bob, pro]), DENIED);
  });

  test('only published professionals can be saved; yourself never', async () => {
    await denies(save(db, bob, draft), DENIED);
    await denies(save(db, bob, bob), DENIED);
    await denies(save(db, pro, pro), '23514');
  });

  test('a professional can save another professional', async () => {
    await save(db, pro, pro2);
    assert.deepEqual(await mine(db, pro), [pro2]);
  });

  test('an unpublished professional disappears from the joined listing', async () => {
    await user(db, pro2).query('update public.professional_profiles set is_published = false where user_id = $1', [pro2]);
    const visible = await user(db, alice).query(
      'select f.professional_id from public.favorites f join public.professional_profiles p on p.user_id = f.professional_id');
    assert.deepEqual(visible.rows, []);
    await user(db, pro2).query('update public.professional_profiles set is_published = true where user_id = $1', [pro2]);
  });

  test('deleting a professional removes the favorites pointing at them', async () => {
    const gone = await publishedPro(db, 'Gone');
    await save(db, bob, gone);
    await user(db, gone).query('select public.delete_my_account()');
    assert.deepEqual(await mine(db, bob), []);
  });

  test('capped at 200 per user', async () => {
    const heavy = await createUser(db);
    for (let i = 0; i < 200; i++) {
      const p = await createUser(db);
      await db.query('insert into public.professional_profiles (user_id) values ($1)', [p]);
      await db.query('insert into public.favorites (user_id, professional_id) values ($1, $2)', [heavy, p]);
    }
    const extra = await publishedPro(db, 'Extra');
    await assert.rejects(save(db, heavy, extra), (e) => e.code === 'P0001' && /favorites_limit/.test(e.message));
  });

  test('the cap is serialized per user (a concurrency race is not observable in a single-connection test)', async () => {
    const src = (await db.query(`select pg_get_functiondef(p.oid) as d from pg_proc p where p.proname = 'enforce_favorites_limit'`)).rows[0].d;
    assert.match(src, /pg_advisory_xact_lock/);
    assert.match(src, />= 200/);
  });
});
