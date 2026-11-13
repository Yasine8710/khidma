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

### Trust v2: scam reports, suspension, badge rules (#54, migration 2000)
- Reports also cover an offer (only the customer who received it) and one message (only the other member of the conversation). New reasons: `pay_outside`, `no_show`. Evidence is text only (500 chars); no extra files are stored.
- Each report records its subject (the person it is about). Limits against weaponised reporting: 10 reports per reporter per 24 h, one open report per target, at most 3 reports by one person on the same subject per 30 days. The queue sorts by distinct reporters on the subject; 3 or more in 30 days sets `flagged`. Nothing is suspended automatically.
- `admin_suspend(user, days | null, reason, report?)`: unpublishes the profile and freelance listing, withdraws pending offers and, when started from a report, closes every open report on that person. The reason is shown to the professional. Triggers on `quote_offers`, `conversations` and `messages` refuse new rows from a suspended professional, whatever function writes them. Booked jobs keep their chat for the customer.
- A timed suspension ends on its own: writes are allowed again once the time is up, the owner's `my_account_status()` lifts it, and `service_lift_expired_suspensions()` (service role, every 15 minutes) clears the rest. Lifting never republishes. System lifts are not written to the admin audit log (it records admin actions only).
- Appeals: one open appeal at a time, a week's wait after a rejection, decided in the admin panel (Appeals tab) and audited.
- Reporters get an outcome notice (`report_actioned` or `report_dismissed`) with an empty payload: never the note or what was done. Account notices use the `account` category, which ignores notification preferences.
- Badge: verification is valid 365 days (`verified_until`, a Tunis date, public). `badge_valid()` gates the search output and freelance visibility, the app hides a badge past its date, and `service_expire_verifications()` (service role, daily) turns expired ones back to unverified with a notice. Admins can revoke a badge (`revoked`, reason required, audited). The profile shows "Identity verified, valid until ..."; no document data is ever shown.
- Owner step: enable `pg_cron` (Database > Extensions) **before** running migration 2000 so the two jobs are scheduled; otherwise schedule both `service_*` functions with any daily or 15-minute cron.

### Freelance moderation (#67, migration 2100)
- Prohibited services (illegal services, academic cheating, fake documents, plagiarised portfolios, selling accounts or fake reviews) are listed in the app in FR/AR/EN: agreed to before every publication and linked from the report form for freelance listings and testimonials.
- `admin_hold_freelancer(user, reason, report?)` unpublishes a freelance listing and puts it on hold (`admin_hold_reason`, shown to the owner only: a held listing is unpublished, so no one else can read its row, and visitors have no grant). A trigger refuses republishing while held; `admin_release_freelancer` lifts it. From a report, the report is closed as actioned and its reporter told. Both actions are audited and send the owner a notice. The local professional profile is not touched (that is what suspension is for).

### Admin billing (#65, migration 2200)
- `admin_billing_summary()` (MRR = running subscriptions normalised to 30 days, in millimes; active, past_due, expired, cancelled; payments waiting and waiting over 48 h), `admin_list_subscriptions(status)`, `admin_billing_detail(user)` (subscription + last 50 orders). A period that ended counts as past_due even before the daily job.
- Corrective actions, reason required and audited: `admin_extend_subscription(user, 1-60 days)` (extend grace, comp a month; starts a subscription on the cheapest plan if there is none) and `admin_set_subscription_status(user, active | cancelled)` (reactivating is refused once the period is over: extend instead).
- All refuse non-admins and visitors (admin_billing tests and the rls_matrix admin sweep). Admin panel: Billing tab.

## Security audit (#55, 2026-11-13)

### Threat model (STRIDE)
Components: iOS app (Flutter), Supabase Auth, PostgREST + Postgres (RLS), Storage (6 buckets), Edge Functions (admin-media, send-notifications, storage-cleanup, flouci-payments), admin web (React, local), testimonial page (Vercel), payment callbacks (Flouci, manual D17/bank).

| Threat | Where | Mitigation (evidence) |
|---|---|---|
| **S**poofing a user | Auth, PostgREST | Supabase JWT; `auth.uid()` in every policy; anonymous sessions refused by `require_registered_user()`; roles never from metadata (tests: profiles, contact_and_integrity) |
| Spoofing an admin | admin web, `is_admin()` | row in `admin_users` (no client path) + `aal2` (TOTP) via `admin_config.require_mfa` (admin_dashboard tests) |
| Spoofing a payment callback | flouci-payments | callback re-verifies the payment with Flouci server-to-server; idempotent `payment_events` key (flouci_logic tests) |
| **T**ampering with rows | PostgREST | column-limited UPDATE grants, RLS USING + WITH CHECK, state machines in definer functions (rls_matrix: mass assignment, stranger updates/deletes) |
| Tampering with files | Storage | per-bucket folder policies (`<uid>/...`, conversation or alias folders); no admin Storage policy (rls_matrix: storage guessing) |
| **R**epudiation by admins | admin actions | append-only `admin_audit_log`, written by every admin function; document and chat views logged |
| **I**nformation disclosure: contact, identity docs | `professional_profiles`, `verification-docs` | `contact_phone`/`verified_at` not granted; reveal RPC rate-limited (40/h) and logged; docs private, deleted after decision |
| Disclosure across tenants (IDOR) | RPCs, tables | id-taking functions re-check membership (rls_matrix: IDOR sweep over every 1-uuid function; admin sweep) |
| Disclosure through push | send-notifications | payloads carry ids only; texts built from the kind (notification_texts tests) |
| **D**enial of service / abuse | RPCs, uploads | per-user limits in functions (requests, offers, messages, reports, reveals, photos); see #56 for the full table |
| **E**levation of privilege | SECURITY DEFINER | every definer function pins `search_path = ''`; EXECUTE matrix pinned; non-admins refused by every `admin_*` (contact_and_integrity, rls_matrix) |

### Automated RLS and API pen-test
`backend/tests/rls_matrix.test.mjs` builds a world with at least one row in **every** table (two professionals, one hidden and suspended, a customer, a full job with chat and review, freelance rows, payments, reports, verification, appeal) and then checks, as a visitor, a registered stranger, the owners and an admin session:
- every table is classified (reference / public / private / closed); a new table fails until classified;
- the exact column grants of `anon` and `authenticated` match a reviewed snapshot;
- public tables show visitors and strangers the same rows and nothing of a hidden owner; private tables show strangers nothing and the owner something; closed tables are denied to every client role;
- a stranger's every granted UPDATE and DELETE touches zero rows; inserts in someone else's name are denied; owners cannot write any column outside their grant;
- Storage: a stranger lists no object in any bucket and cannot write into another user's, conversation's or request's folder;
- every `admin_*` function refuses non-admins and visitors; every function taking one uuid, called by a stranger with real ids, returns nothing and changes nothing.
Mutation check: 9 planted holes (open bookings policy, readable reports, admin function without check, IDOR peek function, unclassified table, Storage list-all policy, public hidden portfolio, stranger booking updates, favorites for others) were all caught.

### MASVS L1 checklist (iOS app)
| Control | Status | Evidence |
|---|---|---|
| STORAGE-1 sensitive data stored securely | pass | session and PKCE verifier in Keychain (`secure_auth_storage.dart`, `main.dart` authOptions); shared preferences hold only locale, theme, onboarding flag, recently viewed and local favorites ids |
| STORAGE-2 no sensitive data in logs or backups | pass | Supabase SDK `debug: false`; `_log` prints error types only, debug builds only |
| CRYPTO-1/2 strong, standard crypto | pass / n.a. | no custom crypto; TLS by the platform; tokens and hashes server-side (invite tokens stored as SHA-256) |
| AUTH-1 secure auth and session | pass | Supabase Auth with PKCE; refresh tokens rotate; account deletion in-app (5.1.1(v)) |
| AUTH-2 local auth | n.a. | no biometric unlock |
| AUTH-3 extra auth for sensitive operations | partial | admin requires TOTP (aal2); app users single factor (MFA for professionals is #57) |
| NETWORK-1 secure traffic | pass | `SUPABASE_URL` must be https (`app_config.dart`); no ATS exceptions in `Info.plist` |
| NETWORK-2 identity pinning | accepted risk | no certificate pinning: Supabase and Google rotate certificates; ATS + system trust store. Revisit with #57 |
| PLATFORM-1 IPC / deep links | pass | one URL scheme (auth callback) handled by supabase_flutter; `FlutterDeepLinkingEnabled = false`, so links cannot drive the router |
| PLATFORM-2 WebViews | n.a. | none |
| PLATFORM-3 UI and external links | pass | only https links leave the app (`freelancer_screen.dart`, DB check on portfolio URLs); tel/WhatsApp built from validated numbers |
| CODE-1/2 platform and dependencies current | pass | direct pub deps up to date; 162 pub packages checked on OSV: 0 advisories; Dependabot config added |
| CODE-3 input validation | pass | every write goes through typed RPCs or column grants with DB checks |
| CODE-4 obfuscation | out of L1 scope | release builds are not obfuscated yet; add `--obfuscate --split-debug-info` with #31 |
| PRIVACY | pass | `PrivacyInfo.xcprivacy`; month-only review dates; customers' ids hidden from professionals (`customer_id` not granted) |

### Dependency audit
| Part | Tool | Result |
|---|---|---|
| app (Flutter) | `flutter pub outdated`, OSV batch query on `pubspec.lock` | direct deps current; 0 advisories (162 packages) |
| admin | `npm audit` | was 2 critical + 1 moderate (dev only: vitest 3.2.7 / tinypool, @vitest/mocker); fixed with vitest 4.1.12 (released 2026-10-15). `.npmrc` sets `legacy-peer-deps` because npm 10 crashes resolving vitest 4's optional peers; `@testing-library/dom` is now an explicit dev dependency. Now 0 |
| backend tests | `npm audit` | 0 |
| Edge Functions | review | imported `supabase-js@2` (floating major); pinned to `npm:@supabase/supabase-js@2.119.0` |
| testimonial page | review | static HTML, no dependencies |
Dependabot (`.github/dependabot.yml`) opens weekly update PRs for pub, admin, backend and monthly for Actions. The owner should also enable Dependabot alerts and security updates in the repository settings.

### Findings
| # | Severity | Finding | Status |
|---|---|---|---|
| A1 | high | A suspended professional could still send messages (no check in `send_message`) | fixed in #54 (triggers on offers, conversations, messages) |
| A2 | medium | Admin dev toolchain had critical advisories (tinypool RCE gadget via vitest) | fixed: vitest 4.1.12 |
| A3 | medium | Edge Functions imported a floating `supabase-js@2` (supply chain) | fixed: pinned 2.119.0; **redeploy storage-cleanup** (live) to pick it up |
| A4 | low | Column SELECT grants were not pinned by a test (only UPDATE/INSERT) | fixed: full snapshot in `rls_matrix` |
| A5 | low | An expired badge blocked renewal until the daily job ran | fixed in #54 |
| A6 | low | INSERT grants on favorites, portfolio, services, areas, request photos include `created_at`/`id`: an owner can backdate their own rows | accepted (own data only, no cross-tenant effect) |
| A7 | low | Customers cannot be suspended, only reported | open: follow-up with #53 levels |
| A8 | info | No certificate pinning | accepted risk (see NETWORK-2) |
| A9 | info | Release builds not obfuscated | open: with #31 |
| A10 | info | Concurrency (advisory-lock races) cannot be exercised on PGlite | open: needs a real Postgres run (#6) |
| A11 | info | CI cannot run (GitHub billing lock, #5), so the suites run locally only | open: owner |

## Abuse protection and operations (#56)

### Limits
Database limits raise `P0001 rate_limited` (or `limit_reached`); PostgREST answers HTTP 400 with that tag, and the app shows a "too many, try later" message (`RequestsFailure.rateLimited`). HTTP 429 only comes from Supabase Auth's own limits.

| What | Limit | Test |
|---|---|---|
| Phone reveals (professionals + freelancers, one budget) | 40 per hour per user | contact_and_integrity, limits |
| Quote requests | 5 per hour, 10 open | requests |
| Offers | 50 pending per professional (withdrawing does not reset) | requests |
| Messages | 30 per minute per sender | messaging |
| Chat images | 100 per conversation, 2 MB, jpeg/png/webp | messaging |
| Request photos | 5 per request, 60 files per person, 2 MB | request_photos |
| Portfolio | 12 items, 16 files, 2 MB | portfolio |
| Freelance portfolio | 24 items; media 25 MB, images + mp4/webm | freelance, limits |
| Avatars | 1 MB, images | avatars, limits |
| Verification | 6 files, 5 MB (images + pdf), 3 requests per 30 days | verification_reports |
| Reviews | 3 per author per subject | reviews |
| Reports | 10 per day, 1 open per target, 3 per person per 30 days | verification_reports, trust_v2 |
| Appeals | 1 open, 7 days after a rejection | trust_v2 |
| Favorites | 200 per user | favorites |
| Testimonial invites | 20 open per freelancer (each single use) | freelance |
| Payment orders | 10 per 24 hours (same unpaid order is reused) | limits |
| Device tokens | 10 per account (newest kept) | notifications |
| Search | 50 rows a page, offset up to 5000, query 100 characters | search_semantics |

Not limited in SQL (no client IP is visible to Postgres): anonymous search and reference reads. Supabase's role `statement_timeout` (anon 3 s, authenticated 8 s by default) bounds each call; put Cloudflare in front if scraping appears. Edge Functions: `send-notifications` and `storage-cleanup` need a 16+ character bearer secret, `admin-media` an admin `aal2` session, `flouci-payments` a valid signature checked before any outbound call. No per-IP limiter: function instances are short-lived, so an in-memory counter would not hold.

**Owner (dashboard, Authentication > Rate limits)**: keep the defaults or lower them (e-mails sent per hour, sign-ups and sign-ins per 5 minutes per IP, token refreshes, OTP / verification per hour). CAPTCHA (Turnstile is free) on sign-up and password reset if fake sign-ups appear; the app would then need to pass `captchaToken`.

### Secrets
- Clients ship only the Supabase URL and the publishable key (`app_config.dart` refuses `sb_secret_` and service-role keys). Secrets live in Supabase Edge Function secrets (`NOTIFY_SECRET`, `CLEANUP_SECRET`, `FLOUCI_*`), Codemagic's `khidma` group (dart-defines) and gitignored `app/config/dev.json` / `admin/.env.local`.
- Scanning: `.gitleaks.toml` (default rules + Supabase key shapes, test fixtures allowlisted), a CI job `secrets` (gitleaks v8.30.1 over the full history; CI runs once #5 is cleared) and `scripts/hooks/pre-commit` (enable with `git config core.hooksPath scripts/hooks`; needs gitleaks installed: `winget install Gitleaks.Gitleaks`).
- History check, 2026-11-13: all 172 commits scanned for Supabase secret keys and access tokens, JWTs, private keys, AWS/Google/GitHub/Slack tokens and URLs with passwords. Only hit: the fake `sb_secret_abcDEF123` in `app_config_test.dart` (it tests that such keys are refused).
- Rotation: (1) create the new key or secret; (2) update it where it is used (Supabase secrets with `supabase secrets set`, Codemagic group, local files); (3) redeploy the functions, rebuild the app if a dart-define changed; (4) revoke the old one; (5) note it in the audit table below. The database password was last rotated on 2026-11-11. Supabase access tokens (`sbp_`) are created for one session and revoked after.

### Logging and monitoring
- App: Sentry, **off unless built with `--dart-define=SENTRY_DSN=...`** (`lib/core/monitoring/error_reporting.dart`). It uses the pure Dart SDK (Dart errors only, no native crash reports, nothing native to build). Events carry no user, request, breadcrumbs or device name; e-mails, phone-like numbers and tokens are scrubbed from messages (tested). `--dart-define=SENTRY_TEST_EVENT=true` sends one test message at startup.
- Admin: the same, with `VITE_SENTRY_DSN`; the SDK is loaded only when it is set and collects no user, cookies, headers, query strings or bodies.
- Edge Functions write no logs containing request bodies, tokens or personal data (none of them call `console.*`); Supabase keeps its own invocation logs.
- **Owner**: create a free Sentry project (EU region), put the DSN in the Codemagic group as `SENTRY_DSN`, build once with `SENTRY_TEST_EVENT=true` and check the alert e-mail arrives. Add alert rules: new issue, more than 20 events in 1 hour. In Supabase, Reports and Logs cover auth failures, 5xx and Edge Function errors; set an e-mail alert on Edge Function error rate if the plan offers it. When Sentry is on, add "Crash data" to the App Store privacy labels (#61).

### Backup and restore
- Facts (Supabase docs, checked 2026-11-13): the Free plan has **no automatic backups**; Pro keeps 7 daily backups; point-in-time recovery is a Pro add-on (about $100/month for 7 days, worst-case data loss about 2 minutes).
- Until then: `scripts/db_backup.sh backup` (Supabase CLI `db dump`: roles, schema, data) weekly and before every migration, kept off-site; Storage files are not in it (they would need the Storage API).
- **Restore drill (owner, needs the DB password)**: create a scratch Free project, run `scripts/db_backup.sh restore backups/<stamp>` against it, check that row counts of `profiles`, `professional_profiles`, `quote_requests` and `messages` match, delete the scratch project. Record the times here:

| Date | Backup time | Restore time (RTO part) | Data loss window (RPO) | By |
|---|---|---|---|---|
| (not run yet) | | | up to the last weekly dump | |

### Incident response (one page)
1. **Detect**: Sentry alert, Supabase logs, a user report or a report in the admin queue.
2. **Contain** (minutes): suspend the account in the admin panel; revoke a leaked key or token at once (Supabase API keys, `sbp_` tokens, function secrets); if data is exposed through a policy, ship a migration that closes it first and analyse after; pausing the project is the last resort.
3. **Assess**: what data, which users, since when (audit log, Supabase logs, `admin_audit_log`).
4. **Fix and verify**: migration plus a regression test in `backend/tests`; rerun the full suite.
5. **Tell**: affected users in clear words; personal data breaches go to the INPDP (Tunisia, law 2004-63, see #57) without delay.
6. **Learn**: add a row to the findings table above and a note here.

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
