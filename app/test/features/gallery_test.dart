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
    await tester.ensureVisible(find.text('Design gallery').last);
    await tester.tap(find.text('Design gallery').last);
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
      find.widgetWithText(TextField, '').at(2),
    );
    expect(field.decoration?.hintTextDirection, TextDirection.ltr);
  });
}
