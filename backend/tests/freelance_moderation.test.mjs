import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, makeAdmin, anon, user, denies, DENIED } from './harness.mjs';

const tagged = (promise, tag) =>
  assert.rejects(promise, (e) => e.code === 'P0001' && e.message === tag, `expected ${tag}`);
const notFound = (promise) => assert.rejects(promise, (e) => e.code === 'P0002', 'expected not found');

async function freelancer(db) {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  await user(db, id).query(
    `update public.professional_profiles
        set business_name = 'Pro ' || left($1::text, 4), primary_category_id = 1,
            description = 'Plombier avec dix ans d experience.', governorate_id = 11,
            contact_phone = '+21620123456', is_published = true
      where user_id = $1`, [id]);
  await db.query(`update public.professional_profiles set verification_status = 'verified', verified_at = now() where user_id = $1`, [id]);
  await user(db, id).query('select public.become_freelancer()');
  await user(db, id).query(
    `update public.freelancer_profiles set display_name = 'Sami', headline = 'Developpeur web', primary_category_id = 1,
       bio = 'Sites et applications web depuis dix ans.', is_published = true where user_id = $1`, [id]);
  return id;
}
const visible = async (client, id) =>
  (await client.query('select user_id from public.freelancer_profiles where user_id = $1', [id])).rows.length === 1;
const outbox = async (db, who, kind) =>
  (await db.query('select payload from public.notification_outbox where user_id = $1 and kind = $2', [who, kind])).rows;

describe('freelance moderation', () => {
  let db, admin, f, reporter, rep;
  before(async () => {
    db = await newDb();
    admin = await createUser(db);
    await makeAdmin(db, admin);
    f = await freelancer(db);
    reporter = await createUser(db);
    rep = (await user(db, reporter).query('select public.report_content($1, $2, $3) as id', ['freelancer', f, 'fake'])).rows[0].id;
  });

  test('only admins hold or release a listing', async () => {
    await denies(user(db, f).query('select public.admin_hold_freelancer($1, $2)', [f, 'x']), DENIED);
    await denies(user(db, reporter).query('select public.admin_release_freelancer($1)', [f]), DENIED);
    await denies(anon(db).query('select public.admin_hold_freelancer($1, $2)', [f, 'x']), DENIED);
  });

  test('a reason is required; the report must be about that listing', async () => {
    await tagged(user(db, admin).query('select public.admin_hold_freelancer($1, $2)', [f, '  ']), 'invalid_input');
    const other = await freelancer(db);
    await notFound(user(db, admin).query('select public.admin_hold_freelancer($1, $2, $3)', [other, 'Plagiat', rep]));
  });

  test('holding from a report: hidden, reason shown to the owner only, report closed, both told', async () => {
    await user(db, admin).query('select public.admin_hold_freelancer($1, $2, $3)', [f, 'Portfolio copie d un autre studio', rep]);
    assert.equal(await visible(anon(db), f), false);
    assert.equal(await visible(user(db, reporter), f), false);
    const mine = (await user(db, f).query('select is_published, admin_hold_reason from public.freelancer_profiles where user_id = $1', [f])).rows[0];
    assert.equal(mine.is_published, false);
    assert.equal(mine.admin_hold_reason, 'Portfolio copie d un autre studio');
    await denies(anon(db).query('select admin_hold_reason from public.freelancer_profiles'), DENIED);
    assert.equal((await db.query('select status from public.reports where id = $1', [rep])).rows[0].status, 'actioned');
    assert.equal((await outbox(db, reporter, 'report_actioned')).length, 1);
    assert.equal((await outbox(db, f, 'listing_held')).length, 1);
    const audit = (await db.query(`select count(*)::int as n from public.admin_audit_log where action = 'freelancer_held' and target_id = $1`, [f])).rows[0].n;
    assert.equal(audit, 1);
    // the local professional profile is untouched
    assert.equal((await db.query('select is_published from public.professional_profiles where user_id = $1', [f])).rows[0].is_published, true);
  });

  test('while held, the owner cannot republish or clear the reason', async () => {
    await tagged(user(db, f).query('update public.freelancer_profiles set is_published = true where user_id = $1', [f]), 'on_hold');
    await denies(user(db, f).query('update public.freelancer_profiles set admin_hold_reason = null where user_id = $1', [f]), DENIED);
  });

  test('releasing lets the owner publish again and tells them', async () => {
    await user(db, admin).query('select public.admin_release_freelancer($1, $2)', [f, 'Corrige']);
    assert.equal((await outbox(db, f, 'listing_released')).length, 1);
    await user(db, f).query('update public.freelancer_profiles set is_published = true where user_id = $1', [f]);
    assert.equal(await visible(anon(db), f), true);
    await notFound(user(db, admin).query('select public.admin_release_freelancer($1)', [f]));
  });

  test('the report context shows the hold', async () => {
    const r2 = (await user(db, reporter).query('select public.report_content($1, $2, $3) as id', ['freelancer', f, 'scam'])).rows[0].id;
    await user(db, admin).query('select public.admin_hold_freelancer($1, $2)', [f, 'Arnaque']);
    const ctx = (await user(db, admin).query('select public.admin_report_context($1) as c', [r2])).rows[0].c;
    assert.equal(ctx.admin_hold_reason, 'Arnaque');
  });
});
