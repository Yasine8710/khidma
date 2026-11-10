# Khidma · خدمة

A trusted local services marketplace built for Tunisia. Discover professionals, request services and connect with local experts.

> **Proprietary — All Rights Reserved.** This repository is public for visibility and portfolio purposes only. It is **not** open-source. No permission is granted to copy, modify, redistribute or commercially use the code, the Khidma name, or its branding. See [LICENSE](LICENSE). Third-party assets keep their own licenses ([THIRD_PARTY.md](THIRD_PARTY.md)).

## Status
**Phase 1 (design system and foundations): implementation complete, acceptance pending** (the automated CI gate cannot run until the GitHub billing lock is cleared; all checks pass locally). The app is a localized, themed, navigable shell with no backend yet. Nothing here is production-ready. Roadmap and open work: [GitHub issues](https://github.com/Yasine8710/khidma/issues) and [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md).

What works today:
- French (default), Arabic (real RTL) and English; Western digits everywhere; TND, Tunisian phone and date formatting.
- First-run onboarding, four-tab navigation (Home, Requests, Messages, Profile), light/dark/system theme.
- Shared component library, brand mark, app icons and splash.
- Debug-only design gallery (`/gallery`) and golden tests.

Not built yet: authentication, backend (Supabase), marketplace, requests/offers, messaging, admin. Placeholder screens say so honestly and show no fake data.

## Stack
Flutter (iOS first) · Riverpod · GoRouter · Supabase (Postgres, Auth, Storage, RLS) · FCM.

## Layout
- `app/` Flutter application
- `backend/` Supabase migrations and config (Phase 2)
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
There is no environment configuration yet. When Supabase is connected (issue #6) the public URL and anon key will be passed with `--dart-define`; `.env.example` lists the names. Never commit secrets or a service-role key.

Brand assets are generated: see the header of `scripts/make_brand_assets.py` for the exact order (it also lists two fixes to re-check after the icon generators run, which tests guard).

## Known limits
- Built on Windows: iOS builds, signing, APNs and real-device checks need a Mac and are not done yet.
- GitHub Actions is currently blocked by an account billing lock; the workflow (Ubuntu runner) has not run yet.
