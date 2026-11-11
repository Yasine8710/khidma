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
| quote_requests | - | - | R own, and those they offered on; no direct writes | R all |
| quote_offers | - | - | R own offers, and offers on own requests (never a rival's); no direct writes | R all |
| bookings | - | - | R as customer or professional; no direct writes | R all |
| favorites | - | - | R, C, D own only (registered accounts, published professionals, max 200, one insert at a time per user) | no access |

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

### Marketplace data (Phase 3.1)
- Search and reference-data reads work for anonymous visitors and are protected by RLS and column grants, not by the app. A published profile needs a public name (profiles are private, so `business_name` is the only name shown).
- **Demo data** (made-up businesses, ratings and verification badges) exists only in debug builds or with `--dart-define=DEMO_DATA=true`, never in a normal release, and the UI must show a visible "demo" notice whenever it is on (enforced in the Home slice, issue #13, with a test). `DEMO_DATA=true` in a release is for screenshots only and must not be distributed.
- Permission failures from the database (`42501`) surface as "forbidden", not as "signed out", so broken grants are not mistaken for an expired session.

### Location (Phase 3.6)
- Only an approximate position (rounded to ~1 km) is used, in memory only, for 10 minutes; it is sent only as search parameters. Android requests coarse location only; iOS asks when-in-use with reduced accuracy by default.
- **Before an App Store upload (needs a Mac):** confirm the release binary does not reference `requestAlwaysAuthorization` (geolocator's `BYPASS_PERMISSION_LOCATION_ALWAYS=1`, set in CI, may not be honoured under Swift Package Manager; known upstream issue). If Apple reports ITMS-90683, add an honest `NSLocationAlwaysAndWhenInUseUsageDescription` ("not used") as the fallback.

### Requests, offers, bookings (Phase 5.1)
- Clients only read these tables (RLS); every change goes through a `SECURITY DEFINER` function that checks the caller and the allowed transition (request: open -> awarded/cancelled/expired; offer: pending -> accepted/declined/withdrawn; booking: scheduled -> in_progress -> pending_confirmation -> completed, or cancelled while scheduled/in progress).
- `accept_offer` locks the request row first, so two accepts, or an accept and a cancel, cannot both win. The customer, not the professional, confirms completion (reviews will be tied to completed bookings).
- Professionals discover open requests with `list_open_requests()`, which never returns who asked. Rate limits: 5 requests per hour and 10 open per customer; 50 pending offers per professional.
- `expire_stale_requests()` is for a scheduled job running as the service role (not callable by clients): to be scheduled when the project exists.
- `quote_requests.customer_id` is not selectable by any client: a professional who offered cannot learn who asked until a booking exists (bookings name both parties).
- Deleting an account deletes its requests, offers and bookings (cascade), including those the other party was involved in; requests a leaving professional had won become `cancelled` rather than staying `awarded` without a booking.

### Request photos (Phase 5.2)
- The `request-photos` bucket is private (signed links, one hour). Readers: the owner; published professionals while the request is open; a professional while their own offer is pending or accepted. Photos of a closed request cannot be deleted. Account deletion removes the object rows.
- Upload quotas (60 files per customer here, 16 per professional for the portfolio) are counted from a snapshot, so a burst of parallel uploads can overshoot slightly; the server-side sweep planned in #32 should also delete files no row points to.

### Messaging (Phase 6.1)
- A conversation hangs on one offer; either side opens it, nobody else can. Customers are anonymous to professionals: no user id is selectable on `conversations` or `messages` (messages carry only a role flag, so realtime payloads leak nothing), and the inbox function shows a professional's public name but never the customer's.
- Clients only read (RLS by membership); `send_message` checks membership, that the offer is pending/accepted and the request open (not expired) or awarded, and rate limits to 30 per minute. Closed conversations are read-only, including image uploads.
- Images: private `chat-images` bucket (2 MB, jpeg/png/webp), members only, 100 per conversation; an upload no message points to can be removed. Read markers are message ids set only up to what was shown.
- Deleting an account removes its conversations and the matching object rows (bytes: server-side cleanup, #32).

### Notifications (Phase 6.2)
- Events write to `notification_outbox` in the same transaction (triggers on offers, messages, bookings); a row holds a kind and ids only, never text, names or message content. Push texts are built from the kind in the recipient's language. Preferences (offers/messages/jobs) are honoured when enqueueing; messages notify once per unread burst.
- The delivery worker is an Edge Function using the service role (`claim_notifications`, `complete_notification` fenced by attempt number, retries with backoff, given up after 5 attempts). Clients cannot read the outbox or the tokens.
- A device token belongs to one account at a time: signing out unregisters it first; if that fails it moves on the next sign-in, and is dropped after 60 days unseen. Residual risk: a signed-out phone that could not unregister may still show generic pushes (no content) until then.
- **Owner step (#26):** create a Firebase project, add APNs auth key, put the service-account JSON in the Edge Function secrets, add `firebase_messaging` and the platform files, implement `PushService`, schedule the function. The Edge Function has not been run.

### Reviews (Phase 6.3)
- One review per person per completed job, written through `submit_review` (checks the job is completed and the caller took part); at most 3 per author about one subject (anti-farming). Only reviews a customer wrote about the job's professional are public and count towards the rating; the other direction stays private (not selectable by anyone but moderators).
- Public columns: rating, comment, month and an ordering counter; never author, job or exact time. Ratings are recomputed by a trigger serialized per professional; clients cannot write them. Admins hide reviews through `admin_set_review_status` (hidden ones leave the list and the average).

### Verification and reports (Phase 6.4)
- Verification documents (photos, up to 3 per request) live in the private `verification-docs` bucket: only the owner can read them through Storage (at most 6 files, counted under a per-user lock), and a file attached to a request cannot be deleted by its owner. Requests are not readable by clients at all; the owner uses `my_verification()`, admins the `admin_*` functions. One pending request at a time, at most 3 per 30 days.
- Only the reviewed workflow sets the public "verified" status: `admin_review_verification` is the only caller of `admin_set_verification`, which clients can no longer execute. A rejection needs a reason (shown to the owner).
- **Admins do not read documents through Storage** (there is no admin Storage policy), so the audit cannot be bypassed: the dashboard's server-side signer (service role, to be built with #29) must call `admin_verification_documents` (which logs the view) and then sign links. The same signer is how admins view images of a reported chat.
- **Files are never deleted from SQL.** Supabase rejects direct deletes on `storage.objects`, so decisions, cancellation and account deletion put names in `storage_cleanup_queue` (service role only); the worker in #32 deletes them through the Storage API. Until it runs, queued files stay in the bucket but no longer count against the owner's allowance. (Earlier slices' account-deletion migrations deleted storage rows directly; the latest `delete_my_account` replaces them and queues instead.)
- Reports: `report_content` accepts a published professional (not yourself), a public review written by someone else, or a conversation you belong to; 10 per day, one open report per reporter and target. The reporter is never exposed to the reported person, and the admin queue does not show reporters. Reading a reported conversation (last 50 messages) is an explicit admin action and is audited.
- Admins can suspend a professional (unpublishes; the owner cannot republish while suspended). Every admin action (verification, suspension, report handling, review moderation, document viewing) is written to `admin_audit_log`, readable only through `admin_audit_log_page`.
- Residual: the delete-versus-submit race is closed with a row lock plus a re-check, which needs real Postgres to exercise (PGlite is single-connection). The app only offers photos (the bucket also accepts PDF). A second factor for admin sessions is an owner step for the dashboard (#29).

### Admin dashboard (Phase 7)
- Admin means a row in `admin_users` **and** a second-factor session: `is_admin()` also requires the JWT claim `aal = 'aal2'` while `admin_config.require_mfa` is on (default). A stolen password alone opens nothing, in the dashboard or through the API. The flag is unreachable by clients; turning it off in production is an owner decision (the tests switch it off, and one test checks it works when on).
- The dashboard has no table access: every list and action is an `admin_*` function (definer, `search_path` pinned, paged and capped at 200 rows, wildcard characters in searches escaped). Lists show names and ids, never phone numbers or message bodies; reading a conversation is a separate, audited action. Mutations (verification, reports, suspension, review moderation, categories) are written to `admin_audit_log`.
- Documents and chat images come from the `admin-media` Edge Function: it calls the audited function **as the caller** (so the database enforces admin + MFA and logs the view), re-validates every path, and signs for 120 seconds with the service role. CORS allows only `ADMIN_ORIGIN`.
- The app keeps its session in `sessionStorage` (closing the tab signs out), ships a strict CSP (own scripts only, Supabase for connect/img), and links open with `rel="noreferrer noopener"`.
- Not verified live: sign-in, TOTP enrollment, the Edge Function and signed links (need a real Supabase project, #6). Residual: no rate limit on admin sign-in beyond Supabase Auth's own; account recovery for a lost authenticator is a manual SQL step for the owner.

### Full security pass (Phase 8, #30)
Codex audited every migration, both Edge Functions and the app's data layer. Fixed: request-photo folders now use a private alias (`my_file_alias()`), not the account id, because a professional can read a photo row's path; a pending verification is withdrawn when the business name or phone changes; the review pair cap takes a per-pair lock; the notification worker refuses callers without `NOTIFY_SECRET`; admin dependencies upgraded (`npm audit --omit=dev` is clean).

Known residuals, all waiting on the server-side worker of #32 or a real Supabase project:
- **Signed upload URLs can pre-reserve names**, so per-user file counts (6 verification files, 16 portfolio, 60 request photos) can be overshot by someone who creates many signed upload tokens first. The cleanup sweep must delete files no row points to, and the bucket size limits still apply per file.
- **Public portfolio files of a deleted account stay reachable** by their URL until the cleanup worker removes the queued files (SQL cannot delete storage rows).
- The remaining `npm audit` findings are dev-only tooling (vitest worker and vite dev server): they cannot run in production, and tests only load our own code.
- Concurrency fixes (review pair lock, verification file locks, upload quota lock) are checked structurally; a true parallel test needs a real Postgres.

### Operational notes
- The phone-reveal rate limit takes a per-caller advisory lock before counting, so concurrent requests cannot all pass; true concurrency can only be exercised on a real Postgres.
- The Supabase SDK's own debug logger is disabled; the app prints only error types, and only in debug builds.
- CI compiles the web, Android (debug) and, allowed to fail until seen green, iOS builds, and runs backend tests; it cannot validate deployed Supabase behavior (function ownership, Auth callbacks, PostgREST). A real-project integration gate is a follow-up once issue #6 is done.

## How it is tested
`backend/tests` runs the real migrations on PGlite (Postgres compiled to WebAssembly) with a Supabase stub (roles, `auth.uid()`, the permissive default grants). Tests act as `anon` and as `authenticated` users with different JWT subjects. Structural guards fail the build if a new table lacks RLS, if the table or column privilege matrix drifts, if a definer function lacks a pinned `search_path`, or if function EXECUTE rights change. The suite was mutation-tested: removing a revoke, disabling RLS, widening a column grant, trusting metadata roles, un-pinning a search_path, exposing `contact_phone` and relaxing the publish check were each caught.

The suite was mutation-tested twice (19 mutations: revokes removed, RLS disabled, column grants widened, metadata trusted, search_path unpinned, phone exposed, rate limit removed, anonymous-auth accepted, sequences left open, a leaky function added, ...); every one was caught.

Limits: PGlite is not a full Supabase stack (no Auth service, Storage, PostGIS or realtime). Storage policies, Edge Functions and JWT handling need testing against a real Supabase project (blocked on issue #6). Seed names, especially Arabic, need native-speaker review.

### Storage cleanup worker (issue #34, free)
`backend/supabase/functions/storage-cleanup` removes the files queued in `storage_cleanup_queue` (account deletion, cancelled requests, verification decisions) through the Storage API, then the queue rows. It only touches the four known buckets, refuses empty or path-escaping names, handles at most 200 rows per run and keeps rows of a failed bucket for the next run. Callers need `Authorization: Bearer <CLEANUP_SECRET>` (16+ characters, compared in constant time). Schedule it every few minutes (Dashboard > Integrations > Cron). Logic and secret check are tested in `backend/tests/storage_cleanup.test.mjs`; the deployed behaviour is not verified yet.
