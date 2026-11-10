import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/l10n/locale_controller.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/onboarding/application/onboarding_controller.dart';

import '../test_helpers.dart';

const _fresh = {'onboardingSeen': false};

String _path(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

void main() {
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
    expect(c.read(sharedPreferencesProvider).getBool('onboardingSeen'), isTrue);
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
    expect(find.bySemanticsLabel('Page 1 sur 4'), findsOneWidget);
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Page 2 sur 4'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('does not ask for location or other permissions', (tester) async {
    // Onboarding is pure UI: no permission plugin is even a dependency.
    await pumpApp(tester, prefs: _fresh);
    expect(find.textContaining('localisation'), findsNothing);
    expect(find.textContaining('location'), findsNothing);
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
