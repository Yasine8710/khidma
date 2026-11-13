import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, anon, user, denies, DENIED } from './harness.mjs';

const tagged = (promise, tag) =>
  assert.rejects(promise, (e) => e.code === 'P0001' && e.message === tag, `expected ${tag}`);
const forbidden = (promise) => assert.rejects(promise, (e) => e.code === '42501', 'expected forbidden');

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
// A freelancer whose local profile is NOT published: remote work only.
async function freelancer(db) {
  const id = await pro(db, false);
  await db.query(`update public.professional_profiles set verification_status = 'verified', verified_at = now() where user_id = $1`, [id]);
  await user(db, id).query('select public.become_freelancer()');
  await user(db, id).query(
    `update public.freelancer_profiles set display_name = 'Sami', headline = 'Designer graphique', primary_category_id = 1,
       bio = 'Logos et identites visuelles depuis dix ans.', is_published = true where user_id = $1`, [id]);
  return id;
}
const one = (db, who, sql, ...args) => user(db, who).query(sql, args).then((r) => r.rows[0]);
const remote = (db, who, over = {}) => {
  const a = { title: 'Logo boutique', desc: 'Un logo pour ma boutique de miel.', cat: 1, deliv: 'PNG et SVG', min: 100, max: 300, by: null, links: [], ...over };
  return one(db, who, 'select public.create_remote_request($1, $2, $3::smallint, $4, $5, $6, $7, $8::text[]) as id',
    a.title, a.desc, a.cat, a.deliv, a.min, a.max, a.by, a.links).then((r) => r.id);
};
const offer = (db, who, req, price = 250, days = 5, revisions = 2) =>
  one(db, who, 'select public.submit_remote_offer($1, $2::numeric, $3::smallint, $4::smallint) as id', req, price, days, revisions).then((r) => r.id);
const upload = (db, who, booking, name) =>
  user(db, who).query(`insert into storage.objects (bucket_id, name, owner) values ('deliveries', $1, $2)`, [`${booking}/${name}`, who]);
const status = async (db, b) => (await db.query('select status from public.bookings where id = $1', [b])).rows[0].status;
const outbox = async (db, who, kind) =>
  (await db.query('select id from public.notification_outbox where user_id = $1 and kind = $2', [who, kind])).rows.length;

describe('remote jobs', () => {
  let db, cust, f, localPro, stranger, req, off, booking, conv;
  before(async () => {
    db = await newDb();
    cust = await createUser(db);
    f = await freelancer(db);
    localPro = await pro(db);
    stranger = await createUser(db);
  });

  test('a remote project has no place and only valid links, budget and dates', async () => {
    req = await remote(db, cust, { links: ['https://pinterest.com/board/miel', ' https://exemple.tn '] });
    const row = (await db.query('select * from public.quote_requests where id = $1', [req])).rows[0];
    assert.equal(row.kind, 'remote');
    assert.equal(row.governorate_id, null);
    assert.equal(row.category_id, null);
    assert.deepEqual([...row.reference_links].sort(), ['https://exemple.tn', 'https://pinterest.com/board/miel']);
    for (const bad of [
      { links: ['javascript:alert(1)'] }, { links: ['http://exemple.tn'] }, { links: ['data:text/html,x'] },
      { links: Array.from({ length: 6 }, (_, i) => `https://x${i}.tn`) },
      { min: 300, max: 100 }, { by: '2020-01-01' }, { cat: 9999 },
    ]) {
      await tagged(remote(db, cust, bad), 'invalid_input');
    }
    await denies(anon(db).query(`select public.create_remote_request('Logo', 'Un logo pour ma boutique.', 1::smallint, 'PNG')`), DENIED);
  });

  test('local lists never show remote projects; remote ones have their own lists', async () => {
    const local = (await user(db, localPro).query('select id from public.list_open_requests()')).rows.map((r) => r.id);
    assert.ok(!local.includes(req));
    assert.equal((await user(db, localPro).query('select * from public.get_open_request($1)', [req])).rows.length, 0);
    const mineLocal = (await user(db, cust).query('select id from public.my_quote_requests()')).rows.map((r) => r.id);
    assert.ok(!mineLocal.includes(req));
    const mineRemote = (await user(db, cust).query('select id, deliverables from public.my_remote_requests()')).rows;
    assert.deepEqual(mineRemote.map((r) => r.id), [req]);
    assert.equal(mineRemote[0].deliverables, 'PNG et SVG');
  });

  test('only visible freelancers see and answer remote projects', async () => {
    await forbidden(user(db, localPro).query('select * from public.list_remote_requests()'));
    await forbidden(user(db, localPro).query('select public.submit_remote_offer($1, 100::numeric, 3::smallint, 1::smallint)', [req]));
    // the local offer path cannot be used to slip in either
    await forbidden(user(db, localPro).query('select public.submit_offer($1, 100::numeric)', [req]));
    await forbidden(user(db, stranger).query('select * from public.get_remote_request($1)', [req]));
    const seen = (await user(db, f).query('select * from public.list_remote_requests()')).rows;
    assert.deepEqual(seen.map((r) => r.id), [req]);
    assert.equal(seen[0].customer_id, undefined, 'never who asked');
  });

  test('an offer says price, delivery days and included revisions', async () => {
    await tagged(offer(db, f, req, 250, 0, 2), 'invalid_input');
    await tagged(offer(db, f, req, 250, 5, 21), 'invalid_input');
    off = await offer(db, f, req);
    const seen = (await user(db, cust).query('select price_tnd, estimated_days, revisions from public.quote_offers where id = $1', [off])).rows[0];
    assert.deepEqual({ ...seen, price_tnd: Number(seen.price_tnd) }, { price_tnd: 250, estimated_days: 5, revisions: 2 });
    assert.equal((await user(db, f).query('select my_offer_status from public.get_remote_request($1)', [req])).rows[0].my_offer_status, 'pending');
  });

  test('a local offer cannot carry revisions', async () => {
    const lr = (await user(db, cust).query(`select public.create_quote_request('Fuite sous évier', 'Une fuite sous le lavabo.', 1::smallint, 11::smallint) as id`)).rows[0].id;
    const lo = (await user(db, localPro).query('select public.submit_offer($1, 100::numeric) as id', [lr])).rows[0].id;
    await tagged(db.query('update public.quote_offers set revisions = 1 where id = $1', [lo]), 'invalid_input');
  });

  test('accepted with a freelancer who has no published local profile; chat works', async () => {
    booking = (await one(db, cust, 'select public.accept_offer($1) as id', off)).id;
    conv = (await one(db, cust, 'select public.start_conversation($1) as id', off)).id;
    await user(db, f).query('select public.send_message($1, $2)', [conv, 'Je commence demain']);
    await user(db, f).query('select public.start_booking($1)', [booking]);
    assert.equal(await status(db, booking), 'in_progress');
  });

  test('delivery files are private to the two parties', async () => {
    await upload(db, f, booking, 'logo-v1.png');
    await denies(upload(db, cust, booking, 'x.png'), DENIED);
    await denies(upload(db, stranger, booking, 'x.png'), DENIED);
    await denies(upload(db, localPro, booking, 'x.png'), DENIED);
    const see = async (who) => (await user(db, who).query(`select name from storage.objects where bucket_id = 'deliveries'`)).rows.length;
    assert.equal(await see(f), 1);
    assert.equal(await see(cust), 1);
    assert.equal(await see(stranger), 0);
    assert.equal(await see(localPro), 0);
  });

  test('delivering moves the job to waiting for the customer and tells them', async () => {
    await tagged(user(db, f).query('select public.deliver_booking($1)', [booking]), 'invalid_input');
    await tagged(user(db, f).query('select public.deliver_booking($1, null, $2)', [booking, 'javascript:x']), 'invalid_input');
    await tagged(user(db, f).query('select public.deliver_booking($1, null, null, $2::text[])', [booking, [`${booking}/missing.png`]]), 'invalid_input');
    await forbidden(user(db, cust).query('select public.deliver_booking($1, $2)', [booking, 'moi']));
    await user(db, f).query('select public.deliver_booking($1, $2, $3, $4::text[])',
      [booking, 'Premiere version', 'https://figma.com/file/abc', [`${booking}/logo-v1.png`]]);
    assert.equal(await status(db, booking), 'pending_confirmation');
    assert.equal(await outbox(db, cust, 'job_done'), 1);
    const d = (await user(db, cust).query('select * from public.booking_deliveries($1)', [booking])).rows;
    assert.equal(d.length, 1);
    assert.deepEqual(d[0].paths, [`${booking}/logo-v1.png`]);
    assert.equal(d[0].link, 'https://figma.com/file/abc');
    assert.equal(d[0].revisions_included, 2);
    await assert.rejects(user(db, stranger).query('select * from public.booking_deliveries($1)', [booking]), (e) => e.code === 'P0002');
    const del = await user(db, f).query(`delete from storage.objects where bucket_id = 'deliveries' and name = $1`, [`${booking}/logo-v1.png`]);
    assert.equal(del.affectedRows, 0, 'a delivered file stays');
  });

  test('a file from another job cannot be handed in', async () => {
    const r2 = await remote(db, cust, { title: 'Banniere' });
    const b2 = (await one(db, cust, 'select public.accept_offer($1) as id', await offer(db, f, r2))).id;
    await user(db, f).query('select public.start_booking($1)', [b2]);
    // an unattached file of the first job, handed in for the second
    await upload(db, f, booking, 'extra.png');
    await tagged(user(db, f).query('select public.deliver_booking($1, null, null, $2::text[])', [b2, [`${booking}/extra.png`]]), 'invalid_input');
    const gone = await user(db, f).query(`delete from storage.objects where bucket_id = 'deliveries' and name = $1`, [`${booking}/extra.png`]);
    assert.equal(gone.affectedRows, 1, 'a file never handed in can be removed');
  });

  test('the customer asks for included revisions, no more; each lands in the chat', async () => {
    await forbidden(user(db, f).query('select public.request_revision($1, $2)', [booking, 'moi']));
    await tagged(user(db, cust).query('select public.request_revision($1, $2)', [booking, ' ']), 'invalid_input');
    for (let i = 1; i <= 2; i += 1) {
      await user(db, cust).query('select public.request_revision($1, $2)', [booking, `Revision ${i}: couleurs plus chaudes`]);
      assert.equal(await status(db, booking), 'in_progress');
      await upload(db, f, booking, `logo-v${i + 1}.png`);
      await user(db, f).query('select public.deliver_booking($1, null, null, $2::text[])', [booking, [`${booking}/logo-v${i + 1}.png`]]);
    }
    await tagged(user(db, cust).query('select public.request_revision($1, $2)', [booking, 'Encore une']), 'limit_reached');
    const msgs = (await user(db, f).query('select body from public.messages where conversation_id = $1 and sender_is_customer', [conv])).rows;
    assert.equal(msgs.filter((m) => m.body.startsWith('Revision')).length, 2);
  });

  test('confirming completes the job, the review follows, and no more uploads', async () => {
    await user(db, cust).query('select public.confirm_booking_completed($1)', [booking]);
    assert.equal(await status(db, booking), 'completed');
    assert.ok((await one(db, cust, 'select public.submit_review($1, 5::smallint, $2) as id', booking, 'Parfait')).id);
    await denies(upload(db, f, booking, 'late.png'), DENIED);
    await tagged(user(db, f).query('select public.deliver_booking($1, $2)', [booking, 'encore']), 'invalid_transition');
  });

  test('deleting an account queues the delivery files of its jobs', async () => {
    await user(db, cust).query('select public.delete_my_account()');
    const n = (await db.query(`select count(*)::int as n from public.storage_cleanup_queue where bucket_id = 'deliveries'`)).rows[0].n;
    assert.equal(n, 3);
  });
});
