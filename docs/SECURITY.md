# Security

Reporting vulnerabilities: see the root [SECURITY.md](../SECURITY.md).

## Principles
- **The database is the security boundary.** The app can be modified or replaced by an attacker; Postgres Row Level Security (RLS), grants and privileged functions must be correct on their own. Router redirects and hidden buttons are UX only.
- **Deny by default.** Supabase grants every new public table to `anon` and `authenticated` by default. Every migration revokes everything first and grants the minimum.
- **No secrets in the app.** Only the Supabase URL and the public (publishable or legacy anon) key ship in the client. `app_config.dart` refuses `sb_secret_...` and `service_role` keys at startup.
- **Identity facts never come from client-controlled data.** Roles are not read from `user_metadata` / sign-up metadata, and admin is a row in a table no client can reach.

## Roles and capabilities
| Concept | Where it lives | Who can change it |
|---|---|---|
| Customer / professional | `profiles.is_customer`, `profiles.is_professional` (a user can be both) | `become_professional()` only (a column grant blocks direct edits) |
| Admin | row in `admin_users` | service role / migration only. No API path, no policy |
| Verification badge | `professional_profiles.verification_status`, `verified_at` | `admin_set_verification()` (checks `is_admin()`) |
| Ratings, review counts | `professional_profiles.rating_avg`, `review_count` | server-side triggers (Phase 6); never owners |

## Permission matrix (current migrations)
`R` read, `C` create, `U` update (column-limited where noted), `D` delete, `-` no access. "own" = rows where the user id matches. Verified by `backend/tests`.

| Table | anon | authenticated (other) | owner | admin |
|---|---|---|---|---|
| governorates, cities, neighborhoods | R | R | R | R (writes by migration) |
| service_categories | R active | R active | R active | R all, U, D (no API insert: see below) |
| profiles | - | - | R own; U `full_name, avatar_url, phone, preferred_language` | - |
| customer_profiles | - | - | R own; U `default_governorate_id, default_city_id` | - |
| admin_users | - | - | - | - (service role only) |
| professional_profiles | R published, **never** `contact_phone` / `verified_at` | same as anon | R own (draft too); U profile fields, `is_published`; own phone via `get_my_professional_contact()` | R all rows; verification via RPC |
| professional_services, service_areas | R when profile published | R when profile published | R, C, D own | R as above |
| contact_reveals (rate-limit log) | - | - | - | - |

Functions (all `SECURITY DEFINER` ones pin `search_path = ''`; no function is callable by PUBLIC; a test enumerates exactly who can execute what):
- `become_professional()`, `get_my_professional_contact()`, `reveal_professional_contact(uuid)`: `authenticated` only, and they refuse Supabase anonymous-auth users (JWT `is_anonymous`).
- `admin_set_verification(uuid, text)`: `authenticated`, but checks `is_admin()` inside.
- `is_admin()`: anon + authenticated (policies need it; it only answers about the caller).
- trigger and helper functions are not executable by clients.

## Privacy and abuse decisions (from the Codex audit, 2026-11-10)
- `profiles.phone` and customer data are private to the owner.
- **Contact phones cannot be scraped.** `professional_profiles.contact_phone` is not selectable by any client role. A registered user reveals one published professional's phone at a time with `reveal_professional_contact()`, limited to 40 per hour, and every reveal is logged. (The log also becomes the "contact" analytic later.)
- **Coordinates are approximate by design:** rounded to 2 decimals (~1.1 km) by a trigger, so a home-based professional is not pinpointed. The UI must present it as an area, never a pin on a house.
- **Verification means something:** changing the business name or contact phone withdraws a verified badge until an admin re-verifies.
- **No half-empty public profile:** publishing requires an active category, a description (>= 20 chars), a governorate and a contact phone. Inactive categories cannot be newly assigned or published with.
- **Categories cannot be created through the API.** A rejected INSERT still consumes an identity value, so a direct insert grant would let anyone exhaust the sequence. Creation is a migration/service-role action until the admin RPC in Phase 7. Clients hold no privileges on any sequence.
- **Anonymous sign-ins must stay disabled** in Supabase Auth settings. If they were ever enabled, such users get the `authenticated` role; the sensitive functions already refuse them (`is_anonymous`), and a test covers it.
- **Accepted:** anyone can list published professionals' ids (needed for browsing); no emails are exposed. The sign-up trigger must never raise (a failure blocks registration): a test feeds it hostile metadata.
- A profile cannot be published unless it has a category, a description (>= 20 chars), a governorate and a contact phone.
- Deleting an auth user cascades to all their rows.

## Authentication (app side, Phase 2.3)
- **Tokens live in secure storage.** The Supabase session and the PKCE code verifier are kept in Keychain / encrypted storage (`flutter_secure_storage`), not in `shared_preferences` (the SDK default, plain text in the app sandbox). Tests prove nothing reaches preferences.
- **Password reset is completable in the app.** The email link opens the app through the `tn.khidma.app://auth-callback` scheme (registered on Android and iOS; Flutter's own deep-link handling is switched off so the link is not also pushed into the router), the SDK creates a recovery session (PKCE), and the new-password screen calls `updateUser`. Without a recovery session the screen says the link expired.
- **No account enumeration from the UI.** Reset shows the same message whether or not the address exists; invalid credentials never say which part was wrong; sign-up copy does not reveal existing addresses.
- **Password rules match the server:** at least 8 Unicode characters, at most 72 UTF-8 bytes (Arabic letters count 2 bytes).
- **Errors and logs:** error messages from the server are never shown or forwarded (mapped to localized categories); release builds log nothing, debug builds log only the error type.
- **Autofill** offers to save credentials only after a successful sign-in.

### Supabase dashboard settings the owner must set (cannot be done from code)
1. Authentication > URL Configuration > **Additional Redirect URLs**: add exactly `tn.khidma.app://auth-callback` (no trailing slash). Set **Site URL** to the production web URL.
2. Authentication > Providers > Email: **Confirm email ON** (hides whether an address is registered); minimum password length 8; enable leaked-password protection if the plan allows.
3. Authentication > Sign In / Providers: **Anonymous sign-ins OFF**.
4. Rate limits: keep the defaults or tighter; the app shows a "too many attempts" message.
5. Provide the project URL and publishable key in `app/config/dev.json` (issue #6). Never the secret / service-role key.

Not yet verified against a real project: the end-to-end link flow on a device, token refresh failure behavior, and exactly which duplicate-signup responses the deployed settings produce.

## How it is tested
`backend/tests` runs the real migrations on PGlite (Postgres compiled to WebAssembly) with a Supabase stub (roles, `auth.uid()`, the permissive default grants). Tests act as `anon` and as `authenticated` users with different JWT subjects. Structural guards fail the build if a new table lacks RLS, if the table or column privilege matrix drifts, if a definer function lacks a pinned `search_path`, or if function EXECUTE rights change. The suite was mutation-tested: removing a revoke, disabling RLS, widening a column grant, trusting metadata roles, un-pinning a search_path, exposing `contact_phone` and relaxing the publish check were each caught.

The suite was mutation-tested twice (19 mutations: revokes removed, RLS disabled, column grants widened, metadata trusted, search_path unpinned, phone exposed, rate limit removed, anonymous-auth accepted, sequences left open, a leaky function added, ...); every one was caught.

Limits: PGlite is not a full Supabase stack (no Auth service, Storage, PostGIS or realtime). Storage policies, Edge Functions and JWT handling need testing against a real Supabase project (blocked on issue #6). Seed names, especially Arabic, need native-speaker review.
