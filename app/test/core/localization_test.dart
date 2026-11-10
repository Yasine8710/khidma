import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/app.dart';
import 'package:khidma/core/l10n/locale_controller.dart';
import 'package:khidma/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KhidmaApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

class _FailingPrefs implements SharedPreferences {
  _FailingPrefs(this._inner);
  final SharedPreferences _inner;

  @override
  Future<bool> setString(String key, String value) async =>
      throw Exception('disk full');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Function.apply((_inner as dynamic).noSuchMethod, [invocation]);
}

TextDirection _dir(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold)));

void main() {
  testWidgets('defaults to French LTR', (tester) async {
    final c = await _pump(tester);
    expect(c.read(localeProvider), const Locale('fr'));
    expect(_dir(tester), TextDirection.ltr);
    expect(find.text('Choisir la langue'), findsOneWidget);
    expect(find.text('12 professionnels'), findsOneWidget);
  });

  testWidgets('switching to Arabic flips to RTL and persists', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(_dir(tester), TextDirection.rtl);
    expect(find.text('اختر اللغة'), findsOneWidget);
    expect(find.text('12 حرفيًا'), findsOneWidget);
    expect(c.read(localeProvider), const Locale('ar'));
    final sp = c.read(sharedPreferencesProvider);
    expect(sp.getString('locale'), 'ar');
  });

  testWidgets('restores saved locale on start', (tester) async {
    await _pump(tester, prefs: {'locale': 'en'});
    expect(_dir(tester), TextDirection.ltr);
    expect(find.text('Choose language'), findsOneWidget);
    expect(find.text('12 professionals'), findsOneWidget);
  });

  testWidgets('unknown saved locale falls back to French', (tester) async {
    final c = await _pump(tester, prefs: {'locale': 'xx'});
    expect(c.read(localeProvider), defaultLocale);
  });

  test('Arabic plural categories select the right form', () async {
    final l = await AppLocalizations.delegate.load(const Locale('ar'));
    final expected = {
      0: 'لا يوجد حرفيون',
      1: 'حرفي واحد',
      2: 'حرفيان',
      3: '3 حرفيين',
      10: '10 حرفيين',
      11: '11 حرفيًا',
      99: '99 حرفيًا',
      100: '100 حرفي',
      101: '101 حرفي',
      102: '102 حرفي',
      103: '103 حرفيين',
      111: '111 حرفيًا',
    };
    expected.forEach(
      (n, s) => expect(l.professionalsCount(n), s, reason: '$n'),
    );
  });

  test('French and English plurals', () async {
    final fr = await AppLocalizations.delegate.load(const Locale('fr'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(fr.professionalsCount(0), 'Aucun professionnel');
    expect(fr.professionalsCount(1), '1 professionnel');
    expect(fr.professionalsCount(5), '5 professionnels');
    expect(en.professionalsCount(0), 'No professionals');
    expect(en.professionalsCount(1), '1 professional');
    expect(en.professionalsCount(5), '5 professionals');
  });

  testWidgets('keeps new language when saving fails', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final failing = _FailingPrefs(await SharedPreferences.getInstance());
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(failing)],
    );
    addTearDown(container.dispose);
    final saved = await container
        .read(localeProvider.notifier)
        .setLocale(const Locale('ar'));
    expect(saved, isFalse);
    expect(container.read(localeProvider), const Locale('ar'));
  });

  testWidgets('language options meet tap-target and label guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  for (final code in ['fr', 'ar', 'en']) {
    testWidgets('no overflow at 2x text scale, narrow screen ($code)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await _pump(tester, prefs: {'locale': code});
      expect(tester.takeException(), isNull);
    });
  }
}
