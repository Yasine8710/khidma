class NotificationPrefs {
  const NotificationPrefs({
    this.offers = true,
    this.messages = true,
    this.jobs = true,
  });

  final bool offers;
  final bool messages;
  final bool jobs;

  NotificationPrefs copyWith({bool? offers, bool? messages, bool? jobs}) =>
      NotificationPrefs(
        offers: offers ?? this.offers,
        messages: messages ?? this.messages,
        jobs: jobs ?? this.jobs,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.offers == offers &&
      other.messages == messages &&
      other.jobs == jobs;
  @override
  int get hashCode => Object.hash(offers, messages, jobs);
}

enum PushPlatform { ios, android }

abstract interface class NotificationsRepository {
  Future<NotificationPrefs> preferences();
  Future<void> savePreferences(NotificationPrefs prefs);

  /// Tells the server this device receives this account's notifications.
  Future<void> registerToken(String token, PushPlatform platform);

  /// Stops this device receiving them (called before signing out).
  Future<void> unregisterToken(String token);
}

/// The phone's push channel (Firebase Cloud Messaging on both platforms).
/// Not wired until a Firebase project exists; the app works without it.
abstract interface class PushService {
  /// Whether this build can receive pushes at all.
  bool get isAvailable;

  /// Asks the person for permission if needed and returns the device token,
  /// or null when permission is refused or pushes are unavailable.
  Future<String?> requestToken();

  /// Called when the system issues a new token.
  Stream<String> get tokenRefreshes;

  PushPlatform get platform;
}

class NotConfiguredPushService implements PushService {
  const NotConfiguredPushService();
  @override
  bool get isAvailable => false;
  @override
  Future<String?> requestToken() async => null;
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
  @override
  PushPlatform get platform => PushPlatform.android;
}

/// Failure of a notifications call (no detail: the settings screen only needs
/// "it did not work").
class NotificationsError implements Exception {
  const NotificationsError();
  @override
  String toString() => 'NotificationsError';
}

class NotConfiguredNotificationsRepository implements NotificationsRepository {
  const NotConfiguredNotificationsRepository();
  @override
  Future<NotificationPrefs> preferences() async =>
      throw const NotificationsError();
  @override
  Future<void> savePreferences(NotificationPrefs prefs) async =>
      throw const NotificationsError();
  @override
  Future<void> registerToken(String token, PushPlatform platform) async {}
  @override
  Future<void> unregisterToken(String token) async {}
}
