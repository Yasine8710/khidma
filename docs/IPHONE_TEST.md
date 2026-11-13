# Run Khidma on your own iPhone (no Mac, no App Store)

Route: Codemagic (cloud Mac) builds an unsigned `.ipa`; Sideloadly on Windows signs it with a free Apple ID and installs it over USB. The app expires after 7 days: re-run Sideloadly to renew. Sign in with Apple does not work in this build (needs a paid account); email sign-in does.

## One time
1. **Supabase**: new project (free). Settings > API: copy the Project URL and the *publishable* key (never a secret/service-role key). Apply `backend/supabase/migrations` in order and set the dashboard options listed in `docs/SECURITY.md` (anonymous sign-ins off, etc.).
2. **Codemagic**: sign in with GitHub, add repo `Yasine8710/khidma`, choose "codemagic.yaml". Create variable group `khidma` with `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_MAPS_API_KEY` (secure).
3. **Google key**: restrict to iOS apps, bundle id `tn.khidma.khidma`, API *Maps SDK for iOS* only (`docs/MAPS.md`).
4. **PC**: install iTunes and iCloud from apple.com (not Microsoft Store) and Sideloadly.
5. **iPhone**: Settings > Privacy & Security > Developer Mode on (appears after the first sideload attempt), then trust your Apple ID profile under General > VPN & Device Management.

## Each build
1. Codemagic > Start new build > workflow `iphone-test`, branch `develop`. Download `khidma.ipa` when done.
2. Plug in the iPhone, open Sideloadly, drop the `.ipa`, enter your Apple ID, Start.
