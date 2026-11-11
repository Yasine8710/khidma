import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/application/auth_providers.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/notifications/application/notifications_providers.dart';
import 'package:khidma/features/notifications/data/supabase_notifications_repository.dart';
import 'package:khidma/features/notifications/domain/notifications_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

class _FakeNotifications implements NotificationsRepository {
  NotificationPrefs prefs = const NotificationPrefs();
  final saved = <NotificationPrefs>[];
  final registered = <(String, PushPlatform)>[];
  final unregistered = <String>[];
  bool failSave = false;
  bool failRegister = false;
  Completer<void>? gate;

  @override
  Future<NotificationPrefs> preferences() async => prefs;

  @override
  Future<void> savePreferences(NotificationPrefs p) async {
    saved.add(p);
    final g = gate;
    if (g != null) await g.future;
    if (failSave) throw const NotificationsError();
    prefs = p;
  }

  @override
  Future<void> registerToken(String token, PushPlatform platform) async {
    if (failRegister) throw const NotificationsError();
    registered.add((token, platform));
  }

  @override
  Future<void> unregisterToken(String token) async => unregistered.add(token);
}

class _FakePush implements PushService {
  _FakePush({this.token = 'fcm-token-1', this.available = true});
  String? token;
  final bool available;
  final refreshes = StreamController<String>.broadcast();
  int asked = 0;

  @override
  bool get isAvailable => available;
  @override
  Future<String?> requestToken() async {
    asked++;
    return token;
  }

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;
  @override
  PushPlatform get platform => PushPlatform.ios;
}

Future<dynamic> _open(
  WidgetTester tester,
  _FakeNotifications repo, {
  PushService? push,
  FakeAuthRepository? auth,
  Map<String, Object> prefs = const {},
}) async {
  final c = await pumpApp(
    tester,
    auth: auth ?? FakeAuthRepository(signedIn: _ali),
    prefs: prefs,
    overrides: [
      notificationsRepositoryProvider.overrideWithValue(repo),
      if (push != null) pushServiceProvider.overrideWithValue(push),
      beforeSignOutProvider.overrideWith(
        (ref) => [() => ref.read(pushLifecycleProvider).unregister()],
      ),
    ],
  );
  c.read(routerProvider).push(AppRoutes.notificationSettings);
  await tester.pumpAndSettle();
  return c;
}

void main() {
  setUpAll(loadAppFonts);

  group('settings', () {
    testWidgets('shows the saved choices and the honest "no push yet" note', (
      tester,
    ) async {
      final repo = _FakeNotifications()
        ..prefs = const NotificationPrefs(messages: false);
      await _open(tester, repo);
      expect(find.text('Offres reçues et acceptées'), findsOneWidget);
      expect(
        find.textContaining('ne sont pas encore disponibles sur cet appareil'),
        findsOneWidget,
      );
      final sw = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(sw.map((s) => s.value), [true, false, true]);
    });

    testWidgets('no "unavailable" note once push is available', (tester) async {
      await _open(tester, _FakeNotifications(), push: _FakePush());
      expect(
        find.textContaining('ne sont pas encore disponibles'),
        findsNothing,
      );
    });

    testWidgets('a switch saves the whole choice; the screen follows', (
      tester,
    ) async {
      final repo = _FakeNotifications();
      await _open(tester, repo);
      await tester.tap(find.text('Nouveaux messages'));
      await tester.pumpAndSettle();
      expect(repo.saved.single, const NotificationPrefs(messages: false));
      final sw = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(sw.map((s) => s.value), [true, false, true]);
    });

    testWidgets('while saving, the switch already shows the new value', (
      tester,
    ) async {
      final repo = _FakeNotifications();
      await _open(tester, repo);
      final gate = repo.gate = Completer<void>();
      await tester.tap(find.text('Avancement des chantiers'));
      await tester.pump();
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Avancement des chantiers'),
            )
            .value,
        isFalse,
      );
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a failed save puts the switch back and says so', (
      tester,
    ) async {
      final repo = _FakeNotifications()..failSave = true;
      await _open(tester, repo);
      await tester.tap(find.text('Offres reçues et acceptées'));
      await tester.pumpAndSettle();
      expect(
        find.text('Impossible d’enregistrer ce choix. Réessayez.'),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .first
            .value,
        isTrue,
      );
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('signed out: an invitation, nothing loaded', (tester) async {
      await _open(tester, _FakeNotifications(), auth: FakeAuthRepository());
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('the Profile tab links to it', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(
            _FakeNotifications(),
          ),
        ],
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Notifications'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Nouveaux messages'), findsOneWidget);
    });

    for (final lang in ['fr', 'ar', 'en']) {
      testWidgets('fits a small phone at 1.5x text ($lang)', (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await _open(tester, _FakeNotifications(), prefs: {'locale': lang});
        expect(tester.takeException(), isNull, reason: lang);
      });
    }
  });

  group('device registration', () {
    testWidgets(
      'a signed-in account registers this device; nobody signed in registers nothing',
      (tester) async {
        final repo = _FakeNotifications();
        final push = _FakePush();
        await pumpApp(
          tester,
          auth: FakeAuthRepository(),
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repo),
            pushServiceProvider.overrideWithValue(push),
          ],
        );
        expect(repo.registered, isEmpty);
        expect(push.asked, 0);

        final repo2 = _FakeNotifications();
        await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: _ali),
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repo2),
            pushServiceProvider.overrideWithValue(_FakePush()),
          ],
        );
        expect(repo2.registered.single, ('fcm-token-1', PushPlatform.ios));
      },
    );

    testWidgets(
      'signing in later registers; a refreshed token is registered too',
      (tester) async {
        final auth = FakeAuthRepository();
        final repo = _FakeNotifications();
        final push = _FakePush();
        await pumpApp(
          tester,
          auth: auth,
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repo),
            pushServiceProvider.overrideWithValue(push),
          ],
        );
        auth.emit(_ali);
        await tester.pumpAndSettle();
        expect(repo.registered.map((r) => r.$1), ['fcm-token-1']);
        push.refreshes.add('fcm-token-2');
        await tester.pumpAndSettle();
        expect(repo.registered.map((r) => r.$1), [
          'fcm-token-1',
          'fcm-token-2',
        ]);
      },
    );

    testWidgets(
      'permission refused or push unavailable: nothing is registered, nothing breaks',
      (tester) async {
        final repo = _FakeNotifications();
        await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: _ali),
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repo),
            pushServiceProvider.overrideWithValue(_FakePush(token: null)),
          ],
        );
        expect(repo.registered, isEmpty);
        final repo2 = _FakeNotifications();
        final off = _FakePush(available: false);
        await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: _ali),
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repo2),
            pushServiceProvider.overrideWithValue(off),
          ],
        );
        expect(
          off.asked,
          0,
          reason: 'no permission prompt when pushes cannot work',
        );
      },
    );

    testWidgets('a failing server does not break the app', (tester) async {
      final repo = _FakeNotifications()..failRegister = true;
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repo),
          pushServiceProvider.overrideWithValue(_FakePush()),
        ],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('signing out first stops pushes for this device', (
      tester,
    ) async {
      final repo = _FakeNotifications();
      final auth = FakeAuthRepository(signedIn: _ali);
      await pumpApp(
        tester,
        auth: auth,
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repo),
          pushServiceProvider.overrideWithValue(_FakePush()),
          beforeSignOutProvider.overrideWith(
            (ref) => [() => ref.read(pushLifecycleProvider).unregister()],
          ),
        ],
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Se déconnecter'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(repo.unregistered, ['fcm-token-1']);
      expect(auth.signOutCalls, 1);
    });

    testWidgets(
      'after signing out, a refreshed token is no longer registered for the previous account',
      (tester) async {
        final repo = _FakeNotifications();
        final push = _FakePush();
        final auth = FakeAuthRepository(signedIn: _ali);
        await pumpApp(
          tester,
          auth: auth,
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repo),
            pushServiceProvider.overrideWithValue(push),
            beforeSignOutProvider.overrideWith(
              (ref) => [() => ref.read(pushLifecycleProvider).unregister()],
            ),
          ],
        );
        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Se déconnecter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Se déconnecter'));
        await tester.pumpAndSettle();
        final before = repo.registered.length;
        push.refreshes.add('fcm-token-late');
        await tester.pumpAndSettle();
        expect(repo.registered.length, before);
      },
    );

    testWidgets('a failing unregister never blocks signing out', (
      tester,
    ) async {
      final repo = _FailingUnregister();
      final auth = FakeAuthRepository(signedIn: _ali);
      await pumpApp(
        tester,
        auth: auth,
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repo),
          pushServiceProvider.overrideWithValue(_FakePush()),
          beforeSignOutProvider.overrideWith(
            (ref) => [() => ref.read(pushLifecycleProvider).unregister()],
          ),
        ],
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Se déconnecter'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(auth.signOutCalls, 1);
    });
  });

  group('wire format', () {
    late List<http.Request> requests;
    SupabaseNotificationsRepository build(Object body) {
      requests = [];
      return SupabaseNotificationsRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(body),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
    }

    test(
      'preferences: defaults when the server has none, values otherwise',
      () async {
        expect(
          await build(<Object>[]).preferences(),
          const NotificationPrefs(),
        );
        final p = await build([
          {'offers': true, 'messages': false, 'jobs': true},
        ]).preferences();
        expect(p, const NotificationPrefs(messages: false));
        expect(
          requests.single.url.path,
          '/rest/v1/rpc/my_notification_preferences',
        );
      },
    );

    test('save and token calls use the right functions', () async {
      final repo = build(<Object>[]);
      await repo.savePreferences(const NotificationPrefs(offers: false));
      await repo.registerToken('tok-tok-tok-tok-tok-tok', PushPlatform.android);
      await repo.unregisterToken('tok-tok-tok-tok-tok-tok');
      expect(requests.map((r) => r.url.path.split('/').last), [
        'set_notification_preferences',
        'register_device_token',
        'unregister_device_token',
      ]);
      expect(jsonDecode(requests[0].body), {
        'p_offers': false,
        'p_messages': true,
        'p_jobs': true,
      });
      expect(jsonDecode(requests[1].body), {
        'p_token': 'tok-tok-tok-tok-tok-tok',
        'p_platform': 'android',
      });
    });

    test('server errors become one error without details', () async {
      final repo = SupabaseNotificationsRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient(
            (r) async => http.Response('{"message":"secret"}', 500, request: r),
          ),
        ),
      );
      await expectLater(repo.preferences(), throwsA(isA<NotificationsError>()));
    });
  });

  test('preferences value equality and copy', () {
    expect(const NotificationPrefs() == const NotificationPrefs(), isTrue);
    expect(const NotificationPrefs().copyWith(jobs: false).jobs, isFalse);
    expect(const NotificationPrefs().copyWith(jobs: false).offers, isTrue);
  });
}

class _FailingUnregister extends _FakeNotifications {
  @override
  Future<void> unregisterToken(String token) async =>
      throw const NotificationsError();
}
