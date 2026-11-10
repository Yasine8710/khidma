# Development Plan
Phases 0–8 follow the product brief: 0 init · 1 design system · 2 auth/profiles · 3 marketplace · 4 professional · 5 requests/offers · 6 chat/notifs/reviews/verification · 7 admin · 8 QA/TestFlight.
Each phase ends with executed tests and updated docs. Status tracked in `AI_COLLABORATION.md`.

## Phase 0 — done
Repo, license, docs, Flutter scaffold, CI file, Codex architecture review.

## Phase 1 — Design system and foundations (plan, awaiting approval)

**Goal:** a navigable, localized (FR/AR/EN, real RTL), themed app shell with reusable components and onboarding. No backend. Brand locked: Bleu Sidi Bou, Inter + IBM Plex Sans Arabic (tokens and theme already on `feat/design-tokens`).

### Dependencies (minimal)
`flutter_riverpod`, `go_router`, `flutter_localizations` + `intl`, `shared_preferences`, `flutter_animate`, `flutter_svg`. Nothing else in Phase 1 (maps, cache, Supabase, Firebase come later).

### Slices (one branch each, merged to `develop` after tests + review)
| # | Branch | Work | Tests |
|---|--------|------|-------|
| 1.0 | `feat/design-tokens` | Tokens, theme, fonts (done) | contrast, font selection |
| 1.1 | `feat/l10n` | `gen-l10n` ARB files fr (default) / ar / en; locale controller persisted via `shared_preferences`; Directionality from locale; formatters: TND (`1 200 DT`), Tunisian phone (`+216 XX XXX XXX`) with validation, dates | locale switch, RTL direction, formatters, phone validation |
| 1.2 | `feat/navigation` | GoRouter, app shell, custom bottom nav (Home, Requests, Messages, Profile; search lives in Home; placeholder screens, no dead buttons — tabs show a real empty state), route guards stubbed for Phase 2 | nav tests, state kept per tab |
| 1.3 | `feat/components` | Buttons, text field, chips, card, section header, rating stars (saffron fill + ink outline), avatar, badge, skeleton shimmer, empty state, error state, haptics helper; dark/light | widget tests per component, RTL widget tests |
| 1.4 | `feat/onboarding` | 3 short pages (discover, compare/quote, contact) + language picker first; seen-flag persisted; location permission NOT requested here | onboarding flow test, persistence |
| 1.5 | `feat/brand-assets` | Logo (wordmark + Arabic خدمة lockup), app icon, splash; 2–3 logo options for you to choose from | visual check on real screens |
| 1.6 | `feat/design-gallery` | Debug-only gallery screen listing all components in LTR/RTL, light/dark, for visual review | golden tests (FR LTR, AR RTL) |

Order: 1.0 → 1.1 → 1.2 → 1.3 → 1.4 → 1.5 → 1.6. 1.1 first because RTL affects every component.

### Rules for this phase
- `EdgeInsetsDirectional`, `AlignmentDirectional`, no hard-coded left/right.
- No user-facing string outside ARB files.
- Icons that imply direction (chevrons, back) mirror in RTL.
- Digits: Western digits (0–9) in all languages, as is usual in Tunisia — see decision 1.
- Motion: subtle, 150–250 ms, honor reduce-motion; haptics only on selection/confirm.
- Files under ~300 lines; business logic in controllers, not widgets.

### Codex tasks
- After 1.1: review l10n/RTL approach and formatters (independent, read-only).
- After 1.3: audit components for RTL, accessibility (tap targets ≥44 pt, semantics, text scaling 1.0–2.0), and dark-mode contrast.
- Findings recorded in `AI_COLLABORATION.md`; Claude decides and integrates.

### Acceptance gates (all must pass before Phase 2)
1. `dart format`, `flutter analyze`, `flutter test` green locally and in CI.
2. App runs on Android emulator or web in FR, AR (RTL) and EN, light and dark, with no overflow at text scale 2.0.
3. Every tab and button leads somewhere real; no dead controls.
4. Codex review findings triaged (fixed or documented disagreement).
5. `docs/ARCHITECTURE.md` and README updated.

### Known limits (stated, not hidden)
- No Mac: iOS look, safe areas and haptics are unverified until a Mac/iPhone is available; Phase 1 is verified on Android/web only.
- CI iOS job has not yet run on GitHub; first push of `develop` will show whether it passes.
- Logo/icon quality cannot be judged until it appears in the shell (slice 1.5 after 1.2/1.3).

### Decisions (confirmed 2026-11-10)
1. Digits: Western 0-9 in all languages.
2. Tabs: 4 (Home incl. search, Requests, Messages, Profile).
3. Dark mode: follows system, manual override in Profile.
4. Merge: squash each slice into `develop`; `main` only at phase end.
