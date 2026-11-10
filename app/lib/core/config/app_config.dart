import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public client settings, passed at build time with `--dart-define` or
/// `--dart-define-from-file=config/dev.json` (see `config/dev.example.json`).
/// Only the Supabase URL and the public key (the new `sb_publishable_...` key,
/// or a legacy JWT `anon` key) belong here. A secret or service-role key is
/// rejected on sight: it must never ship inside an app.
sealed class BackendConfig {
  const BackendConfig();
}

/// Everything needed to talk to Supabase, validated.
class BackendReady extends BackendConfig {
  const BackendReady({required this.url, required this.anonKey});
  final Uri url;
  final String anonKey;
}

/// Nothing was provided (normal for a fresh checkout: the app runs without a
/// backend and features that need one show an honest "not connected" state).
class BackendMissing extends BackendConfig {
  const BackendMissing();
}

/// Something was provided but is unusable or unsafe. [reason] is for
/// developers (logs, debug screens), never shown to end users.
class BackendInvalid extends BackendConfig {
  const BackendInvalid(this.reason);
  final String reason;
}

BackendConfig parseBackendConfig({
  required String url,
  required String anonKey,
}) {
  final u = url.trim();
  final k = anonKey.trim();
  if (u.isEmpty && k.isEmpty) return const BackendMissing();
  if (u.isEmpty) return const BackendInvalid('SUPABASE_URL is empty');
  if (k.isEmpty) return const BackendInvalid('SUPABASE_ANON_KEY is empty');

  final uri = Uri.tryParse(u);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
    return const BackendInvalid('SUPABASE_URL is not a valid URL');
  }
  final local = uri.host == 'localhost' || uri.host == '127.0.0.1';
  if (uri.scheme != 'https' && !(local && uri.scheme == 'http')) {
    return const BackendInvalid(
      'SUPABASE_URL must be https (http only for localhost)',
    );
  }
  if (uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    return const BackendInvalid('SUPABASE_URL must be a bare project URL');
  }

  // New-style keys (legacy JWT keys are deprecated by end of 2026).
  if (k.startsWith('sb_secret_')) {
    return const BackendInvalid(
      'SUPABASE_ANON_KEY is a secret key. Never put it in the app.',
    );
  }
  if (k.startsWith('sb_publishable_')) {
    if (k.length <= 'sb_publishable_'.length || k.contains(RegExp(r'\s'))) {
      return const BackendInvalid('SUPABASE_ANON_KEY is malformed');
    }
    return BackendReady(
      url: Uri.parse('${uri.scheme}://${uri.authority}'),
      anonKey: k,
    );
  }

  // Legacy JWT keys: only the `anon` role is acceptable.
  final parts = k.split('.');
  if (parts.length != 3) {
    return const BackendInvalid('SUPABASE_ANON_KEY is not a JWT');
  }
  final role = _jwtRole(parts[1]);
  if (role == null) {
    return const BackendInvalid('SUPABASE_ANON_KEY payload is unreadable');
  }
  if (role == 'service_role') {
    return const BackendInvalid(
      'SUPABASE_ANON_KEY is a service-role key. Never put it in the app.',
    );
  }
  if (role != 'anon') {
    return BackendInvalid('SUPABASE_ANON_KEY has unexpected role "$role"');
  }
  return BackendReady(
    url: Uri.parse('${uri.scheme}://${uri.authority}'),
    anonKey: k,
  );
}

String? _jwtRole(String payloadSegment) {
  try {
    final json = utf8.decode(
      base64Url.decode(base64Url.normalize(payloadSegment)),
    );
    final map = jsonDecode(json);
    return map is Map ? map['role'] as String? : null;
  } catch (_) {
    return null;
  }
}

/// Reads the compile-time definitions. Overridden in tests.
final backendConfigProvider = Provider<BackendConfig>(
  (ref) => parseBackendConfig(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  ),
);
