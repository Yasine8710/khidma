import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, anon, user, anonymousAuthUser, denies, DENIED } from './harness.mjs';

const TAG = 'P0001';
const NOTFOUND = 'P0002';

// Errors raised with a tag message: the SQLSTATE is P0001 and the message is the tag.
const tagged = (promise, tag) =>
  assert.rejects(promise, (e) => e.code === TAG && e.message === tag, `expected ${tag}`);

async function pro(db, { publish = true } = {}) {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  if (publish) {
    await user(db, id).query(
      `update public.professional_profiles
          set business_name = 'Pro ' || left($1::text, 4), primary_category_id = 1,
              description = 'Plombier avec dix ans d experience.', governorate_id = 11,
              contact_phone = '+21620123456', is_published = true
        where user_id = $1`, [id]);
  }
  return id;
}

const ask = (db, who, over = {}) => {
  const a = { title: 'Fuite sous évier', description: 'Une fuite sous le lavabo de la cuisine.', cat: 1, gov: 11, city: null, budget: null, by: null, ...over };
  return user(db, who).query(
    'select public.create_quote_request($1, $2, $3::smallint, $4::smallint, $5::integer, $6::numeric, $7::date) as id',
    [a.title, a.description, a.cat, a.gov, a.city, a.budget, a.by],
  ).then((r) => r.rows[0].id);
};
const offer = (db, who, request, price = 120, message = 'Je peux passer demain', days = null) =>
  user(db, who).query('select public.submit_offer($1, $2::numeric, $3, $4::smallint) as id', [request, price, message, days]).then((r) => r.rows[0].id);
const rpc = (db, who, fn, ...args) =>
  user(db, who).query(`select public.${fn}(${args.map((_, i) => `$${i + 1}`).join(', ')}) as v`, args).then((r) => r.rows[0].v);
const status = async (db, table, id) => (await db.query(`select status from public.${table} where id = $1`, [id])).rows[0].status;

describe('requests and offers', () => {
  let db, cust, other, p1, p2, p3, draftPro;
  before(async () => {
    db = await newDb();
    cust = await createUser(db);
    other = await createUser(db);
    p1 = await pro(db);
    p2 = await pro(db);
    p3 = await pro(db);
    draftPro = await pro(db, { publish: false });
  });

  describe('creating and cancelling a request', () => {
    test('a registered user posts a request; text is trimmed; defaults are open + 14 days', async () => {
      const id = await ask(db, cust, { title: '  Fuite  ', description: '  Une fuite sous le lavabo.  ' });
      const r = (await db.query('select id, category_id, governorate_id, city_id, title, description, budget_tnd, needed_by, status, expires_at, created_at, updated_at from public.quote_requests where id = $1', [id])).rows[0];
      assert.equal(r.title, 'Fuite');
      assert.equal(r.description, 'Une fuite sous le lavabo.');
      assert.equal(r.status, 'open');
      const days = (new Date(r.expires_at) - new Date(r.created_at)) / 86400000;
      assert.ok(days > 13.9 && days < 14.1);
    });

    test('inputs are validated', async () => {
      await assert.rejects(ask(db, cust, { title: 'ab' }), (e) => e.code === '23514');
      await assert.rejects(ask(db, cust, { description: 'court' }), (e) => e.code === '23514');
      await assert.rejects(ask(db, cust, { budget: -1 }), (e) => e.code === '23514');
      await assert.rejects(ask(db, cust, { gov: 99 }), (e) => e.code === '23503');
      await assert.rejects(ask(db, cust, { city: 1, gov: 24 }), (e) => e.code === '23503', 'city must belong to the governorate');
      await tagged(ask(db, cust, { cat: 999 }), 'invalid_input');
      await tagged(ask(db, cust, { by: '2020-01-01' }), 'invalid_input');
    });

    test('anon and anonymous-auth users cannot post', async () => {
      await denies(anon(db).query(`select public.create_quote_request('abc', 'description ok ok', 1::smallint, 11::smallint)`), DENIED);
      await denies(anonymousAuthUser(db, other).query(`select public.create_quote_request('abc', 'description ok ok', 1::smallint, 11::smallint)`), DENIED);
    });

    test('rate limit: 5 per hour, and at most 10 open', async () => {
      const u = await createUser(db);
      for (let i = 0; i < 5; i++) await ask(db, u);
      await tagged(ask(db, u), 'rate_limited');
      await db.query(`update public.quote_requests set created_at = now() - interval '2 hours' where customer_id = $1`, [u]);
      for (let i = 0; i < 5; i++) await ask(db, u);
      await db.query(`update public.quote_requests set created_at = now() - interval '2 hours' where customer_id = $1`, [u]);
      await tagged(ask(db, u), 'limit_reached');
    });

    test('only the owner cancels, only while open; pending offers are declined', async () => {
      const req = await ask(db, other);
      const o = await offer(db, p1, req);
      await assert.rejects(rpc(db, cust, 'cancel_quote_request', req), (e) => e.code === NOTFOUND);
      await rpc(db, other, 'cancel_quote_request', req);
      assert.equal(await status(db, 'quote_requests', req), 'cancelled');
      assert.equal(await status(db, 'quote_offers', o), 'declined');
      await tagged(rpc(db, other, 'cancel_quote_request', req), 'not_open');
    });
  });

  describe('visibility', () => {
    let req, o1, o2;
    before(async () => {
      req = await ask(db, cust);
      o1 = await offer(db, p1, req, 100);
      o2 = await offer(db, p2, req, 90);
    });

    test('the customer sees their request and both offers', async () => {
      assert.equal((await user(db, cust).query('select id, category_id, governorate_id, city_id, title, description, budget_tnd, needed_by, status, expires_at, created_at, updated_at from public.quote_requests where id = $1', [req])).rows.length, 1);
      assert.equal((await user(db, cust).query('select * from public.quote_offers where request_id = $1', [req])).rows.length, 2);
    });

    test('a professional sees only their own offer: never a rival\'s', async () => {
      const r = await user(db, p1).query('select id, professional_id, price_tnd from public.quote_offers where request_id = $1', [req]);
      assert.deepEqual(r.rows.map((x) => x.id), [o1]);
      const r2 = await user(db, p2).query('select id from public.quote_offers where request_id = $1', [req]);
      assert.deepEqual(r2.rows.map((x) => x.id), [o2]);
    });

    test('strangers see nothing; anon sees nothing', async () => {
      assert.equal((await user(db, other).query('select id, category_id, governorate_id, city_id, title, description, budget_tnd, needed_by, status, expires_at, created_at, updated_at from public.quote_requests where id = $1', [req])).rows.length, 0);
      assert.equal((await user(db, other).query('select * from public.quote_offers where request_id = $1', [req])).rows.length, 0);
      await denies(anon(db).query('select id from public.quote_requests'), DENIED);
      await denies(anon(db).query('select * from public.quote_offers'), DENIED);
      await denies(anon(db).query('select * from public.bookings'), DENIED);
    });

    test('a professional who has not offered cannot read the request table (discovery is the RPC)', async () => {
      assert.equal((await user(db, p3).query('select id, category_id, governorate_id, city_id, title, description, budget_tnd, needed_by, status, expires_at, created_at, updated_at from public.quote_requests where id = $1', [req])).rows.length, 0);
      assert.equal((await user(db, p1).query('select id, category_id, governorate_id, city_id, title, description, budget_tnd, needed_by, status, expires_at, created_at, updated_at from public.quote_requests where id = $1', [req])).rows.length, 1, 'once they offered, yes');
    });

    test('clients cannot write the tables or move status directly', async () => {
      await denies(user(db, cust).query(`update public.quote_requests set status = 'awarded' where id = $1`, [req]), DENIED);
      await denies(user(db, p1).query(`update public.quote_offers set status = 'accepted', price_tnd = 1 where id = $1`, [o1]), DENIED);
      await denies(user(db, cust).query(`insert into public.quote_offers (request_id, professional_id, price_tnd) values ($1, $2, 5)`, [req, p3]), DENIED);
      await denies(user(db, cust).query('delete from public.quote_requests where id = $1', [req]), DENIED);
      await denies(user(db, cust).query(`insert into public.bookings (request_id, offer_id, customer_id, professional_id, price_tnd) values ($1, $2, $3, $4, 1)`, [req, o1, cust, p1]), DENIED);
    });

    test('a professional who offered still cannot learn who asked (customer_id is not selectable)', async () => {
      await denies(user(db, p1).query('select customer_id from public.quote_requests where id = $1', [req]), DENIED);
      await denies(user(db, p1).query('select * from public.quote_requests where id = $1', [req]), DENIED);
      await denies(user(db, cust).query('select customer_id from public.quote_requests where id = $1', [req]), DENIED);
      const cols = await db.query(
        `select column_name from information_schema.column_privileges
          where table_schema = 'public' and table_name = 'quote_requests'
            and grantee = 'authenticated' and privilege_type = 'SELECT'`);
      assert.ok(!cols.rows.some((x) => x.column_name === 'customer_id'));
    });

    test('discovery lists open requests without the customer; filters and caps hold', async () => {
      const r = await user(db, p3).query('select * from public.list_open_requests()');
      assert.ok(r.rows.length > 0);
      assert.deepEqual(r.fields.map((f) => f.name).filter((n) => /customer|user/.test(n)), [], 'no identity columns');
      const mine = r.rows.find((x) => x.id === req);
      assert.equal(mine.offers_count, 2);
      assert.equal(mine.my_offer_status, null);
      const seen = await user(db, p1).query('select * from public.list_open_requests()');
      assert.equal(seen.rows.find((x) => x.id === req).my_offer_status, 'pending');
      assert.equal((await user(db, p3).query('select * from public.list_open_requests(2::smallint)')).rows.length, 0, 'category filter');
      assert.equal((await user(db, p3).query('select * from public.list_open_requests(null, 12::smallint)')).rows.length, 0, 'governorate filter');
    });

    test('discovery never lists a professional\'s own requests, expired or closed ones', async () => {
      const mineAsCustomer = await ask(db, p3);
      assert.ok(!(await user(db, p3).query('select * from public.list_open_requests()')).rows.some((x) => x.id === mineAsCustomer));
      const old = await ask(db, other);
      await db.query(`update public.quote_requests set expires_at = now() - interval '1 minute' where id = $1`, [old]);
      assert.ok(!(await user(db, p3).query('select * from public.list_open_requests()')).rows.some((x) => x.id === old));
      await rpc(db, other, 'cancel_quote_request', old).catch(() => {});
    });

    test('only published professionals can discover or offer', async () => {
      await denies(user(db, draftPro).query('select * from public.list_open_requests()'), DENIED);
      await denies(user(db, cust).query('select * from public.list_open_requests()'), DENIED);
      await denies(user(db, draftPro).query('select public.submit_offer($1, 50::numeric)', [req]), DENIED);
      await denies(user(db, draftPro).query('select * from public.get_open_request($1)', [req]), DENIED);
    });

    test('get_open_request returns one request, still visible after the professional offered', async () => {
      const r = await user(db, p3).query('select * from public.get_open_request($1)', [req]);
      assert.equal(r.rows.length, 1);
      assert.equal((await user(db, cust).query('select * from public.get_open_request($1)', [req]).catch(() => ({ rows: [] }))).rows.length, 0);
    });
  });

  describe('offers', () => {
    let req;
    before(async () => {
      req = await ask(db, cust);
    });

    test('submit, then update the pending offer in place', async () => {
      const a = await offer(db, p1, req, 100, 'Premier prix');
      const b = await offer(db, p1, req, 80, '  Meilleur prix  ', 3);
      assert.equal(a, b, 'one offer per professional per request');
      const row = (await db.query('select * from public.quote_offers where id = $1', [a])).rows[0];
      assert.equal(Number(row.price_tnd), 80);
      assert.equal(row.message, 'Meilleur prix');
      assert.equal(row.estimated_days, 3);
    });

    test('validation: price range, no own request, open and not expired', async () => {
      await assert.rejects(offer(db, p2, req, 0.5), (e) => e.code === TAG && e.message === 'invalid_input');
      await assert.rejects(offer(db, p2, req, 2000000), (e) => e.code === TAG && e.message === 'invalid_input');
      const mine = await ask(db, p3);
      await tagged(offer(db, p3, mine), 'own_request');
      await assert.rejects(user(db, p2).query('select public.submit_offer($1, 10::numeric)', ['00000000-0000-0000-0000-000000000000']), (e) => e.code === NOTFOUND);
      const stale = await ask(db, other);
      await db.query(`update public.quote_requests set expires_at = now() - interval '1 minute' where id = $1`, [stale]);
      await tagged(offer(db, p2, stale), 'expired');
    });

    test('withdraw: only the owner, only while pending; may re-offer after withdrawing', async () => {
      const id = await offer(db, p2, req, 70);
      await assert.rejects(rpc(db, p3, 'withdraw_offer', id), (e) => e.code === NOTFOUND);
      await rpc(db, p2, 'withdraw_offer', id);
      assert.equal(await status(db, 'quote_offers', id), 'withdrawn');
      await tagged(rpc(db, p2, 'withdraw_offer', id), 'invalid_transition');
      assert.equal(await offer(db, p2, req, 65), id, 're-offering revives the same offer');
      assert.equal(await status(db, 'quote_offers', id), 'pending');
    });

    test('withdrawing does not dodge the 50-offer limit: revival counts too', async () => {
      const busy = await pro(db);
      const mine = [];
      for (let i = 0; i < 51; i++) {
        const asker = await createUser(db);
        mine.push(await ask(db, asker));
      }
      const offers = [];
      for (let i = 0; i < 50; i++) offers.push(await offer(db, busy, mine[i]));
      await rpc(db, busy, 'withdraw_offer', offers[0]);
      await offer(db, busy, mine[50]); // fills the freed slot: 50 pending again
      await tagged(offer(db, busy, mine[0], 77), 'limit_reached');
      assert.equal(await status(db, 'quote_offers', offers[0]), 'withdrawn');
    });

    test('a declined offer cannot be revived by the professional', async () => {
      const id = await offer(db, p3, req, 60);
      await rpc(db, cust, 'decline_offer', id);
      assert.equal(await status(db, 'quote_offers', id), 'declined');
      await tagged(offer(db, p3, req, 55), 'offer_closed');
      await tagged(rpc(db, cust, 'decline_offer', id), 'invalid_transition');
    });

    test('only the request owner declines', async () => {
      const id = (await db.query('select id from public.quote_offers where request_id = $1 and professional_id = $2', [req, p1])).rows[0].id;
      await assert.rejects(rpc(db, other, 'decline_offer', id), (e) => e.code === NOTFOUND);
      await assert.rejects(rpc(db, p1, 'decline_offer', id), (e) => e.code === NOTFOUND);
    });

    test('no new offers on a cancelled request', async () => {
      const r = await ask(db, other);
      await rpc(db, other, 'cancel_quote_request', r);
      await tagged(offer(db, p1, r), 'not_open');
    });

    test('at most 50 pending offers per professional', async () => {
      const busy = await pro(db);
      const askers = [];
      for (let i = 0; i < 10; i++) askers.push(await createUser(db));
      let n = 0;
      for (const a of askers) {
        for (let k = 0; k < 5; k++) {
          const r = await ask(db, a);
          await db.query(`update public.quote_requests set created_at = now() - interval '2 hours' where id = $1`, [r]);
          await offer(db, busy, r);
          n++;
        }
      }
      assert.equal(n, 50);
      const extra = await ask(db, await createUser(db));
      await tagged(offer(db, busy, extra), 'limit_reached');
    });
  });

  describe('accepting an offer', () => {
    let req, oa, ob, oc, booking;
    before(async () => {
      req = await ask(db, cust, { title: 'Chauffe-eau en panne' });
      oa = await offer(db, p1, req, 150);
      ob = await offer(db, p2, req, 130);
      oc = await offer(db, p3, req, 170);
    });

    test('accepting awards the request, declines the rest and creates a booking at the offer price', async () => {
      await assert.rejects(rpc(db, other, 'accept_offer', ob), (e) => e.code === NOTFOUND, 'not their request');
      await assert.rejects(rpc(db, p2, 'accept_offer', ob), (e) => e.code === NOTFOUND, 'a professional cannot accept');
      booking = await rpc(db, cust, 'accept_offer', ob);
      assert.equal(await status(db, 'quote_requests', req), 'awarded');
      assert.equal(await status(db, 'quote_offers', ob), 'accepted');
      assert.equal(await status(db, 'quote_offers', oa), 'declined');
      assert.equal(await status(db, 'quote_offers', oc), 'declined');
      const b = (await db.query('select * from public.bookings where id = $1', [booking])).rows[0];
      assert.equal(b.status, 'scheduled');
      assert.equal(Number(b.price_tnd), 130);
      assert.equal(b.customer_id, cust);
      assert.equal(b.professional_id, p2);
    });

    test('a second accept (or a late cancel) fails: only one winner', async () => {
      await tagged(rpc(db, cust, 'accept_offer', oa), 'not_open');
      await tagged(rpc(db, cust, 'accept_offer', ob), 'not_open');
      await tagged(rpc(db, cust, 'cancel_quote_request', req), 'not_open');
      assert.equal((await db.query('select count(*)::int as n from public.bookings where request_id = $1', [req])).rows[0].n, 1);
    });

    test('the winner and the customer see the booking; the losers do not', async () => {
      assert.equal((await user(db, cust).query('select * from public.bookings')).rows.some((b) => b.id === booking), true);
      assert.equal((await user(db, p2).query('select * from public.bookings')).rows.some((b) => b.id === booking), true);
      assert.equal((await user(db, p1).query('select * from public.bookings')).rows.some((b) => b.id === booking), false);
      assert.equal((await user(db, other).query('select * from public.bookings')).rows.length, 0);
    });

    test('an offer withdrawn first cannot be accepted', async () => {
      const asker = await createUser(db);
      const r = await ask(db, asker);
      const o = await offer(db, p1, r);
      await rpc(db, p1, 'withdraw_offer', o);
      await tagged(rpc(db, asker, 'accept_offer', o), 'offer_closed');
      assert.equal(await status(db, 'quote_requests', r), 'open');
    });

    test('an expired request cannot be accepted', async () => {
      const asker = await createUser(db);
      const r = await ask(db, asker);
      const o = await offer(db, p1, r);
      await db.query(`update public.quote_requests set expires_at = now() - interval '1 minute' where id = $1`, [r]);
      await tagged(rpc(db, asker, 'accept_offer', o), 'expired');
    });

    test('an offer from a professional who unpublished meanwhile cannot be accepted', async () => {
      const asker = await createUser(db);
      const r = await ask(db, asker);
      const o = await offer(db, p3, r);
      await user(db, p3).query('update public.professional_profiles set is_published = false where user_id = $1', [p3]);
      await tagged(rpc(db, asker, 'accept_offer', o), 'offer_closed');
      await user(db, p3).query('update public.professional_profiles set is_published = true where user_id = $1', [p3]);
    });

    test('the lock that makes accept atomic is in the function', async () => {
      const src = (await db.query(`select pg_get_functiondef(p.oid) as d from pg_proc p where p.proname = 'accept_offer'`)).rows[0].d;
      assert.match(src, /from public\.quote_requests where id = o\.request_id for update/);
      assert.match(src, /from public\.quote_offers where id = p_offer for update/);
    });
  });

  describe('booking lifecycle', () => {
    let booking;
    before(async () => {
      const r = await ask(db, cust);
      const o = await offer(db, p1, r, 99);
      booking = await rpc(db, cust, 'accept_offer', o);
    });

    test('scheduled -> in progress -> pending confirmation -> completed, by the right party', async () => {
      await assert.rejects(rpc(db, cust, 'start_booking', booking), (e) => e.code === DENIED, 'the customer cannot start');
      await assert.rejects(rpc(db, other, 'start_booking', booking), (e) => e.code === NOTFOUND);
      await tagged(rpc(db, p1, 'mark_booking_done', booking), 'invalid_transition');
      await rpc(db, p1, 'start_booking', booking);
      assert.equal(await status(db, 'bookings', booking), 'in_progress');
      assert.ok((await db.query('select started_at from public.bookings where id = $1', [booking])).rows[0].started_at);
      await tagged(rpc(db, p1, 'start_booking', booking), 'invalid_transition');
      await tagged(rpc(db, cust, 'confirm_booking_completed', booking), 'invalid_transition');
      await assert.rejects(rpc(db, cust, 'mark_booking_done', booking), (e) => e.code === DENIED, 'the customer cannot mark done');
      await rpc(db, p1, 'mark_booking_done', booking);
      assert.equal(await status(db, 'bookings', booking), 'pending_confirmation');
      await assert.rejects(rpc(db, p1, 'confirm_booking_completed', booking), (e) => e.code === DENIED, 'the professional cannot confirm their own job');
      await rpc(db, cust, 'confirm_booking_completed', booking);
      assert.equal(await status(db, 'bookings', booking), 'completed');
      const b = (await db.query('select * from public.bookings where id = $1', [booking])).rows[0];
      assert.ok(b.done_at && b.completed_at);
    });

    test('a completed booking is final', async () => {
      for (const fn of ['start_booking', 'mark_booking_done', 'confirm_booking_completed', 'cancel_booking']) {
        await assert.rejects(rpc(db, fn === 'confirm_booking_completed' ? cust : p1, fn, booking), (e) => e.code === TAG && e.message === 'invalid_transition', fn);
      }
    });

    test('either party cancels while scheduled or in progress; it records who', async () => {
      const mk = async () => {
        const r = await ask(db, await createUser(db));
        return rpc(db, (await db.query('select customer_id from public.quote_requests where id = $1', [r])).rows[0].customer_id, 'accept_offer', await offer(db, p2, r));
      };
      const b1 = await mk();
      await assert.rejects(rpc(db, other, 'cancel_booking', b1), (e) => e.code === NOTFOUND);
      await rpc(db, p2, 'cancel_booking', b1);
      const row = (await db.query('select * from public.bookings where id = $1', [b1])).rows[0];
      assert.equal(row.status, 'cancelled');
      assert.equal(row.cancelled_by, p2);
      assert.ok(row.cancelled_at);
      await tagged(rpc(db, p2, 'cancel_booking', b1), 'invalid_transition');

      const b2 = await mk();
      await rpc(db, p2, 'start_booking', b2);
      const customer2 = (await db.query('select customer_id from public.bookings where id = $1', [b2])).rows[0].customer_id;
      await rpc(db, customer2, 'cancel_booking', b2);
      assert.equal(await status(db, 'bookings', b2), 'cancelled');
    });

    test('cancelling is not possible once the work is awaiting confirmation', async () => {
      const cu = await createUser(db);
      const r = await ask(db, cu);
      const b = await rpc(db, cu, 'accept_offer', await offer(db, p3, r));
      await rpc(db, p3, 'start_booking', b);
      await rpc(db, p3, 'mark_booking_done', b);
      await tagged(rpc(db, cu, 'cancel_booking', b), 'invalid_transition');
    });
  });

  describe('housekeeping and account deletion', () => {
    test('expire_stale_requests expires old open requests and declines their pending offers; closed to clients', async () => {
      const c = await createUser(db);
      const r = await ask(db, c);
      const o = await offer(db, p1, r);
      await db.query(`update public.quote_requests set expires_at = now() - interval '1 minute' where id = $1`, [r]);
      await denies(user(db, c).query('select public.expire_stale_requests()'), DENIED);
      await denies(anon(db).query('select public.expire_stale_requests()'), DENIED);
      const n = (await db.query('select public.expire_stale_requests() as n')).rows[0].n;
      assert.ok(n >= 1);
      assert.equal(await status(db, 'quote_requests', r), 'expired');
      assert.equal(await status(db, 'quote_offers', o), 'declined');
    });

    test('housekeeping locks requests before offers (same order as cancel and accept)', async () => {
      const src = (await db.query(`select pg_get_functiondef(p.oid) as d from pg_proc p where p.proname = 'expire_stale_requests'`)).rows[0].d;
      assert.ok(src.indexOf('for update') < src.indexOf('update public.quote_offers'));
    });

    test('a professional who wins and then leaves does not strand the request as awarded', async () => {
      const winner = await pro(db);
      const c = await createUser(db);
      const r = await ask(db, c);
      await rpc(db, c, 'accept_offer', await offer(db, winner, r));
      await user(db, winner).query('select public.delete_my_account()');
      assert.equal(await status(db, 'quote_requests', r), 'cancelled');
      assert.equal((await db.query('select count(*)::int as n from public.bookings where request_id = $1', [r])).rows[0].n, 0);
    });

    test('the internal step helper is not callable by clients', async () => {
      await denies(user(db, p1).query(`select public._booking_step($1, array['scheduled'], 'completed', true)`, ['00000000-0000-0000-0000-000000000000']), DENIED);
    });

    test('deleting an account removes its requests, offers and bookings', async () => {
      const c = await createUser(db);
      const r = await ask(db, c);
      const o = await offer(db, p1, r);
      await rpc(db, c, 'accept_offer', o);
      await user(db, c).query('select public.delete_my_account()');
      for (const [t, col] of [['quote_requests', 'customer_id'], ['bookings', 'customer_id']]) {
        assert.equal((await db.query(`select count(*)::int as n from public.${t} where ${col} = $1`, [c])).rows[0].n, 0, t);
      }
      assert.equal((await db.query('select count(*)::int as n from public.quote_offers where id = $1', [o])).rows[0].n, 0);
      const gone = await pro(db);
      const c2 = await createUser(db);
      const r2 = await ask(db, c2);
      await offer(db, gone, r2);
      await user(db, gone).query('select public.delete_my_account()');
      assert.equal((await db.query('select count(*)::int as n from public.quote_offers where professional_id = $1', [gone])).rows[0].n, 0);
    });
  });
});
