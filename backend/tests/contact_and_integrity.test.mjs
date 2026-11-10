import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import {
  newDb, createUser, makeAdmin, anon, user, anonymousAuthUser, denies, DENIED, CHECK,
} from './harness.mjs';

const phone = '+21620123456';
const longDesc = 'Plombier avec dix ans d expérience à Tunis.';

async function becomePro(db, id) {
  await user(db, id).query('select public.become_professional()');
}
async function publish(db, id, cat = 1) {
  return user(db, id).query(
    `update public.professional_profiles
        set business_name = 'Karim Plomberie', primary_category_id = $2, description = $3,
            governorate_id = 11, contact_phone = $4, is_published = true
      where user_id = $1`,
    [id, cat, longDesc, phone],
  );
}

describe('contact phone reveal (anti-scraping)', () => {
  let db, pro, viewer, other;
  before(async () => {
    db = await newDb();
    pro = await createUser(db);
    viewer = await createUser(db);
    other = await createUser(db);
    await becomePro(db, pro);
    await publish(db, pro);
  });

  test('anonymous visitors cannot call the reveal functions', async () => {
    await denies(anon(db).query('select public.reveal_professional_contact($1)', [pro]), DENIED);
    await denies(anon(db).query('select public.get_my_professional_contact()'), DENIED);
  });

  test('a reveal is logged for the caller only', async () => {
    await user(db, viewer).query('select public.reveal_professional_contact($1)', [pro]);
    const n = await db.query('select count(*)::int as n from public.contact_reveals where user_id = $1 and professional_id = $2', [viewer, pro]);
    assert.equal(n.rows[0].n, 1);
    await denies(user(db, viewer).query('select * from public.contact_reveals'), DENIED);
    await denies(user(db, viewer).query('delete from public.contact_reveals'), DENIED);
  });

  test('at most 40 reveals per hour per user; other users are unaffected', async () => {
    const heavy = await createUser(db);
    for (let i = 0; i < 40; i += 1) {
      await user(db, heavy).query('select public.reveal_professional_contact($1)', [pro]);
    }
    await denies(user(db, heavy).query('select public.reveal_professional_contact($1)', [pro]), 'P0001');
    const fine = await user(db, other).query('select public.reveal_professional_contact($1) as p', [pro]);
    assert.equal(fine.rows[0].p, phone);
    // The window slides: old reveals stop counting after an hour.
    await db.query(`update public.contact_reveals set created_at = now() - interval '2 hours' where user_id = $1`, [heavy]);
    const again = await user(db, heavy).query('select public.reveal_professional_contact($1) as p', [pro]);
    assert.equal(again.rows[0].p, phone);
  });

  test('unknown ids and unpublished profiles are "not found" and not logged', async () => {
    const draft = await createUser(db);
    await becomePro(db, draft);
    const before = (await db.query('select count(*)::int as n from public.contact_reveals')).rows[0].n;
    await denies(user(db, viewer).query('select public.reveal_professional_contact($1)', [draft]), 'P0002');
    await denies(user(db, viewer).query('select public.reveal_professional_contact(gen_random_uuid())'), 'P0002');
    const after = (await db.query('select count(*)::int as n from public.contact_reveals')).rows[0].n;
    assert.equal(after, before);
  });

  test('the rate limit serializes per caller (advisory lock before counting)', async () => {
    // PGlite is single-connection, so true concurrency cannot be exercised here;
    // this guards that the lock stays in the function and sits before the count.
    const src = (await db.query(`select pg_get_functiondef(p.oid) as d from pg_proc p where p.proname = 'reveal_professional_contact'`)).rows[0].d;
    assert.match(src, /pg_advisory_xact_lock/);
    assert.ok(src.indexOf('pg_advisory_xact_lock') < src.indexOf('count(*)'), 'lock first, then count');
  });

  test('the owner reads their own phone; others get nothing for it', async () => {
    const mine = await user(db, pro).query('select public.get_my_professional_contact() as p');
    assert.equal(mine.rows[0].p, phone);
    const notPro = await user(db, viewer).query('select public.get_my_professional_contact() as p');
    assert.equal(notPro.rows[0].p, null);
  });
});

describe('anonymous-auth users are not registered users', () => {
  let db, pro, ghost;
  before(async () => {
    db = await newDb();
    pro = await createUser(db);
    ghost = await createUser(db); // an anonymous sign-in still creates an auth user
    await becomePro(db, pro);
    await publish(db, pro);
  });

  test('they can browse public data like a visitor', async () => {
    const r = await anonymousAuthUser(db, ghost).query('select user_id from public.professional_profiles');
    assert.equal(r.rows.length, 1);
  });

  test('they cannot reveal phones or become professionals', async () => {
    await denies(anonymousAuthUser(db, ghost).query('select public.reveal_professional_contact($1)', [pro]), DENIED);
    await denies(anonymousAuthUser(db, ghost).query('select public.become_professional()'), DENIED);
    await denies(anonymousAuthUser(db, ghost).query('select public.get_my_professional_contact()'), DENIED);
    const n = await db.query('select is_professional from public.profiles where id = $1', [ghost]);
    assert.equal(n.rows[0].is_professional, false);
  });
});

describe('verification is withdrawn when identity details change', () => {
  let db, pro, admin;
  before(async () => {
    db = await newDb();
    pro = await createUser(db);
    admin = await createUser(db);
    await makeAdmin(db, admin);
    await becomePro(db, pro);
    await publish(db, pro);
  });
  const verify = () => user(db, admin).query(`select public.admin_set_verification($1, 'verified')`, [pro]);
  const status = async () =>
    (await db.query('select verification_status, verified_at from public.professional_profiles where user_id = $1', [pro])).rows[0];

  test('editing the description keeps the badge', async () => {
    await verify();
    await user(db, pro).query(`update public.professional_profiles set description = 'Une description tout à fait différente.' where user_id = $1`, [pro]);
    assert.equal((await status()).verification_status, 'verified');
  });

  test('changing the business name withdraws it, publicly and immediately', async () => {
    await user(db, pro).query(`update public.professional_profiles set business_name = 'Autre Nom' where user_id = $1`, [pro]);
    const s = await status();
    assert.equal(s.verification_status, 'unverified');
    assert.equal(s.verified_at, null);
    const pub = await anon(db).query('select verification_status from public.professional_profiles');
    assert.equal(pub.rows[0].verification_status, 'unverified');
  });

  test('changing the contact phone withdraws it too; unchanged values do not', async () => {
    await verify();
    await user(db, pro).query('update public.professional_profiles set contact_phone = $1, business_name = $2 where user_id = $3', [phone, 'Autre Nom', pro]);
    assert.equal((await status()).verification_status, 'verified', 'same values: still verified');
    await user(db, pro).query(`update public.professional_profiles set contact_phone = '+21671123456' where user_id = $1`, [pro]);
    assert.equal((await status()).verification_status, 'unverified');
  });

  test('an admin re-verifying is not undone by the trigger', async () => {
    await verify();
    assert.equal((await status()).verification_status, 'verified');
  });
});

describe('inactive categories', () => {
  let db, pro, admin;
  before(async () => {
    db = await newDb();
    pro = await createUser(db);
    admin = await createUser(db);
    await makeAdmin(db, admin);
    await becomePro(db, pro);
    await user(db, admin).query(`update public.service_categories set is_active = false where id = 5`);
  });

  test('cannot be assigned as primary category or as a service', async () => {
    await denies(user(db, pro).query('update public.professional_profiles set primary_category_id = 5 where user_id = $1', [pro]), CHECK);
    await denies(user(db, pro).query('insert into public.professional_services (professional_id, category_id) values ($1, 5)', [pro]), CHECK);
  });

  test('cannot be published with; existing professionals keep working', async () => {
    // Legacy state: assigned while active, deactivated afterwards.
    await user(db, admin).query(`update public.service_categories set is_active = true where id = 5`);
    await user(db, pro).query('update public.professional_profiles set primary_category_id = 5 where user_id = $1', [pro]);
    await user(db, admin).query(`update public.service_categories set is_active = false where id = 5`);
    await denies(publish(db, pro, 5), CHECK);
    // Editing other fields of a profile whose category was deactivated later is fine.
    const r = await user(db, pro).query(`update public.professional_profiles set years_experience = 7 where user_id = $1`, [pro]);
    assert.equal(r.affectedRows, 1);
    await user(db, admin).query(`update public.service_categories set is_active = true where id = 5`);
    assert.equal((await publish(db, pro, 5)).affectedRows, 1);
  });
});

describe('sequence and function exposure', () => {
  let db, a;
  before(async () => {
    db = await newDb();
    a = await createUser(db);
  });

  test('clients hold no privileges on any sequence', async () => {
    const r = await db.query(
      `select c.relname, r.rolname,
              has_sequence_privilege(r.rolname, c.oid, 'USAGE') as u,
              has_sequence_privilege(r.rolname, c.oid, 'UPDATE') as w,
              has_sequence_privilege(r.rolname, c.oid, 'SELECT') as s
         from pg_class c join pg_namespace n on n.oid = c.relnamespace
         cross join (values ('anon'), ('authenticated')) as r (rolname)
        where n.nspname = 'public' and c.relkind = 'S'`);
    assert.ok(r.rows.length > 0);
    assert.deepEqual(r.rows.filter((x) => x.u || x.w || x.s), []);
  });

  test('rejected category inserts cannot burn identity values', async () => {
    const seq = async () => (await db.query(`select last_value::int as v from pg_sequences where schemaname = 'public' and sequencename like 'service_categories%'`)).rows[0].v;
    const before = await seq();
    for (let i = 0; i < 50; i += 1) {
      await denies(user(db, a).query(`insert into public.service_categories (slug, name_fr, name_ar, name_en) values ('s${i}', 'x', 'x', 'x')`), DENIED);
    }
    assert.equal(await seq(), before);
  });

  test('no function in public is callable by PUBLIC, and executability matches the reviewed list', async () => {
    const r = await db.query(
      `select p.proname, p.proacl is null as default_acl,
              has_function_privilege('anon', p.oid, 'execute') as anon_x,
              has_function_privilege('authenticated', p.oid, 'execute') as auth_x,
              exists (select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a where a.grantee = 0) as public_x
         from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' order by p.proname`);
    assert.deepEqual(r.rows.filter((x) => x.public_x || x.default_acl).map((x) => x.proname), [], 'PUBLIC / default ACL');
    const anonCan = r.rows.filter((x) => x.anon_x).map((x) => x.proname).sort();
    const authCan = r.rows.filter((x) => x.auth_x).map((x) => x.proname).sort();
    assert.deepEqual(anonCan, ['is_admin', 'search_normalize', 'search_professionals']);
    assert.deepEqual(authCan, [
      'accept_offer', 'admin_set_review_status', 'admin_set_verification', 'become_professional', 'can_view_request_photos', 'cancel_booking',
      'cancel_quote_request', 'chat_file_unsent', 'chat_folder_member', 'chat_folder_writable', 'chat_image_count', 'confirm_booking_completed',
      'create_quote_request', 'decline_offer', 'delete_my_account', 'get_my_activity',
      'get_my_professional_contact', 'get_my_quote_request', 'get_open_request', 'has_offered_on', 'is_admin',
      'is_conversation_member', 'is_request_owner', 'list_open_requests', 'mark_booking_done',
      'mark_conversation_read', 'my_conversations', 'my_notification_preferences', 'my_portfolio_file_count', 'my_quote_requests',
      'my_request_file_count', 'my_reviewed_bookings', 'owns_open_request', 'register_device_token', 'request_photo_is_locked', 'reveal_professional_contact',
      'search_normalize', 'search_professionals', 'send_message', 'set_notification_preferences', 'start_booking',
      'start_conversation', 'submit_offer', 'submit_review', 'unregister_device_token', 'withdraw_offer',
    ]);
  });

  test('every SECURITY DEFINER function pins search_path to the empty string exactly', async () => {
    const r = await db.query(
      `select p.proname, p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.prosecdef`);
    assert.ok(r.rows.length >= 5);
    for (const f of r.rows) {
      assert.ok((f.proconfig ?? []).includes('search_path=""'), `${f.proname}: ${JSON.stringify(f.proconfig)}`);
    }
  });
});

describe('sign-up trigger never blocks sign-up (it would break registration)', () => {
  let db;
  before(async () => { db = await newDb(); });

  test('survives hostile or odd metadata', async () => {
    const weird = [
      null,
      {},
      { full_name: 123 },
      { full_name: ['a', 'b'] },
      { full_name: { nested: { deep: true } } },
      { full_name: null, preferred_language: null },
      { preferred_language: 42 },
      { preferred_language: ['fr'] },
      { full_name: 'x'.repeat(100000) },
      { full_name: '   ' },
      { full_name: "Robert'); drop table public.profiles;--" },
      { full_name: '\u0000'.replace('\u0000', '') },
      { 'نام': 'قيمة' },
    ];
    for (const meta of weird) {
      const id = (await db.query('select gen_random_uuid() as id')).rows[0].id;
      await db.query('insert into auth.users (id, email, raw_user_meta_data) values ($1, $2, $3)', [
        id, `${id}@t.test`, meta === null ? null : JSON.stringify(meta),
      ]);
      const p = await db.query('select id, is_professional, preferred_language from public.profiles where id = $1', [id]);
      assert.equal(p.rows.length, 1, JSON.stringify(meta)?.slice(0, 60));
      assert.equal(p.rows[0].is_professional, false);
      assert.ok(['fr', 'ar', 'en'].includes(p.rows[0].preferred_language));
    }
    const still = await db.query(`select count(*)::int as n from information_schema.tables where table_schema = 'public' and table_name = 'profiles'`);
    assert.equal(still.rows[0].n, 1);
  });
});
