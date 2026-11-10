# AI Collaboration
**Lead:** Claude Code (architecture, integration, decisions). **Partner:** OpenAI Codex CLI 0.167.0, invoked via `codex exec` (verified available 2026-11-10).

## Protocol
Claude plans → delegates to Codex (review or isolated-branch implementation) → Claude reviews/integrates → tests → docs. No two agents edit the same files; use branches/worktrees.

## Status
- Phase: 1 (design system). Slices 1.0-1.6 merged to develop; next 1.7 phase gate (#4).
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
