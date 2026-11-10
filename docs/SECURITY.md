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
- **Password reset is completable in the app.** The email link opens the app through the `tn.khidma.app://auth-callback` scheme (registered on Android and iOS; Flutter's own deep-link handling is switched off so the link is not also pushed into the router), the SDK creates a recovery session (PKCE), and the new-password screen calls `updateUser`. Without any session the screen says the link expired. (With a session of any kind the form works as an ordinary "change password" screen; the server's own rules, e.g. requiring a recent login for password changes, apply.)
- **No account enumeration from the UI.** Reset shows the same message whether or not the address exists; invalid credentials never say which part was wrong; sign-up copy does not reveal existing addresses.
- **Password rules match the server:** at least 8 Unicode characters, at most 72 UTF-8 bytes (Arabic letters count 2 bytes).
- **Errors and logs:** error messages from the server are never shown or forwarded (mapped to localized categories); release builds log nothing, debug builds log only the error type.
- **Autofill** offers to save credentials only after a successful sign-in.

### Account deletion (Phase 2.7, App Store 5.1.1(v))
- Profile > "Delete my account" opens a confirmation that explains the consequences and requires typing a localized word (SUPPRIMER / DELETE / حذف); Cancel changes nothing.
- The app calls `delete_my_account()`: a `SECURITY DEFINER` function with no arguments (a person can only delete themselves), executable by registered users only (not anon, not anonymous-auth). It deletes the caller from `auth.users`, and every row cascades. A backend test lists every user-id column in `public` and proves nothing is left, including reveal-log rows about the person.
- If the server call fails, nothing is deleted and the person stays signed in with an error message. On success the app signs out locally and forgets the device's pending account choice.
- **Not done / to verify on the real project:** the function assumes its owner may delete from `auth.users` (true on hosted Supabase, to be confirmed in issue #6; otherwise use an Edge Function with the admin API). Revoking the Apple token on deletion needs a server-side Edge Function holding the owner's Apple key (issue #32 stays open for it). Any future table with personal data must cascade from `profiles`/`auth.users`.

### Sign in with Apple (app side, Phase 2.4)
- iOS only. Flow: a fresh random nonce per attempt; Apple receives its SHA-256, Supabase receives the original and checks that they match (replay protection); the Apple identity token is exchanged with `signInWithIdToken`. Tests assert hash vs original on the wire, that a missing token sends nothing, and that closing Apple's sheet is a silent cancel, not an error.
- Apple shares the person's name only on the first sign-in; the app stores it in the auth metadata when given. Apple users start with no profile name until they edit it.
- The name Apple shares is saved to the profile only when the profile has no name yet (never overwrites what the person typed), as a suggestion capped at 120 characters.
- Account type chosen on the register screen is applied through the same single coordinator as email sign-ups (identity-bound pending choice), not by a second direct call.
- Known gaps (tracked in issue #32): in-app account deletion and Apple token revocation; automatic linking when someone signs in with Apple's "Hide My Email" relay address and also has a password account (Supabase links only verified identical emails, so a relay address creates a separate account; explicit identity linking is future work).
- The button follows Apple's style (black in light mode, white in dark) and is hidden when no backend is configured or off iOS.
- `ios/Runner/Runner.entitlements` declares the Sign in with Apple capability and the Runner target points at it.
- **Owner steps (needs an Apple Developer account and a Mac):** enable the *Sign in with Apple* capability for the app id `tn.khidma.khidma`; in Supabase > Authentication > Providers > Apple add the iOS bundle id as an authorized client id; build and test on a device. None of this has been verified on a device.

### Account type and roles (app side, Phase 2.5)
- Sign-up offers two choices only: find a professional, or offer services. There is no admin option anywhere in the app; admins exist only as rows created by the platform owner.
- "Offer services" is applied by calling `become_professional()` (the database ignores roles in sign-up metadata). With email confirmation there is no session at sign-up, so the choice is kept on the device as a *pending choice* and applied on the first session.
- A pending choice is **bound to the sign-up email** (case-insensitive), expires after 7 days, and is applied only when that same account has a session. Another person signing in on the same device neither triggers nor erases it. Clearing happens only if it is still the same choice for the same signed-in user.
- The Profile screen always offers the same action manually ("Become a professional"), so a lost or expired choice costs one tap.
- The UI shows only the profile of the account signed in *now* (`visibleProfileProvider`): while a different account's profile loads or fails, nothing of the previous one is shown, and edit forms are keyed by account id.
- Profile writes send exactly three fields (`full_name`, `phone`, `preferred_language`), filtered by the user's id; the transport tests assert this against the real Supabase client.

### Supabase dashboard settings the owner must set (cannot be done from code)
1. Authentication > URL Configuration > **Additional Redirect URLs**: add exactly `tn.khidma.app://auth-callback` (no trailing slash). Set **Site URL** to the production web URL.
2. Authentication > Providers > Email: **Confirm email ON** (hides whether an address is registered); minimum password length 8; enable leaked-password protection if the plan allows.
3. Authentication > Sign In / Providers: **Anonymous sign-ins OFF**.
4. Rate limits: keep the defaults or tighter; the app shows a "too many attempts" message.
5. Provide the project URL and publishable key in `app/config/dev.json` (issue #6). Never the secret / service-role key.

Not yet verified against a real project: the end-to-end link flow on a device, token refresh failure behavior, and exactly which duplicate-signup responses the deployed settings produce.

### Operational notes
- The phone-reveal rate limit takes a per-caller advisory lock before counting, so concurrent requests cannot all pass; true concurrency can only be exercised on a real Postgres.
- The Supabase SDK's own debug logger is disabled; the app prints only error types, and only in debug builds.
- CI compiles the web, Android (debug) and, allowed to fail until seen green, iOS builds, and runs backend tests; it cannot validate deployed Supabase behavior (function ownership, Auth callbacks, PostgREST). A real-project integration gate is a follow-up once issue #6 is done.

## How it is tested
`backend/tests` runs the real migrations on PGlite (Postgres compiled to WebAssembly) with a Supabase stub (roles, `auth.uid()`, the permissive default grants). Tests act as `anon` and as `authenticated` users with different JWT subjects. Structural guards fail the build if a new table lacks RLS, if the table or column privilege matrix drifts, if a definer function lacks a pinned `search_path`, or if function EXECUTE rights change. The suite was mutation-tested: removing a revoke, disabling RLS, widening a column grant, trusting metadata roles, un-pinning a search_path, exposing `contact_phone` and relaxing the publish check were each caught.

The suite was mutation-tested twice (19 mutations: revokes removed, RLS disabled, column grants widened, metadata trusted, search_path unpinned, phone exposed, rate limit removed, anonymous-auth accepted, sequences left open, a leaky function added, ...); every one was caught.

Limits: PGlite is not a full Supabase stack (no Auth service, Storage, PostGIS or realtime). Storage policies, Edge Functions and JWT handling need testing against a real Supabase project (blocked on issue #6). Seed names, especially Arabic, need native-speaker review.
