# Khidma admin

Web dashboard for the people who run Khidma: verification requests, reports, professionals, users, reviews, requests, categories, and the audit log. English only (internal tool).

It has **no table access**. Every screen calls an `admin_*` database function that checks the caller is an admin (with a TOTP second factor) on every call. Identity documents and reported chat images are never read through Storage: a signer Edge Function (`backend/supabase/functions/admin-media`) first calls the audited function as the caller, then returns links that expire after 2 minutes.

## Run

```
cd admin
npm ci
cp .env.example .env.local   # fill in the two public values
npm run dev                  # http://localhost:5173
npm test                     # 39 tests, no network needed
npm run build                # type check + production build in dist/
```

`VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` are the project's public values. Never put a service key in this app.

## Owner steps (nothing here can be done from this repository)

1. Create the Supabase project and apply the migrations (issue #6).
2. Create the first admin: sign up in Supabase Auth, then in the SQL editor `insert into public.admin_users (user_id) values ('<that user id>');`.
3. Deploy the signer: `supabase functions deploy admin-media` and set `ADMIN_ORIGIN` to the dashboard's origin.
4. Host `dist/` on a static host over HTTPS on its own origin, with the headers in `public/_headers` or your host's equivalent (the CSP in `index.html` already blocks other scripts).
5. First sign-in: enroll the authenticator app when asked. Until an admin has a verified TOTP session, `is_admin()` is false everywhere (`admin_config.require_mfa`, on by default).

## What has not been verified live

Sign-in, TOTP enrollment, the Edge Function and signed links need a real project; they are covered by unit tests with fakes only.
