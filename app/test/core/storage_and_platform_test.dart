import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/l10n/locale_controller.dart';
import 'package:khidma/core/theme/theme_mode_controller.dart';
import 'package:khidma/features/onboarding/application/onboarding_controller.dart';
import 'package:khidma/core/storage/preferences_provider.dart';
import 'package:khidma/shared/widgets/app_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

void main() {
  group('KeyValueStore', () {
    test(
      'MemoryStore round-trips and never fails (storage fallback)',
      () async {
        final s = MemoryStore();
        expect(s.getString('a'), isNull);
        expect(s.getBool('b'), isNull);
        expect(await s.setString('a', 'x'), isTrue);
        expect(await s.setBool('b', true), isTrue);
        expect(s.getString('a'), 'x');
        expect(s.getBool('b'), isTrue);
      },
    );

    test('PrefsStore persists through shared_preferences', () async {
      SharedPreferences.setMockInitialValues({'k': 'v'});
      final s = PrefsStore(await SharedPreferences.getInstance());
      expect(s.getString('k'), 'v');
      await s.setBool('flag', true);
      expect(s.getBool('flag'), isTrue);
    });

    test('settings work end to end on the in-memory fallback', () async {
      // The store main() falls back to when SharedPreferences cannot open.
      final c = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(MemoryStore())],
      );
      addTearDown(c.dispose);
      expect(c.read(localeProvider), defaultLocale);
      expect(
        await c.read(localeProvider.notifier).setLocale(const Locale('ar')),
        isTrue,
      );
      expect(c.read(localeProvider), const Locale('ar'));
      expect(
        await c.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
        isTrue,
      );
      expect(c.read(onboardingSeenProvider), isFalse);
      await c.read(onboardingSeenProvider.notifier).complete();
      expect(c.read(onboardingSeenProvider), isTrue);
    });
  });

  group('password field', () {
    testWidgets('disables autocorrect and suggestions, also while shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        bareApp(
          const Scaffold(
            body: AppTextField(label: 'Mot de passe', obscureText: true),
          ),
        ),
      );
      EditableText e() =>
          tester.widget<EditableText>(find.byType(EditableText));
      expect(e().autocorrect, isFalse);
      expect(e().enableSuggestions, isFalse);
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(e().obscureText, isFalse, reason: 'now visible');
      expect(e().autocorrect, isFalse);
      expect(e().enableSuggestions, isFalse);
    });

    testWidgets('ordinary fields keep autocorrect', (tester) async {
      await tester.pumpWidget(
        bareApp(const Scaffold(body: AppTextField(label: 'Nom'))),
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).autocorrect,
        isTrue,
      );
    });
  });

  group('platform configuration', () {
    test('Android release builds can reach the network', () {
      final main = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(main, contains('android.permission.INTERNET'));
    });

    test('Android does not back up app data by default', () {
      final main = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(main, contains('android:allowBackup="false"'));
    });

    test('web page has one viewport tag and a real description', () {
      final html = File('web/index.html').readAsStringSync();
      expect('name="viewport"'.allMatches(html).length, 1);
      expect(html, isNot(contains('A new Flutter project')));
    });

    test('no unused dependencies', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('cupertino_icons')));
    });

    test('CI builds web and checks an unsigned iOS build', () {
      final ci = File('../.github/workflows/ci.yml').readAsStringSync();
      expect(ci, contains('flutter build web --release'));
      expect(ci, contains('flutter build ios --release --no-codesign'));
      expect(ci, contains('flutter-version: 3.47.9'));
    });
  });
}
