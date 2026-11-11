import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { newDb, createUser, anon, user, anonymousAuthUser, denies, DENIED, CHECK, UNIQUE } from './harness.mjs';

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
const add = (db, who, owner, file = `${randomUUID()}.jpg`, caption = null) =>
  user(db, who).query('insert into public.portfolio_items (professional_id, path, caption) values ($1, $2, $3)', [owner, `${owner}/${file}`, caption]);
const filesOf = async (client) => (await client.query('select professional_id, path from public.portfolio_items order by path')).rows;
const files = (db, who) => filesOf(user(db, who));
const upload = (db, who, name, bucket = 'portfolio') =>
  user(db, who).query('insert into storage.objects (bucket_id, name, owner) values ($1, $2, $3)', [bucket, name, who]);

describe('portfolio items', () => {
  let db, a, b, draft, visitor;
  before(async () => {
    db = await newDb();
    a = await pro(db);
    b = await pro(db);
    draft = await pro(db, { publish: false });
    visitor = await createUser(db);
  });

  test('the owner adds, captions and removes; everyone sees a published profile', async () => {
    await add(db, a, a, 'one.jpg', 'Salle de bain');
    await add(db, a, a, 'two.webp');
    assert.equal((await filesOf(anon(db))).length, 2);
    assert.equal((await files(db, visitor)).length, 2);
    await user(db, a).query(`update public.portfolio_items set caption = 'Cuisine' where path = $1`, [`${a}/one.jpg`]);
    assert.equal((await anon(db).query('select caption from public.portfolio_items where path = $1', [`${a}/one.jpg`])).rows[0].caption, 'Cuisine');
    await user(db, a).query('delete from public.portfolio_items where path = $1', [`${a}/two.webp`]);
    assert.equal((await files(db, a)).length, 1);
  });

  test('nobody writes into someone else\'s portfolio', async () => {
    await denies(add(db, b, a), DENIED);
    await user(db, b).query('delete from public.portfolio_items where professional_id = $1', [a]);
    assert.equal((await files(db, a)).length, 1, 'still there');
    await user(db, b).query(`update public.portfolio_items set caption = 'x' where professional_id = $1`, [a]);
    const r = await user(db, a).query('select caption from public.portfolio_items');
    assert.equal(r.rows[0].caption, 'Cuisine');
  });

  test('the path must sit in the owner folder and have an image extension', async () => {
    await denies(user(db, b).query('insert into public.portfolio_items (professional_id, path) values ($1, $2)', [b, `${a}/steal.jpg`]), CHECK);
    await denies(user(db, b).query('insert into public.portfolio_items (professional_id, path) values ($1, $2)', [b, `${b}/script.html`]), CHECK);
    await denies(user(db, b).query('insert into public.portfolio_items (professional_id, path) values ($1, $2)', [b, `${b}/../x.jpg`]), CHECK);
    await denies(user(db, b).query('insert into public.portfolio_items (professional_id, path) values ($1, $2)', [b, `${b}/a/b.jpg`]), CHECK);
  });

  test('the same file cannot be listed twice', async () => {
    await add(db, b, b, 'dup.jpg');
    await denies(add(db, b, b, 'dup.jpg'), UNIQUE);
  });

  test('a draft profile\'s items are invisible to others, visible to the owner', async () => {
    await add(db, draft, draft, 'wip.jpg');
    assert.ok(!(await filesOf(anon(db))).some((r) => r.professional_id === draft));
    assert.ok(!(await files(db, visitor)).some((r) => r.professional_id === draft));
    assert.ok((await files(db, draft)).some((r) => r.professional_id === draft));
  });

  test('anonymous-auth users cannot add; anon cannot write', async () => {
    await denies(anonymousAuthUser(db, a).query('insert into public.portfolio_items (professional_id, path) values ($1, $2)', [a, `${a}/anon.jpg`]), DENIED);
    await denies(anon(db).query('insert into public.portfolio_items (professional_id, path) values ($1, $2)', [a, `${a}/x.jpg`]), DENIED);
  });

  test('captions are limited to 140 characters', async () => {
    await denies(add(db, a, a, 'long.jpg', 'x'.repeat(141)), CHECK);
    await add(db, a, a, 'ok.jpg', 'x'.repeat(140));
  });

  test('capped at 12 per professional', async () => {
    const heavy = await pro(db);
    for (let i = 0; i < 12; i++) await add(db, heavy, heavy, `p${i}.jpg`);
    await assert.rejects(add(db, heavy, heavy, 'p12.jpg'), (e) => e.code === 'P0001' && /portfolio_limit/.test(e.message));
    const src = (await db.query(`select pg_get_functiondef(p.oid) as d from pg_proc p where p.proname = 'enforce_portfolio_limit'`)).rows[0].d;
    assert.match(src, /pg_advisory_xact_lock/);
  });

  test('items go away with the professional', async () => {
    const gone = await pro(db);
    await add(db, gone, gone, 'a.jpg');
    await user(db, gone).query('select public.delete_my_account()');
    assert.equal((await db.query('select count(*)::int as n from public.portfolio_items where professional_id = $1', [gone])).rows[0].n, 0);
  });
});

describe('portfolio storage', () => {
  let db, a, b;
  before(async () => {
    db = await newDb();
    a = await pro(db);
    b = await pro(db);
  });

  test('the bucket is public with a 2 MB limit and image types only', async () => {
    const r = (await db.query(`select * from storage.buckets where id = 'portfolio'`)).rows[0];
    assert.equal(r.public, true);
    assert.equal(Number(r.file_size_limit), 2097152);
    assert.deepEqual([...r.allowed_mime_types].sort(), ['image/jpeg', 'image/png', 'image/webp']);
  });

  test('a professional uploads only into their own folder', async () => {
    await upload(db, a, `${a}/x.jpg`);
    await denies(upload(db, a, `${b}/x.jpg`), DENIED);
    await denies(upload(db, a, 'x.jpg'), DENIED, 'no folder at all');
  });

  test('a customer without a professional profile cannot use the storage', async () => {
    const customer = await createUser(db);
    await denies(upload(db, customer, `${customer}/x.jpg`), DENIED);
  });

  test('capped at 16 files in a folder, so storage is not free hosting', async () => {
    const heavy = await pro(db);
    for (let i = 0; i < 16; i++) await upload(db, heavy, `${heavy}/f${i}.jpg`);
    await denies(upload(db, heavy, `${heavy}/f16.jpg`), DENIED);
    // another professional is unaffected
    await upload(db, b, `${b}/free.jpg`);
  });

  test('only the portfolio bucket is writable by clients', async () => {
    await db.query(`insert into storage.buckets (id, name) values ('other', 'other')`);
    await denies(upload(db, a, `${a}/o.jpg`, 'other'), DENIED);
  });

  test('anonymous-auth users and anon cannot upload', async () => {
    await denies(anonymousAuthUser(db, a).query('insert into storage.objects (bucket_id, name) values ($1, $2)', ['portfolio', `${a}/y.jpg`]), DENIED);
    await denies(anon(db).query('insert into storage.objects (bucket_id, name) values ($1, $2)', ['portfolio', `${a}/y.jpg`]), DENIED);
  });

  test('deleting is limited to the own folder', async () => {
    await upload(db, b, `${b}/keep.jpg`);
    await user(db, a).query('delete from storage.objects where name = $1', [`${b}/keep.jpg`]);
    assert.equal((await db.query(`select count(*)::int as n from storage.objects where name = $1`, [`${b}/keep.jpg`])).rows[0].n, 1);
    await user(db, b).query('delete from storage.objects where name = $1', [`${b}/keep.jpg`]);
    assert.equal((await db.query(`select count(*)::int as n from storage.objects where name = $1`, [`${b}/keep.jpg`])).rows[0].n, 0);
  });

  test('deleting the account queues its files for the cleanup worker (SQL cannot delete storage rows)', async () => {
    const leaving = await pro(db);
    await upload(db, leaving, `${leaving}/a.jpg`);
    await upload(db, leaving, `${leaving}/b.jpg`);
    await upload(db, a, `${a}/stays.jpg`);
    await user(db, leaving).query('select public.delete_my_account()');
    const q = async (who) => (await db.query(`select count(*)::int as n from public.storage_cleanup_queue where split_part(name, '/', 1) = $1`, [who])).rows[0].n;
    assert.equal(await q(leaving), 2);
    assert.equal(await q(a), 0, 'others untouched');
  });
});
