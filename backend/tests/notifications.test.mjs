import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, anon, user, as, anonymousAuthUser, denies, DENIED } from './harness.mjs';

const service = (db) => as(db, 'service_role');
const tok = (n) => `fcm-token-${String(n).padStart(4, '0')}-abcdefghijklmnopqrstuvwxyz`;

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
const offer = (db, who, request) => user(db, who).query('select public.submit_offer($1, 100::numeric) as id', [request]).then((r) => r.rows[0].id);
const outbox = async (db, who) => (await db.query('select * from public.notification_outbox where user_id = $1 order by id', [who])).rows;
const kinds = async (db, who) => (await outbox(db, who)).map((r) => r.kind);

describe('notification outbox', () => {
  let db, cust, p1, p2;
  before(async () => {
    db = await newDb();
    cust = await createUser(db);
    p1 = await pro(db);
    p2 = await pro(db);
  });

  test('a new offer queues one notification for the customer, with ids only', async () => {
    const r = await ask(db, cust);
    const o = await offer(db, p1, r);
    const rows = (await outbox(db, cust)).filter((x) => x.kind === 'offer_received');
    assert.equal(rows.length, 1);
    assert.deepEqual(Object.keys(rows[0].payload).sort(), ['offer_id', 'request_id']);
    assert.equal(rows[0].payload.offer_id, o);
    assert.equal(rows[0].category, 'offers');
    // updating the pending offer does not queue another
    await user(db, p1).query('select public.submit_offer($1, 90::numeric)', [r]);
    assert.equal((await outbox(db, cust)).filter((x) => x.kind === 'offer_received').length, 1);
    assert.equal((await outbox(db, p1)).length, 0, 'nothing for the author');
  });

  test('accepting tells the professional; the job steps tell the right person', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    const o = await offer(db, p1, r);
    const b = (await user(db, c).query('select public.accept_offer($1) as id', [o])).rows[0].id;
    assert.ok((await kinds(db, p1)).includes('offer_accepted'));
    await user(db, p1).query('select public.start_booking($1)', [b]);
    await user(db, p1).query('select public.mark_booking_done($1)', [b]);
    await user(db, c).query('select public.confirm_booking_completed($1)', [b]);
    const cKinds = await kinds(db, c);
    assert.ok(cKinds.includes('job_started') && cKinds.includes('job_done'));
    assert.ok(!cKinds.includes('job_completed'), 'the customer confirmed it themselves');
    assert.ok((await kinds(db, p1)).includes('job_completed'));
  });

  test('a cancellation tells the other party, not the one who cancelled', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    const o = await offer(db, p2, r);
    const b = (await user(db, c).query('select public.accept_offer($1) as id', [o])).rows[0].id;
    await user(db, c).query('select public.cancel_booking($1)', [b]);
    assert.ok((await kinds(db, p2)).includes('job_cancelled'));
    assert.ok(!(await kinds(db, c)).includes('job_cancelled'));
  });

  test('a message queues one push per unread burst, with the conversation id only', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    const o = await offer(db, p1, r);
    const conv = (await user(db, c).query('select public.start_conversation($1) as id', [o])).rows[0].id;
    for (const t of ['a', 'b', 'c']) await user(db, p1).query('select public.send_message($1, $2)', [conv, `secret ${t}`]);
    const msgs = (await outbox(db, c)).filter((x) => x.kind === 'message');
    assert.equal(msgs.length, 1, 'three messages in a row, one notification');
    assert.deepEqual(msgs[0].payload, { conversation_id: conv });
    assert.ok(!JSON.stringify(await outbox(db, c)).includes('secret'), 'no message text ever');
    // after the customer reads, the next message notifies again
    const last = (await db.query('select max(id)::bigint as m from public.messages where conversation_id = $1', [conv])).rows[0].m;
    await user(db, c).query('select public.mark_conversation_read($1, $2)', [conv, last]);
    await user(db, p1).query('select public.send_message($1, $2)', [conv, 'encore']);
    assert.equal((await outbox(db, c)).filter((x) => x.kind === 'message').length, 2);
    assert.equal((await outbox(db, p1)).filter((x) => x.kind === 'message').length, 0, 'not for the sender');
  });

  test('messages in opposite directions with equal read markers both notify (the key includes the recipient)', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    const o = await offer(db, p1, r);
    const conv = (await user(db, c).query('select public.start_conversation($1) as id', [o])).rows[0].id;
    // both sides write before either reads: the read markers are equal
    await db.query('update public.conversations set customer_read_id = 0, professional_read_id = 0 where id = $1', [conv]);
    await db.query(`insert into public.messages (conversation_id, sender_is_customer, body) values ($1, true, 'a'), ($1, false, 'b')`, [conv]);
    assert.equal((await outbox(db, c)).filter((x) => x.kind === 'message').length, 1);
    assert.equal((await outbox(db, p1)).filter((x) => x.kind === 'message').length, 1);
  });

  test('disabled categories queue nothing; the others still do', async () => {
    const c = await createUser(db);
    await user(db, c).query('select public.set_notification_preferences(false, true, true)');
    const r = await ask(db, c);
    await offer(db, p1, r);
    assert.equal((await outbox(db, c)).length, 0);
    await user(db, c).query('select public.set_notification_preferences(true, true, true)');
    const r2 = await ask(db, c);
    await offer(db, p1, r2);
    assert.equal((await outbox(db, c)).length, 1);
  });

  test('preferences: default all on, then what was saved; private to the owner', async () => {
    const c = await createUser(db);
    assert.deepEqual((await user(db, c).query('select * from public.my_notification_preferences()')).rows[0], { offers: true, messages: true, jobs: true });
    await user(db, c).query('select public.set_notification_preferences(false, true, false)');
    assert.deepEqual((await user(db, c).query('select * from public.my_notification_preferences()')).rows[0], { offers: false, messages: true, jobs: false });
    assert.equal((await user(db, c).query('select * from public.notification_preferences')).rows.length, 1);
    assert.equal((await user(db, p1).query('select * from public.notification_preferences')).rows.filter((r) => r.user_id === c).length, 0);
    await denies(user(db, c).query('update public.notification_preferences set offers = true'), DENIED);
    await denies(anon(db).query('select public.my_notification_preferences()'), DENIED);
    await denies(anonymousAuthUser(db, c).query('select public.set_notification_preferences(true, true, true)'), DENIED);
  });

  test('clients cannot see or write the outbox or the tokens', async () => {
    await denies(user(db, cust).query('select * from public.notification_outbox'), DENIED);
    await denies(user(db, cust).query('insert into public.notification_outbox (user_id, category, kind, dedup_key) values ($1, $2, $3, $4)', [cust, 'offers', 'message', 'x']), DENIED);
    await denies(user(db, cust).query('select * from public.device_tokens'), DENIED);
    await denies(user(db, cust).query('select public.claim_notifications(10)'), DENIED);
    await denies(user(db, cust).query('select public.complete_notification(1, 1::smallint, true)'), DENIED);
    await denies(anon(db).query('select public.claim_notifications(10)'), DENIED);
    await denies(user(db, cust).query('select public._enqueue_notification($1, $2, $3, $4, $5)', [cust, 'offers', 'message', 'zz', '{}']), DENIED);
  });

  describe('device tokens', () => {
    test('register, move between accounts, unregister', async () => {
      const a = await createUser(db);
      const b = await createUser(db);
      await user(db, a).query('select public.register_device_token($1, $2)', [tok(1), 'android']);
      await user(db, a).query('select public.register_device_token($1, $2)', [tok(1), 'android']);
      assert.equal((await db.query('select count(*)::int as n from public.device_tokens where user_id = $1', [a])).rows[0].n, 1, 'idempotent');
      await user(db, b).query('select public.register_device_token($1, $2)', [tok(1), 'ios']);
      assert.equal((await db.query('select count(*)::int as n from public.device_tokens where user_id = $1', [a])).rows[0].n, 0, 'the phone now belongs to the new account');
      await user(db, a).query('select public.unregister_device_token($1)', [tok(1)]);
      assert.equal((await db.query('select count(*)::int as n from public.device_tokens where user_id = $1', [b])).rows[0].n, 1, 'cannot unregister someone else\'s');
      await user(db, b).query('select public.unregister_device_token($1)', [tok(1)]);
      assert.equal((await db.query('select count(*)::int as n from public.device_tokens')).rows[0].n, 0);
    });

    test('validated, capped at 10 per account (newest kept)', async () => {
      const a = await createUser(db);
      await assert.rejects(user(db, a).query(`select public.register_device_token('short', 'ios')`), (e) => e.code === 'P0001');
      await assert.rejects(user(db, a).query('select public.register_device_token($1, $2)', [tok(1), 'windows']), (e) => e.code === 'P0001');
      for (let i = 10; i < 22; i++) await user(db, a).query('select public.register_device_token($1, $2)', [tok(i), 'ios']);
      const rows = (await db.query('select token from public.device_tokens where user_id = $1', [a])).rows.map((r) => r.token);
      assert.equal(rows.length, 10);
      assert.ok(rows.includes(tok(21)) && !rows.includes(tok(10)));
    });

    test('anonymous-auth users cannot register', async () => {
      await denies(anonymousAuthUser(db, cust).query('select public.register_device_token($1, $2)', [tok(99), 'ios']), DENIED);
    });
  });

  describe('delivery worker (service role)', () => {
    let c, id;
    before(async () => {
      c = await createUser(db);
      await user(db, c).query('select public.register_device_token($1, $2)', [tok(500), 'android']);
      await user(db, c).query(`update public.profiles set preferred_language = 'ar' where id = $1`, [c]);
      const r = await ask(db, c);
      await offer(db, p1, r);
      id = (await outbox(db, c))[0].id;
    });

    test('claiming returns due rows with the recipient\'s tokens and language, and leases them', async () => {
      const claimed = (await service(db).query('select * from public.claim_notifications(100)')).rows.find((x) => x.id === id);
      assert.equal(claimed.language, 'ar');
      assert.deepEqual(claimed.tokens, [{ token: tok(500), platform: 'android' }]);
      assert.equal(claimed.kind, 'offer_received');
      const again = (await service(db).query('select * from public.claim_notifications(100)')).rows.find((x) => x.id === id);
      assert.equal(again, undefined, 'leased: a second worker does not get it');
      assert.equal((await db.query('select attempts from public.notification_outbox where id = $1', [id])).rows[0].attempts, 1);
    });

    test('failing backs off and retries; five failures give up; success is final', async () => {
      await service(db).query('select public.complete_notification($1, 1::smallint, false, $2)', [id, 'UNAVAILABLE']);
      const row = (await db.query('select * from public.notification_outbox where id = $1', [id])).rows[0];
      assert.equal(row.last_error, 'UNAVAILABLE');
      assert.equal(row.dead, false);
      assert.ok(new Date(row.leased_until) > new Date(), 'not due again right away');
      for (let i = 2; i <= 5; i++) {
        await db.query('update public.notification_outbox set leased_until = null where id = $1', [id]);
        await service(db).query('select * from public.claim_notifications(100)');
        await service(db).query('select public.complete_notification($1, $2::smallint, false, $3)', [id, i, 'again']);
      }
      assert.equal((await db.query('select dead from public.notification_outbox where id = $1', [id])).rows[0].dead, true);
      await db.query('update public.notification_outbox set leased_until = null where id = $1', [id]);
      assert.equal((await service(db).query('select * from public.claim_notifications(100)')).rows.find((x) => x.id === id), undefined, 'dead rows are never claimed');

      const c2 = await createUser(db);
      const r = await ask(db, c2);
      await offer(db, p1, r);
      const id2 = (await outbox(db, c2))[0].id;
      await service(db).query('select * from public.claim_notifications(100)');
      const attempt2 = (await db.query('select attempts from public.notification_outbox where id = $1', [id2])).rows[0].attempts;
      await service(db).query('select public.complete_notification($1, $2::smallint, true)', [id2, attempt2]);
      assert.ok((await db.query('select sent_at from public.notification_outbox where id = $1', [id2])).rows[0].sent_at);
      await db.query('update public.notification_outbox set leased_until = null where id = $1', [id2]);
      assert.equal((await service(db).query('select * from public.claim_notifications(100)')).rows.find((x) => x.id === id2), undefined, 'sent rows are not sent again');
    });

    test('a worker that keeps crashing cannot retry forever: rows are given up after five claims', async () => {
      const c4 = await createUser(db);
      const r = await ask(db, c4);
      await offer(db, p2, r);
      const id4 = (await outbox(db, c4))[0].id;
      for (let i = 0; i < 6; i++) {
        await db.query(`update public.notification_outbox set leased_until = now() - interval '1 minute' where id = $1`, [id4]);
        await service(db).query('select * from public.claim_notifications(100)');
      }
      const row = (await db.query('select attempts, dead from public.notification_outbox where id = $1', [id4])).rows[0];
      assert.equal(row.dead, true);
      assert.equal(row.attempts, 5, 'never claimed a sixth time');
    });

    test('a late report from a worker whose lease expired is ignored (fencing)', async () => {
      const c5 = await createUser(db);
      const r = await ask(db, c5);
      await offer(db, p2, r);
      const id5 = (await outbox(db, c5))[0].id;
      const first = (await service(db).query('select * from public.claim_notifications(100)')).rows.find((x) => x.id === id5);
      assert.equal(first.attempt, 1);
      await db.query(`update public.notification_outbox set leased_until = now() - interval '1 minute' where id = $1`, [id5]);
      const second = (await service(db).query('select * from public.claim_notifications(100)')).rows.find((x) => x.id === id5);
      assert.equal(second.attempt, 2);
      // the first (slow) worker reports failure late: it must not touch the newer claim
      await service(db).query('select public.complete_notification($1, 1::smallint, false, $2)', [id5, 'late']);
      const row = (await db.query('select last_error, leased_until from public.notification_outbox where id = $1', [id5])).rows[0];
      assert.equal(row.last_error, null);
      assert.ok(new Date(row.leased_until) > new Date(), 'the new lease still holds');
      await service(db).query('select public.complete_notification($1, 2::smallint, true)', [id5]);
      assert.ok((await db.query('select sent_at from public.notification_outbox where id = $1', [id5])).rows[0].sent_at);
      // and a second report for a sent row changes nothing
      await service(db).query('select public.complete_notification($1, 2::smallint, false, $2)', [id5, 'again']);
      assert.equal((await db.query('select last_error from public.notification_outbox where id = $1', [id5])).rows[0].last_error, null);
    });

    test('an expired lease makes a crashed worker\'s row claimable again', async () => {
      const c3 = await createUser(db);
      const r = await ask(db, c3);
      await offer(db, p2, r);
      const id3 = (await outbox(db, c3))[0].id;
      await service(db).query('select * from public.claim_notifications(100)');
      await db.query(`update public.notification_outbox set leased_until = now() - interval '1 minute' where id = $1`, [id3]);
      assert.ok((await service(db).query('select * from public.claim_notifications(100)')).rows.some((x) => x.id === id3));
    });

    test('invalid tokens can be forgotten; old rows are purged', async () => {
      await service(db).query('select public.forget_device_token($1)', [tok(500)]);
      assert.equal((await db.query('select count(*)::int as n from public.device_tokens where token = $1', [tok(500)])).rows[0].n, 0);
      await db.query(`update public.notification_outbox set sent_at = now() - interval '20 days' where sent_at is not null`);
      const n = (await service(db).query('select public.purge_old_notifications() as n')).rows[0].n;
      assert.ok(n >= 1);
    });
  });

  describe('account deletion', () => {
    test('removes preferences, tokens and queued notifications', async () => {
      const leaving = await createUser(db);
      await user(db, leaving).query('select public.set_notification_preferences(true, true, true)');
      await user(db, leaving).query('select public.register_device_token($1, $2)', [tok(777), 'ios']);
      const r = await ask(db, leaving);
      await offer(db, p1, r);
      assert.ok((await outbox(db, leaving)).length > 0);
      await user(db, leaving).query('select public.delete_my_account()');
      for (const t of ['notification_preferences', 'device_tokens', 'notification_outbox']) {
        assert.equal((await db.query(`select count(*)::int as n from public.${t} where user_id = $1`, [leaving])).rows[0].n, 0, t);
      }
    });
  });
});
