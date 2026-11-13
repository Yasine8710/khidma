// Abuse limits not covered by a feature suite, and the upload limits of every
// bucket in one place (#56). The full table lives in docs/SECURITY.md.
import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, user } from './harness.mjs';

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

describe('limits', () => {
  let db;
  before(async () => { db = await newDb(); });

  test('every bucket has a size limit and an image/video/pdf allowlist (reviewed values)', async () => {
    const r = await db.query('select id, public, file_size_limit, allowed_mime_types from storage.buckets order by id');
    const got = Object.fromEntries(r.rows.map((b) => [b.id, [b.public, Number(b.file_size_limit), [...b.allowed_mime_types].sort()]]));
    const img = ['image/jpeg', 'image/png', 'image/webp'];
    assert.deepEqual(got, {
      avatars: [true, 1048576, img],
      'chat-images': [false, 2097152, img],
      'freelance-media': [true, 26214400, [...img, 'video/mp4', 'video/webm'].sort()],
      'payment-proofs': [false, 5242880, ['application/pdf', ...img].sort()],
      portfolio: [true, 2097152, img],
      'request-photos': [false, 2097152, img],
      'verification-docs': [false, 5242880, ['application/pdf', ...img].sort()],
    });
  });

  test('payment orders: at most 10 per professional per 24 hours (cancelling does not reset it)', async () => {
    const p = await pro(db);
    for (let i = 0; i < 10; i += 1) {
      const o = (await user(db, p).query('select * from public.create_payment_order($1, $2)', ['standard', 'bank_transfer'])).rows[0];
      await user(db, p).query('select public.cancel_payment_order($1)', [o.id]);
    }
    await tagged(user(db, p).query('select * from public.create_payment_order($1, $2)', ['plus', 'd17']), 'rate_limited');
    const other = await pro(db);
    assert.ok((await user(db, other).query('select * from public.create_payment_order($1, $2)', ['standard', 'd17'])).rows[0].id);
  });

  test('phone reveals share one budget of 40 per hour across professionals and freelancers', async () => {
    const viewer = await createUser(db);
    const p = await pro(db);
    const f = await pro(db);
    await db.query(`update public.professional_profiles set verification_status = 'verified', verified_at = now() where user_id = $1`, [f]);
    await user(db, f).query('select public.become_freelancer()');
    await user(db, f).query(
      `update public.freelancer_profiles set display_name = 'Sami', headline = 'Developpeur web', primary_category_id = 1,
         bio = 'Sites et applications web depuis dix ans.', is_published = true where user_id = $1`, [f]);
    for (let i = 0; i < 40; i += 1) await user(db, viewer).query('select public.reveal_professional_contact($1)', [p]);
    await tagged(user(db, viewer).query('select public.reveal_freelancer_contact($1)', [f]), 'rate_limited');
  });
});
