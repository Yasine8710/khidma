import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/storage/preferences_provider.dart';
import 'package:khidma/core/l10n/locale_controller.dart';
import 'package:khidma/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

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

Future<void> _openProfile(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('defaults to French LTR', (tester) async {
    final c = await pumpApp(tester);
    expect(c.read(localeProvider), const Locale('fr'));
    expect(screenDirection(tester), TextDirection.ltr);
    expect(find.text('Accueil'), findsOneWidget);
  });

  testWidgets('switching to Arabic flips to RTL and persists', (tester) async {
    final c = await pumpApp(tester);
    await _openProfile(tester, 'Profil');
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(screenDirection(tester), TextDirection.rtl);
    expect(find.text('اختر اللغة'), findsOneWidget);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(c.read(localeProvider), const Locale('ar'));
    expect(c.read(keyValueStoreProvider).getString('locale'), 'ar');
  });

  testWidgets('restores saved locale on start', (tester) async {
    await pumpApp(tester, prefs: {'locale': 'en'});
    expect(screenDirection(tester), TextDirection.ltr);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('unknown saved locale falls back to French', (tester) async {
    final c = await pumpApp(tester, prefs: {'locale': 'xx'});
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
    final failing = _FailingStore();
    final container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(failing)],
    );
    addTearDown(container.dispose);
    final saved = await container
        .read(localeProvider.notifier)
        .setLocale(const Locale('ar'));
    expect(saved, isFalse);
    expect(container.read(localeProvider), const Locale('ar'));
  });

  for (final code in ['fr', 'ar', 'en']) {
    testWidgets('no overflow at 2x text scale on 320 px screen ($code)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await pumpApp(tester, prefs: {'locale': code});
      final l = await AppLocalizations.delegate.load(Locale(code));
      for (final tab in [
        l.navRequests,
        l.navMessages,
        l.navProfile,
        l.navHome,
      ]) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$code $tab');
      }
    });
  }
}
