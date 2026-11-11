import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, anon, user, anonymousAuthUser, denies, DENIED, CHECK } from './harness.mjs';

const pathOf = (id, ts = 1762800000000, ext = 'jpg') => `${id}/avatar-${ts}.${ext}`;
const setProfile = (db, who, path) =>
  user(db, who).query('update public.profiles set avatar_path = $2 where id = $1', [who, path]);
const upload = (db, who, name, bucket = 'avatars') =>
  user(db, who).query('insert into storage.objects (bucket_id, name, owner) values ($1, $2, $3)', [bucket, name, who]);

describe('profile pictures', () => {
  let db, a, b, pro;
  before(async () => {
    db = await newDb();
    a = await createUser(db);
    b = await createUser(db);
    pro = await createUser(db);
    await user(db, pro).query('select public.become_professional()');
  });

  test('the avatars bucket exists, is public and small', async () => {
    const r = (await db.query(`select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'avatars'`)).rows[0];
    assert.equal(r.public, true);
    assert.equal(r.file_size_limit, 1048576);
    assert.deepEqual(r.allowed_mime_types.sort(), ['image/jpeg', 'image/png', 'image/webp']);
  });

  test('a person sets and clears their own picture path', async () => {
    await setProfile(db, a, pathOf(a));
    const r = await user(db, a).query('select avatar_path from public.profiles where id = $1', [a]);
    assert.equal(r.rows[0].avatar_path, pathOf(a));
    await setProfile(db, a, null);
    assert.equal((await user(db, a).query('select avatar_path from public.profiles')).rows[0].avatar_path, null);
  });

  test('the path must be in the owner folder, with the avatar-<time>.<ext> shape', async () => {
    await denies(setProfile(db, a, pathOf(b)), CHECK);
    await denies(setProfile(db, a, `${a}/../x.jpg`), CHECK);
    await denies(setProfile(db, a, `${a}/avatar-1762800000000.html`), CHECK);
    await denies(setProfile(db, a, `${a}/other.jpg`), CHECK);
    await denies(setProfile(db, a, 'https://evil.example/x.png'), CHECK);
  });

  test('nobody edits someone else\'s picture', async () => {
    await setProfile(db, a, pathOf(a));
    await user(db, b).query('update public.profiles set avatar_path = $2 where id = $1', [a, pathOf(a, 1762800000001)]);
    assert.equal((await user(db, a).query('select avatar_path from public.profiles')).rows[0].avatar_path, pathOf(a));
  });

  test('a customer\'s picture path is private; a professional\'s is public', async () => {
    assert.equal((await user(db, b).query('select avatar_path from public.profiles where id = $1', [a])).rows.length, 0);
    await user(db, pro).query(
      `update public.professional_profiles
          set business_name = 'Pro Photo', primary_category_id = 1, description = 'Plombier avec dix ans d experience.',
              governorate_id = 11, contact_phone = '+21620123456', is_published = true, avatar_path = $2
        where user_id = $1`, [pro, pathOf(pro)]);
    const seen = await anon(db).query('select avatar_path from public.professional_profiles where user_id = $1', [pro]);
    assert.equal(seen.rows[0].avatar_path, pathOf(pro));
    await user(db, b).query('update public.professional_profiles set avatar_path = $2 where user_id = $1', [pro, pathOf(pro, 1762800000002)]);
    const still = await anon(db).query('select avatar_path from public.professional_profiles where user_id = $1', [pro]);
    assert.equal(still.rows[0].avatar_path, pathOf(pro), 'only the owner changes it');
  });

  test('files: owners write and delete in their own folder only', async () => {
    await upload(db, a, pathOf(a));
    await denies(upload(db, a, pathOf(b)), DENIED);
    await denies(upload(db, b, `${a}/avatar-1762800000009.jpg`), DENIED);
    await user(db, b).query(`delete from storage.objects where bucket_id = 'avatars' and name = $1`, [pathOf(a)]);
    assert.equal((await db.query(`select count(*)::int n from storage.objects where bucket_id = 'avatars' and name = $1`, [pathOf(a)])).rows[0].n, 1, 'b cannot delete a\'s file');
    await user(db, a).query(`delete from storage.objects where bucket_id = 'avatars' and name = $1`, [pathOf(a)]);
    assert.equal((await db.query(`select count(*)::int n from storage.objects where bucket_id = 'avatars' and name = $1`, [pathOf(a)])).rows[0].n, 0);
  });

  test('anonymous-auth users cannot upload', async () => {
    await denies(anonymousAuthUser(db, a).query('insert into storage.objects (bucket_id, name) values ($1, $2)', ['avatars', pathOf(a, 1762800000007)]), DENIED);
    await denies(anon(db).query('insert into storage.objects (bucket_id, name) values ($1, $2)', ['avatars', pathOf(a, 1762800000008)]), DENIED);
  });

  test('deleting an account queues the avatar files for the cleanup worker', async () => {
    const c = await createUser(db);
    await upload(db, c, pathOf(c));
    await user(db, c).query('select public.delete_my_account()');
    const q = await db.query(`select bucket_id, name from public.storage_cleanup_queue where name = $1`, [pathOf(c)]);
    assert.deepEqual(q.rows, [{ bucket_id: 'avatars', name: pathOf(c) }]);
  });
});
