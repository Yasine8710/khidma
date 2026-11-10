import 'package:flutter/foundation.dart';

/// The design gallery exists only in debug builds, or when explicitly built
/// with `--dart-define=GALLERY=true` (e.g. to review it in a browser).
/// A default release build creates no route or Profile entry, so the screen
/// is tree-shaken. (A release built with GALLERY=true exposes both; do not
/// ship that.)
const bool kShowGallery = kDebugMode || bool.fromEnvironment('GALLERY');
