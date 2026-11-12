# Khidma · خدمة

A trusted local services marketplace built for Tunisia. Discover professionals, request services and connect with local experts.

> **Proprietary — All Rights Reserved.** This repository is public for visibility and portfolio purposes only. It is **not** open-source. No permission is granted to copy, modify, redistribute or commercially use the code, the Khidma name, or its branding. See [LICENSE](LICENSE). Third-party assets keep their own licenses ([THIRD_PARTY.md](THIRD_PARTY.md)).

## Status
Pre-release, tested on the owner's own iPhone (sideloaded; no App Store yet). Work is tracked in [GitHub issues](https://github.com/Yasine8710/khidma/issues). Everything below is covered by automated tests (fakes, recorded HTTP and a real Postgres engine); the live Supabase project is exercised by hand.

- **Local trades marketplace:** search with filters and map, professional profiles with portfolio, reviews tied to completed jobs, favorites, quote requests with photos, offers and comparison, bookings, chat, notifications settings.
- **Digital freelance section:** freelancer profiles, portfolio (photos, short clips, video links), invite-link client testimonials, one shared identity verification.
- **Merchant subscription:** plans in TND, D17 and bank transfer confirmed by an admin; Flouci integration written but not live.
- **Trust and safety:** identity verification review, reports, suspension, account deletion with file cleanup, Row Level Security everywhere.
- **Languages:** French (default), Arabic (RTL), English; Western digits; TND formatting.
- **Admin:** separate web app (`admin/`) behind a TOTP second factor.

Not done: Sign in with Apple, push notifications and the App Store release (they need a paid Apple Developer account), Flouci go-live, invoices.

## Stack
Flutter (iOS first) · Riverpod · GoRouter · Supabase (Postgres, Auth, Storage, RLS) · FCM.

## Layout
- `app/` Flutter application
- `backend/` Supabase migrations and their tests (`cd backend && npm install && npm test`)
- `admin/` admin dashboard (React)
- `web-testimonial/` public page where past clients leave a testimonial
- `docs/` architecture, schema, security, design brief, iPhone test guide
- `scripts/` tooling (brand asset generator)
- `codemagic.yaml` cloud build of an unsigned iPhone test build

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
