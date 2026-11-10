# AI Collaboration
**Lead:** Claude Code (architecture, integration, decisions). **Partner:** OpenAI Codex CLI 0.167.0, invoked via `codex exec` (verified available 2026-11-10).

## Protocol
Claude plans → delegates to Codex (review or isolated-branch implementation) → Claude reviews/integrates → tests → docs. No two agents edit the same files; use branches/worktrees.

## Status
- Phase: 1 (design system) implementation complete on develop; gate review done; merging to main with tag v0.1.0-phase1.
- Claude: repo, license, docs, Flutter bootstrap
- Codex: architecture review DONE (raw output: docs/reviews-codex-phase0.md)
- Accepted from Codex: manual Riverpod, lifecycle state machine, atomic accept, permission matrix, multi-role flags, outbox notifications, privacy split, early signed-iOS proof, Google Maps pending benchmark.
- Disagreements (Claude keeps): English stays (cheap via ARB, in the brief); favorites stay but are late-sequenced; reviews stay in scope but ship only after completion flow is trustworthy. Cut candidates (offline cache, chat attachments, presence) are deferred past MVP.
- Note: `codex exec` needs `< /dev/null` or it hangs waiting on stdin.

## Phase 1, slice 1.1 (l10n): Codex review, 2026-11-10
Codex (read-only, static) raised 8 P2 and 4 P3 findings; all accepted and fixed:
- NaN, infinity and huge amounts now throw; the sign is decided after rounding.
- Arabic negative amounts are bidi-isolated; phone parsing strips all bidi controls.
- Phone numbers and language names keep their own direction but align to the screen start (`AlignedText`).
- `setLocale` returns success and tolerates save failures; each language option has its own speech locale.
- Tests: exact Arabic plural forms, tap-target guidelines, 2x text scale on a 320 px screen.
Codex confirmed the six Arabic plural branches and found no date or icon defects. Claude ran the tests: 26 pass, analyze clean.

Gotchas:
- `codex exec` needs `< /dev/null`, and its output file holds the full transcript (read the tail).
- The Edit tool can rewrite unicode escapes into invisible literal characters; `flutter analyze` flags them as `text_direction_code_point_in_literal`.
- GitHub Actions is blocked by an account billing lock (see below), so CI has not run yet.

## Phase 1, slice 1.2 (navigation): Codex review, 2026-11-10
Codex (read-only, static) confirmed the router instance is stable and disposed, indexed stacks and `goBranch` reset work, RTL mirroring is right. Findings accepted and fixed:
- `/` had no route (also `/?utm_source=...` on web): now redirects to `/home`, keeping the query.
- Bottom nav hid hover/focus ink behind an opaque box and dropped focus semantics: now `Material` surface with the border outside; tabs expose tap and focus actions.
- Saffron leaked through unset Material roles (segmented button, tertiary, secondaryFixed): defined explicitly in both themes.
- Nav labels clamp to 1.3x text scale (page text still scales).
Visual check: web build rendered on a 390 px viewport in French light and Arabic dark; layout mirrored, no saffron leaks. The old saffron segmented button was caught this way, not by tests.
Not done (deferred, stated): browser Back/Forward history tests and nested-detail restoration tests, because no detail routes exist yet; keyboard-focus ring visual check.
Test-env caveat: flutter test text widths are not representative of real fonts, so a truncation test at 2x was dropped.
Tests: 42 pass, analyze clean.

## Phase 1, slice 1.3 (components): Codex review, 2026-11-10
Codex (read-only, static) raised 7 P1, 17 P2. Fixed:
- Password toggle was unreachable by screen readers (MergeSemantics swallowed its action): label now names the field, toggle stays its own button; toggle follows `enabled` and re-syncs on `obscureText` change.
- Loading button lost its button role: now stays a disabled button, spinner announces "loading"; duplicate label removed.
- Tappable card: label and tap now on one node, min 48 high.
- Chip: packs in a Wrap (was one per row), grows with text, label wraps, keeps focus semantics.
- Inline (`expand: false`) buttons no longer demand infinite width.
- Field and chip borders were 1.28:1 (below WCAG 3:1 for controls): `outline` is now a control color (3.7:1 light, 3.65:1 dark); the old hairline moved to `outlineVariant` for cards, dividers and bars.
- Neutral badge text was 4.17:1: darkened (found by our own contrast test).
- Avatar: grapheme-safe initials, no blank frame before load, safe `cacheWidth`, `decorative` mode.
- Rating: wraps instead of overflowing; number/count forced LTR.
- Header action capped so translations wrap.
Deferred (stated): count text on primary-container backgrounds is 4.12:1 dark (no such use yet; fix when a card uses it); keyboard-focus ring and shimmer-unmount tests; controlled image-stream avatar tests; 2x text scale with real fonts (test env uses substitute font widths).
Visual review of all components is part of slice 1.6 (gallery); they have not been seen on screen yet.
Tests: 83 pass, analyze clean.

## Phase 1, slice 1.4 (onboarding): Codex review, 2026-11-10
No redirect loops or disposal problems found. Fixed: first-run redirect now keeps the original destination (`?from=`, validated to internal paths only) and restores it after onboarding; keyboard/screen-reader Back button; page indicator is a live region naming the page; implicit scrolling on; reduced motion honored; decoration dropped on short screens or large text so the language list stays reachable.
Bug found by our own new test (not by Codex): `animateToPage` asserts on `Duration.zero`, so Next/Back would have thrown with reduce-motion on; now uses `jumpToPage` in that case.
Deferred: direction-aware arrow-key shortcuts (Back button covers keyboard use).
Tests: 103 pass, analyze clean.

## Phase 1, slice 1.5 (brand assets): Codex review, 2026-11-10
Mark: doorway arch (Sidi Bou Said) with a saffron lantern dot; one geometry in `scripts/make_brand_assets.py`, mirrored in the Dart painter and SVG (a test fails if they drift). Codex verified dark-mode contrast of the mark (7.1-8.7:1) and that iOS icons are opaque and correctly sized. Fixed:
- `flutter_launcher_icons` rewrote an Xcode build setting to `AppIcon` (invalid): restored, guarded by a test.
- Generated web viewport disabled user zoom: removed, guarded by a test.
- Added Android monochrome (themed icon) layer and separately padded web maskable icons (`--maskable` step), with decoded-pixel safe-zone tests (maskable 40% circle, adaptive 66dp zone after the 16% inset, Android 12 splash circle).
- Names standardized to "Khidma" (web manifest, title, Android label); web description replaced; Arabic locale gets an Arabic logo semantic name; Pillow pinned in `scripts/requirements.txt`.
Also found by looking at the screens: onboarding stretched edge to edge on wide screens (now max 520 px) and the logo disappeared on screens under 700 px high (now only under 560 px or large text).
Regeneration order and the two post-generator fixes are documented in the script and pubspec.
Tests: 124 pass, analyze clean. Web build compiles. Not verified: real Android/iOS rendering of the icons (no device/Mac).

## Phase 1, slice 1.6 (gallery + goldens): Codex review, 2026-11-10
Built the debug-only gallery (all shared components except the whole-screen AppShell/NotFound, all type tokens, colors, disabled/loading/error/RTL/dark states) and 6 golden images (FR/AR/EN x light/dark). First real look at every component in a browser (FR light, AR dark) found one bug tests had missed: a forced-LTR phone field showed its hint reversed in Arabic (`hintTextDirection` now follows the field). Test helpers now load the bundled fonts and the Material icon font, so widget tests measure real text widths and goldens show real glyphs.
Codex fixes: comparator disposes images and restores itself; goldens tagged `golden` and excluded from CI (baselines are Windows-made; refresh with `flutter test --update-goldens --tags golden`); CI pins Flutter 3.47.9; gallery coverage widened; interaction tests at a normal phone height; phone field found by key; config comment corrected.
Release exclusion verified on real builds: default release web bundle has 0 occurrences of gallery strings; `--dart-define=GALLERY=true` has them.
Known limits: golden tolerance is 0.5% of pixels regardless of magnitude (coarse); AppButton's indeterminate spinner is not frozen in goldens (deterministic in test time); Linux CI baselines not generated (CI is billing-locked anyway).
Tests: 141 pass (6 are goldens), analyze clean.

## Phase 1 gate (#4): whole-phase Codex review, 2026-11-10
Codex reviewed the whole phase (static). Fixed:
- P1 Android release builds had no INTERNET permission (only debug/profile): added to the main manifest; `allowBackup=false` until per-account data exists.
- P1 A failing `SharedPreferences` load would crash before the first frame: storage is now a small `KeyValueStore` interface (`PrefsStore`, `MemoryStore` fallback); this also replaced brittle `noSuchMethod` test fakes. Storage moved out of `core/l10n` into `core/storage`.
- Password fields: no autocorrect or suggestions (also while shown).
- CI: added web release build and an allowed-to-fail unsigned iOS build job; Flutter pinned.
- Main widget suites now load real fonts (all still pass); README no longer claims `.env` configures anything; "complete" reworded to "implementation complete, acceptance pending"; web page description and duplicate viewport fixed; unused `cupertino_icons` removed.
Deferred (noted): gallery samples use French for English; gallery and two test files exceed ~300 lines; Linux golden baselines.
Tests: 151 pass (6 goldens), analyze clean.

## Phase 2, #7 (database foundation): Codex security audit, 2026-11-10
Codex (read-only, with its own in-memory probes) found no admin/rating escalation; RETURNING, UPSERT, NULL-subject RPC, draft joins and composite-FK probes were blocked. Accepted and fixed: category-id exhaustion by rejected inserts (direct INSERT grant removed), verification surviving identity edits (trigger), bulk phone scraping (phone no longer selectable; rate-limited reveal function with log), coordinate precision (2 decimals), anonymous-auth users acting as registered users (`is_anonymous` guard), inactive categories assignable/publishable (triggers), permissive sequence privileges (revoked), and weak structural guards (now enumerate every function's EXECUTE rights, PUBLIC/default ACLs, exact search_path).
Tests: 81 on PGlite; two mutation rounds (19 mutations) all caught. Not done / needs a real Supabase project: GoTrue + PostgREST behavior (embeds, RETURNING over HTTP), forced signup-trigger failure rollback, Storage policies, realtime publications, exposed schemas.

## Phase 2, #8 (auth): Codex review, 2026-11-10
Codex found: P1 password reset not completable (no recovery screen/event, no redirect or deep-link setup); P1 reset link target undefined; P2 plain-text token storage, hidden stream errors, init failure becomes permanent "not configured", enumeration notes, password limits counted in the wrong units, forgot-password "back" crash on direct entry, silent sign-out failure; P3 autofill commit timing, focus after errors, unconditional logging, test gaps.
Fixed: recovery event + new-password screen + `updateUser`; `redirectTo` + Android intent filter + iOS URL type with Flutter deep-link handling disabled (tests check the three agree); secure storage for the session and PKCE verifier; password limits as 8 code points / 72 UTF-8 bytes; canPop fallbacks; sign-out failure snackbar; autofill saved only on success; quiet release logging.
Deferred (stated): surfacing auth-stream errors and "session expired" state; distinguishing init failure from missing config with retry; moving focus to the error after a failed submit; HTTP-level tests of the real client (flutter_test stubs HTTP); verifying the link flow on a device. All of these need a real Supabase project or device (issue #6).
Tests: 215 pass (6 goldens), analyze clean.

## Phase 2, #10 (profile + account type): Codex review, 2026-11-10
Codex confirmed no admin escalation path in SQL or app. Found: P1 the pending "professional" choice belonged to no account (another login on the device could inherit it); P2 stale or mixed-account data (stale profile while reloading, form not keyed by account, header ignoring the edited name), racing submissions clearing consent, swallowed persistence failures, disabled-state semantics, fake-only tests.
Fixed: choice bound to the sign-up email + 7-day expiry + identity re-check before clearing; `visibleProfileProvider` (current account only, never stale); edit form keyed by account id; header shows the saved name; whole register submit locked; selector exposes disabled state; persistence failures documented (in-memory authoritative, identity-bound copy cannot grant anything to others); 6 transport tests drive the real Supabase client over a recorded fake HTTP layer (columns, id filter, `phone: null`, RPC without arguments, error mapping, no message leakage).
Found by writing the tests: Riverpod 3 auto-retries failing providers (disabled for the profile load, which has an explicit retry button).
Deferred: keyboard-visibility and RTL scroll tests of the longer register form; avatar upload (Phase 4).
Tests: 255 pass (6 goldens), analyze clean.

## Phase 2, #9 (Sign in with Apple, offline part): Codex review, 2026-11-10
Codex verified: fresh `Random.secure()` nonce, SHA-256 to Apple and original to Supabase, correct provider/token arguments, null/empty token rejected, no token logging, entitlements wired into all three Runner configurations, label/disabled semantics. Findings: P1 no account deletion (App Store 5.1.1(v)) -> new issue #32; P2 Apple authorization code discarded (needed for token revocation, server-side) -> #32; P2 register flow raced a second direct `becomeProfessional` call and ignored its failure -> now one coordinator (identity-bound pending choice); P2 Apple's shared name only reached auth metadata, leaving the profile blank -> `adoptSharedName` fills an empty profile name only; P2 Hide-My-Email relay accounts are separate from password accounts -> documented, explicit linking deferred; test gaps -> transport tests for token edge cases, name preservation, failing metadata update, pending-choice interplay.
Found by tests: reading the user from the stream-backed provider right after sign-in raced the stream (email was null and the choice was skipped); the repository's `currentUser` is used instead.
Not verified (needs owner/device): the real Apple sheet, capability provisioning with a paid team, Supabase Apple provider settings.
Tests: 283 pass (6 goldens), analyze clean.

## Phase 2, #32 (account deletion), 2026-11-10
Opened from the Codex review of #9 (App Store 5.1.1(v)). Database: `delete_my_account()` (definer, pinned search_path, no arguments, registered users only) + 7 PGlite tests (full cascade across every user-id column, other users untouched, anon / anonymous-auth / no-user refused, function grants matrix updated). App: confirm-by-typing dialog (localized word), server delete then local sign-out, pending choice cleared, failure keeps the session; 10 tests incl. the exact RPC on the wire. Not reviewed by Codex separately (small, heavily tested); to verify on a real project: owner's right to delete from auth.users, Apple token revocation (server key needed).
Tests: app 293 + backend 88.

## Phase 2 gate (#11): whole-phase Codex review, 2026-11-10
Codex ran the 88 backend tests, probed the exact app queries against the migrations (profile SELECT/UPDATE-RETURNING, both RPCs: all passed) and checked metadata keys, grants and RLS against the Dart code: contract matches. Findings fixed: P1 reveal rate limit was count-then-insert (now serialized per caller with an advisory lock, guarded by a test); P2 sign-up confirmation link ignored the app callback (now `emailRedirectTo`, wire-tested); P2 Apple-name adoption could copy one account's phone/language into another after an account switch (now bound to the captured account, tested); P2 the SDK's debug logger printed raw errors (disabled); P2/P3 CI gaps (Android compile job, lockfile enforcement), docs still saying auth was unbuilt, recovery-screen wording, Android debug signing noted.
Deferred (needs the owner / a real project): real Supabase integration gate for signup, PATCH-returning and deletion; P0001/P0002 error mappings when the reveal/admin RPCs get app consumers; release signing.
Tests: app 298 + backend 89.
