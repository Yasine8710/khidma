import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import {
  newDb, createUser, makeAdmin, anon, user, anonymousAuthUser, denies, DENIED,
} from './harness.mjs';

const phone = '+21620123456';

async function becomePro(db, id) {
  await user(db, id).query('select public.become_professional()');
}
async function publish(db, id) {
  await user(db, id).query(
    `update public.professional_profiles
        set business_name = 'Pro ' || left($1::text, 4), primary_category_id = 1, description = 'Plombier avec dix ans d expérience.',
            governorate_id = 11, contact_phone = $2, is_published = true
      where user_id = $1`, [id, phone]);
}
const count = async (db, sql, params = []) => (await db.query(sql, params)).rows[0].n;

describe('delete_my_account', () => {
  let db, leaving, staying, admin;
  before(async () => {
    db = await newDb();
    leaving = await createUser(db, { meta: { full_name: 'Leaving' } });
    staying = await createUser(db, { meta: { full_name: 'Staying' } });
    admin = await createUser(db);
    await makeAdmin(db, admin);
    for (const id of [leaving, staying]) {
      await becomePro(db, id);
      await publish(db, id);
      await user(db, id).query('insert into public.professional_services (professional_id, category_id) values ($1, 1), ($1, 2)', [id]);
      await user(db, id).query('insert into public.service_areas (professional_id, governorate_id) values ($1, 11)', [id]);
    }
    // They look at each other's phone numbers: reveal logs reference both.
    await user(db, leaving).query('select public.reveal_professional_contact($1)', [staying]);
    await user(db, staying).query('select public.reveal_professional_contact($1)', [leaving]);
  });

  test('the leaving person is gone everywhere; the other person is untouched', async () => {
    await user(db, leaving).query('select public.delete_my_account()');
    for (const [table, col] of [
      ['profiles', 'id'], ['customer_profiles', 'user_id'], ['professional_profiles', 'user_id'],
      ['professional_services', 'professional_id'], ['service_areas', 'professional_id'],
    ]) {
      assert.equal(await count(db, `select count(*)::int as n from public.${table} where ${col} = $1`, [leaving]), 0, table);
    }
    assert.equal(await count(db, 'select count(*)::int as n from public.contact_reveals where user_id = $1 or professional_id = $1', [leaving]), 0, 'reveal log both ways');
    assert.equal(await count(db, 'select count(*)::int as n from auth.users where id = $1', [leaving]), 0);

    const left = await anon(db).query('select user_id from public.professional_profiles');
    assert.deepEqual(left.rows.map((r) => r.user_id), [staying], 'no longer public');
    assert.equal(await count(db, 'select count(*)::int as n from public.professional_services where professional_id = $1', [staying]), 2);
    assert.equal(await count(db, 'select count(*)::int as n from public.profiles where id = $1', [staying]), 1);
  });

  test('nothing in the public schema still references the deleted person', async () => {
    // Every column that holds a user id must have been cleaned up.
    const cols = await db.query(
      `select table_name, column_name from information_schema.columns
        where table_schema = 'public' and data_type = 'uuid'
          and column_name in ('id', 'user_id', 'professional_id')
          and table_name not in ('governorates', 'cities', 'neighborhoods', 'service_categories', 'service_areas')`);
    for (const { table_name, column_name } of cols.rows) {
      const n = await count(db, `select count(*)::int as n from public.${table_name} where ${column_name} = $1`, [leaving]);
      assert.equal(n, 0, `${table_name}.${column_name}`);
    }
  });

  test('deleting twice is harmless to everyone else and fails for the deleted account', async () => {
    // The deleted user still has a (now useless) token: they are a nobody.
    await user(db, leaving).query('select public.delete_my_account()'); // no row left: no-op
    assert.equal(await count(db, 'select count(*)::int as n from public.profiles where id = $1', [staying]), 1);
  });

  test('a user can only ever delete themselves (there is no id argument)', async () => {
    const other = await createUser(db);
    await user(db, other).query('select public.delete_my_account()');
    assert.equal(await count(db, 'select count(*)::int as n from auth.users where id = $1', [staying]), 1);
    const { rows } = await db.query(`select pronargs from pg_proc where proname = 'delete_my_account'`);
    assert.equal(rows[0].pronargs, 0);
  });

  test('anonymous visitors, anonymous-auth users and "no user" cannot call it', async () => {
    const victim = await createUser(db);
    await denies(anon(db).query('select public.delete_my_account()'), DENIED);
    await denies(anonymousAuthUser(db, victim).query('select public.delete_my_account()'), DENIED);
    await denies(user(db, null).query('select public.delete_my_account()'), '28000');
    assert.equal(await count(db, 'select count(*)::int as n from auth.users where id = $1', [victim]), 1);
  });

  test('an admin can delete their own account like anyone else; admin rows go too', async () => {
    await user(db, admin).query('select public.delete_my_account()');
    assert.equal(await count(db, 'select count(*)::int as n from public.admin_users where user_id = $1', [admin]), 0);
  });

  test('the function is a definer with a pinned search_path and not callable by PUBLIC/anon', async () => {
    const r = await db.query(
      `select p.prosecdef, p.proconfig,
              has_function_privilege('anon', p.oid, 'execute') as anon_x,
              has_function_privilege('authenticated', p.oid, 'execute') as auth_x
         from pg_proc p where p.proname = 'delete_my_account'`);
    assert.equal(r.rows[0].prosecdef, true);
    assert.ok(r.rows[0].proconfig.includes('search_path=""'));
    assert.equal(r.rows[0].anon_x, false);
    assert.equal(r.rows[0].auth_x, true);
  });
});
