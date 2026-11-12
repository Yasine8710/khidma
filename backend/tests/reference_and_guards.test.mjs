import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import {
  newDb, createUser, makeAdmin, anon, user, denies, DENIED, CHECK,
} from './harness.mjs';

describe('service categories', () => {
  let db, a, admin;
  before(async () => {
    db = await newDb();
    a = await createUser(db);
    admin = await createUser(db);
    await makeAdmin(db, admin);
  });

  test('12 starting categories, public to everyone, with all three languages', async () => {
    const r = await anon(db).query('select slug, name_fr, name_ar, name_en from public.service_categories order by sort_order');
    assert.equal(r.rows.length, 12);
    for (const c of r.rows) {
      assert.ok(c.name_fr && c.name_ar && c.name_en, c.slug);
      assert.match(c.name_ar, /[؀-ۿ]/, `${c.slug} Arabic name has Arabic letters`);
    }
    assert.deepEqual(r.rows.slice(0, 3).map((c) => c.slug), ['plumbing', 'electricity', 'air-conditioning']);
  });

  test('regular users cannot create, change or delete categories', async () => {
    await denies(user(db, a).query(`insert into public.service_categories (slug, name_fr, name_ar, name_en) values ('x', 'x', 'x', 'x')`), DENIED);
    await denies(user(db, a).query(`update public.service_categories set name_fr = 'Hacked'`), DENIED);
    await denies(user(db, a).query('delete from public.service_categories'), DENIED);
    await denies(anon(db).query(`update public.service_categories set name_fr = 'Hacked'`), DENIED);
    const names = await anon(db).query(`select count(*)::int as n from public.service_categories where name_fr = 'Hacked'`);
    assert.equal(names.rows[0].n, 0);
  });

  test('admins edit categories only through the audited function; deactivated ones disappear for the public', async () => {
    const id = (await user(db, admin).query(`select public.admin_upsert_category(null, 'welding', 'Soudure', 'اللحام', 'Welding') as id`)).rows[0].id;
    await denies(user(db, admin).query(`update public.service_categories set is_active = false where slug = 'welding'`), DENIED);
    await user(db, admin).query(`select public.admin_upsert_category($1, 'welding', 'Soudure', 'اللحام', 'Welding', 'build', 0, false)`, [id]);
    const pub = await anon(db).query(`select slug from public.service_categories where slug = 'welding'`);
    assert.equal(pub.rows.length, 0);
    const adm = await user(db, admin).query(`select slug from public.service_categories where slug = 'welding'`);
    assert.equal(adm.rows.length, 1);
    await denies(user(db, admin).query(`delete from public.service_categories where slug = 'welding'`), DENIED);
  });

  test('slugs are validated', async () => {
    await denies(db.query(`insert into public.service_categories (slug, name_fr, name_ar, name_en) values ('Bad Slug', 'x', 'x', 'x')`), CHECK);
  });
});

describe('geography', () => {
  let db, a;
  before(async () => {
    db = await newDb();
    a = await createUser(db);
  });

  test('all 24 governorates with unique ISO codes', async () => {
    const r = await anon(db).query('select id, code, name_fr, name_ar, name_en from public.governorates order by id');
    assert.equal(r.rows.length, 24);
    assert.equal(new Set(r.rows.map((g) => g.code)).size, 24);
    for (const g of r.rows) {
      assert.match(g.code, /^TN-\d{2}$/);
      assert.match(g.name_ar, /[؀-ۿ]/, g.code);
    }
    const names = r.rows.map((g) => g.name_fr);
    for (const n of ['Tunis', 'Ariana', 'Ben Arous', 'Manouba', 'Sfax', 'Sousse', 'Tataouine', 'Kébili']) {
      assert.ok(names.includes(n), n);
    }
  });

  test('Greater Tunis is seeded: 4 governorates, linked cities and neighborhoods', async () => {
    const r = await anon(db).query('select governorate_id, count(*)::int as n from public.cities group by governorate_id order by governorate_id');
    assert.deepEqual(r.rows.map((x) => x.governorate_id), [11, 12, 13, 14]);
    assert.ok(r.rows.every((x) => x.n >= 4));
    const n = await anon(db).query(
      `select c.name_fr as city, n.name_fr from public.neighborhoods n join public.cities c on c.id = n.city_id where n.name_fr = 'Gammarth'`);
    assert.equal(n.rows[0].city, 'La Marsa');
  });

  test('everyone can read; nobody can write through the API', async () => {
    for (const t of ['governorates', 'cities', 'neighborhoods']) {
      assert.ok((await anon(db).query(`select count(*)::int as n from public.${t}`)).rows[0].n > 0, t);
      await denies(user(db, a).query(`delete from public.${t}`), DENIED);
      await denies(user(db, a).query(`update public.${t} set name_fr = 'x'`), DENIED);
      await denies(anon(db).query(`update public.${t} set name_fr = 'x'`), DENIED);
    }
    await denies(user(db, a).query(`insert into public.governorates (id, code, name_fr, name_ar, name_en) values (99, 'TN-99', 'x', 'x', 'x')`), DENIED);
  });

  test('cities cannot be deleted while professionals reference them (restrict)', async () => {
    const db2 = await newDb();
    const p = await createUser(db2);
    await user(db2, p).query('select public.become_professional()');
    const marsa = (await db2.query(`select id from public.cities where name_fr = 'La Marsa'`)).rows[0].id;
    await db2.query('update public.professional_profiles set governorate_id = 11, city_id = $1 where user_id = $2', [marsa, p]);
    await assert.rejects(db2.query('delete from public.cities where id = $1', [marsa]), (e) => e.code === '23503');
  });
});

// These guard future migrations: a new table or function that forgets RLS or
// leaves Supabase's permissive default grants in place fails here.
describe('structural security guards', () => {
  let db;
  before(async () => { db = await newDb(); });

  test('every table in the public schema has Row Level Security enabled', async () => {
    const r = await db.query(
      `select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity`);
    assert.deepEqual(r.rows, [], 'tables without RLS');
  });

  test('table privileges of anon and authenticated match the reviewed matrix exactly', async () => {
    const r = await db.query(
      `select grantee, table_name, privilege_type from information_schema.table_privileges
        where table_schema = 'public' and grantee in ('anon', 'authenticated')
        order by grantee, table_name, privilege_type`);
    const got = r.rows.map((x) => `${x.grantee}:${x.table_name}:${x.privilege_type}`);
    const reference = ['governorates', 'cities', 'neighborhoods', 'service_categories'];
    const expected = [
      ...reference.map((t) => `anon:${t}:SELECT`),
      'anon:professional_services:SELECT',
      'anon:service_areas:SELECT',
      ...reference.map((t) => `authenticated:${t}:SELECT`),
      'authenticated:profiles:SELECT',
      'authenticated:customer_profiles:SELECT',
      'authenticated:professional_services:SELECT',
      'authenticated:professional_services:INSERT',
      'authenticated:professional_services:DELETE',
      'authenticated:service_areas:SELECT',
      'authenticated:service_areas:INSERT',
      'authenticated:service_areas:DELETE',
      'authenticated:favorites:SELECT',
      'authenticated:favorites:INSERT',
      'authenticated:favorites:DELETE',
      'anon:portfolio_items:SELECT',
      'authenticated:portfolio_items:SELECT',
      'authenticated:portfolio_items:INSERT',
      'authenticated:portfolio_items:DELETE',
      'authenticated:quote_offers:SELECT',
      'authenticated:bookings:SELECT',
      'authenticated:request_photos:SELECT',
      'authenticated:request_photos:INSERT',
      'authenticated:request_photos:DELETE',
      'authenticated:notification_preferences:SELECT',
      // freelance (column-level grants are checked in the column matrix)
      'anon:digital_categories:SELECT',
      'authenticated:digital_categories:SELECT',
      'anon:freelancer_portfolio_items:SELECT',
      'authenticated:freelancer_portfolio_items:SELECT',
      'authenticated:freelancer_portfolio_items:INSERT',
      'authenticated:freelancer_portfolio_items:DELETE',
      'authenticated:freelancer_invites:DELETE',
    ];
    assert.deepEqual([...got].sort(), [...expected].sort());
  });

  test('column-level grants match the reviewed matrix exactly', async () => {
    const r = await db.query(
      `select grantee, table_name, column_name, privilege_type from information_schema.column_privileges
        where table_schema = 'public' and grantee in ('anon', 'authenticated')
          and table_name in ('profiles', 'customer_profiles', 'professional_profiles', 'portfolio_items')
          and privilege_type in ('UPDATE', 'INSERT')
        order by 1, 2, 3`);
    const updates = (grantee, table) =>
      r.rows.filter((x) => x.grantee === grantee && x.table_name === table).map((x) => x.column_name).sort();
    assert.deepEqual(updates('authenticated', 'profiles'), ['avatar_path', 'avatar_url', 'full_name', 'phone', 'preferred_language']);
    assert.deepEqual(updates('authenticated', 'customer_profiles'), ['default_city_id', 'default_governorate_id']);
    assert.deepEqual(updates('authenticated', 'professional_profiles'), [
      'availability', 'avatar_path', 'business_name', 'city_id', 'contact_phone', 'description', 'governorate_id',
      'is_published', 'latitude', 'longitude', 'neighborhood_id', 'primary_category_id', 'years_experience',
    ]);
    assert.deepEqual(
      r.rows.filter((x) => x.grantee === 'authenticated' && x.table_name === 'portfolio_items' && x.privilege_type === 'UPDATE').map((x) => x.column_name),
      ['caption'],
    );
    assert.deepEqual(r.rows.filter((x) => x.grantee === 'anon'), [], 'anon may not write any column');
    // What anonymous visitors may read on professional_profiles (never contact_phone).
    const anonRead = await db.query(
      `select column_name from information_schema.column_privileges
        where table_schema = 'public' and table_name = 'professional_profiles'
          and grantee = 'anon' and privilege_type = 'SELECT' order by 1`);
    const cols = anonRead.rows.map((x) => x.column_name);
    assert.ok(!cols.includes('contact_phone') && !cols.includes('verified_at'));
    assert.ok(cols.includes('verification_status') && cols.includes('rating_avg'));
  });

  test('admin_users is unreachable for every client role', async () => {
    const r = await db.query(
      `select count(*)::int as n from information_schema.table_privileges
        where table_schema = 'public' and table_name = 'admin_users' and grantee in ('anon', 'authenticated', 'PUBLIC')`);
    assert.equal(r.rows[0].n, 0);
  });

  test('every SECURITY DEFINER function pins its search_path', async () => {
    const r = await db.query(
      `select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.prosecdef
          and not coalesce(p.proconfig::text, '') like '%search_path=%'`);
    assert.deepEqual(r.rows, [], 'definer functions without a pinned search_path');
  });

  test('function EXECUTE rights match the reviewed matrix', async () => {
    const can = async (role, fn) =>
      (await db.query(`select has_function_privilege($1, $2, 'execute') as v`, [role, fn])).rows[0].v;
    assert.equal(await can('anon', 'public.become_professional()'), false);
    assert.equal(await can('authenticated', 'public.become_professional()'), true);
    assert.equal(await can('anon', 'public.admin_set_verification(uuid, text)'), false);
    assert.equal(await can('authenticated', 'public.admin_set_verification(uuid, text)'), false, 'only the reviewed workflow may verify');
    assert.equal(await can('anon', 'public.handle_new_user()'), false);
    assert.equal(await can('authenticated', 'public.handle_new_user()'), false);
    assert.equal(await can('authenticated', 'public.set_updated_at()'), false);
    assert.equal(await can('anon', 'public.is_admin()'), true);
    assert.equal(await can('authenticated', 'public.enforce_favorites_limit()'), false);
    assert.equal(await can('authenticated', 'public.enforce_portfolio_limit()'), false);
    assert.equal(await can('authenticated', 'public.enforce_request_photo_limit()'), false);
    assert.equal(await can('anon', 'public.get_my_activity()'), false);
    assert.equal(await can('authenticated', 'public.get_my_activity()'), true);
  });

  test('the new-user trigger is installed on auth.users', async () => {
    const r = await db.query(`select tgname from pg_trigger where tgname = 'on_auth_user_created' and not tgisinternal`);
    assert.equal(r.rows.length, 1);
  });
});
