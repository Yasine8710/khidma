import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../domain/notifications_domain.dart';

/// Preferences and device tokens through database functions (the tables are
/// not readable by clients except one's own preferences).
class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository(this._client);
  final sb.SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (_) {
      throw const NotificationsError();
    }
  }

  @override
  Future<NotificationPrefs> preferences() => _guard(() async {
    final rows = await _client.rpc('my_notification_preferences');
    final list = rows as List;
    if (list.isEmpty) return const NotificationPrefs();
    final r = list.first as Map<String, dynamic>;
    return NotificationPrefs(
      offers: r['offers'] != false,
      messages: r['messages'] != false,
      jobs: r['jobs'] != false,
    );
  });

  @override
  Future<void> savePreferences(NotificationPrefs prefs) => _guard(() async {
    await _client.rpc(
      'set_notification_preferences',
      params: {
        'p_offers': prefs.offers,
        'p_messages': prefs.messages,
        'p_jobs': prefs.jobs,
      },
    );
  });

  @override
  Future<void> registerToken(String token, PushPlatform platform) =>
      _guard(() async {
        await _client.rpc(
          'register_device_token',
          params: {'p_token': token, 'p_platform': platform.name},
        );
      });

  @override
  Future<void> unregisterToken(String token) => _guard(() async {
    await _client.rpc('unregister_device_token', params: {'p_token': token});
  });
}
