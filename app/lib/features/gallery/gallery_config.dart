import 'package:flutter/foundation.dart';

/// The design gallery exists only in debug builds, or when explicitly built
/// with `--dart-define=GALLERY=true` (e.g. to review it in a browser).
/// Release builds never include a route or entry point to it.
const bool kShowGallery = kDebugMode || bool.fromEnvironment('GALLERY');
