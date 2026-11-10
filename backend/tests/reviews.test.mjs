import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, makeAdmin, anon, user, anonymousAuthUser, denies, DENIED } from './harness.mjs';

const tagged = (promise, tag) =>
  assert.rejects(promise, (e) => e.code === 'P0001' && e.message === tag, `expected ${tag}`);

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
const ask = (db, who) =>
  user(db, who).query(`select public.create_quote_request('Fuite sous évier', 'Une fuite sous le lavabo.', 1::smallint, 11::smallint) as id`).then((r) => r.rows[0].id);

/** A booking taken all the way to `completed` (or stopped earlier). */
async function job(db, customer, professional, upTo = 'completed') {
  const r = await ask(db, customer);
  const o = (await user(db, professional).query('select public.submit_offer($1, 100::numeric) as id', [r])).rows[0].id;
  const b = (await user(db, customer).query('select public.accept_offer($1) as id', [o])).rows[0].id;
  if (upTo === 'scheduled') return b;
  await user(db, professional).query('select public.start_booking($1)', [b]);
  if (upTo === 'in_progress') return b;
  await user(db, professional).query('select public.mark_booking_done($1)', [b]);
  if (upTo === 'pending_confirmation') return b;
  await user(db, customer).query('select public.confirm_booking_completed($1)', [b]);
  return b;
}
const review = (db, who, booking, rating = 5, comment = 'Très bien') =>
  user(db, who).query('select public.submit_review($1, $2::smallint, $3) as id', [booking, rating, comment]).then((r) => r.rows[0].id);
const rating = async (db, p) => (await db.query('select rating_avg::float as a, review_count as n from public.professional_profiles where user_id = $1', [p])).rows[0];

describe('reviews', () => {
  let db, cust, p1, p2, admin;
  before(async () => {
    db = await newDb();
    cust = await createUser(db);
    p1 = await pro(db);
    p2 = await pro(db);
    admin = await createUser(db);
    await makeAdmin(db, admin);
  });

  test('only after the job is completed, and only by the two people on it', async () => {
    for (const stage of ['scheduled', 'in_progress', 'pending_confirmation']) {
      const b = await job(db, await createUser(db), p1, stage);
      const c = (await db.query('select customer_id from public.bookings where id = $1', [b])).rows[0].customer_id;
      await tagged(review(db, c, b), 'not_completed');
      await tagged(review(db, p1, b), 'not_completed');
    }
    const b = await job(db, cust, p1);
    await assert.rejects(review(db, p2, b), (e) => e.code === 'P0002', 'another professional');
    await assert.rejects(review(db, await createUser(db), b), (e) => e.code === 'P0002', 'a stranger');
    await denies(anon(db).query('select public.submit_review($1, 5::smallint)', [b]), DENIED);
    await denies(anonymousAuthUser(db, cust).query('select public.submit_review($1, 5::smallint)', [b]), DENIED);
    await review(db, cust, b, 4, 'Bon travail');
  });

  test('one review per person per job; both sides can review', async () => {
    const b = await job(db, cust, p1);
    await review(db, cust, b, 5);
    await tagged(review(db, cust, b, 1), 'already_reviewed');
    await review(db, p1, b, 3, 'Client sympathique');
    await tagged(review(db, p1, b, 3), 'already_reviewed');
    const mine = (await user(db, cust).query('select * from public.my_reviewed_bookings()')).rows.map((r) => r.booking_id);
    assert.ok(mine.includes(b));
    assert.ok(!(await user(db, p2).query('select * from public.my_reviewed_bookings()')).rows.some((r) => r.booking_id === b));
  });

  test('rating and comment are validated', async () => {
    const b = await job(db, await createUser(db), p2);
    const c = (await db.query('select customer_id from public.bookings where id = $1', [b])).rows[0].customer_id;
    await assert.rejects(user(db, c).query('select public.submit_review($1, 0::smallint)', [b]), (e) => e.message === 'invalid_input');
    await assert.rejects(user(db, c).query('select public.submit_review($1, 6::smallint)', [b]), (e) => e.message === 'invalid_input');
    await assert.rejects(user(db, c).query('select public.submit_review($1, 5::smallint, $2)', [b, 'x'.repeat(1001)]), (e) => e.message === 'invalid_input');
    const id = await review(db, c, b, 5, '   ');
    assert.equal((await db.query('select comment from public.reviews where id = $1', [id])).rows[0].comment, null, 'a blank comment is no comment');
  });

  test('the average and count of a professional follow their published reviews, to one decimal', async () => {
    const pr = await pro(db);
    assert.deepEqual(await rating(db, pr), { a: 0, n: 0 });
    const ids = [];
    for (const stars of [5, 4, 4]) {
      const c = await createUser(db);
      const b = await job(db, c, pr);
      ids.push(await review(db, c, b, stars));
    }
    assert.deepEqual(await rating(db, pr), { a: 4.3, n: 3 });
    // a review by the professional about the customer does not move their own rating
    const c2 = await createUser(db);
    const b2 = await job(db, c2, pr);
    await review(db, pr, b2, 1, 'retard de paiement');
    assert.deepEqual(await rating(db, pr), { a: 4.3, n: 3 });
    // hiding one removes it from the average; unhiding brings it back
    await user(db, admin).query('select public.admin_set_review_status($1, $2, $3)', [ids[0], 'hidden', 'insulte']);
    assert.deepEqual(await rating(db, pr), { a: 4, n: 2 });
    await user(db, admin).query('select public.admin_set_review_status($1, $2)', [ids[0], 'published']);
    assert.deepEqual(await rating(db, pr), { a: 4.3, n: 3 });
  });

  test('clients cannot change ratings or write reviews directly', async () => {
    const b = await job(db, cust, p2);
    await denies(user(db, cust).query(`insert into public.reviews (booking_id, author_id, subject_id, rating) values ($1, $2, $3, 5)`, [b, cust, p2]), DENIED);
    await denies(user(db, p2).query('update public.professional_profiles set rating_avg = 5, review_count = 999'), DENIED);
    await denies(user(db, cust).query(`update public.reviews set rating = 1`), DENIED);
    await denies(user(db, cust).query('delete from public.reviews'), DENIED);
  });

  test('public reads: rating, comment, date; never who wrote it or which job', async () => {
    const pr = await pro(db);
    const c = await createUser(db);
    const b = await job(db, c, pr);
    await review(db, c, b, 5, 'Parfait');
    const open = await anon(db).query('select id, subject_id, rating, comment, status, reviewed_month, seq from public.reviews where subject_id = $1', [pr]);
    assert.equal(open.rows.length, 1);
    await denies(anon(db).query('select author_id from public.reviews'), DENIED);
    await denies(anon(db).query('select booking_id from public.reviews'), DENIED);
    await denies(user(db, c).query('select author_id from public.reviews'), DENIED);
    await denies(anon(db).query('select moderation_note from public.reviews'), DENIED);
    await denies(anon(db).query('select created_at from public.reviews'), DENIED);
    await denies(anon(db).query('select about_professional from public.reviews'), DENIED);
    const cols = await db.query(`select column_name from information_schema.column_privileges where table_schema = 'public' and table_name = 'reviews' and grantee = 'anon' and privilege_type = 'SELECT'`);
    assert.deepEqual(cols.rows.map((x) => x.column_name).sort(), ['comment', 'id', 'rating', 'reviewed_month', 'seq', 'status', 'subject_id']);
  });

  test('a professional\'s review of a customer is never public (not even the customer\'s id)', async () => {
    const c = await createUser(db);
    const b = await job(db, c, p1);
    const id = await review(db, p1, b, 1, 'client difficile');
    assert.equal((await anon(db).query('select id from public.reviews where id = $1', [id])).rows.length, 0);
    assert.equal((await anon(db).query('select id from public.reviews where subject_id = $1', [c])).rows.length, 0);
    assert.equal((await user(db, c).query('select id from public.reviews where id = $1', [id])).rows.length, 0);
    assert.equal((await user(db, p2).query('select id from public.reviews where subject_id = $1', [c])).rows.length, 0);
  });

  test('the public sees the month, not the exact time', async () => {
    const pr = await pro(db);
    const c = await createUser(db);
    await review(db, c, await job(db, c, pr), 4);
    const r = (await anon(db).query('select reviewed_month from public.reviews where subject_id = $1', [pr])).rows[0];
    assert.equal(new Date(r.reviewed_month).getUTCDate(), 1, 'first of the month');
  });

  test('the same pair cannot farm ratings: at most 3 reviews from one author about one subject', async () => {
    const pr = await pro(db);
    const c = await createUser(db);
    for (let i = 0; i < 3; i++) await review(db, c, await job(db, c, pr), 5);
    const b4 = await job(db, c, pr);
    await tagged(review(db, c, b4, 5), 'review_limit');
    assert.deepEqual(await rating(db, pr), { a: 5, n: 3 });
    // other customers are unaffected
    const c2 = await createUser(db);
    await review(db, c2, await job(db, c2, pr), 3);
    assert.deepEqual(await rating(db, pr), { a: 4.5, n: 4 });
  });

  test('the recount is serialized per professional (a lock precedes the aggregate)', async () => {
    const src = (await db.query(`select pg_get_functiondef(p.oid) as d from pg_proc p where p.proname = '_refresh_professional_rating'`)).rows[0].d;
    assert.ok(src.indexOf('pg_advisory_xact_lock') < src.indexOf('update public.professional_profiles'));
  });

  test('hidden reviews are not readable by the public', async () => {
    const pr = await pro(db);
    const c = await createUser(db);
    const b = await job(db, c, pr);
    const id = await review(db, c, b, 1, 'abusif');
    await user(db, admin).query('select public.admin_set_review_status($1, $2, $3)', [id, 'hidden', 'abus']);
    assert.equal((await anon(db).query('select id from public.reviews where id = $1', [id])).rows.length, 0);
    assert.equal((await user(db, pr).query('select id from public.reviews where id = $1', [id])).rows.length, 0);
  });

  test('only an admin moderates, with valid statuses', async () => {
    const pr = await pro(db);
    const c = await createUser(db);
    const b = await job(db, c, pr);
    const id = await review(db, c, b, 2);
    await denies(user(db, c).query('select public.admin_set_review_status($1, $2)', [id, 'hidden']), DENIED);
    await denies(user(db, pr).query('select public.admin_set_review_status($1, $2)', [id, 'hidden']), DENIED);
    await denies(anon(db).query('select public.admin_set_review_status($1, $2)', [id, 'hidden']), DENIED);
    await assert.rejects(user(db, admin).query('select public.admin_set_review_status($1, $2)', [id, 'deleted']), (e) => e.message === 'invalid_input');
    await assert.rejects(user(db, admin).query('select public.admin_set_review_status($1, $2)', ['00000000-0000-0000-0000-000000000000', 'hidden']), (e) => e.code === 'P0002');
  });

  test('deleting an account removes its reviews and recomputes the average', async () => {
    const pr = await pro(db);
    const keep = await createUser(db);
    const leave = await createUser(db);
    await review(db, keep, await job(db, keep, pr), 5);
    await review(db, leave, await job(db, leave, pr), 1);
    assert.deepEqual(await rating(db, pr), { a: 3, n: 2 });
    await user(db, leave).query('select public.delete_my_account()');
    assert.deepEqual(await rating(db, pr), { a: 5, n: 1 }, 'the leaving person\'s review is gone from the average');
    // a leaving professional takes the reviews about them with them
    const gone = await pro(db);
    const c = await createUser(db);
    await review(db, c, await job(db, c, gone), 4);
    await user(db, gone).query('select public.delete_my_account()');
    assert.equal((await db.query('select count(*)::int as n from public.reviews where subject_id = $1', [gone])).rows[0].n, 0);
  });

  test('the rating trigger never runs for a customer subject (no professional row)', async () => {
    const c = await createUser(db);
    const b = await job(db, c, p1);
    await review(db, p1, b, 2);
    assert.equal((await db.query('select count(*)::int as n from public.professional_profiles where user_id = $1', [c])).rows[0].n, 0);
  });
});
