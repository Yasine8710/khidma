import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/shared/widgets/khidma_logo.dart';

import 'components_test.dart' show host;

({int w, int h, int colorType}) _png(String path) {
  final b = File(path).readAsBytesSync();
  final d = ByteData.sublistView(Uint8List.fromList(b.sublist(0, 33)));
  return (w: d.getUint32(16), h: d.getUint32(20), colorType: b[25]);
}

typedef _Pixels = ({int w, int h, ByteData px});

Future<_Pixels> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final img = (await codec.getNextFrame()).image;
  return (w: img.width, h: img.height, px: (await img.toByteData())!);
}

/// Largest distance from the center, as a fraction of the canvas width, to
/// any pixel for which [isBackground] is false.
double _maxRadius(_Pixels i, bool Function(int r, int g, int b, int a) isBg) {
  var maxD = 0.0;
  for (var y = 0; y < i.h; y++) {
    for (var x = 0; x < i.w; x++) {
      final o = (y * i.w + x) * 4;
      final px = i.px;
      if (isBg(
        px.getUint8(o),
        px.getUint8(o + 1),
        px.getUint8(o + 2),
        px.getUint8(o + 3),
      )) {
        continue;
      }
      final d = math.sqrt(
        math.pow(x + .5 - i.w / 2, 2) + math.pow(y + .5 - i.h / 2, 2),
      );
      maxD = math.max(maxD, d / i.w);
    }
  }
  return maxD;
}

void main() {
  group('platform files', () {
    test('every iOS icon matches its filename size and has no alpha', () {
      final dir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      final re = RegExp(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png');
      var n = 0;
      for (final f in dir.listSync().whereType<File>()) {
        final m = re.firstMatch(f.uri.pathSegments.last);
        if (m == null) continue;
        final expected = (double.parse(m[1]!) * int.parse(m[2]!)).round();
        final png = _png(f.path);
        expect((png.w, png.h), (expected, expected), reason: f.path);
        expect(png.colorType, 2, reason: '${f.path} must be opaque RGB');
        n++;
      }
      expect(n, greaterThanOrEqualTo(15));
    });

    test('Xcode build setting is intact (generator once corrupted it)', () {
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();
      expect(pbx, isNot(contains('SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon')));
      expect(pbx, contains('SWIFT_ASSET_SYMBOL_EXTENSIONS = YES'));
    });

    test('web page allows user zoom and uses the Khidma name', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, isNot(contains('user-scalable=no')));
      expect(html, isNot(contains('maximum-scale')));
      final manifest = File('web/manifest.json').readAsStringSync();
      expect(manifest, contains('"name": "Khidma"'));
      expect(manifest, contains('"short_name": "Khidma"'));
      expect(manifest, isNot(contains('A new Flutter project')));
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android:label="Khidma"'),
      );
    });

    test('Android has a monochrome (themed) icon layer', () {
      expect(
        File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
            .readAsStringSync(),
        contains('monochrome'),
      );
    });
  });

  group('icon safe zones (decoded pixels)', () {
    testWidgets('maskable web icons keep the mark inside the 40% circle', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final n in [192, 512]) {
          final i = await _decode('web/icons/Icon-maskable-$n.png');
          // Background is brand terracotta B0432A; anything else is the mark.
          final r = _maxRadius(
            i,
            (r, g, b, a) =>
                (r - 0xB0).abs() < 6 &&
                (g - 0x43).abs() < 6 &&
                (b - 0x2A).abs() < 6,
          );
          expect(r, lessThanOrEqualTo(0.40), reason: 'Icon-maskable-$n');
        }
      });
    });

    testWidgets('adaptive foreground fits the Android safe zone', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final i = await _decode('assets/brand/icon-foreground.png');
        final r = _maxRadius(i, (r, g, b, a) => a < 8);
        // The launcher insets the layer by 16% (scale 0.68); the safe zone
        // is a circle of 66/108 of the canvas (radius 0.305). Allow 0.33.
        expect(r * 0.68, lessThanOrEqualTo(0.33));
      });
    });

    testWidgets('splash mark fits the Android 12 icon circle', (tester) async {
      await tester.runAsync(() async {
        final i = await _decode('assets/brand/mark-splash.png');
        expect(_maxRadius(i, (r, g, b, a) => a < 8), lessThanOrEqualTo(0.333));
      });
    });

    testWidgets('monochrome layer is a single color', (tester) async {
      await tester.runAsync(() async {
        final i = await _decode('assets/brand/icon-monochrome.png');
        for (var o = 0; o < i.w * i.h * 4; o += 4) {
          if (i.px.getUint8(o + 3) > 250) {
            // Resampling can leave 254; the layer must still be (near) white.
            for (var c = 0; c < 3; c++) {
              expect(i.px.getUint8(o + c), greaterThanOrEqualTo(250));
            }
          }
        }
      });
    });
  });

  group('geometry stays in sync', () {
    test('Dart painter, Python script and SVG share the same numbers', () {
      final dart = File('lib/shared/widgets/khidma_logo.dart')
          .readAsStringSync();
      final py = File('../scripts/make_brand_assets.py').readAsStringSync();
      final svg = File('assets/brand/logo-mark.svg').readAsStringSync();
      expect(dart, contains('arch(36, 84, 52, 92)'));
      expect(dart, contains('arch(48, 72, 52, 92)'));
      expect(dart, contains('Offset(60 * s, 70 * s)'));
      expect(dart, contains('5.5 * s'));
      expect(py, contains('OUTER = dict(x0=36, x1=84, spring=52, bottom=92)'));
      expect(py, contains('INNER = dict(x0=48, x1=72, spring=52, bottom=92)'));
      expect(py, contains('DOT = dict(cx=60, cy=70, r=5.5)'));
      expect(svg, contains('M36 92V52a24 24 0 0 1 48 0V92Z'));
      expect(svg, contains('M48 92V52a12 12 0 0 1 24 0V92Z'));
      expect(svg, contains('cx="60" cy="70" r="5.5"'));
    });
  });

  group('logo in other locales and sizes', () {
    testWidgets('Arabic: Arabic semantic name, wordmark stays Latin', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const KhidmaLogo(), lang: 'ar'));
      expect(find.bySemanticsLabel('خدمة'), findsOneWidget);
      expect(find.text('Khidma'), findsOneWidget);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('lockup copes with 2x text scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(host(const KhidmaLogo()));
      expect(tester.takeException(), isNull);
    });
  });
}
