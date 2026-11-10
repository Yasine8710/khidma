import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-level key-value storage (locale, theme, onboarding). Per-account
/// state (Phase 2) must not live here. Writes report success as a bool and
/// never throw into the UI.
abstract interface class KeyValueStore {
  String? getString(String key);
  bool? getBool(String key);
  Future<bool> setString(String key, String value);
  Future<bool> setBool(String key, bool value);
}

/// Backed by `shared_preferences`.
class PrefsStore implements KeyValueStore {
  PrefsStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);
  @override
  bool? getBool(String key) => _prefs.getBool(key);
  @override
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);
  @override
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);
}

/// Used when device storage cannot be opened: the app still starts, settings
/// just do not persist this session.
class MemoryStore implements KeyValueStore {
  final _values = <String, Object>{};

  @override
  String? getString(String key) => _values[key] as String?;
  @override
  bool? getBool(String key) => _values[key] as bool?;
  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _values[key] = value;
    return true;
  }
}

/// Overridden in `main()` with the real store, and in tests with fakes.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('keyValueStoreProvider not overridden'),
);
