import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/l10n/locale_controller.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/core/storage/preferences_provider.dart';
import 'package:khidma/core/theme/app_theme.dart';
import 'package:khidma/features/auth/presentation/login_screen.dart';
import 'package:khidma/features/onboarding/application/onboarding_controller.dart';
import 'package:khidma/features/onboarding/presentation/onboarding_screen.dart';
import 'package:khidma/features/onboarding/presentation/welcome_marquee.dart';
import 'package:khidma/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

const _fresh = {'onboardingSeen': false};

const _sentenceFr =
    'Trouvez un plombier, un électricien, un développeur, un designer '
    'ou un menuisier près de chez vous.';

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

/// Scroll offsets of the three moving rows.
List<double> _rowOffsets(WidgetTester tester) => tester
    .stateList<ScrollableState>(
      find.descendant(
        of: find.byType(WelcomeMarquee),
        matching: find.byType(Scrollable),
      ),
    )
    .map((s) => s.position.pixels)
    .toList();

/// Advances [seconds] of animation one frame at a time (the screen never
/// settles while its rows move).
Future<void> _run(WidgetTester tester, double seconds) async {
  final frames = (seconds * 20).round();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The welcome screen alone (no router), with motion on and optional
/// TickerMode / Reduce Motion, to check how its endless motion behaves.
Future<void> _pumpWelcome(
  WidgetTester tester, {
  bool tickers = true,
  bool reduce = false,
}) async {
  SharedPreferences.setMockInitialValues(_fresh);
  final sp = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(PrefsStore(sp))],
      child: TickerMode(
        enabled: tickers,
        child: MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(const Locale('fr')),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
            child: child!,
          ),
          home: const OnboardingScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('first launch shows the single welcome screen', (tester) async {
    final c = await pumpApp(tester, prefs: _fresh);
    expect(_path(c), AppRoutes.onboarding);
    expect(find.text('Khidma'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget, reason: 'language button');
    expect(find.text('Trouvez un'), findsOneWidget);
    expect(find.text('plombier'), findsOneWidget);
    expect(find.text('près de chez vous.'), findsOneWidget);
    expect(find.text('Artisans et freelances vérifiés'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text("J'ai déjà un compte"), findsOneWidget);
    expect(find.byType(WelcomeMarquee), findsOneWidget);
    // One screen: no slides, no Next/Skip, no tab bar.
    expect(find.byType(PageView), findsNothing);
    expect(find.text('Suivant'), findsNothing);
    expect(find.text('Passer'), findsNothing);
    expect(find.text('Accueil'), findsNothing);
  });

  testWidgets('rows show real category names and sample pros, no counts', (
    tester,
  ) async {
    await pumpApp(tester, prefs: _fresh);
    expect(find.text('Plomberie'), findsWidgets);
    expect(find.text('Développement web'), findsWidgets);
    expect(find.text('Mehdi B.'), findsWidgets);
    expect(find.text('Plombier'), findsWidgets);
    // No invented numbers anywhere ("2 400+ pros", "1000 avis"...).
    expect(find.textContaining('+'), findsNothing);
    expect(find.textContaining(RegExp(r'\d{3}')), findsNothing);
  });

  testWidgets('Commencer marks onboarding seen and lands on Home, saved', (
    tester,
  ) async {
    final c = await pumpApp(tester, prefs: _fresh);
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(_path(c), AppRoutes.home);
    expect(find.text('Accueil'), findsOneWidget);
    expect(c.read(onboardingSeenProvider), isTrue);
    expect(c.read(keyValueStoreProvider).getBool('onboardingSeen'), isTrue);
  });

  testWidgets('"J\'ai déjà un compte" marks seen and opens sign-in', (
    tester,
  ) async {
    final c = await pumpApp(tester, prefs: _fresh);
    await tester.tap(find.text("J'ai déjà un compte"));
    await tester.pumpAndSettle();
    expect(_path(c), AppRoutes.login);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(c.read(onboardingSeenProvider), isTrue);
    expect(c.read(keyValueStoreProvider).getBool('onboardingSeen'), isTrue);
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

  testWidgets('language sheet switches the language and closes', (
    tester,
  ) async {
    final c = await pumpApp(tester, prefs: _fresh);
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('Choisir la langue'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(c.read(localeProvider), const Locale('en'));
    expect(c.read(keyValueStoreProvider).getString('locale'), 'en');
    expect(find.text('Choose language'), findsNothing, reason: 'sheet closed');
    expect(find.text('Find'), findsOneWidget);
    expect(find.text('a plumber'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(find.text('English'), findsOneWidget, reason: 'button shows it');
    expect(find.text('Plumbing'), findsWidgets, reason: 'rows translated');
    expect(_path(c), AppRoutes.onboarding, reason: 'still on welcome');
  });

  testWidgets('Arabic: RTL, natural headline, logo at the start (right)', (
    tester,
  ) async {
    await pumpApp(tester, prefs: {..._fresh, 'locale': 'ar'});
    expect(screenDirection(tester), TextDirection.rtl);
    expect(find.text('اعثر على'), findsOneWidget);
    expect(find.text('قريب منك.'), findsOneWidget);
    // "اعثر على سبّاك قريب منك": the word sits between the two lines.
    final headline = find
        .ancestor(of: find.text('اعثر على'), matching: find.byType(Column))
        .first;
    expect(
      find.descendant(of: headline, matching: find.text('سبّاك')),
      findsOneWidget,
    );
    expect(find.text('ابدأ'), findsOneWidget);
    expect(find.text('مهدي ب.'), findsWidgets, reason: 'names in Arabic');
    final logo = tester.getCenter(find.text('Khidma'));
    final lang = tester.getCenter(find.text('العربية'));
    expect(logo.dx, greaterThan(lang.dx));
  });

  testWidgets('screen readers hear the headline once, not the moving rows', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, prefs: _fresh);
    expect(find.bySemanticsLabel(_sentenceFr), findsOneWidget);
    // The rotating word is not announced on its own.
    expect(find.bySemanticsLabel('plombier'), findsNothing);
    // Decorative rows are hidden from assistive tech.
    expect(find.bySemanticsLabel('Mehdi B.'), findsNothing);
    expect(find.bySemanticsLabel('Plomberie'), findsNothing);
    expect(find.bySemanticsLabel('Langue : Français'), findsOneWidget);
    expect(find.bySemanticsLabel('Commencer'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('does not ask for location or other permissions', (tester) async {
    // Onboarding is pure UI: no permission plugin is even a dependency.
    await pumpApp(tester, prefs: _fresh);
    expect(find.textContaining('localisation'), findsNothing);
    expect(find.textContaining('location'), findsNothing);
  });

  testWidgets('Commencer restores the deep link that was waiting', (
    tester,
  ) async {
    final c = await pumpApp(tester, prefs: _fresh);
    c.read(routerProvider).go('${AppRoutes.messages}?ref=push');
    await tester.pumpAndSettle();
    final uri = c.read(routerProvider).routerDelegate.currentConfiguration.uri;
    expect(uri.path, AppRoutes.onboarding);
    expect(uri.queryParameters['from'], '${AppRoutes.messages}?ref=push');

    await tester.tap(find.text('Commencer'));
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

  testWidgets('cold start at a deep link goes through the welcome screen', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/profile';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final c = await pumpApp(tester, prefs: _fresh);
    expect(_path(c), AppRoutes.onboarding);
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(_path(c), AppRoutes.profile);
  });

  group('motion', () {
    testWidgets('rows scroll and the word rotates while visible', (
      tester,
    ) async {
      await _pumpWelcome(tester);
      expect(find.text('plombier'), findsOneWidget);
      expect(_rowOffsets(tester), everyElement(0.0));
      await _run(tester, 1);
      final first = _rowOffsets(tester);
      expect(first, hasLength(3));
      expect(first, everyElement(greaterThan(10.0)));
      // Different speeds per row.
      expect(first.toSet(), hasLength(3));
      await _run(tester, 1.8);
      expect(find.text('électricien'), findsOneWidget);
      expect(_rowOffsets(tester).first, greaterThan(first.first));
      // Disposing mid-motion leaves no ticker or timer behind.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('paused when hidden (TickerMode off)', (tester) async {
      await _pumpWelcome(tester, tickers: false);
      await _run(tester, 3);
      expect(_rowOffsets(tester), everyElement(0.0));
      expect(find.text('plombier'), findsOneWidget);
      expect(find.text('électricien'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Reduce Motion: still rows, fixed word, everything shown', (
      tester,
    ) async {
      await _pumpWelcome(tester, reduce: true);
      // No entrance either: the last item of the cascade is fully visible.
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Commencer'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
      await _run(tester, 3);
      expect(_rowOffsets(tester), everyElement(0.0));
      expect(find.text('plombier'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('full app with motion on keeps moving, then disposes', (
      tester,
    ) async {
      final c = await pumpApp(
        tester,
        prefs: _fresh,
        ambientMotion: true,
        settle: false,
      );
      await _run(tester, 2.5);
      expect(find.text('électricien'), findsOneWidget);
      // Buttons still work while the rows move.
      await tester.tap(find.text('Commencer'));
      await _run(tester, 1);
      expect(_path(c), AppRoutes.home);
      expect(find.byType(OnboardingScreen), findsNothing);
      await tester.pumpAndSettle();
    });
  });

  testWidgets('small phone at 2x text: no overflow, every language reachable', (
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
    expect(tester.takeException(), isNull);
    // The rows give their room to the words at very large text.
    expect(find.byType(WelcomeMarquee), findsNothing);
    var current = 'Français';
    for (final entry in {
      'العربية': const Locale('ar'),
      'English': const Locale('en'),
      'Français': const Locale('fr'),
    }.entries) {
      await tester.tap(find.text(current));
      await tester.pumpAndSettle();
      final option = find.text(entry.key).last;
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(c.read(localeProvider), entry.value, reason: entry.key);
      expect(tester.takeException(), isNull, reason: entry.key);
      current = entry.key;
    }
    await tester.ensureVisible(find.text('Commencer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(_path(c), AppRoutes.home);
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
    expect(find.byType(WelcomeMarquee), findsOneWidget);
  });

  for (final lang in ['fr', 'ar', 'en']) {
    for (final width in [320.0, 390.0]) {
      testWidgets('no overflow at ${width.round()} px and 1.5x text ($lang)', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final c = await pumpApp(tester, prefs: {..._fresh, 'locale': lang});
        expect(tester.takeException(), isNull, reason: lang);
        // The words are all there and the main button is reachable.
        final start = find.byType(FilledButton);
        await tester.ensureVisible(start);
        await tester.pumpAndSettle();
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: lang);
        expect(_path(c), AppRoutes.home, reason: lang);
      });
    }
  }
}
