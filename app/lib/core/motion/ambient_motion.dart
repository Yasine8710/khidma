import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether endless decorative motion (the welcome screen's scrolling rows
/// and rotating word) may run. True in the app. Widget tests that settle
/// the whole app override it to false, because a never-ending animation
/// never settles; tests of that motion itself leave it on. Reduce Motion
/// (`Motion.reduced`) still turns it off regardless.
final ambientMotionProvider = Provider<bool>((ref) => true);
