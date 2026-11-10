# Khidma · خدمة

A trusted local services marketplace built for Tunisia. Discover professionals, request services and connect with local experts.

> **Proprietary — All Rights Reserved.** This repository is public for visibility and portfolio purposes only. It is **not** open-source. No permission is granted to copy, modify, redistribute or commercially use the code, the Khidma name, or its branding. See [LICENSE](LICENSE). Third-party assets keep their own licenses ([THIRD_PARTY.md](THIRD_PARTY.md)).

## Status
**Phase 1 (design system) and Phase 2 (accounts) are implemented and tested; acceptance is pending** because GitHub Actions is blocked by a billing lock and nothing has run against a real Supabase project yet. All checks pass locally. Nothing here is production-ready. Roadmap and open work: [GitHub issues](https://github.com/Yasine8710/khidma/issues) and [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md).

What works today (verified with fakes, recorded HTTP and a real Postgres engine, not against a live project):
- French (default), Arabic (real RTL) and English; Western digits; TND, Tunisian phone and date formatting; light/dark/system theme; onboarding; four-tab navigation; component library; brand mark, icons, splash.
- Accounts: email sign-up and sign-in, in-app password reset through a deep link, Sign in with Apple (iOS), sign-out, in-app account deletion, secure token storage. Account type choice (customer / professional; no admin path), profile editing, "become a professional".
- Database (`backend/`): profiles with capability flags, admin table with no client path, 24 governorates + Greater Tunis, 12 service categories, professional profiles with publish rules, rate-limited phone reveal, verification rules; Row Level Security everywhere, tested on real Postgres (PGlite) and mutation-checked.
- Without Supabase keys the app still runs and says honestly that accounts are unavailable.

Not built yet: marketplace (search, profiles, favorites, maps), requests/offers, messaging, notifications, reviews, verification workflow, admin dashboard. Placeholder screens say so and show no fake data.

## Stack
Flutter (iOS first) · Riverpod · GoRouter · Supabase (Postgres, Auth, Storage, RLS) · FCM.

## Layout
- `app/` Flutter application
- `backend/` Supabase migrations and their tests (`cd backend && npm install && npm test`)
- `admin/` admin dashboard (Phase 7)
- `docs/` architecture, plan, schema, security, AI collaboration log
- `scripts/` tooling (brand asset generator)

## Develop
```bash
cd app
flutter pub get
flutter run                       # device / emulator / -d chrome
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test --exclude-tags golden
flutter test --tags golden        # pixel tests (baselines are Windows-made)
flutter test --update-goldens --tags golden   # refresh baselines
flutter run --dart-define=GALLERY=true        # gallery in a profile/release build
```
Backend settings are passed at build time, not read from a file at runtime:
```bash
cp app/config/dev.example.json app/config/dev.json   # git-ignored; fill in URL + anon key
flutter run --dart-define-from-file=config/dev.json
```
Without them the app still runs; features that need a backend show a "not connected" state. A service-role key is rejected at startup (it must never ship in an app). See `lib/core/config/app_config.dart`.

Brand assets are generated: see the header of `scripts/make_brand_assets.py` for the exact order (it also lists two fixes to re-check after the icon generators run, which tests guard).

## Known limits
- Android release builds are signed with the debug key until release signing is configured (do not distribute them).
- Built on Windows: iOS builds, signing, APNs and real-device checks need a Mac and are not done yet.
- GitHub Actions is currently blocked by an account billing lock; the workflow (Ubuntu runner) has not run yet.
