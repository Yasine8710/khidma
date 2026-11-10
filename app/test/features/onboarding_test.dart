import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/storage/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:khidma/core/l10n/locale_controller.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/onboarding/application/onboarding_controller.dart';

import '../test_helpers.dart';

const _fresh = {'onboardingSeen': false};

class _FailingStore implements KeyValueStore {
  @override
  String? getString(String key) => null;
  @override
  bool? getBool(String key) => null;
  @override
  Future<bool> setString(String key, String value) async =>
      throw Exception('disk full');
  @override
  Future<bool> setBool(String key, bool value) async =>
      throw Exception('disk full');
}

String _path(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('first launch shows onboarding, language page first', (
    tester,
  ) async {
    final c = await pumpApp(tester, prefs: _fresh);
    expect(_path(c), AppRoutes.onboarding);
    expect(find.text('Choisir la langue'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
    // No tab bar and no Skip on the language page.
    expect(find.text('Accueil'), findsNothing);
    expect(find.text('Passer'), findsNothing);
  });

  testWidgets('walks through the pages and ends on Home, saved', (
    tester,
  ) async {
    final c = await pumpApp(tester, prefs: _fresh);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(
      find.text('Trouvez des professionnels de confiance'),
      findsOneWidget,
    );
    expect(find.text('Passer'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Comparez et demandez un devis'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Contactez-les directement'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Passer'), findsNothing, reason: 'last page has no skip');

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(_path(c), AppRoutes.home);
    expect(find.text('Accueil'), findsOneWidget);
    expect(c.read(onboardingSeenProvider), isTrue);
    expect(c.read(keyValueStoreProvider).getBool('onboardingSeen'), isTrue);
  });

  testWidgets('Skip completes onboarding', (tester) async {
    final c = await pumpApp(tester, prefs: _fresh);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    expect(_path(c), AppRoutes.home);
  });

  testWidgets('onboarding is not shown again once seen', (tester) async {
    final c = await pumpApp(tester);
    expect(_path(c), AppRoutes.home);
    c.read(routerProvider).go(AppRoutes.onboarding);
    await tester.pumpAndSettle();
    expect(_path(c), AppRoutes.home, reason: 'seen users are redirected away');
  });

  testWidgets('deep link before onboarding is redirected to onboarding', (
    tester,
  ) async {
    final c = await pumpApp(tester, prefs: _fresh);
    c.read(routerProvider).go(AppRoutes.profile);
    await tester.pumpAndSettle();
    expect(_path(c), AppRoutes.onboarding);
  });

  testWidgets('changing language on page one re-renders the flow', (
    tester,
  ) async {
    final c = await pumpApp(tester, prefs: _fresh);
    await tester.ensureVisible(find.text('English'));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(c.read(localeProvider), const Locale('en'));
    expect(find.text('Choose language'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Find trusted professionals'), findsOneWidget);
  });

  testWidgets('Arabic: RTL, swipe direction and page order', (tester) async {
    await pumpApp(tester, prefs: {..._fresh, 'locale': 'ar'});
    expect(screenDirection(tester), TextDirection.rtl);
    expect(find.text('اختر اللغة'), findsOneWidget);
    // In RTL the next page is to the left: swiping right-to-left goes back,
    // left-to-right goes forward.
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('اعثر على حرفيين موثوقين'), findsOneWidget);
  });

  testWidgets('screen readers get "page x of y"', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, prefs: _fresh);
    expect(find.bySemanticsLabel(RegExp('Page 1 sur 4')), findsOneWidget);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('Page 2 sur 4, Trouvez')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('does not ask for location or other permissions', (tester) async {
    // Onboarding is pure UI: no permission plugin is even a dependency.
    await pumpApp(tester, prefs: _fresh);
    expect(find.textContaining('localisation'), findsNothing);
    expect(find.textContaining('location'), findsNothing);
  });

  testWidgets('keeps the deep link through onboarding and restores it', (
    tester,
  ) async {
    final c = await pumpApp(tester, prefs: _fresh);
    c.read(routerProvider).go('${AppRoutes.messages}?ref=push');
    await tester.pumpAndSettle();
    final uri = c.read(routerProvider).routerDelegate.currentConfiguration.uri;
    expect(uri.path, AppRoutes.onboarding);
    expect(uri.queryParameters['from'], '${AppRoutes.messages}?ref=push');

    await c.read(onboardingSeenProvider.notifier).complete();
    await tester.pumpAndSettle();
    final after = c
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri;
    expect(after.path, AppRoutes.messages);
    expect(after.queryParameters, {'ref': 'push'});
  });

  testWidgets('crafted ?from= values cannot redirect off-app', (tester) async {
    for (final evil in ['//evil.com', 'https://evil.com', '/onboarding?x=1']) {
      final c = await pumpApp(tester, prefs: _fresh);
      c
          .read(routerProvider)
          .go(
            Uri(
              path: AppRoutes.onboarding,
              queryParameters: {'from': evil},
            ).toString(),
          );
      await tester.pumpAndSettle();
      await c.read(onboardingSeenProvider.notifier).complete();
      await tester.pumpAndSettle();
      expect(_path(c), AppRoutes.home, reason: evil);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('cold start at a deep link before onboarding goes through it', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/profile';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final c = await pumpApp(tester, prefs: _fresh);
    expect(_path(c), AppRoutes.onboarding);
    await c.read(onboardingSeenProvider.notifier).complete();
    await tester.pumpAndSettle();
    expect(_path(c), AppRoutes.profile);
  });

  testWidgets('Back button returns to the previous page', (tester) async {
    await pumpApp(tester, prefs: _fresh);
    expect(find.byTooltip('Précédent'), findsNothing);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Précédent'));
    await tester.pumpAndSettle();
    expect(find.text('Choisir la langue'), findsOneWidget);
    expect(find.byTooltip('Précédent'), findsNothing);
  });

  testWidgets('Arabic: Next goes forward, Back returns, all pages reachable', (
    tester,
  ) async {
    await pumpApp(tester, prefs: {..._fresh, 'locale': 'ar'});
    for (final title in [
      'اعثر على حرفيين موثوقين',
      'قارن واطلب عرض سعر',
      'تواصل معهم مباشرة',
    ]) {
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('ابدأ'), findsOneWidget);
    await tester.tap(find.byTooltip('السابق'));
    await tester.pumpAndSettle();
    expect(find.text('قارن واطلب عرض سعر'), findsOneWidget);
    // Reverse swipe (left to right in RTL is forward; right to left is back).
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('اعثر على حرفيين موثوقين'), findsOneWidget);
  });

  testWidgets('reduced motion: page changes apply without animation', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester, prefs: _fresh);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(
      find.text('Trouvez des professionnels de confiance'),
      findsOneWidget,
    );
  });

  testWidgets('every language is reachable on a small phone at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final c = await pumpApp(tester, prefs: _fresh);
    for (final entry in {
      'العربية': const Locale('ar'),
      'English': const Locale('en'),
      'Français': const Locale('fr'),
    }.entries) {
      await tester.ensureVisible(find.text(entry.key));
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(c.read(localeProvider), entry.value, reason: entry.key);
    }
    // Decoration is dropped on compact screens to leave room for the list.
    expect(find.byIcon(Icons.translate_rounded), findsNothing);
  });

  testWidgets(
    'storage failure: user still proceeds, onboarding returns later',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboardingSeen': false});
      final failing = _FailingStore();
      final c = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(failing)],
      );
      addTearDown(c.dispose);
      final saved = await c.read(onboardingSeenProvider.notifier).complete();
      expect(saved, isFalse);
      expect(c.read(onboardingSeenProvider), isTrue, reason: 'proceeds now');
      // A new session reads the (unchanged) store: onboarding shows again.
      final fresh = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            PrefsStore(await SharedPreferences.getInstance()),
          ),
        ],
      );
      addTearDown(fresh.dispose);
      expect(fresh.read(onboardingSeenProvider), isFalse);
    },
  );

  testWidgets('content stays phone-width on a wide screen', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, prefs: _fresh);
    expect(
      tester.getSize(find.byType(FilledButton)).width,
      lessThanOrEqualTo(520),
    );
  });

  testWidgets('brand logo shows on an ordinary small phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(tester, prefs: _fresh);
    expect(find.text('Khidma'), findsOneWidget);
  });

  for (final lang in ['fr', 'ar', 'en']) {
    testWidgets('no overflow on a 320x568 phone at 1.5x text ($lang)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await pumpApp(tester, prefs: {..._fresh, 'locale': lang});
      for (var i = 0; i < 4; i++) {
        expect(tester.takeException(), isNull, reason: '$lang page $i');
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
      }
    });
  }
}
