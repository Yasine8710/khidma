import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
const migrationsDir = join(here, '..', 'supabase', 'migrations');

// What a Supabase project provides before our migrations run. The important
// part is the *permissive default privileges*: Supabase grants ALL on every
// new public table to anon/authenticated, so our migrations must revoke them.
const SUPABASE_STUB = `
  create role anon nologin noinherit;
  create role authenticated nologin noinherit;
  create role service_role nologin noinherit bypassrls;
  create schema auth;
  create table auth.users (
    id uuid primary key,
    email text,
    raw_user_meta_data jsonb default '{}'::jsonb,
    created_at timestamptz not null default now()
  );
  create function auth.uid() returns uuid language sql stable as $$
    select coalesce(
      nullif(current_setting('request.jwt.claim.sub', true), ''),
      (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
    )::uuid
  $$;
  create function auth.jwt() returns jsonb language sql stable as $$
    select coalesce(
      nullif(current_setting('request.jwt.claim', true), ''),
      nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
  $$;
  -- Storage, as far as our policies need it (the real schema has more).
  create schema storage;
  create table storage.buckets (
    id text primary key, name text not null, public boolean default false,
    file_size_limit bigint, allowed_mime_types text[]
  );
  create table storage.objects (
    id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets (id),
    name text, owner uuid, metadata jsonb, created_at timestamptz default now()
  );
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[] language sql immutable as $$
    select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
  $$;
  grant usage on schema storage to anon, authenticated, service_role;
  grant all on storage.objects to anon, authenticated, service_role;
  grant select on storage.buckets to anon, authenticated, service_role;
  grant usage on schema public, auth to anon, authenticated, service_role;
  grant execute on function auth.jwt() to anon, authenticated, service_role;
  grant execute on function auth.uid() to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`;

/** A fresh in-memory Postgres with the stub and every migration applied. */
export async function newDb() {
  const db = new PGlite();
  await db.exec(SUPABASE_STUB);
  const files = readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
  for (const f of files) {
    await db.exec(readFileSync(join(migrationsDir, f), 'utf8'));
  }
  return db;
}

/** Creates an auth user (as the superuser, like Supabase Auth does). */
export async function createUser(db, { id = randomUUID(), email, meta = {} } = {}) {
  await db.query('insert into auth.users (id, email, raw_user_meta_data) values ($1, $2, $3)', [
    id,
    email ?? `${id}@example.test`,
    JSON.stringify(meta),
  ]);
  return id;
}

export async function makeAdmin(db, userId) {
  await db.query('insert into public.admin_users (user_id) values ($1)', [userId]);
}

/**
 * Runs SQL the way the API would: with a database role and a JWT subject.
 * `sub` null means an authenticated role without a user (should be useless).
 */
export function as(db, role, sub = null, claims = {}) {
  const run = async (sql, params = []) => {
    await db.query(`select set_config('request.jwt.claim.sub', $1, false)`, [sub ?? '']);
    await db.query(`select set_config('request.jwt.claims', $1, false)`, [
      JSON.stringify({ sub, role, ...claims }),
    ]);
    await db.exec(`set role ${role}`);
    try {
      return await db.query(sql, params);
    } finally {
      await db.exec('reset role');
      await db.query(`select set_config('request.jwt.claim.sub', '', false)`);
      await db.query(`select set_config('request.jwt.claims', '', false)`);
    }
  };
  return { query: run };
}
export const anon = (db) => as(db, 'anon');
export const user = (db, id) => as(db, 'authenticated', id);
/** A Supabase anonymous-auth user: `authenticated` role, is_anonymous claim. */
export const anonymousAuthUser = (db, id) => as(db, 'authenticated', id, { is_anonymous: true });

/** Asserts a query fails with a Postgres SQLSTATE (e.g. 42501, 23514). */
export async function denies(promise, code) {
  await assert.rejects(promise, (e) => {
    assert.equal(e.code, code, `expected SQLSTATE ${code}, got ${e.code}: ${e.message}`);
    return true;
  });
}

// SQLSTATE shortcuts
export const DENIED = '42501'; // permission denied / RLS violation
export const CHECK = '23514';
export const UNIQUE = '23505';
export const FK = '23503';
