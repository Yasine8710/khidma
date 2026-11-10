import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import {
  newDb, createUser, makeAdmin, anon, user, denies, DENIED, CHECK,
} from './harness.mjs';

describe('sign-up trigger', () => {
  let db;
  before(async () => { db = await newDb(); });

  test('creates a profile and a customer profile with safe defaults', async () => {
    const id = await createUser(db, { meta: { full_name: '  Karim Ben Salah  ', preferred_language: 'ar' } });
    const p = await user(db, id).query('select * from public.profiles');
    assert.equal(p.rows.length, 1);
    assert.equal(p.rows[0].full_name, 'Karim Ben Salah');
    assert.equal(p.rows[0].preferred_language, 'ar');
    assert.equal(p.rows[0].is_customer, true);
    assert.equal(p.rows[0].is_professional, false);
    const c = await user(db, id).query('select user_id from public.customer_profiles');
    assert.equal(c.rows.length, 1);
  });

  test('sign-up metadata can NOT grant admin or professional status', async () => {
    const id = await createUser(db, {
      meta: { is_admin: true, role: 'admin', is_professional: true, is_customer: false, admin: true },
    });
    const p = await user(db, id).query('select is_professional, is_customer from public.profiles');
    assert.deepEqual(p.rows[0], { is_professional: false, is_customer: true });
    const a = await db.query('select count(*)::int as n from public.admin_users where user_id = $1', [id]);
    assert.equal(a.rows[0].n, 0);
    const adm = await user(db, id).query('select public.is_admin() as a');
    assert.equal(adm.rows[0].a, false);
  });

  test('invalid language falls back to French; name is trimmed and capped', async () => {
    const id = await createUser(db, { meta: { full_name: 'x'.repeat(300), preferred_language: 'de' } });
    const p = await user(db, id).query('select full_name, preferred_language from public.profiles');
    assert.equal(p.rows[0].preferred_language, 'fr');
    assert.equal(p.rows[0].full_name.length, 120);
  });

  test('empty metadata gives a null name', async () => {
    const id = await createUser(db, { meta: {} });
    const p = await user(db, id).query('select full_name from public.profiles');
    assert.equal(p.rows[0].full_name, null);
  });
});

describe('profiles access', () => {
  let db, a, b;
  before(async () => {
    db = await newDb();
    a = await createUser(db, { meta: { full_name: 'Alice' } });
    b = await createUser(db, { meta: { full_name: 'Bob' } });
  });

  test('a user sees only their own profile', async () => {
    const r = await user(db, a).query('select id, full_name from public.profiles');
    assert.deepEqual(r.rows.map((x) => x.full_name), ['Alice']);
  });

  test('anonymous visitors cannot read profiles at all', async () => {
    await denies(anon(db).query('select id from public.profiles'), DENIED);
  });

  test('an authenticated role without a user id sees nothing', async () => {
    const r = await user(db, null).query('select id from public.profiles');
    assert.equal(r.rows.length, 0);
  });

  test('owner can edit the four allowed columns', async () => {
    const r = await user(db, a).query(
      `update public.profiles set full_name = 'Alice B', preferred_language = 'en',
         phone = '+21620123456', avatar_url = 'https://x.test/a.png' where id = $1`, [a]);
    assert.equal(r.affectedRows, 1);
  });

  test('owner can NOT edit capability flags, id or timestamps', async () => {
    for (const col of ['is_professional = true', 'is_customer = false', `id = gen_random_uuid()`,
                       `created_at = now()`, `updated_at = now()`]) {
      await denies(user(db, a).query(`update public.profiles set ${col} where id = $1`, [a]), DENIED);
    }
    const r = await user(db, a).query('select is_professional from public.profiles');
    assert.equal(r.rows[0].is_professional, false);
  });

  test('a user cannot edit someone else (0 rows touched)', async () => {
    const r = await user(db, a).query(`update public.profiles set full_name = 'hacked' where id = $1`, [b]);
    assert.equal(r.affectedRows, 0);
    const bob = await user(db, b).query('select full_name from public.profiles');
    assert.equal(bob.rows[0].full_name, 'Bob');
  });

  test('no client can insert or delete profiles', async () => {
    await denies(user(db, a).query(`insert into public.profiles (id) values (gen_random_uuid())`), DENIED);
    await denies(user(db, a).query('delete from public.profiles where id = $1', [a]), DENIED);
    await denies(anon(db).query(`insert into public.profiles (id) values (gen_random_uuid())`), DENIED);
  });

  test('phone numbers must be valid Tunisian E.164', async () => {
    for (const bad of ['+33612345678', '20123456', '+21610123456', '+2162012345', 'abc']) {
      await denies(user(db, a).query('update public.profiles set phone = $1 where id = $2', [bad, a]), CHECK);
    }
    for (const ok of ['+21620123456', '+21671123456', '+21699123456']) {
      const r = await user(db, a).query('update public.profiles set phone = $1 where id = $2', [ok, a]);
      assert.equal(r.affectedRows, 1);
    }
  });

  test('bad language and over-long values are rejected', async () => {
    await denies(user(db, a).query(`update public.profiles set preferred_language = 'xx' where id = $1`, [a]), CHECK);
    await denies(user(db, a).query('update public.profiles set full_name = $1 where id = $2', ['x'.repeat(121), a]), CHECK);
  });

  test('updated_at moves forward on edit', async () => {
    const before = (await user(db, a).query('select updated_at from public.profiles')).rows[0].updated_at;
    await new Promise((r) => setTimeout(r, 15));
    await user(db, a).query(`update public.profiles set full_name = 'Alice C' where id = $1`, [a]);
    const after = (await user(db, a).query('select updated_at from public.profiles')).rows[0].updated_at;
    assert.ok(after > before);
  });
});

describe('customer profiles', () => {
  let db, a, b;
  before(async () => {
    db = await newDb();
    a = await createUser(db);
    b = await createUser(db);
  });

  test('owner-only read and limited update', async () => {
    const r = await user(db, a).query('select user_id from public.customer_profiles');
    assert.deepEqual(r.rows.map((x) => x.user_id), [a]);
    const u = await user(db, a).query('update public.customer_profiles set default_governorate_id = 11 where user_id = $1', [a]);
    assert.equal(u.affectedRows, 1);
    const other = await user(db, a).query('update public.customer_profiles set default_governorate_id = 12 where user_id = $1', [b]);
    assert.equal(other.affectedRows, 0);
    await denies(anon(db).query('select * from public.customer_profiles'), DENIED);
  });

  test('a default city must belong to the default governorate', async () => {
    const city = (await db.query(`select id from public.cities where name_fr = 'Ariana'`)).rows[0].id; // governorate 12
    await denies(
      user(db, a).query('update public.customer_profiles set default_governorate_id = 11, default_city_id = $1 where user_id = $2', [city, a]),
      '23503',
    );
    await denies(
      user(db, a).query('update public.customer_profiles set default_governorate_id = null, default_city_id = $1 where user_id = $2', [city, a]),
      CHECK,
    );
  });
});

describe('admin membership', () => {
  let db, a, admin;
  before(async () => {
    db = await newDb();
    a = await createUser(db);
    admin = await createUser(db);
    await makeAdmin(db, admin);
  });

  test('is_admin reflects admin_users only', async () => {
    assert.equal((await user(db, a).query('select public.is_admin() as v')).rows[0].v, false);
    assert.equal((await user(db, admin).query('select public.is_admin() as v')).rows[0].v, true);
    assert.equal((await anon(db).query('select public.is_admin() as v')).rows[0].v, false);
  });

  test('no client can read or write admin_users', async () => {
    await denies(user(db, a).query('select * from public.admin_users'), DENIED);
    await denies(user(db, admin).query('select * from public.admin_users'), DENIED);
    await denies(user(db, a).query('insert into public.admin_users (user_id) values ($1)', [a]), DENIED);
    await denies(anon(db).query('insert into public.admin_users (user_id) values ($1)', [a]), DENIED);
  });

  test('deleting the auth user cascades profile and admin rows', async () => {
    const u = await createUser(db);
    await makeAdmin(db, u);
    await db.query('delete from auth.users where id = $1', [u]);
    for (const t of ['profiles', 'customer_profiles', 'admin_users']) {
      const col = t === 'profiles' ? 'id' : 'user_id';
      const r = await db.query(`select count(*)::int as n from public.${t} where ${col} = $1`, [u]);
      assert.equal(r.rows[0].n, 0, t);
    }
  });
});
