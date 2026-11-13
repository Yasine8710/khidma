import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, makeAdmin, as, anon, user, denies, DENIED } from './harness.mjs';

const tagged = (promise, tag) =>
  assert.rejects(promise, (e) => e.code === 'P0001' && e.message === tag, `expected ${tag}`);

async function pro(db, { ageDays = 60 } = {}) {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  await user(db, id).query(
    `update public.professional_profiles
        set business_name = 'Pro ' || left($1::text, 4), primary_category_id = 1,
            description = 'Plombier avec dix ans d experience.', governorate_id = 11,
            contact_phone = '+21620123456', is_published = true
      where user_id = $1`, [id]);
  await db.query(`update public.professional_profiles set created_at = now() - make_interval(days => $2) where user_id = $1`, [id, ageDays]);
  return id;
}
const subscribe = (db, who, endSql, status = 'active') =>
  db.query(
    `insert into public.subscriptions (user_id, plan_code, status, current_period_end) values ($1, 'standard', $2, ${endSql})
     on conflict (user_id) do update set status = excluded.status, current_period_end = excluded.current_period_end`,
    [who, status]);
const listed = async (client, who) =>
  (await client.query('select user_id from public.professional_profiles where user_id = $1', [who])).rows.length === 1;
const inSearch = async (db, who) =>
  (await anon(db).query('select user_id from public.search_professionals(p_limit => 50)')).rows.some((r) => r.user_id === who);
const ask = (db, who) =>
  user(db, who).query(`select public.create_quote_request('Fuite sous évier', 'Une fuite sous le lavabo.', 1::smallint, 11::smallint) as id`).then((r) => r.rows[0].id);
const offer = (db, who, req) => user(db, who).query('select public.submit_offer($1, 100::numeric) as id', [req]).then((r) => r.rows[0].id);
const reminders = async (db, who) =>
  (await db.query(`select kind from public.notification_outbox where user_id = $1 and kind like 'subscription_%' order by id`, [who])).rows.map((r) => r.kind);
const runReminders = (db) => as(db, 'service_role').query('select public.service_subscription_reminders() as n');

describe('subscription enforcement', () => {
  let db, admin, cust, unpaid, paid, booked, req, conv, booking;
  const enforce = (on, trial = 30) =>
    user(db, admin).query('select public.admin_set_billing_config($1, $2, $3)', [on, trial, 'Lancement']);

  before(async () => {
    db = await newDb();
    admin = await createUser(db);
    await makeAdmin(db, admin);
    cust = await createUser(db);
    unpaid = await pro(db);
    paid = await pro(db);
    await subscribe(db, paid, "now() + interval '20 days'");
    // a job accepted before enforcement, with a professional who will be hidden
    booked = await pro(db);
    req = await ask(db, cust);
    const o = await offer(db, booked, req);
    conv = (await user(db, cust).query('select public.start_conversation($1) as id', [o])).rows[0].id;
    booking = (await user(db, cust).query('select public.accept_offer($1) as id', [o])).rows[0].id;
  });

  test('off by default: unpaid professionals stay listed', async () => {
    assert.equal(await listed(anon(db), unpaid), true);
    assert.equal(await inSearch(db, unpaid), true);
  });

  test('only admins change the switch; a reason is required and it is audited', async () => {
    await denies(user(db, unpaid).query('select public.admin_set_billing_config(true, 30, $1)', ['x']), DENIED);
    await denies(user(db, unpaid).query('select public.admin_billing_config()'), DENIED);
    await tagged(user(db, admin).query('select public.admin_set_billing_config(true, 30, $1)', [' ']), 'invalid_input');
    await tagged(user(db, admin).query('select public.admin_set_billing_config(true, 400, $1)', ['x']), 'invalid_input');
    await enforce(true);
    const cfg = (await user(db, admin).query('select public.admin_billing_config() as c')).rows[0].c;
    assert.deepEqual(cfg, { enforce_subscriptions: true, free_trial_days: 30 });
    const n = (await db.query(`select count(*)::int as n from public.admin_audit_log where action = 'billing_config'`)).rows[0].n;
    assert.equal(n, 1);
  });

  test('on: an unpaid professional past the trial disappears everywhere for others, not for the owner', async () => {
    const stranger = await createUser(db);
    assert.equal(await listed(anon(db), unpaid), false);
    assert.equal(await listed(user(db, stranger), unpaid), false);
    assert.equal(await inSearch(db, unpaid), false);
    assert.equal(await listed(user(db, unpaid), unpaid), true, 'the owner still sees their profile');
    assert.equal(await listed(user(db, admin), unpaid), true, 'admins too');
    assert.equal((await anon(db).query('select * from public.professional_services where professional_id = $1', [unpaid])).rows.length, 0);
    await assert.rejects(user(db, stranger).query('select public.reveal_professional_contact($1)', [unpaid]), (e) => e.code === 'P0002');
    await denies(user(db, stranger).query('insert into public.favorites (user_id, professional_id) values ($1, $2)', [stranger, unpaid]), DENIED);
    // the paying one is unaffected
    assert.equal(await inSearch(db, paid), true);
  });

  test('on: no new offers while unlisted', async () => {
    const r = await ask(db, cust);
    await tagged(offer(db, unpaid, r), 'subscription_required');
    assert.ok(await offer(db, paid, r));
  });

  test('a job accepted earlier keeps working with a hidden professional', async () => {
    assert.equal(await listed(anon(db), booked), false);
    await user(db, booked).query('select public.send_message($1, $2)', [conv, 'Je passe demain']);
    await user(db, booked).query('select public.start_booking($1)', [booking]);
    await user(db, booked).query('select public.mark_booking_done($1)', [booking]);
    await user(db, cust).query('select public.confirm_booking_completed($1)', [booking]);
    assert.ok((await user(db, cust).query('select public.submit_review($1, 5::smallint, $2) as id', [booking, 'Tres bien'])).rows[0].id);
  });

  test('the free trial lists new professionals; 0 days ends it', async () => {
    const fresh = await pro(db, { ageDays: 3 });
    assert.equal(await listed(anon(db), fresh), true);
    await enforce(true, 0);
    assert.equal(await listed(anon(db), fresh), false);
    await enforce(true, 30);
  });

  test('grace: listed up to 7 days after the period ends; cancelled is hidden; paying shows it at once', async () => {
    const g = await pro(db);
    await subscribe(db, g, "now() - interval '6 days 23 hours'", 'past_due');
    assert.equal(await listed(anon(db), g), true);
    await subscribe(db, g, "now() - interval '7 days 1 hour'", 'past_due');
    assert.equal(await listed(anon(db), g), false);
    await subscribe(db, g, "now() + interval '10 days'", 'cancelled');
    assert.equal(await listed(anon(db), g), false);
    // paying: an admin confirms a manual order, the profile is back immediately
    const o = (await user(db, g).query('select * from public.create_payment_order($1, $2)', ['standard', 'd17'])).rows[0].id;
    await user(db, g).query('select public.mark_payment_sent($1)', [o]);
    await user(db, admin).query('select public.admin_confirm_payment($1)', [o]);
    assert.equal(await listed(anon(db), g), true);
  });

  test('the owner sees whether they are listed and until when', async () => {
    const s = (await user(db, unpaid).query('select public.my_listing_status() as s')).rows[0].s;
    assert.equal(s.enforced, true);
    assert.equal(s.listed, false);
    assert.equal(s.paid_until, null);
    const p = (await user(db, paid).query('select public.my_listing_status() as s')).rows[0].s;
    assert.equal(p.listed, true);
    assert.ok(p.grace_ends_at);
    await denies(user(db, cust).query('select public.my_listing_status()'), DENIED);
  });

  test('freelance listings follow the same rule', async () => {
    const f = await pro(db);
    await db.query(`update public.professional_profiles set verification_status = 'verified', verified_at = now() where user_id = $1`, [f]);
    await user(db, f).query('select public.become_freelancer()');
    await user(db, f).query(
      `update public.freelancer_profiles set display_name = 'Sami', headline = 'Developpeur web', primary_category_id = 1,
         bio = 'Sites et applications web depuis dix ans.', is_published = true where user_id = $1`, [f]);
    assert.equal((await anon(db).query('select public.freelancer_is_visible($1) as v', [f])).rows[0].v, false);
    await subscribe(db, f, "now() + interval '30 days'");
    assert.equal((await anon(db).query('select public.freelancer_is_visible($1) as v', [f])).rows[0].v, true);
  });

  test('switching off lists everyone again', async () => {
    await enforce(false);
    assert.equal(await listed(anon(db), unpaid), true);
    await enforce(true);
  });
});

describe('subscription reminders', () => {
  let db;
  before(async () => { db = await newDb(); });

  // A period ending at `hour`:30 Tunis time, `days` local days from today.
  const endsIn = (db2, who, days, hour = 12) => db2.query(
    `insert into public.subscriptions (user_id, plan_code, status, current_period_end)
     values ($1, 'standard', 'active', ((public.tunis_today() + $2::int)::timestamp + make_interval(hours => $3, mins => 30)) at time zone 'Africa/Tunis')
     on conflict (user_id) do update set current_period_end = excluded.current_period_end, status = excluded.status`,
    [who, days, hour]);

  test('only the service role runs them', async () => {
    const p = await pro(db);
    await denies(user(db, p).query('select public.service_subscription_reminders()'), DENIED);
  });

  test('each stage is sent once per period, however often the job runs', async () => {
    const p = await pro(db);
    await endsIn(db, p, 5);
    await runReminders(db);
    await runReminders(db);
    assert.deepEqual(await reminders(db, p), ['subscription_due_soon']);
    await endsIn(db, p, 1);
    await runReminders(db);
    await endsIn(db, p, -1);
    await runReminders(db);
    await endsIn(db, p, -7);
    await runReminders(db);
    await runReminders(db);
    // each move above is a new period end, so each stage fired once
    assert.deepEqual(await reminders(db, p), [
      'subscription_due_soon', 'subscription_due_now', 'subscription_overdue', 'subscription_grace_over',
    ]);
  });

  test('days are Tunis days: 00:30 local is still the next day, though it is the evening before in UTC', async () => {
    const early = await pro(db);
    const late = await pro(db);
    await endsIn(db, early, 6, 0); // 00:30 Tunis = 23:30 UTC on day +5
    await endsIn(db, late, 6, 23);
    await runReminders(db);
    assert.deepEqual(await reminders(db, early), [], 'day +6 in Tunis: too early for the 5-day reminder');
    assert.deepEqual(await reminders(db, late), []);
    await endsIn(db, early, 5, 0);
    await runReminders(db);
    assert.deepEqual(await reminders(db, early), ['subscription_due_soon']);
  });

  test('nothing for periods far away or long expired', async () => {
    const far = await pro(db);
    const old = await pro(db);
    await endsIn(db, far, 20);
    await endsIn(db, old, -60);
    await runReminders(db);
    assert.deepEqual(await reminders(db, far), []);
    assert.deepEqual(await reminders(db, old), []);
  });
});
