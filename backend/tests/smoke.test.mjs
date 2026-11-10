import test from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, user } from './harness.mjs';

test('migrations apply and a user can read their own profile', async () => {
  const db = await newDb();
  const id = await createUser(db, { meta: { full_name: 'Karim' } });
  const r = await user(db, id).query('select full_name, is_professional from public.profiles');
  assert.equal(r.rows.length, 1);
  assert.equal(r.rows[0].full_name, 'Karim');
  assert.equal(r.rows[0].is_professional, false);
});
