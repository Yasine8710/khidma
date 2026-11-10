import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/config/app_config.dart';

String _jwt(Map<String, Object?> payload) {
  String b(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b({'alg': 'HS256', 'typ': 'JWT'})}.${b(payload)}.signature';
}

final _anon = _jwt({'role': 'anon', 'iss': 'supabase'});
final _service = _jwt({'role': 'service_role', 'iss': 'supabase'});
const _url = 'https://abcdefgh.supabase.co';

void main() {
  test('nothing provided means no backend (fresh checkout)', () {
    expect(parseBackendConfig(url: '', anonKey: ''), isA<BackendMissing>());
    expect(parseBackendConfig(url: '  ', anonKey: ' '), isA<BackendMissing>());
  });

  test('valid https URL and anon key', () {
    final c = parseBackendConfig(url: _url, anonKey: _anon);
    expect(c, isA<BackendReady>());
    final ready = c as BackendReady;
    expect(ready.url.toString(), _url);
    expect(ready.anonKey, _anon);
  });

  test('trailing slash and whitespace are tolerated', () {
    final c = parseBackendConfig(url: ' $_url/ ', anonKey: ' $_anon ');
    expect((c as BackendReady).url.toString(), _url);
  });

  test('new-style publishable key is accepted', () {
    final c = parseBackendConfig(
      url: _url,
      anonKey: 'sb_publishable_abcDEF123_-xyz',
    );
    expect(c, isA<BackendReady>());
  });

  test('new-style SECRET key is rejected', () {
    final c = parseBackendConfig(url: _url, anonKey: 'sb_secret_abcDEF123');
    expect(c, isA<BackendInvalid>());
    expect((c as BackendInvalid).reason, contains('secret'));
  });

  test('malformed publishable keys are rejected', () {
    for (final k in ['sb_publishable_', 'sb_publishable_ab cd']) {
      expect(
        parseBackendConfig(url: _url, anonKey: k),
        isA<BackendInvalid>(),
        reason: k,
      );
    }
  });

  test('a SERVICE-ROLE key is rejected with a clear reason', () {
    final c = parseBackendConfig(url: _url, anonKey: _service);
    expect(c, isA<BackendInvalid>());
    expect((c as BackendInvalid).reason, contains('service-role'));
  });

  test('other roles and non-JWT keys are rejected', () {
    for (final key in [
      _jwt({'role': 'authenticated'}),
      _jwt({'sub': 'x'}),
      'not-a-jwt',
      'a.b.c',
      '${_anon.split('.')[0]}.!!!.sig',
    ]) {
      expect(
        parseBackendConfig(url: _url, anonKey: key),
        isA<BackendInvalid>(),
        reason: key,
      );
    }
  });

  test('half-configured is invalid, not silently missing', () {
    expect(parseBackendConfig(url: _url, anonKey: ''), isA<BackendInvalid>());
    expect(parseBackendConfig(url: '', anonKey: _anon), isA<BackendInvalid>());
  });

  test('bad URLs are rejected', () {
    for (final u in [
      'http://abcdefgh.supabase.co',
      'ftp://abcdefgh.supabase.co',
      'abcdefgh.supabase.co',
      'https://',
      'https://abcdefgh.supabase.co/rest/v1',
      'https://abcdefgh.supabase.co?x=1',
    ]) {
      expect(
        parseBackendConfig(url: u, anonKey: _anon),
        isA<BackendInvalid>(),
        reason: u,
      );
    }
  });

  test('http is allowed only for localhost development', () {
    expect(
      parseBackendConfig(url: 'http://localhost:54321', anonKey: _anon),
      isA<BackendReady>(),
    );
    expect(
      parseBackendConfig(url: 'http://127.0.0.1:54321', anonKey: _anon),
      isA<BackendReady>(),
    );
    expect(
      parseBackendConfig(url: 'http://example.com', anonKey: _anon),
      isA<BackendInvalid>(),
    );
  });

  test('without --dart-define the provider reports "missing"', () {
    // Tests run without the defines, like a fresh checkout.
    final c = parseBackendConfig(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
    expect(c, isA<BackendMissing>());
  });
}
