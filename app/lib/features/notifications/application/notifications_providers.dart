import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../domain/notifications_domain.dart';

/// Overridden in `main()` with the Supabase repository when configured.
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => const NotConfiguredNotificationsRepository(),
);

/// Overridden with the Firebase-backed service once a Firebase project exists.
final pushServiceProvider = Provider<PushService>(
  (ref) => const NotConfiguredPushService(),
);

final notificationPrefsProvider = FutureProvider.autoDispose<NotificationPrefs>(
  retry: (n, e) => null,
  (ref) {
    if (ref.watch(currentUserProvider.select((u) => u?.id)) == null) {
      return Future.value(const NotificationPrefs());
    }
    return ref.watch(notificationsRepositoryProvider).preferences();
  },
);

/// Saves preferences. The switch moves at once; if saving fails it goes back
/// and the failure is returned (null = saved).
final notificationActionsProvider =
    NotifierProvider<NotificationActions, NotificationPrefs?>(
      NotificationActions.new,
    );

class NotificationActions extends Notifier<NotificationPrefs?> {
  @override
  NotificationPrefs? build() => null;

  /// The preferences shown while a save is in flight (else null).
  Future<bool> save(NotificationPrefs wanted) async {
    state = wanted;
    try {
      await ref.read(notificationsRepositoryProvider).savePreferences(wanted);
      if (ref.mounted) ref.invalidate(notificationPrefsProvider);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted) state = null;
    }
  }
}

/// Keeps this device's push token registered for the signed-in account, and
/// removes it when the person signs out (so the next person on this phone, or
/// nobody, receives nothing meant for the previous account).
final pushLifecycleProvider = Provider<PushLifecycle>((ref) {
  final life = PushLifecycle(ref);
  ref.onDispose(life.dispose);
  return life;
});

class PushLifecycle {
  PushLifecycle(this._ref);
  final Ref _ref;
  String? _token;
  StreamSubscription<String>? _refreshes;

  /// Registers the device for the account that is signed in now. Quiet when
  /// pushes are unavailable, refused, or the server is unreachable (retried on
  /// the next start or sign-in).
  Future<void> register() async {
    final push = _ref.read(pushServiceProvider);
    if (!push.isAvailable) return;
    try {
      final token = await push.requestToken();
      if (token == null) return;
      _token = token;
      await _ref
          .read(notificationsRepositoryProvider)
          .registerToken(token, push.platform);
      _refreshes ??= push.tokenRefreshes.listen((t) async {
        _token = t;
        try {
          await _ref
              .read(notificationsRepositoryProvider)
              .registerToken(t, push.platform);
        } catch (_) {}
      });
    } catch (_) {}
  }

  /// Called while still signed in, just before signing out.
  Future<void> unregister() async {
    // Stop reacting to token changes for the account that is leaving.
    final refreshes = _refreshes;
    _refreshes = null;
    // Not awaited: stopping the listener must never delay signing out.
    unawaited(refreshes?.cancel());
    final token = _token;
    if (token == null) return;
    try {
      await _ref.read(notificationsRepositoryProvider).unregisterToken(token);
    } catch (_) {
      // Not reachable now: the server forgets the device when the next account
      // signs in on it (the token moves), or after 60 days unseen.
    }
    _token = null;
  }

  void dispose() => _refreshes?.cancel();
}

/// Registers the device whenever someone signs in (and at start with a restored
/// session). Read once from the app root.
final pushRegistrationProvider = Provider<void>((ref) {
  ref.listen(currentUserProvider.select((u) => u?.id), (previous, now) {
    if (now != null && now != previous) {
      ref.read(pushLifecycleProvider).register();
    }
  }, fireImmediately: true);
});
