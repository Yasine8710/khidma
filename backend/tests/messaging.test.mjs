import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { newDb, createUser, anon, user, anonymousAuthUser, denies, DENIED } from './harness.mjs';

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
const offer = (db, who, request) =>
  user(db, who).query('select public.submit_offer($1, 100::numeric) as id', [request]).then((r) => r.rows[0].id);
const call = (db, who, sql, ...args) => user(db, who).query(sql, args).then((r) => r.rows);
const start = (db, who, offerId) => call(db, who, 'select public.start_conversation($1) as id', offerId).then((r) => r[0].id);
const send = (db, who, conv, body = 'Bonjour', image = null) =>
  call(db, who, 'select public.send_message($1, $2, $3) as id', conv, body, image).then((r) => r[0].id);
const msgs = async (db, who, conv) => (await call(db, who, 'select id, conversation_id, sender_is_customer, body, image_path, created_at from public.messages where conversation_id = $1 order by id', conv));
const upload = (db, who, name) =>
  user(db, who).query(`insert into storage.objects (bucket_id, name, owner) values ('chat-images', $1, $2)`, [name, who]);

describe('messaging', () => {
  let db, cust, p1, p2, stranger, req, offer1, conv;
  before(async () => {
    db = await newDb();
    cust = await createUser(db);
    stranger = await createUser(db);
    p1 = await pro(db);
    p2 = await pro(db);
    req = await ask(db, cust);
    offer1 = await offer(db, p1, req);
    await offer(db, p2, req);
  });

  test('either party starts the conversation about an offer; it is one per offer', async () => {
    conv = await start(db, cust, offer1);
    assert.equal(await start(db, p1, offer1), conv, 'the professional reopens the same one');
    assert.equal(await start(db, cust, offer1), conv, 'idempotent');
    const row = (await db.query('select * from public.conversations where id = $1', [conv])).rows[0];
    assert.equal(row.customer_id, cust);
    assert.equal(row.professional_id, p1);
  });

  test('strangers and other professionals cannot start or see it', async () => {
    await assert.rejects(start(db, stranger, offer1), (e) => e.code === 'P0002');
    await assert.rejects(start(db, p2, offer1), (e) => e.code === 'P0002', 'a rival cannot open someone else\'s offer chat');
    assert.equal((await call(db, stranger, 'select id, offer_id, created_at, last_message_at from public.conversations')).length, 0);
    assert.equal((await call(db, p2, 'select id, offer_id, created_at, last_message_at from public.conversations where id = $1', conv)).length, 0);
    await denies(anon(db).query('select id from public.conversations'), DENIED);
  });

  test('members exchange text; both read it; non-members read nothing', async () => {
    await send(db, cust, conv, '  Bonjour, vous pouvez passer demain ?  ');
    await send(db, p1, conv, 'Oui, vers 10h.');
    const m = await msgs(db, cust, conv);
    assert.deepEqual(m.map((x) => x.body), ['Bonjour, vous pouvez passer demain ?', 'Oui, vers 10h.']);
    assert.equal((await msgs(db, p1, conv)).length, 2);
    assert.equal((await msgs(db, p2, conv)).length, 0);
    assert.equal((await msgs(db, stranger, conv)).length, 0);
    await denies(anon(db).query('select id from public.messages'), DENIED);
  });

  test('clients cannot write the tables directly, nor as someone else', async () => {
    await denies(user(db, cust).query(`insert into public.messages (conversation_id, sender_is_customer, body) values ($1, true, 'x')`, [conv]), DENIED);
    await denies(user(db, cust).query(`update public.messages set body = 'edited'`), DENIED);
    await denies(user(db, cust).query('delete from public.messages'), DENIED);
    await denies(user(db, cust).query(`insert into public.conversations (offer_id, customer_id, professional_id) values ($1, $2, $3)`, [offer1, cust, p1]), DENIED);
    await assert.rejects(call(db, stranger, 'select public.send_message($1, $2)', conv, 'intrusion'), (e) => e.code === 'P0002');
    await assert.rejects(call(db, p2, 'select public.send_message($1, $2)', conv, 'rival'), (e) => e.code === 'P0002');
  });

  test('message content is validated', async () => {
    await tagged(call(db, cust, 'select public.send_message($1, $2)', conv, '   '), 'invalid_input');
    await tagged(call(db, cust, 'select public.send_message($1)', conv), 'invalid_input');
    await tagged(call(db, cust, 'select public.send_message($1, $2)', conv, 'x'.repeat(2001)), 'invalid_input');
    await send(db, cust, conv, 'x'.repeat(2000));
  });

  test('anonymous-auth users cannot use messaging', async () => {
    await denies(anonymousAuthUser(db, cust).query('select public.send_message($1, $2)', [conv, 'hi']), DENIED);
    await denies(anonymousAuthUser(db, cust).query('select public.start_conversation($1)', [offer1]), DENIED);
  });

  test('inbox: last message, unread count, anonymous customer, public professional name', async () => {
    const c = await createUser(db, { meta: { full_name: 'Secret Customer' } });
    const r = await ask(db, c);
    const o = await offer(db, p1, r);
    const cv = await start(db, c, o);
    await send(db, p1, cv, 'Bonjour');
    await send(db, p1, cv, 'Je suis disponible');
    const mine = (await call(db, c, 'select * from public.my_conversations()')).find((x) => x.conversation_id === cv);
    assert.equal(mine.unread_count, 2);
    assert.equal(mine.last_body, 'Je suis disponible');
    assert.equal(mine.i_am_customer, true);
    assert.match(mine.other_name, /^Pro /);
    assert.equal(mine.other_id, p1);
    assert.equal(mine.writable, true);
    const theirs = (await call(db, p1, 'select * from public.my_conversations()')).find((x) => x.conversation_id === cv);
    assert.equal(theirs.unread_count, 0, 'own messages are not unread');
    assert.equal(theirs.other_name, null, 'the customer is anonymous (their name is set, and still not shown)');
    assert.equal(theirs.other_id, null);
    assert.equal(theirs.request_title, 'Fuite sous évier');
  });

  test('reading clears the unread count; sending counts as reading', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    const o = await offer(db, p1, r);
    const cv = await start(db, c, o);
    await send(db, p1, cv, 'a');
    await send(db, p1, cv, 'b');
    const unread = async (who) => (await call(db, who, 'select * from public.my_conversations()')).find((x) => x.conversation_id === cv).unread_count;
    assert.equal(await unread(c), 2);
    const last = (await msgs(db, c, cv)).at(-1).id;
    await call(db, c, 'select public.mark_conversation_read($1, $2)', cv, last);
    assert.equal(await unread(c), 0);
    await send(db, p1, cv, 'c');
    assert.equal(await unread(c), 1);
    await send(db, c, cv, 'reply');
    assert.equal(await unread(c), 0, 'answering means having read');
    await assert.rejects(call(db, stranger, 'select public.mark_conversation_read($1, 1)', cv), (e) => e.code === 'P0002');
  });

  test('a member cannot read for the other: marking read only moves my own marker', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    const o = await offer(db, p1, r);
    const cv = await start(db, c, o);
    await send(db, p1, cv, 'a');
    await call(db, p1, 'select public.mark_conversation_read($1, 999999)', cv);
    const unread = (await call(db, c, 'select * from public.my_conversations()')).find((x) => x.conversation_id === cv).unread_count;
    assert.equal(unread, 1);
  });

  test('no user id can be read: not on conversations, not on messages', async () => {
    await denies(user(db, p1).query('select customer_id from public.conversations'), DENIED);
    await denies(user(db, p1).query('select professional_id from public.conversations'), DENIED);
    await denies(user(db, cust).query('select * from public.conversations'), DENIED);
    await denies(user(db, p1).query('select sender_id from public.messages'), '42703');
    const cols = await db.query(
      `select table_name, column_name from information_schema.column_privileges
        where table_schema = 'public' and table_name in ('conversations', 'messages')
          and grantee = 'authenticated' and privilege_type = 'SELECT'`);
    assert.ok(!cols.rows.some((x) => /customer_id|professional_id|sender_id|user_id/.test(x.column_name)));
    const m = await db.query(`select column_name from information_schema.columns where table_schema = 'public' and table_name = 'messages'`);
    assert.ok(!m.rows.some((x) => x.column_name === 'sender_id'), 'messages carry no sender id at all (realtime payloads included)');
  });

  test('reading is only up to what was shown, and never backwards', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    const cv = await start(db, c, await offer(db, p1, r));
    const first = await send(db, p1, cv, 'un');
    await send(db, p1, cv, 'deux');
    const third = await send(db, p1, cv, 'trois');
    const unread = async () => (await call(db, c, 'select * from public.my_conversations()')).find((x) => x.conversation_id === cv).unread_count;
    assert.equal(await unread(), 3);
    await call(db, c, 'select public.mark_conversation_read($1, $2)', cv, first);
    assert.equal(await unread(), 2, 'only the first was shown');
    await call(db, c, 'select public.mark_conversation_read($1, $2)', cv, third);
    assert.equal(await unread(), 0);
    await call(db, c, 'select public.mark_conversation_read($1, $2)', cv, first);
    assert.equal(await unread(), 0, 'marking an older one does not un-read');
  });

  test('an expired request is no longer writable, nor can a chat start on it', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    const o = await offer(db, p1, r);
    const cv = await start(db, c, o);
    await db.query(`update public.quote_requests set expires_at = now() - interval '1 minute' where id = $1`, [r]);
    await tagged(call(db, c, 'select public.send_message($1, $2)', cv, 'trop tard'), 'not_open');
    const r2 = await ask(db, c);
    const o2 = await offer(db, p2, r2);
    await db.query(`update public.quote_requests set expires_at = now() - interval '1 minute' where id = $1`, [r2]);
    await tagged(call(db, c, 'select public.start_conversation($1)', o2), 'not_open');
  });

  test('rate limit: 30 messages per minute', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    const o = await offer(db, p1, r);
    const cv = await start(db, c, o);
    for (let i = 0; i < 30; i++) await send(db, c, cv, `m${i}`);
    await tagged(call(db, c, 'select public.send_message($1, $2)', cv, 'one too many'), 'rate_limited');
  });

  describe('when the offer closes', () => {
    test('declined offer: history stays, no new messages; cannot start a new chat on it', async () => {
      const c = await createUser(db);
      const r = await ask(db, c);
      const o = await offer(db, p1, r);
      const o2 = await offer(db, p2, r);
      const cv = await start(db, c, o);
      await send(db, c, cv, 'avant');
      await call(db, c, 'select public.decline_offer($1)', o);
      assert.equal((await msgs(db, p1, cv)).length, 1, 'history readable');
      await tagged(call(db, p1, 'select public.send_message($1, $2)', cv, 'après'), 'not_open');
      await tagged(call(db, c, 'select public.send_message($1, $2)', cv, 'après'), 'not_open');
      const row = (await call(db, c, 'select * from public.my_conversations()')).find((x) => x.conversation_id === cv);
      assert.equal(row.writable, false);
      // a conversation can still be reopened for the live offer
      assert.ok(await start(db, c, o2));
    });

    test('no new conversation on a declined or withdrawn offer', async () => {
      const c = await createUser(db);
      const r = await ask(db, c);
      const o = await offer(db, p1, r);
      await call(db, p1, 'select public.withdraw_offer($1)', o);
      await tagged(call(db, c, 'select public.start_conversation($1)', o), 'not_open');
    });

    test('accepted offer: the chat keeps working, even after the job', async () => {
      const c = await createUser(db);
      const r = await ask(db, c);
      const o = await offer(db, p1, r);
      const cv = await start(db, c, o);
      await call(db, c, 'select public.accept_offer($1)', o);
      await send(db, p1, cv, 'merci');
      assert.equal((await msgs(db, c, cv)).length, 1);
    });

    test('cancelled request: read-only', async () => {
      const c = await createUser(db);
      const r = await ask(db, c);
      const o = await offer(db, p1, r);
      const cv = await start(db, c, o);
      await call(db, c, 'select public.cancel_quote_request($1)', r);
      await tagged(call(db, c, 'select public.send_message($1, $2)', cv, 'x'), 'not_open');
    });
  });

  describe('images', () => {
    let cv, c;
    before(async () => {
      c = await createUser(db);
      const r = await ask(db, c);
      const o = await offer(db, p1, r);
      cv = await start(db, c, o);
    });

    test('the bucket is private with a 2 MB limit and image types only', async () => {
      const b = (await db.query(`select * from storage.buckets where id = 'chat-images'`)).rows[0];
      assert.equal(b.public, false);
      assert.equal(Number(b.file_size_limit), 2097152);
      assert.deepEqual([...b.allowed_mime_types].sort(), ['image/jpeg', 'image/png', 'image/webp']);
    });

    test('members upload into their conversation folder; others cannot', async () => {
      await upload(db, c, `${cv}/${randomUUID()}.jpg`);
      await upload(db, p1, `${cv}/${randomUUID()}.jpg`);
      await denies(upload(db, stranger, `${cv}/${randomUUID()}.jpg`), DENIED);
      await denies(upload(db, p2, `${cv}/${randomUUID()}.jpg`), DENIED);
      await denies(upload(db, c, `${randomUUID()}/x.jpg`), DENIED, 'a folder that is not my conversation');
      await denies(upload(db, c, 'not-a-uuid/x.jpg'), DENIED);
      await denies(upload(db, c, 'x.jpg'), DENIED);
      await denies(anonymousAuthUser(db, c).query(`insert into storage.objects (bucket_id, name) values ('chat-images', $1)`, [`${cv}/${randomUUID()}.jpg`]), DENIED);
    });

    test('only members read the files', async () => {
      const name = `${cv}/${randomUUID()}.jpg`;
      await upload(db, c, name);
      const read = async (who) => (await call(db, who, `select name from storage.objects where name = $1`, name)).length;
      assert.equal(await read(c), 1);
      assert.equal(await read(p1), 1);
      assert.equal(await read(stranger), 0);
      assert.equal(await read(p2), 0);
    });

    test('an image message needs an uploaded file in this conversation', async () => {
      const name = `${cv}/${randomUUID()}.jpg`;
      await tagged(call(db, c, 'select public.send_message($1, null, $2)', cv, name), 'invalid_input');
      await upload(db, c, name);
      const id = await call(db, c, 'select public.send_message($1, null, $2) as id', cv, name);
      assert.ok(id[0].id);
      const m = (await msgs(db, p1, cv)).find((x) => x.image_path === name);
      assert.equal(m.body, null);
      const other = `${randomUUID()}/${randomUUID()}.jpg`;
      await tagged(call(db, c, 'select public.send_message($1, null, $2)', cv, other), 'invalid_input');
      await tagged(call(db, c, 'select public.send_message($1, null, $2)', cv, `${cv}/x.html`), 'invalid_input');
    });

    test('a closed conversation takes no new uploads; an unsent upload can be removed, a sent one cannot', async () => {
      const c4 = await createUser(db);
      const r = await ask(db, c4);
      const o = await offer(db, p1, r);
      const cv4 = await start(db, c4, o);
      const unsent = `${cv4}/${randomUUID()}.jpg`;
      await upload(db, c4, unsent);
      await user(db, c4).query('delete from storage.objects where name = $1', [unsent]);
      assert.equal((await db.query('select count(*)::int as n from storage.objects where name = $1', [unsent])).rows[0].n, 0, 'unsent upload removed');
      const sent = `${cv4}/${randomUUID()}.jpg`;
      await upload(db, c4, sent);
      await call(db, c4, 'select public.send_message($1, null, $2)', cv4, sent);
      await user(db, c4).query('delete from storage.objects where name = $1', [sent]);
      assert.equal((await db.query('select count(*)::int as n from storage.objects where name = $1', [sent])).rows[0].n, 1, 'a file a message points to stays');
      await call(db, c4, 'select public.cancel_quote_request($1)', r);
      await denies(upload(db, c4, `${cv4}/${randomUUID()}.jpg`), DENIED);
      await denies(upload(db, p1, `${cv4}/${randomUUID()}.jpg`), DENIED);
    });

    test('an image from another conversation cannot be attached here', async () => {
      const c3 = await createUser(db);
      const r = await ask(db, c3);
      const o = await offer(db, p1, r);
      const cv3 = await start(db, c3, o);
      const foreign = `${cv3}/${randomUUID()}.jpg`;
      await upload(db, c3, foreign); // a real file, in someone else's conversation
      await tagged(call(db, c, 'select public.send_message($1, null, $2)', cv, foreign), 'invalid_input');
    });

    test('capped at 100 images per conversation', async () => {
      const c2 = await createUser(db);
      const r = await ask(db, c2);
      const o = await offer(db, p1, r);
      const cv2 = await start(db, c2, o);
      for (let i = 0; i < 100; i++) await db.query(`insert into storage.objects (bucket_id, name, owner) values ('chat-images', $1, $2)`, [`${cv2}/f${i}.jpg`, c2]);
      await denies(upload(db, c2, `${cv2}/f100.jpg`), DENIED);
    });
  });

  describe('account deletion', () => {
    test('removes the conversations, messages and image objects of the leaving person; others keep theirs', async () => {
      const leaving = await createUser(db);
      const other = await createUser(db);
      const r1 = await ask(db, leaving);
      const r2 = await ask(db, other);
      const c1 = await start(db, leaving, await offer(db, p1, r1));
      const c2 = await start(db, other, await offer(db, p1, r2));
      await send(db, leaving, c1, 'salut');
      await send(db, p1, c2, 'salut');
      await upload(db, leaving, `${c1}/a.jpg`);
      await upload(db, other, `${c2}/b.jpg`);
      await user(db, leaving).query('select public.delete_my_account()');
      assert.equal((await db.query('select count(*)::int as n from public.conversations where id = $1', [c1])).rows[0].n, 0);
      assert.equal((await db.query('select count(*)::int as n from public.messages where conversation_id = $1', [c1])).rows[0].n, 0);
      assert.equal((await db.query(`select count(*)::int as n from public.storage_cleanup_queue where name = $1`, [`${c1}/a.jpg`])).rows[0].n, 1, 'queued for the cleanup worker');
      assert.equal((await db.query('select count(*)::int as n from public.conversations where id = $1', [c2])).rows[0].n, 1);
      assert.equal((await db.query(`select count(*)::int as n from storage.objects where name = $1`, [`${c2}/b.jpg`])).rows[0].n, 1);
      assert.equal((await db.query(`select count(*)::int as n from public.storage_cleanup_queue where name = $1`, [`${c2}/b.jpg`])).rows[0].n, 0, 'the other side keeps theirs');
    });
  });
});
