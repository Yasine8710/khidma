@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/features/gallery/gallery_screen.dart';

import '../test_helpers.dart';

/// Golden images are rendered with the bundled fonts, so text is real, not
/// placeholder boxes. Glyph anti-aliasing differs slightly between
/// operating systems, so a small pixel difference is tolerated.
///
/// Tagged `golden`: CI (Linux) excludes them until baselines are generated
/// there. Refresh locally with
///   flutter test --update-goldens --tags golden
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile, this.tolerance);

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    try {
      if (result.passed || result.diffPercent <= tolerance) return true;
      throw FlutterError(await generateFailureOutput(result, golden, basedir));
    } finally {
      result.dispose();
    }
  }
}

Widget _gallery(String lang, {required bool dark}) =>
    bareApp(const GalleryScreen(), lang: lang, dark: dark);

void main() {
  late GoldenFileComparator previous;

  setUpAll(() async {
    previous = goldenFileComparator;
    final current = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _TolerantComparator(
      current.basedir.resolve('gallery_golden_test.dart'),
      0.005, // 0.5% of pixels
    );
    await loadAppFonts();
  });

  tearDownAll(() => goldenFileComparator = previous);

  for (final c in [
    ('fr', false),
    ('fr', true),
    ('ar', false),
    ('ar', true),
    ('en', false),
    ('en', true),
  ]) {
    final (lang, dark) = c;
    final name = 'gallery_${lang}_${dark ? 'dark' : 'light'}';
    testWidgets('golden: $name', (tester) async {
      tester.view.physicalSize = const Size(390, 2800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_gallery(lang, dark: dark));
      await tester.pump(const Duration(milliseconds: 50));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('$name.png'),
      );
    });
  }
}
