# iOS release checklist

What is prepared in the repository, and what only the owner can do (needs a Mac and a paid Apple Developer account). Nothing below has been built or run on iOS yet: CI's iOS job is allowed to fail until it has been seen green once.

## Prepared
- Bundle display name, URL scheme for auth callbacks, `Runner.entitlements`, location usage text (`NSLocationWhenInUseUsageDescription`; coarse location only), reduced-accuracy key.
- `app/ios/Runner/PrivacyInfo.xcprivacy`, registered in the Xcode project (resources of the Runner target). Declares: no tracking, no tracking domains; collected and linked to the user, for app functionality only: email, phone, name, coarse location, photos, other user content, user id; required-reason API: UserDefaults (CA92.1). Plugins ship their own manifests. Review it against the final dependency list before each submission.
- Account deletion in the app (App Store 5.1.1(v)); sign-in with Apple is implemented but untested live (issue #9).
- Backend, admin dashboard and notifications code, with owner steps in `docs/SECURITY.md`.

## Owner steps
1. Apple Developer Program membership; create the App ID with capabilities: Sign in with Apple, Push Notifications (when #26 is done).
2. Xcode: open `app/ios/Runner.xcworkspace`, set the Team and a unique bundle identifier, let Xcode create the provisioning profiles. Confirm `PrivacyInfo.xcprivacy` is listed under Runner > Build Phases > Copy Bundle Resources.
3. Backend first (issue #6): Supabase project, migrations, Auth redirect URLs for the URL scheme, Apple provider keys (#9). Put the project URL and publishable key in the build via `--dart-define` (see `app/lib/core/config/app_config.dart`); never a service key.
4. `flutter build ipa --release --dart-define=...`, upload with Xcode Organizer or Transporter, test on TestFlight with at least one real device (also checks `geolocator` background-location settings, issue #17 map vendor key, push on a device).
5. App Store Connect: privacy nutrition label (must match `PrivacyInfo.xcprivacy`), privacy policy URL, support URL, screenshots (FR/AR/EN), age rating, review notes with a demo account, export-compliance answer (standard HTTPS only).
6. Content: Arabic seed names need native-speaker review before submission.
