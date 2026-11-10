import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/preferences_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(await _openStore())],
      child: const KhidmaApp(),
    ),
  );
}

/// Device storage can fail to open (corrupt file, full disk). The app must
/// still start, so fall back to an in-memory store.
Future<KeyValueStore> _openStore() async {
  try {
    return PrefsStore(await SharedPreferences.getInstance());
  } catch (e, s) {
    debugPrint('Preferences unavailable, using in-memory settings: $e\n$s');
    return MemoryStore();
  }
}
