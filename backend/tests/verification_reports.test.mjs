import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, makeAdmin, anon, user, denies, DENIED } from './harness.mjs';

const tagged = (promise, tag) =>
  assert.rejects(promise, (e) => e.code === 'P0001' && e.message === tag, `expected ${tag}`);

async function pro(db, publish = true) {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  await user(db, id).query(
    `update public.professional_profiles
        set business_name = 'Pro ' || left($1::text, 4), primary_category_id = 1,
            description = 'Plombier avec dix ans d experience.', governorate_id = 11,
            contact_phone = '+21620123456', is_published = $2
      where user_id = $1`, [id, publish]);
  return id;
}
const put = (db, who, name, owner = who) =>
  user(db, who).query(`insert into storage.objects (bucket_id, name, owner) values ('verification-docs', $1, $2)`, [`${owner}/${name}`, who]);
const submit = (db, who, names) =>
  user(db, who).query('select public.submit_verification($1::text[]) as id', [names.map((n) => `${who}/${n}`)]).then((r) => r.rows[0].id);
const status = async (db, p) =>
  (await db.query('select verification_status as s from public.professional_profiles where user_id = $1', [p])).rows[0].s;
const queued = async (db, p) =>
  (await db.query(`select count(*)::int as n from public.storage_cleanup_queue where split_part(name, '/', 1) = $1`, [p])).rows[0].n;

describe('verification', () => {
  let db, admin;
  before(async () => {
    db = await newDb();
    admin = await createUser(db);
    await makeAdmin(db, admin);
  });

  test('submit marks the profile pending; one pending request at a time', async () => {
    const p = await pro(db);
    await put(db, p, 'id.jpg');
    const req = await submit(db, p, ['id.jpg']);
    assert.ok(req);
    assert.equal(await status(db, p), 'pending');
    await put(db, p, 'two.jpg');
    await tagged(submit(db, p, ['two.jpg']), 'already_pending');
    const mine = (await user(db, p).query('select * from public.my_verification()')).rows[0];
    assert.equal(mine.status, 'pending');
  });

  test('only professionals with their own uploaded files can submit', async () => {
    const c = await createUser(db);
    await assert.rejects(user(db, c).query('select public.submit_verification($1::text[])', [[`${c}/x.jpg`]]), (e) => e.code === '42501');
    const p = await pro(db);
    await tagged(user(db, p).query('select public.submit_verification($1::text[])', [[`${p}/missing.jpg`]]), 'invalid_input');
    const other = await pro(db);
    await put(db, other, 'o.jpg');
    await tagged(user(db, p).query('select public.submit_verification($1::text[])', [[`${other}/o.jpg`]]), 'invalid_input');
    await tagged(user(db, p).query('select public.submit_verification($1::text[])', [[]]), 'invalid_input');
    await denies(anon(db).query('select public.submit_verification($1::text[])', [[`${p}/x.jpg`]]), DENIED);
  });

  test('documents are private: only the owner reads through Storage (admins go through the audited function)', async () => {
    const p = await pro(db);
    const stranger = await createUser(db);
    await put(db, p, 'id.png');
    const q = 'select name from storage.objects where bucket_id = $1';
    assert.equal((await user(db, p).query(q, ['verification-docs'])).rows.filter((r) => r.name.startsWith(p)).length, 1);
    assert.equal((await user(db, stranger).query(q, ['verification-docs'])).rows.length, 0);
    assert.equal((await anon(db).query(q, ['verification-docs'])).rows.length, 0);
    assert.equal((await user(db, admin).query(q, ['verification-docs'])).rows.length, 0, 'an admin cannot bypass the audit by reading Storage');
  });

  test('uploads: own folder only, professionals only, at most 6 files', async () => {
    const p = await pro(db);
    const c = await createUser(db);
    await denies(put(db, p, 'x.jpg', c), DENIED);
    await denies(put(db, c, 'x.jpg'), DENIED);
    for (let i = 0; i < 6; i++) await put(db, p, `f${i}.jpg`);
    await denies(put(db, p, 'f6.jpg'), DENIED);
  });

  test('a submitted file cannot be deleted by the owner; an unsubmitted one can', async () => {
    const p = await pro(db);
    await put(db, p, 'a.jpg');
    await put(db, p, 'b.jpg');
    await submit(db, p, ['a.jpg']);
    await user(db, p).query('delete from storage.objects where name = $1', [`${p}/a.jpg`]);
    assert.equal((await db.query('select count(*)::int as n from storage.objects where name = $1', [`${p}/a.jpg`])).rows[0].n, 1);
    await user(db, p).query('delete from storage.objects where name = $1', [`${p}/b.jpg`]);
    assert.equal((await db.query('select count(*)::int as n from storage.objects where name = $1', [`${p}/b.jpg`])).rows[0].n, 0);
  });

  test('no direct table access to requests or documents', async () => {
    const p = await pro(db);
    await put(db, p, 'a.jpg');
    await submit(db, p, ['a.jpg']);
    await denies(user(db, p).query('select * from public.verification_requests'), DENIED);
    await denies(user(db, p).query('select * from public.verification_documents'), DENIED);
    await denies(user(db, p).query(`update public.verification_requests set status = 'approved'`), DENIED);
    await denies(user(db, p).query(`update public.professional_profiles set verification_status = 'verified' where user_id = $1`, [p]), DENIED);
  });

  test('cancel removes the documents and returns the profile to unverified', async () => {
    const p = await pro(db);
    await put(db, p, 'a.jpg');
    await submit(db, p, ['a.jpg']);
    await user(db, p).query('select public.cancel_verification()');
    assert.equal(await status(db, p), 'unverified');
    assert.equal(await queued(db, p), 1, 'the file is queued for the cleanup worker');
    assert.equal((await db.query('select count(*)::int as n from public.verification_documents d join public.verification_requests r on r.id = d.request_id where r.professional_id = $1', [p])).rows[0].n, 0, 'document rows are gone');
    await tagged(user(db, p).query('select public.cancel_verification()'), 'invalid_transition');
    // and a new request is possible
    await put(db, p, 'b.jpg');
    await submit(db, p, ['b.jpg']);
  });

  test('at most 3 requests in 30 days', async () => {
    const p = await pro(db);
    for (let i = 0; i < 3; i++) {
      await put(db, p, `r${i}.jpg`);
      await submit(db, p, [`r${i}.jpg`]);
      await user(db, p).query('select public.cancel_verification()');
    }
    await put(db, p, 'r3.jpg');
    await tagged(submit(db, p, ['r3.jpg']), 'rate_limited');
  });

  test('admin approval verifies, deletes documents, and is audited', async () => {
    const p = await pro(db);
    await put(db, p, 'a.jpg');
    const req = await submit(db, p, ['a.jpg']);
    const list = (await user(db, admin).query(`select * from public.admin_list_verifications('pending')`)).rows;
    assert.ok(list.some((r) => r.id === req && r.documents === 1));
    const docs = (await user(db, admin).query('select * from public.admin_verification_documents($1)', [req])).rows;
    assert.deepEqual(docs.map((d) => d.path), [`${p}/a.jpg`]);
    await user(db, admin).query('select public.admin_review_verification($1, true)', [req]);
    assert.equal(await status(db, p), 'verified');
    assert.equal(await queued(db, p), 1);
    assert.equal((await db.query('select count(*)::int as n from public.verification_documents where request_id = $1', [req])).rows[0].n, 0);
    const audit = (await user(db, admin).query('select action from public.admin_audit_log_page(50, 0)')).rows.map((r) => r.action);
    assert.ok(audit.includes('verification_approved'));
    assert.ok(audit.includes('view_documents'));
    await tagged(user(db, admin).query('select public.admin_review_verification($1, true)', [req]), 'invalid_transition');
    // verified professionals cannot submit again
    await put(db, p, 'again.jpg');
    await tagged(submit(db, p, ['again.jpg']), 'already_verified');
  });

  test('rejection needs a reason, shows it to the owner, and lets them retry', async () => {
    const p = await pro(db);
    await put(db, p, 'a.jpg');
    const req = await submit(db, p, ['a.jpg']);
    await tagged(user(db, admin).query('select public.admin_review_verification($1, false)', [req]), 'invalid_input');
    await tagged(user(db, admin).query('select public.admin_review_verification($1, false, $2)', [req, 'x'.repeat(301)]), 'invalid_input');
    await user(db, admin).query('select public.admin_review_verification($1, false, $2)', [req, 'Photo illisible']);
    assert.equal(await status(db, p), 'rejected');
    const mine = (await user(db, p).query('select * from public.my_verification()')).rows[0];
    assert.deepEqual([mine.status, mine.reject_reason], ['rejected', 'Photo illisible']);
    await put(db, p, 'b.jpg');
    await submit(db, p, ['b.jpg']);
    assert.equal(await status(db, p), 'pending');
  });

  test('the admin functions refuse everyone else', async () => {
    const p = await pro(db);
    const req = (await (async () => { await put(db, p, 'a.jpg'); return submit(db, p, ['a.jpg']); })());
    for (const [sql, args] of [
      [`select * from public.admin_list_verifications('pending')`, []],
      ['select * from public.admin_verification_documents($1)', [req]],
      ['select public.admin_review_verification($1, true)', [req]],
      ['select * from public.admin_audit_log_page()', []],
      ['select public.admin_set_suspended($1, true)', [p]],
      [`select public.admin_set_verification($1, 'verified')`, [p]],
      [`select * from public.admin_list_reports('open')`, []],
    ]) {
      await assert.rejects(user(db, p).query(sql, args), (e) => e.code === '42501', sql);
    }
    await denies(anon(db).query(`select * from public.admin_list_verifications('pending')`), DENIED);
    await denies(user(db, p).query('select * from public.admin_audit_log'), DENIED);
  });

  test('suspension unpublishes, blocks republishing, and is reversible', async () => {
    const p = await pro(db);
    await user(db, admin).query('select public.admin_set_suspended($1, true, $2)', [p, 'arnaque']);
    const r = (await db.query('select is_published, suspended from public.professional_profiles where user_id = $1', [p])).rows[0];
    assert.deepEqual([r.is_published, r.suspended], [false, true]);
    await assert.rejects(
      user(db, p).query('update public.professional_profiles set is_published = true where user_id = $1', [p]),
      (e) => e.code === '23514');
    await assert.rejects(
      user(db, p).query('update public.professional_profiles set suspended = false where user_id = $1', [p]),
      (e) => e.code === '42501');
    await user(db, admin).query('select public.admin_set_suspended($1, false)', [p]);
    await user(db, p).query('update public.professional_profiles set is_published = true where user_id = $1', [p]);
  });

  test('deleting the account removes the documents', async () => {
    const p = await pro(db);
    await put(db, p, 'a.jpg');
    await submit(db, p, ['a.jpg']);
    await user(db, p).query('select public.delete_my_account()');
    assert.equal(await queued(db, p), 1);
    assert.equal((await db.query('select count(*)::int as n from public.verification_requests where professional_id = $1', [p])).rows[0].n, 0);
  });

  test('queued files do not count against the upload allowance, and clients cannot read the queue', async () => {
    const p = await pro(db);
    for (let i = 0; i < 6; i++) await put(db, p, `f${i}.jpg`);
    await denies(put(db, p, 'f6.jpg'), DENIED);
    await db.query(`insert into public.storage_cleanup_queue (bucket_id, name) values ('verification-docs', $1)`, [`${p}/f0.jpg`]);
    await put(db, p, 'f6.jpg');
    await denies(user(db, p).query('select * from public.storage_cleanup_queue'), DENIED);
    await denies(user(db, admin).query('select * from public.storage_cleanup_queue'), DENIED);
  });

  test('submit refuses nested, null-containing or oversized path arrays', async () => {
    const p = await pro(db);
    const names = [];
    for (let i = 0; i < 6; i++) { await put(db, p, `n${i}.jpg`); names.push(`${p}/n${i}.jpg`); }
    await tagged(user(db, p).query('select public.submit_verification($1::text[])', [[names.slice(0, 3), names.slice(3)]]), 'invalid_input');
    await tagged(user(db, p).query('select public.submit_verification($1::text[])', [names.slice(0, 4)]), 'invalid_input');
    await tagged(user(db, p).query('select public.submit_verification($1::text[])', [[names[0], null]]), 'invalid_input');
    assert.equal(await status(db, p), 'unverified');
  });

  test('no database function deletes storage rows (Supabase forbids it); they queue instead', async () => {
    const r = await db.query(`select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prosrc ilike '%delete from storage.objects%'`);
    assert.deepEqual(r.rows, []);
  });
});

describe('reports', () => {
  let db, admin, p, c, other;
  before(async () => {
    db = await newDb();
    admin = await createUser(db);
    await makeAdmin(db, admin);
    p = await pro(db);
    c = await createUser(db);
    other = await createUser(db);
  });
  const report = (who, type, target, reason = 'spam', details = null) =>
    user(db, who).query('select public.report_content($1, $2, $3, $4) as id', [type, target, reason, details]).then((r) => r.rows[0].id);

  test('report a published professional; duplicates while open are refused', async () => {
    const id = await report(c, 'professional', p, 'scam', 'Demande un acompte');
    assert.ok(id);
    await tagged(report(c, 'professional', p), 'already_reported');
    // another reporter is fine
    await report(other, 'professional', p, 'fake');
  });

  test('cannot report yourself, an unpublished profile, or a missing target', async () => {
    await assert.rejects(report(p, 'professional', p), (e) => e.code === 'P0002');
    const hidden = await pro(db, false);
    await assert.rejects(report(c, 'professional', hidden), (e) => e.code === 'P0002');
    await assert.rejects(report(c, 'professional', '00000000-0000-0000-0000-000000000000'), (e) => e.code === 'P0002');
  });

  test('validates type, reason and details; registered users only', async () => {
    const q = await pro(db);
    await tagged(report(c, 'user', q), 'invalid_input');
    await tagged(report(c, 'professional', q, 'bogus'), 'invalid_input');
    await tagged(report(c, 'professional', q, 'abuse', 'x'.repeat(501)), 'invalid_input');
    await denies(anon(db).query(`select public.report_content('professional', $1, 'spam')`, [q]), DENIED);
  });

  test('rate limit: 10 reports per day', async () => {
    const r = await createUser(db);
    for (let i = 0; i < 10; i++) await report(r, 'professional', await pro(db));
    await tagged(report(r, 'professional', await pro(db)), 'rate_limited');
  });

  test('reports are not readable by their authors or anyone but admins', async () => {
    await denies(user(db, c).query('select * from public.reports'), DENIED);
    await denies(anon(db).query('select * from public.reports'), DENIED);
    const list = (await user(db, admin).query(`select * from public.admin_list_reports('open')`)).rows;
    const mine = list.find((x) => x.target_id === p);
    assert.ok(mine);
    assert.equal(mine.reports_on_target, 2);
    assert.ok(!('reporter_id' in mine), 'the queue does not expose reporters');
  });

  test('admin handles a report: status, note, audit; bad status refused', async () => {
    const id = await report(other, 'professional', await pro(db), 'inappropriate');
    await tagged(user(db, admin).query(`select public.admin_handle_report($1, 'open')`, [id]), 'invalid_input');
    await user(db, admin).query(`select public.admin_handle_report($1, 'actioned', 'retiré')`, [id]);
    const r = (await db.query('select status, handled_by, note from public.reports where id = $1', [id])).rows[0];
    assert.deepEqual([r.status, r.handled_by, r.note], ['actioned', admin, 'retiré']);
    const audit = (await user(db, admin).query('select action from public.admin_audit_log_page(100, 0)')).rows.map((x) => x.action);
    assert.ok(audit.includes('report_actioned'));
    await assert.rejects(user(db, c).query(`select public.admin_handle_report($1, 'dismissed')`, [id]), (e) => e.code === '42501');
  });

  test('a handled report no longer blocks a new one on the same target', async () => {
    const q = await pro(db);
    const id = await report(c, 'professional', q);
    await user(db, admin).query(`select public.admin_handle_report($1, 'dismissed')`, [id]);
    await report(c, 'professional', q, 'abuse');
  });

  test('admin context for a professional report; reading context needs admin', async () => {
    const q = await pro(db);
    const id = await report(c, 'professional', q);
    const ctx = (await user(db, admin).query('select public.admin_report_context($1) as c', [id])).rows[0].c;
    assert.equal(ctx.suspended, false);
    assert.ok(ctx.business_name);
    await assert.rejects(user(db, c).query('select public.admin_report_context($1)', [id]), (e) => e.code === '42501');
  });
});

describe('conversation and review reports', () => {
  let db, admin, cust, pr, conv;
  before(async () => {
    db = await newDb();
    admin = await createUser(db);
    await makeAdmin(db, admin);
    cust = await createUser(db);
    pr = await pro(db);
    const r = (await user(db, cust).query(
      `select public.create_quote_request('Fuite sous évier', 'Une fuite sous le lavabo.', 1::smallint, 11::smallint) as id`)).rows[0].id;
    const o = (await user(db, pr).query('select public.submit_offer($1, 100::numeric) as id', [r])).rows[0].id;
    await user(db, cust).query('select public.accept_offer($1)', [o]);
    conv = (await user(db, cust).query('select public.start_conversation($1) as id', [o])).rows[0].id;
    await user(db, cust).query(`select public.send_message($1, 'Bonjour', null)`, [conv]);
    await user(db, pr).query(`select public.send_message($1, 'Salut', null)`, [conv]);
  });

  test('only members can report a conversation; the admin reads it and the read is audited', async () => {
    const stranger = await createUser(db);
    await assert.rejects(user(db, stranger).query(`select public.report_content('conversation', $1, 'abuse')`, [conv]), (e) => e.code === 'P0002');
    const id = (await user(db, pr).query(`select public.report_content('conversation', $1, 'abuse') as id`, [conv])).rows[0].id;
    const ctx = (await user(db, admin).query('select public.admin_report_context($1) as c', [id])).rows[0].c;
    assert.equal(ctx.messages.length, 2);
    const audit = (await user(db, admin).query('select action from public.admin_audit_log_page(50, 0)')).rows.map((x) => x.action);
    assert.ok(audit.includes('read_conversation'));
  });

  test('reviews: only public reviews by someone else; the admin can hide one (audited)', async () => {
    const q = await pro(db);
    const r = (await user(db, cust).query(
      `select public.create_quote_request('Fuite sous évier', 'Une fuite sous le lavabo.', 1::smallint, 11::smallint) as id`)).rows[0].id;
    const o = (await user(db, q).query('select public.submit_offer($1, 90::numeric) as id', [r])).rows[0].id;
    const b = (await user(db, cust).query('select public.accept_offer($1) as id', [o])).rows[0].id;
    await user(db, q).query('select public.start_booking($1)', [b]);
    await user(db, q).query('select public.mark_booking_done($1)', [b]);
    await user(db, cust).query('select public.confirm_booking_completed($1)', [b]);
    const rv = (await user(db, cust).query('select public.submit_review($1, 1::smallint, $2) as id', [b, 'Nul']).then((x) => x.rows[0].id));
    // the author cannot report their own review
    await assert.rejects(user(db, cust).query(`select public.report_content('review', $1, 'abuse')`, [rv]), (e) => e.code === 'P0002');
    const reporter = await createUser(db);
    const rep = (await user(db, reporter).query(`select public.report_content('review', $1, 'fake') as id`, [rv])).rows[0].id;
    const ctx = (await user(db, admin).query('select public.admin_report_context($1) as c', [rep])).rows[0].c;
    assert.equal(ctx.comment, 'Nul');
    await user(db, admin).query(`select public.admin_set_review_status($1, 'hidden', 'faux avis')`, [rv]);
    assert.equal((await anon(db).query('select id from public.reviews where id = $1', [rv])).rows.length, 0);
    // a hidden review can no longer be reported
    await assert.rejects(user(db, await createUser(db)).query(`select public.report_content('review', $1, 'spam')`, [rv]), (e) => e.code === 'P0002');
    const audit = (await user(db, admin).query('select action from public.admin_audit_log_page(100, 0)')).rows.map((x) => x.action);
    assert.ok(audit.includes('review_hidden'));
  });
});
