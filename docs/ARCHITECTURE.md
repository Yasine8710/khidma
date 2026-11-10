# Architecture (v2, end of Phase 1)

## Client (as built)
Flutter app in `app/`, feature-first:
```
lib/
  app.dart, main.dart
  core/
    l10n/       locale controller (persisted), supported locales
    format/     money (TND), Tunisian phone, dates, rating, digit normalization
    router/     GoRouter provider, route paths, onboarding redirect
    theme/      colors, spacing, typography, theme (light/dark), theme-mode controller
    haptics.dart
  features/<feature>/{application,presentation[,domain,data]}
    onboarding, home, requests, messages, profile, settings, gallery (debug)
  shared/widgets/   reusable components (button, field, chip, card, rating, avatar, badge, skeleton, states, nav, logo)
  l10n/             ARB files (fr template, ar, en) and generated localizations
```
Layers `domain/` and `data/` are added per feature when it gets real data (Phase 2+); Phase 1 features are presentation plus small controllers, on purpose (Codex review: avoid pass-through boilerplate).

Key decisions:
- State: Riverpod 3, manual `Notifier`/`AsyncNotifier`; no codegen.
- Navigation: GoRouter 18; `StatefulShellRoute.indexedStack` keeps each tab alive; redirects are UX only (real access control is Supabase RLS). The router instance is stable: onboarding changes trigger `refreshListenable`, not a rebuild. First-run redirects keep the intended destination (`?from=`, internal paths only).
- Localization: `gen-l10n`; French default; Arabic uses real RTL (directional insets, mirrored order, forced-LTR for phone/email/rating stars/brand wordmark, `AlignedText` to keep alignment at the screen start); Western digits in every language via our own formatters (intl would emit Arabic-Indic digits).
- Theme: `ColorScheme.outline` is the 3:1 control border (fields, chips); `outlineVariant` is the decorative hairline. Saffron is for fills/icons only (2.16:1 on white). All text pairings are tested for WCAG AA.
- Accessibility baked into components: tap targets >= 48, labelled controls, selected/disabled state, focus semantics, reduced-motion honored (including a `jumpToPage` fallback), nav labels capped at 1.3x text scale.
- Persistence in Phase 1: `shared_preferences` (locale, theme, onboarding flag); writes are optimistic and failures never block the user.
- Brand: one geometry (`scripts/make_brand_assets.py`) drives the icon rasters, SVG and the Dart painter; tests compare them and check icon safe zones from decoded pixels.

## Testing approach
Unit tests for formatters and controllers; widget tests with the bundled fonts loaded (`loadAppFonts`) so widths are real; semantics assertions; golden tests (tag `golden`, excluded from CI until Linux baselines exist). Tests have caught real bugs (reduced-motion crash, reversed hint in RTL, neutral badge contrast, generator corrupting an Xcode setting).

## Backend (planned, Phase 2+)
Postgres + RLS on all user-data tables, SQL migrations in `backend/supabase/migrations`. Business-critical writes (offer accept, review eligibility, verification) via SECURITY DEFINER RPC or Edge Functions, never client-trusted. Roles are capability flags (a user can be customer and professional); `admin` is set server-side only; role/verification columns are not owner-updatable; never authorize from `user_metadata`. Private storage buckets for verification documents. Geo search via PostGIS. Job lifecycle as an explicit state machine with an atomic accept RPC. Notifications via a transactional outbox with dedup keys. Details: [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md), [SECURITY.md](SECURITY.md) (filled in Phase 2).

## Admin
Separate web app in `admin/` (Phase 7), role-gated by RLS and server checks.

## Open questions
PostGIS on the chosen Supabase plan; Google Maps vs Mapbox (benchmark 50-100 Tunisian addresses before Phase 3); iOS signing/APNs proof needs a Mac and iPhone; Linux golden baselines once CI is unlocked.
