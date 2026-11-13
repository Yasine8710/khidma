import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, makeAdmin, as, anon, user, denies, DENIED } from './harness.mjs';

const tagged = (promise, tag) =>
  assert.rejects(promise, (e) => e.code === 'P0001' && e.message === tag, `expected ${tag}`);
const forbidden = (promise) => assert.rejects(promise, (e) => e.code === '42501', 'expected forbidden');
const notFound = (promise) => assert.rejects(promise, (e) => e.code === 'P0002', 'expected not found');

async function pro(db) {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  await user(db, id).query(
    `update public.professional_profiles
        set business_name = 'Pro ' || left($1::text, 4), primary_category_id = 1,
            description = 'Plombier avec dix ans d experience.', governorate_id = 11,
            contact_phone = '+21620123456', is_published = true
      where user_id = $1`, [id]);
  return id;
}
const call = (db, who, sql, ...args) => user(db, who).query(sql, args).then((r) => r.rows);
const one = (db, who, sql, ...args) => call(db, who, sql, ...args).then((r) => r[0]);
const ask = (db, who) =>
  one(db, who, `select public.create_quote_request('Fuite sous évier', 'Une fuite sous le lavabo.', 1::smallint, 11::smallint) as id`).then((r) => r.id);
const offer = (db, who, request) => one(db, who, 'select public.submit_offer($1, 100::numeric) as id', request).then((r) => r.id);
const start = (db, who, offerId) => one(db, who, 'select public.start_conversation($1) as id', offerId).then((r) => r.id);
const send = (db, who, conv, body = 'Bonjour') => one(db, who, 'select public.send_message($1, $2) as id', conv, body).then((r) => r.id);
const report = (db, who, type, target, reason = 'scam') =>
  one(db, who, 'select public.report_content($1, $2, $3) as id', type, target, reason).then((r) => r.id);
const reportMsg = (db, who, msg, reason = 'pay_outside') =>
  one(db, who, 'select public.report_message($1, $2) as id', msg, reason).then((r) => r.id);
const outbox = async (db, who, kind) =>
  (await db.query('select payload from public.notification_outbox where user_id = $1 and kind = $2', [who, kind])).rows;
const prof = async (db, p) =>
  (await db.query('select * from public.professional_profiles where user_id = $1', [p])).rows[0];
const inSearch = async (db, p) =>
  (await anon(db).query('select user_id, verification_status from public.search_professionals(p_limit => 50)')).rows.find((r) => r.user_id === p);
const verify = (db, p) =>
  db.query(`update public.professional_profiles set verification_status = 'verified', verified_at = now() where user_id = $1`, [p]);

describe('trust v2: reports on offers and messages', () => {
  let db, cust, other, p1, req, off, conv, proMsg, custMsg;
  before(async () => {
    db = await newDb();
    cust = await createUser(db);
    other = await createUser(db);
    p1 = await pro(db);
    req = await ask(db, cust);
    off = await offer(db, p1, req);
    conv = await start(db, cust, off);
    custMsg = await send(db, cust, conv, 'Bonjour');
    proMsg = await send(db, p1, conv, 'Payez-moi d avance sur ce numero');
  });

  test('only the customer who received an offer can report it; the subject is the professional', async () => {
    await notFound(report(db, other, 'offer', off));
    await notFound(report(db, p1, 'offer', off));
    const id = await report(db, cust, 'offer', off, 'pay_outside');
    const row = (await db.query('select * from public.reports where id = $1', [id])).rows[0];
    assert.equal(row.subject_id, p1);
    assert.equal(row.reason, 'pay_outside');
    await tagged(report(db, cust, 'offer', off), 'already_reported');
  });

  test('a message is reported by the other member only; one open report per message', async () => {
    await notFound(reportMsg(db, p1, proMsg), 'the author cannot report their own message');
    await notFound(reportMsg(db, other, proMsg), 'a stranger cannot report it');
    const id = await reportMsg(db, cust, proMsg);
    const row = (await db.query('select * from public.reports where id = $1', [id])).rows[0];
    assert.equal(row.target_type, 'message');
    assert.equal(row.target_id, conv);
    assert.equal(Number(row.message_id), Number(proMsg));
    assert.equal(row.subject_id, p1);
    await tagged(reportMsg(db, cust, proMsg), 'already_reported');
    // the professional can report the customer's message
    const back = await reportMsg(db, p1, custMsg, 'abuse');
    assert.equal((await db.query('select subject_id from public.reports where id = $1', [back])).rows[0].subject_id, cust);
  });

  test('message reports cannot be faked through report_content and bad reasons are refused', async () => {
    await tagged(report(db, cust, 'message', conv), 'invalid_input');
    await tagged(reportMsg(db, cust, proMsg, 'not_a_reason'), 'invalid_input');
    await denies(anon(db).query('select public.report_message(1, $1)', ['scam']), DENIED);
  });

  test('one person cannot pile more than 3 reports on the same person in 30 days', async () => {
    const c2 = await createUser(db);
    const p2 = await pro(db);
    const r2 = await ask(db, c2);
    const o2 = await offer(db, p2, r2);
    const cv = await start(db, c2, o2);
    const m1 = await send(db, p2, cv, 'un');
    const m2 = await send(db, p2, cv, 'deux');
    await report(db, c2, 'professional', p2);
    await report(db, c2, 'offer', o2);
    await reportMsg(db, c2, m1);
    await tagged(reportMsg(db, c2, m2), 'rate_limited');
  });

  test('reports and appeals tables stay closed to clients', async () => {
    await denies(user(db, cust).query('select id from public.reports'), DENIED);
    await denies(user(db, cust).query('select id from public.suspension_appeals'), DENIED);
    await denies(anon(db).query('select suspended_until from public.professional_profiles'), DENIED);
    await denies(user(db, p1).query('select suspension_reason from public.professional_profiles'), DENIED);
  });
});

describe('trust v2: queue, flag and suspension', () => {
  let db, admin, p, reporters, offers, conv, cust;
  before(async () => {
    db = await newDb();
    admin = await createUser(db);
    await makeAdmin(db, admin);
    p = await pro(db);
    reporters = [];
    offers = [];
    for (let i = 0; i < 3; i += 1) {
      const c = await createUser(db);
      const r = await ask(db, c);
      offers.push(await offer(db, p, r));
      reporters.push(c);
    }
    cust = reporters[0];
    conv = await start(db, cust, offers[0]);
    // a booked job: its chat must survive a suspension
    await call(db, cust, 'select public.accept_offer($1)', offers[0]);
  });

  test('3 different reporters in 30 days flag the person and put them first; nobody is suspended automatically', async () => {
    const lone = await pro(db);
    await report(db, reporters[0], 'professional', lone, 'spam');
    for (const c of reporters) await report(db, c, 'professional', p);
    const q = await call(db, admin, 'select * from public.admin_list_reports()');
    assert.equal(q[0].subject_id, p);
    assert.equal(q[0].flagged, true);
    assert.equal(q[0].subject_reporters_30d, 3);
    assert.equal(q[0].subject_is_professional, true);
    assert.equal(q.find((x) => x.subject_id === lone).flagged, false);
    assert.equal((await prof(db, p)).suspended, false);
    await forbidden(call(db, cust, 'select * from public.admin_list_reports()'));
  });

  test('suspend from a report: hidden, offers withdrawn, writes refused, reports closed, everyone told', async () => {
    const rep = (await call(db, admin, `select id from public.admin_list_reports() where subject_id = $1 limit 1`, p))[0].id;
    await forbidden(call(db, cust, 'select public.admin_suspend($1, 7, $2, $3)', p, 'Scam', rep));
    await tagged(call(db, admin, 'select public.admin_suspend($1, 0, $2)', p, 'Scam'), 'invalid_input');
    await tagged(call(db, admin, 'select public.admin_suspend($1, 7, $2)', p, '  '), 'invalid_input');
    await notFound(call(db, admin, 'select public.admin_suspend($1, 7, $2, $3)', cust, 'Wrong person', rep));
    await call(db, admin, 'select public.admin_suspend($1, 7, $2, $3)', p, 'Demande de paiement hors application', rep);

    const row = await prof(db, p);
    assert.equal(row.suspended, true);
    assert.equal(row.is_published, false);
    assert.ok(row.suspended_until > new Date(Date.now() + 6 * 86400e3));
    assert.equal(await inSearch(db, p), undefined, 'gone from search');
    const st = (await db.query(`select status from public.quote_offers where professional_id = $1`, [p])).rows;
    assert.deepEqual(st.map((x) => x.status).sort(), ['accepted', 'withdrawn', 'withdrawn'], 'pending offers withdrawn, the booked one kept');

    const open = (await db.query(`select count(*)::int as n from public.reports where subject_id = $1 and status = 'open'`, [p])).rows[0].n;
    assert.equal(open, 0, 'every open report on the person is closed');
    for (const c of reporters) {
      const n = await outbox(db, c, 'report_actioned');
      assert.equal(n.length, 1);
      assert.deepEqual(n[0].payload, {}, 'no details for the reporter');
    }
    assert.equal((await outbox(db, p, 'account_suspended')).length, 1);
    const audit = (await db.query(`select count(*)::int as n from public.admin_audit_log where action = 'suspend' and target_id = $1`, [p])).rows[0].n;
    assert.equal(audit, 1);
  });

  test('a suspended professional cannot offer, start a chat or write; the customer still can', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    await assert.rejects(offer(db, p, r), (e) => ['P0001', '42501'].includes(e.code));
    await tagged(send(db, p, conv, 'encore moi'), 'suspended');
    await send(db, cust, conv, 'Je vais annuler.');
    await assert.rejects(
      user(db, p).query(`update public.professional_profiles set is_published = true where user_id = $1`, [p]),
      (e) => e.code === '23514', 'cannot republish while suspended');
  });

  test('the owner sees the reason and end date; others see nothing', async () => {
    const s = (await one(db, p, 'select public.my_account_status() as s')).s;
    assert.equal(s.suspended, true);
    assert.equal(s.reason, 'Demande de paiement hors application');
    assert.ok(s.suspended_until);
    const c = (await one(db, cust, 'select public.my_account_status() as s')).s;
    assert.equal(c.suspended, false);
    await denies(anon(db).query('select public.my_account_status()'), DENIED);
  });

  test('appeal: one open at a time, rejection waits a week, lifting restores the account', async () => {
    await tagged(call(db, cust, 'select public.submit_appeal($1)', 'Je ne suis pas suspendu'), 'not_suspended');
    await tagged(call(db, p, 'select public.submit_appeal($1)', 'court'), 'invalid_input');
    const a1 = (await one(db, p, 'select public.submit_appeal($1) as id', 'Je n ai jamais demande d avance.')).id;
    await tagged(call(db, p, 'select public.submit_appeal($1)', 'Encore une fois svp.'), 'already_pending');
    await forbidden(call(db, p, 'select * from public.admin_list_appeals()'));
    const list = await call(db, admin, 'select * from public.admin_list_appeals()');
    assert.equal(list.length, 1);
    assert.equal(list[0].professional_id, p);

    await forbidden(call(db, p, 'select public.admin_decide_appeal($1, true)', a1));
    await call(db, admin, 'select public.admin_decide_appeal($1, false, $2)', a1, 'Preuves claires');
    await tagged(call(db, admin, 'select public.admin_decide_appeal($1, true)', a1), 'invalid_transition');
    assert.equal((await outbox(db, p, 'appeal_rejected')).length, 1);
    assert.equal((await one(db, p, 'select public.my_account_status() as s')).s.appeal_status, 'rejected');
    await tagged(call(db, p, 'select public.submit_appeal($1)', 'Je conteste encore.'), 'rate_limited');

    await db.query(`update public.suspension_appeals set decided_at = now() - interval '8 days' where id = $1`, [a1]);
    const a2 = (await one(db, p, 'select public.submit_appeal($1) as id', 'Voici mes preuves nouvelles.')).id;
    await call(db, admin, 'select public.admin_decide_appeal($1, true, $2)', a2, 'Erreur');
    const row = await prof(db, p);
    assert.equal(row.suspended, false);
    assert.equal(row.suspended_until, null);
    assert.equal(row.suspension_reason, null);
    assert.equal(row.is_published, false, 'lifting does not republish');
    assert.equal((await outbox(db, p, 'account_restored')).length, 1);
    await user(db, p).query(`update public.professional_profiles set is_published = true where user_id = $1`, [p]);
    assert.ok(await inSearch(db, p));
  });

  test('a temporary suspension ends by itself (lazily for the owner, or by the daily job)', async () => {
    await call(db, admin, 'select public.admin_suspend($1, 1, $2)', p, 'Test court');
    await db.query(`update public.professional_profiles set suspended_until = now() - interval '1 minute' where user_id = $1`, [p]);
    // writes are allowed again as soon as the time is up
    const c = await createUser(db);
    const r = await ask(db, c);
    await send(db, p, conv, 'De retour');
    const s = (await one(db, p, 'select public.my_account_status() as s')).s;
    assert.equal(s.suspended, false);
    assert.equal((await prof(db, p)).suspended, false);

    const p2 = await pro(db);
    await call(db, admin, 'select public.admin_suspend($1, 2, $2)', p2, 'Test job');
    await db.query(`update public.professional_profiles set suspended_until = now() - interval '1 minute' where user_id = $1`, [p2]);
    await denies(user(db, p2).query('select public.service_lift_expired_suspensions()'), DENIED);
    const n = (await as(db, 'service_role').query('select public.service_lift_expired_suspensions() as n')).rows[0].n;
    assert.equal(n, 1);
    assert.equal((await prof(db, p2)).suspended, false);
    assert.ok(r);
  });

  test('the old toggle still works: true suspends until lifted, false lifts', async () => {
    const p3 = await pro(db);
    await call(db, admin, 'select public.admin_set_suspended($1, true, $2)', p3, 'Toggle');
    const row = await prof(db, p3);
    assert.equal(row.suspended, true);
    assert.equal(row.suspended_until, null);
    await call(db, admin, 'select public.admin_set_suspended($1, false)', p3);
    assert.equal((await prof(db, p3)).suspended, false);
  });

  test('dismissing a report tells the reporter, without the note', async () => {
    const c = await createUser(db);
    const target = await pro(db);
    const id = await report(db, c, 'professional', target, 'other');
    await call(db, admin, 'select public.admin_handle_report($1, $2, $3)', id, 'dismissed', 'rien de grave');
    const n = await outbox(db, c, 'report_dismissed');
    assert.equal(n.length, 1);
    assert.deepEqual(n[0].payload, {});
  });
});

describe('trust v2: badge validity and revocation', () => {
  let db, admin, p;
  before(async () => {
    db = await newDb();
    admin = await createUser(db);
    await makeAdmin(db, admin);
    p = await pro(db);
  });

  test('a verification is valid 12 months and shows in search while valid', async () => {
    await verify(db, p);
    const row = await prof(db, p);
    const today = (await db.query('select public.tunis_today() as d')).rows[0].d;
    assert.equal(Math.round((row.verified_until - today) / 86400e3), 365);
    assert.equal((await inSearch(db, p)).verification_status, 'verified');
    const pub = (await anon(db).query('select verified_until from public.professional_profiles where user_id = $1', [p])).rows[0];
    assert.ok(pub.verified_until, 'the validity date is public');
  });

  test('once the date has passed, search reports unverified even before the daily job', async () => {
    await db.query(`update public.professional_profiles set verified_until = public.tunis_today() - 1 where user_id = $1`, [p]);
    assert.equal((await prof(db, p)).verification_status, 'verified');
    assert.equal((await inSearch(db, p)).verification_status, 'unverified');
    assert.equal((await anon(db).query('select public.badge_valid($1, $2::date) as v', ['verified', '2000-01-01'])).rows[0].v, false);
  });

  test('the daily job turns expired badges back to unverified and tells the professional', async () => {
    const n = (await as(db, 'service_role').query('select public.service_expire_verifications() as n')).rows[0].n;
    assert.equal(n, 1);
    const row = await prof(db, p);
    assert.equal(row.verification_status, 'unverified');
    assert.equal(row.verified_until, null);
    assert.equal((await outbox(db, p, 'verification_expired')).length, 1);
    await denies(user(db, p).query('select public.service_expire_verifications()'), DENIED);
  });

  test('an admin can revoke a badge with a reason; it disappears at once', async () => {
    await verify(db, p);
    await forbidden(call(db, p, 'select public.admin_revoke_verification($1, $2)', p, 'x'));
    await tagged(call(db, admin, 'select public.admin_revoke_verification($1, $2)', p, ''), 'invalid_input');
    await call(db, admin, 'select public.admin_revoke_verification($1, $2)', p, 'Document falsifie');
    const row = await prof(db, p);
    assert.equal(row.verification_status, 'revoked');
    assert.equal(row.verified_until, null);
    assert.equal((await inSearch(db, p)).verification_status, 'revoked');
    await notFound(call(db, admin, 'select public.admin_revoke_verification($1, $2)', p, 'deja fait'));
  });

  test('an expired badge can be renewed before the daily job runs', async () => {
    const q = await pro(db);
    await verify(db, q);
    await user(db, q).query(`insert into storage.objects (bucket_id, name, owner) values ('verification-docs', $1, $2)`, [`${q}/id.jpg`, q]);
    await tagged(call(db, q, 'select public.submit_verification($1::text[])', [`${q}/id.jpg`]), 'already_verified');
    await db.query(`update public.professional_profiles set verified_until = public.tunis_today() - 1 where user_id = $1`, [q]);
    await call(db, q, 'select public.submit_verification($1::text[])', [`${q}/id.jpg`]);
    const row = await prof(db, q);
    assert.equal(row.verification_status, 'pending');
    assert.equal(row.verified_until, null);
    assert.equal(row.verified_at, null);
  });

  test('an identity change still withdraws the badge (and its date)', async () => {
    await verify(db, p);
    await user(db, p).query(`update public.professional_profiles set business_name = 'Autre nom' where user_id = $1`, [p]);
    const row = await prof(db, p);
    assert.equal(row.verification_status, 'unverified');
    assert.equal(row.verified_until, null);
  });
});
