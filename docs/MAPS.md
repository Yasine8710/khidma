# Google Maps setup (issue #17)

The map behind the list/map toggle is `GoogleMapProvider`. With no key the toggle is hidden and nothing Google-related loads.

## 1. Create the key (owner)
1. Google Cloud console: create a project, enable billing (a monthly free credit applies), enable **Maps SDK for Android** and **Maps SDK for iOS**.
2. Create **two** API keys, one per platform, each restricted:
   - Android: restrict to *Android apps*, package `tn.khidma.khidma` + the SHA-1 of the signing key (debug key for dev, release/Play key later). Restrict API to Maps SDK for Android.
   - iOS: restrict to *iOS apps*, bundle id from Xcode. Restrict API to Maps SDK for iOS.
3. Set a per-day request quota on the Maps SDK APIs (this is what actually stops usage; budget alerts only email you). Keys inside an app bundle can be extracted, so the package/bundle restriction is the real protection.

## 2. Use the key
- Android: `flutter run --dart-define=GOOGLE_MAPS_API_KEY=<android key>` (or put it in `app/config/dev.json` and use `--dart-define-from-file`). Gradle reads the same define into the manifest.
- iOS (needs a Mac): create `app/ios/Flutter/Maps.xcconfig` (gitignored) with `GOOGLE_MAPS_API_KEY=<ios key>`, and also pass the define so the Dart side shows the toggle.
- Never commit a key. A restricted client key is not secret, but keep it out of git anyway.

## 3. Benchmark (still open)
Run the 60-address benchmark from docs/ARCHITECTURE.md against Google (and Apple Maps / MapLibre if curious) on a device. Pins are rounded to ~1 km by design, so judge label quality and Arabic rendering, not pin precision.

## Known limits
- iOS needs BOTH the define (shows the toggle) and `Maps.xcconfig` (gives the native SDK its key). The define without the xcconfig would open a broken map, so always set them together.
- Tunisia only: bounds ignore the antimeridian; the app is iOS/Android only.
- iOS side is unverified (no Mac): `AppDelegate.swift`, `Info.plist` (`GMSApiKey`), `Maps.xcconfig`.
- Widget tests cannot render the native map; the pure logic (camera target, bounds, availability) is unit-tested.
