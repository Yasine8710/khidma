import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/features/gallery/gallery_config.dart';
import 'package:khidma/features/gallery/gallery_screen.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(loadAppFonts);

  test('gallery is available in debug test builds', () {
    // In release builds without --dart-define=GALLERY=true this is false and
    // the route and the Profile entry are not created at all.
    expect(kShowGallery, isTrue);
  });

  testWidgets('Profile has an entry that opens the gallery', (tester) async {
    final c = await pumpApp(tester);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    // The Profile list is lazy: scroll until the developer entry is built.
    await tester.scrollUntilVisible(
      find.text('Design gallery'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Design gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Design gallery'));
    // The gallery has a looping shimmer, so settle by time, not by idle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GalleryScreen), findsOneWidget);
    // Back returns to Profile.
    c.read(routerProvider).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GalleryScreen), findsNothing);
    expect(find.text('Choisir la langue'), findsOneWidget);
  });

  for (final lang in ['fr', 'ar', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('renders without errors: $lang dark=$dark at 320 px', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320 * 2, 4000 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          bareApp(const GalleryScreen(), lang: lang, dark: dark),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        for (final section in [
          'BRAND',
          'COLORS',
          'TYPOGRAPHY',
          'BUTTONS',
          'TEXT FIELDS',
          'CHIPS',
          'CARDS, RATING, AVATAR, BADGES',
          'LOADING',
          'EMPTY AND ERROR STATES',
        ]) {
          expect(find.text(section), findsOneWidget, reason: section);
        }
      });
    }
  }

  testWidgets('forced-LTR phone field shows its hint left-to-right in Arabic', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 2, 4000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(bareApp(const GalleryScreen(), lang: 'ar'));
    await tester.pump(const Duration(milliseconds: 50));
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('gallery-phone')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.decoration?.hintTextDirection, TextDirection.ltr);
  });

  testWidgets(
    'works on a normal phone: scrolls, chips select, password toggles',
    (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(bareApp(const GalleryScreen()));
      await tester.pump(const Duration(milliseconds: 50));
      final list = find.byType(Scrollable).first;

      // Every section is reachable by scrolling.
      for (final section in ['COLORS', 'CHIPS', 'EMPTY AND ERROR STATES']) {
        await tester.dragUntilVisible(
          find.text(section),
          list,
          const Offset(0, -300),
        );
        expect(find.text(section), findsOneWidget);
      }
      await tester.dragUntilVisible(
        find.text('Climatisation'),
        list,
        const Offset(0, 300),
      );
      await tester.tap(find.text('Climatisation'));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.dragUntilVisible(
        find.byTooltip('Afficher le mot de passe'),
        list,
        const Offset(0, 300),
      );
      await tester.ensureVisible(find.byTooltip('Afficher le mot de passe'));
      await tester.pump();
      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pump();
      expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
    },
  );

  testWidgets('enlarged text (1.5x) still renders every section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 2, 6000 * 2);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    for (final lang in ['fr', 'ar']) {
      await tester.pumpWidget(bareApp(const GalleryScreen(), lang: lang));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: lang);
    }
  });
}
