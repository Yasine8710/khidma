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

  test('every locale defines the same keys (plural coverage)', () async {
    for (final locale in supportedLocales) {
      final l = await AppLocalizations.delegate.load(locale);
      for (final n in [0, 1, 2, 3, 11, 100]) {
        expect(l.professionalsCount(n), isNotEmpty, reason: '$locale $n');
      }
    }
  });
}
