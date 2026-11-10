import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { newDb, createUser, anon, user, anonymousAuthUser, denies, DENIED, CHECK } from './harness.mjs';

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
const ask = (db, who) =>
  user(db, who).query(`select public.create_quote_request('Fuite sous évier', 'Une fuite sous le lavabo.', 1::smallint, 11::smallint) as id`).then((r) => r.rows[0].id);
const upload = (db, who, name = `${who}/${randomUUID()}.jpg`, bucket = 'request-photos') =>
  user(db, who).query('insert into storage.objects (bucket_id, name, owner) values ($1, $2, $3)', [bucket, name, who]).then(() => name);
const attach = (db, who, request, path) =>
  user(db, who).query('insert into public.request_photos (request_id, path) values ($1, $2)', [request, path]);
const rows = async (client) => (await client.query('select request_id, path from public.request_photos order by path')).rows;
const objects = async (client) => (await client.query(`select name from storage.objects where bucket_id = 'request-photos' order by name`)).rows.map((r) => r.name);

describe('request photos', () => {
  let db, cust, stranger, p1, p2, draftPro, req, path;
  before(async () => {
    db = await newDb();
    cust = await createUser(db);
    stranger = await createUser(db);
    p1 = await pro(db);
    p2 = await pro(db);
    draftPro = await pro(db, { publish: false });
    req = await ask(db, cust);
    path = await upload(db, cust);
    await attach(db, cust, req, path);
  });

  test('the bucket is private with a 2 MB limit and image types only', async () => {
    const r = (await db.query(`select * from storage.buckets where id = 'request-photos'`)).rows[0];
    assert.equal(r.public, false);
    assert.equal(Number(r.file_size_limit), 2097152);
    assert.deepEqual([...r.allowed_mime_types].sort(), ['image/jpeg', 'image/png', 'image/webp']);
  });

  test('the owner sees their photo; strangers and anon do not', async () => {
    assert.equal((await rows(user(db, cust))).length, 1);
    assert.equal((await rows(user(db, stranger))).length, 0);
    assert.deepEqual(await objects(user(db, stranger)), []);
    await denies(rows(anon(db)), DENIED);
  });

  test('a published professional sees the photos of an open request, a draft professional does not', async () => {
    assert.equal((await rows(user(db, p1))).length, 1);
    assert.deepEqual(await objects(user(db, p1)), [path], 'and can read the file');
    assert.equal((await rows(user(db, draftPro))).length, 0);
    assert.deepEqual(await objects(user(db, draftPro)), []);
  });

  test('once awarded, only the winner keeps seeing them; declined and other professionals do not', async () => {
    const r = await ask(db, cust);
    const pth = await upload(db, cust);
    await attach(db, cust, r, pth);
    await user(db, p1).query('select public.submit_offer($1, 100::numeric)', [r]);
    await user(db, p2).query('select public.submit_offer($1, 90::numeric)', [r]);
    const offer = (await db.query('select id from public.quote_offers where request_id = $1 and professional_id = $2', [r, p1])).rows[0].id;
    await user(db, cust).query('select public.accept_offer($1)', [offer]);
    const p3 = await pro(db);
    assert.ok((await rows(user(db, p1))).some((x) => x.path === pth), 'winner');
    assert.ok(!(await rows(user(db, p2))).some((x) => x.path === pth), 'a declined offer no longer gives access');
    assert.ok(!(await rows(user(db, p3))).some((x) => x.path === pth), 'one who never offered loses it');
  });

  test('only the owner attaches, only to an open request, only a file in their own folder', async () => {
    const mine = await upload(db, cust);
    await denies(attach(db, stranger, req, await upload(db, stranger)), DENIED);
    await denies(attach(db, p1, req, await upload(db, p1)), DENIED);
    await denies(attach(db, cust, req, `${stranger}/${randomUUID()}.jpg`), DENIED);
    await denies(attach(db, cust, req, `${cust}/x.html`), CHECK);
    await attach(db, cust, req, mine);
  });

  test('capped at 5 photos per request', async () => {
    const r = await ask(db, stranger);
    for (let i = 0; i < 5; i++) await attach(db, stranger, r, await upload(db, stranger));
    await assert.rejects(attach(db, stranger, r, await upload(db, stranger)), (e) => e.code === 'P0001' && /photo_limit/.test(e.message));
  });

  test('no changes once the request is closed; the owner can remove photos while open', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    const a = await upload(db, c);
    await attach(db, c, r, a);
    await user(db, c).query('delete from public.request_photos where path = $1', [a]);
    assert.equal((await rows(user(db, c))).length, 0);
    const b = await upload(db, c);
    await attach(db, c, r, b);
    await user(db, c).query('select public.cancel_quote_request($1)', [r]);
    await denies(attach(db, c, r, await upload(db, c)), DENIED);
    await user(db, c).query('delete from public.request_photos where path = $1', [b]);
    assert.equal((await rows(user(db, c))).length, 1, 'delete is refused too once cancelled');
  });

  test('strangers cannot delete someone else\'s photo row or file', async () => {
    await user(db, stranger).query('delete from public.request_photos where request_id = $1', [req]);
    await user(db, stranger).query('delete from storage.objects where name = $1', [path]);
    assert.equal((await rows(user(db, cust))).filter((x) => x.path === path).length, 1);
    assert.ok((await objects(user(db, cust))).includes(path));
  });

  test('storage: own folder only, customers only, anonymous-auth and anon refused', async () => {
    await denies(upload(db, cust, `${stranger}/x.jpg`), DENIED);
    await denies(upload(db, cust, 'x.jpg'), DENIED);
    await denies(anonymousAuthUser(db, cust).query(`insert into storage.objects (bucket_id, name) values ('request-photos', $1)`, [`${cust}/y.jpg`]), DENIED);
    await denies(anon(db).query(`insert into storage.objects (bucket_id, name) values ('request-photos', $1)`, [`${cust}/y.jpg`]), DENIED);
  });

  test('storage is capped at 60 files per person', async () => {
    const heavy = await createUser(db);
    for (let i = 0; i < 60; i++) await upload(db, heavy, `${heavy}/f${i}.jpg`);
    await denies(upload(db, heavy, `${heavy}/f60.jpg`), DENIED);
  });

  test('deleting the account removes the request, its photo rows and the object rows', async () => {
    const leaving = await createUser(db);
    const r = await ask(db, leaving);
    await attach(db, leaving, r, await upload(db, leaving));
    await user(db, leaving).query('select public.delete_my_account()');
    assert.equal((await db.query('select count(*)::int as n from public.request_photos where request_id = $1', [r])).rows[0].n, 0);
    assert.equal((await db.query(`select count(*)::int as n from storage.objects where (storage.foldername(name))[1] = $1`, [leaving])).rows[0].n, 0);
  });

  test('the photos of a closed request can no longer be deleted', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    const f = await upload(db, c);
    await attach(db, c, r, f);
    await user(db, c).query('select public.cancel_quote_request($1)', [r]);
    await user(db, c).query('delete from storage.objects where name = $1', [f]);
    assert.ok((await objects(user(db, c))).includes(f), 'file stays');
    const loose = await upload(db, c);
    await user(db, c).query('delete from storage.objects where name = $1', [loose]);
    assert.ok(!(await objects(user(db, c))).includes(loose), 'an unattached file can still be removed');
  });

  test('my_quote_requests lists only requests I own, with the offers count', async () => {
    const c = await createUser(db);
    const r = await ask(db, c);
    await user(db, p1).query('select public.submit_offer($1, 100::numeric)', [r]);
    const mine = await user(db, c).query('select * from public.my_quote_requests()');
    assert.deepEqual(mine.rows.map((x) => x.id), [r]);
    assert.equal(mine.rows[0].offers_count, 1);
    assert.deepEqual((await user(db, p1).query('select * from public.my_quote_requests()')).rows.filter((x) => x.id === r), []);
    assert.equal((await user(db, p1).query('select * from public.get_my_quote_request($1)', [r])).rows.length, 0);
    assert.equal((await user(db, c).query('select * from public.get_my_quote_request($1)', [r])).rows.length, 1);
    await denies(anon(db).query('select * from public.my_quote_requests()'), DENIED);
  });
});
