import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, makeAdmin, anon, user, as, denies, DENIED } from './harness.mjs';

const tagged = (promise, tag) =>
  assert.rejects(promise, (e) => e.code === 'P0001' && e.message === tag, `expected ${tag}`);

async function pro(db, name) {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  await user(db, id).query(
    `update public.professional_profiles
        set business_name = $2, primary_category_id = 1,
            description = 'Plombier avec dix ans d experience.', governorate_id = 11,
            contact_phone = '+21620123456', is_published = true
      where user_id = $1`, [id, name]);
  return id;
}

const READS = [
  ['select public.admin_overview()', []],
  ['select * from public.admin_stats_daily(7)', []],
  ['select * from public.admin_list_users()', []],
  ['select * from public.admin_list_professionals()', []],
  ['select * from public.admin_list_requests()', []],
  ['select * from public.admin_list_reviews()', []],
];

describe('admin dashboard functions', () => {
  let db, admin, plain, p1, p2;
  before(async () => {
    db = await newDb();
    admin = await createUser(db);
    await makeAdmin(db, admin);
    plain = await createUser(db);
    p1 = await pro(db, 'Plomberie Ben Ali');
    p2 = await pro(db, 'Électricité 100% Tunis');
  });

  test('everything is closed to anyone but admins', async () => {
    for (const [sql, args] of READS) {
      await assert.rejects(user(db, plain).query(sql, args), (e) => e.code === '42501', sql);
      await assert.rejects(user(db, p1).query(sql, args), (e) => e.code === '42501', sql);
      await denies(anon(db).query(sql, args), DENIED);
    }
    await assert.rejects(
      user(db, plain).query(`select public.admin_upsert_category(null, 'x', 'a', 'b', 'c')`), (e) => e.code === '42501');
    await denies(anon(db).query(`select public.admin_upsert_category(null, 'x', 'a', 'b', 'c')`), DENIED);
  });

  test('overview counts what exists', async () => {
    const o = (await user(db, admin).query('select public.admin_overview() as o')).rows[0].o;
    assert.equal(o.professionals, 2);
    assert.equal(o.published, 2);
    assert.equal(o.verified, 0);
    assert.equal(o.open_reports, 0);
    assert.equal(o.users, 4);
  });

  test('stats: one row per day, today included, signups counted', async () => {
    const rows = (await user(db, admin).query('select * from public.admin_stats_daily(7)')).rows;
    assert.equal(rows.length, 7);
    assert.equal(rows.at(-1).signups, 4);
    assert.equal((await user(db, admin).query('select * from public.admin_stats_daily(1000)')).rows.length, 180, 'capped');
    assert.equal((await user(db, admin).query('select * from public.admin_stats_daily(0)')).rows.length, 1);
  });

  test('user list: search by name or id, paging, no phone column', async () => {
    const all = (await user(db, admin).query('select * from public.admin_list_users()')).rows;
    assert.equal(all.length, 4);
    assert.ok(!('phone' in all[0]));
    assert.equal(all.find((u) => u.id === admin).is_admin, true);
    assert.equal(all.find((u) => u.id === plain).is_admin, false);
    assert.equal((await user(db, admin).query('select * from public.admin_list_users($1)', [plain])).rows.length, 1);
    assert.equal((await user(db, admin).query('select * from public.admin_list_users(null, 2, 0)')).rows.length, 2);
    assert.equal((await user(db, admin).query('select * from public.admin_list_users(null, 2, 3)')).rows.length, 1);
  });

  test('search treats % and _ as plain characters', async () => {
    const hit = (await user(db, admin).query(`select * from public.admin_list_professionals('100%')`)).rows;
    assert.deepEqual(hit.map((r) => r.user_id), [p2]);
    assert.equal((await user(db, admin).query(`select * from public.admin_list_professionals('%')`)).rows.length, 1, 'only the one containing a literal %');
    assert.equal((await user(db, admin).query(`select * from public.admin_list_professionals('_')`)).rows.length, 0);
  });

  test('professionals: filters and the invalid-filter tag', async () => {
    const f = async (name) => (await user(db, admin).query('select * from public.admin_list_professionals(null, $1)', [name])).rows.length;
    assert.equal(await f('all'), 2);
    assert.equal(await f('published'), 2);
    assert.equal(await f('unpublished'), 0);
    assert.equal(await f('verified'), 0);
    await user(db, admin).query('select public.admin_set_suspended($1, true)', [p1]);
    assert.equal(await f('suspended'), 1);
    assert.equal(await f('published'), 1);
    assert.equal(await f('unpublished'), 1);
    await tagged(user(db, admin).query(`select * from public.admin_list_professionals(null, 'bogus')`), 'invalid_input');
  });

  test('requests: status filter and offer counts; customers are not in the result', async () => {
    const c = await createUser(db);
    const r = (await user(db, c).query(
      `select public.create_quote_request('Fuite sous évier', 'Une fuite sous le lavabo.', 1::smallint, 11::smallint) as id`)).rows[0].id;
    await user(db, p2).query('select public.submit_offer($1, 80::numeric)', [r]);
    const rows = (await user(db, admin).query(`select * from public.admin_list_requests('open')`)).rows;
    const mine = rows.find((x) => x.id === r);
    assert.equal(mine.offers, 1);
    assert.ok(!('customer_id' in mine));
    assert.equal((await user(db, admin).query(`select * from public.admin_list_requests('cancelled')`)).rows.length, 0);
    await tagged(user(db, admin).query(`select * from public.admin_list_requests('weird')`), 'invalid_input');
  });

  test('reviews: published and hidden lists follow moderation', async () => {
    const c = await createUser(db);
    const r = (await user(db, c).query(
      `select public.create_quote_request('Fuite sous évier', 'Une fuite sous le lavabo.', 1::smallint, 11::smallint) as id`)).rows[0].id;
    const o = (await user(db, p2).query('select public.submit_offer($1, 80::numeric) as id', [r])).rows[0].id;
    const b = (await user(db, c).query('select public.accept_offer($1) as id', [o])).rows[0].id;
    await user(db, p2).query('select public.start_booking($1)', [b]);
    await user(db, p2).query('select public.mark_booking_done($1)', [b]);
    await user(db, c).query('select public.confirm_booking_completed($1)', [b]);
    const rv = (await user(db, c).query('select public.submit_review($1, 2::smallint, $2) as id', [b, 'Moyen'])).rows[0].id;
    const pub = async (s) => (await user(db, admin).query('select * from public.admin_list_reviews($1)', [s])).rows;
    assert.ok((await pub('published')).some((x) => x.id === rv));
    await user(db, admin).query(`select public.admin_set_review_status($1, 'hidden')`, [rv]);
    assert.ok((await pub('hidden')).some((x) => x.id === rv));
    assert.ok(!(await pub('published')).some((x) => x.id === rv));
    await tagged(user(db, admin).query(`select * from public.admin_list_reviews('x')`), 'invalid_input');
    const o2 = (await user(db, admin).query('select public.admin_overview() as o')).rows[0].o;
    assert.equal(o2.hidden_reviews, 1);
    assert.equal(o2.bookings.completed, 1);
  });

  test('categories: create, update, audit; bad input and duplicate slug are refused', async () => {
    const id = (await user(db, admin).query(
      `select public.admin_upsert_category(null, 'jardinage', 'Jardinage', 'بستنة', 'Gardening', 'grass', 5) as id`)).rows[0].id;
    assert.ok(id);
    await user(db, admin).query(`select public.admin_upsert_category($1, 'jardinage', 'Jardin', 'بستنة', 'Gardening', 'grass', 5, false)`, [id]);
    const row = (await db.query('select name_fr, is_active from public.service_categories where id = $1', [id])).rows[0];
    assert.deepEqual(row, { name_fr: 'Jardin', is_active: false });
    await tagged(user(db, admin).query(`select public.admin_upsert_category(null, 'jardinage', 'A', 'B', 'C')`), 'invalid_input');
    await tagged(user(db, admin).query(`select public.admin_upsert_category(null, 'Bad Slug', 'A', 'B', 'C')`), 'invalid_input');
    await tagged(user(db, admin).query(`select public.admin_upsert_category(null, 'ok-slug', ' ', 'B', 'C')`), 'invalid_input');
    await assert.rejects(user(db, admin).query(`select public.admin_upsert_category(9999::smallint, 'zz', 'A', 'B', 'C')`), (e) => e.code === 'P0002');
    const audit = (await user(db, admin).query('select action from public.admin_audit_log_page(100, 0)')).rows.map((x) => x.action);
    assert.ok(audit.includes('category_created') && audit.includes('category_updated'));
  });

  test('no STABLE function writes the audit log (PostgREST runs those read-only)', async () => {
    const r = await db.query(`select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.provolatile = 's' and p.prosrc ilike '%_audit(%'`);
    assert.deepEqual(r.rows, []);
  });

  test('paging past 5000 rows keeps moving (no silent cap on the offset)', async () => {
    const o = (await user(db, admin).query('select * from public.admin_list_users(null, 1, 6000)')).rows;
    assert.deepEqual(o, [], 'beyond the end there is nothing, not a repeat of an earlier page');
    for (const f of ['admin_list_users', 'admin_list_professionals', 'admin_list_requests', 'admin_list_reviews', 'admin_list_verifications', 'admin_list_reports', 'admin_audit_log_page']) {
      const src = (await db.query('select prosrc from pg_proc where proname = $1', [f])).rows[0].prosrc;
      assert.doesNotMatch(src, /least\(coalesce\(p_offset/, f);
    }
  });

  test('categories cannot be changed behind the audit (direct update and delete are gone)', async () => {
    await denies(user(db, admin).query(`update public.service_categories set is_active = false where id = 1`), DENIED);
    await denies(user(db, admin).query('delete from public.service_categories where id = 1'), DENIED);
  });

  test('every read is stable and every function pins its search_path', async () => {
    const r = await db.query(`select p.proname, p.provolatile, p.proconfig::text as cfg from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname in ('admin_overview','admin_stats_daily','admin_list_users','admin_list_professionals','admin_list_requests','admin_list_reviews')`);
    assert.equal(r.rows.length, 6);
    for (const f of r.rows) {
      assert.equal(f.provolatile, 's', f.proname);
      assert.match(f.cfg, /search_path=\\"\\"/, f.proname);
    }
  });

  test('with the second-factor rule on, only an aal2 session is an admin', async () => {
    await db.exec('update public.admin_config set require_mfa = true');
    try {
      const isAdmin = async (claims) => (await as(db, 'authenticated', admin, claims).query('select public.is_admin() as v')).rows[0].v;
      assert.equal(await isAdmin({}), false, 'password only');
      assert.equal(await isAdmin({ aal: 'aal1' }), false);
      assert.equal(await isAdmin({ aal: 'aal2' }), true);
      assert.equal(await isAdmin({ aal: 'AAL2' }), false);
      await assert.rejects(as(db, 'authenticated', admin, { aal: 'aal1' }).query('select public.admin_overview()'), (e) => e.code === '42501');
      await as(db, 'authenticated', admin, { aal: 'aal2' }).query('select public.admin_overview()');
      // a non-admin with aal2 is still not an admin
      assert.equal((await as(db, 'authenticated', plain, { aal: 'aal2' }).query('select public.is_admin() as v')).rows[0].v, false);
      // the flag itself is out of reach
      await denies(as(db, 'authenticated', admin, { aal: 'aal2' }).query('select * from public.admin_config'), DENIED);
      await denies(as(db, 'authenticated', admin, { aal: 'aal2' }).query('update public.admin_config set require_mfa = false'), DENIED);
    } finally {
      await db.exec('update public.admin_config set require_mfa = false');
    }
  });

  test('the second factor is on by default in the migration', async () => {
    assert.match(
      (await import('node:fs')).readFileSync(new URL('../supabase/migrations/20261110001400_admin_dashboard.sql', import.meta.url), 'utf8'),
      /require_mfa boolean not null default true/);
  });
});
