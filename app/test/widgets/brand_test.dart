import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/theme/app_colors.dart';
import 'package:khidma/shared/widgets/khidma_logo.dart';

import 'components_test.dart' show host;

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// PNG header: width, height, color type (6 = RGBA, 2 = RGB).
({int w, int h, int colorType}) _png(String path) {
  final b = File(path).readAsBytesSync();
  final d = ByteData.sublistView(Uint8List.fromList(b.sublist(0, 33)));
  return (w: d.getUint32(16), h: d.getUint32(20), colorType: b[25]);
}

void main() {
  group('brand assets', () {
    test('icon is 1024 square and opaque (iOS rejects alpha)', () {
      final i = _png('assets/brand/icon-1024.png');
      expect((i.w, i.h), (1024, 1024));
      expect(i.colorType, 2, reason: 'RGB without alpha');
    });

    test('adaptive foreground and splash mark are transparent', () {
      final f = _png('assets/brand/icon-foreground.png');
      expect((f.w, f.h, f.colorType), (1024, 1024, 6));
      final s = _png('assets/brand/mark-splash.png');
      expect(s.colorType, 6);
    });

    test('SVG mark uses the theme brand colors (violet square, white K)', () {
      final svg = File('assets/brand/logo-mark.svg').readAsStringSync();
      expect(svg.toUpperCase(), contains(_hex(AppColors.brand)));
      expect(svg.toUpperCase(), contains(_hex(AppColors.paper)));
      // No trace of the rejected Signal / terracotta identities.
      for (final old in ['#F5C400', '#0E0E0E', '#B0432A']) {
        expect(svg.toUpperCase(), isNot(contains(old)), reason: old);
      }
    });

    test('launcher and splash colours are the violet brand', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains('adaptive_icon_background: "${_hex(AppColors.brand)}"'),
      );
      expect(pubspec, contains('color: "${_hex(AppColors.ground)}"'));
      for (final old in ['#B0432A', '#F4EFE6', '#F5C400']) {
        expect(pubspec, isNot(contains(old)), reason: old);
      }
    });

    test('app icons exist for iOS and Android', () {
      for (final p in [
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
        'web/icons/Icon-512.png',
      ]) {
        expect(File(p).existsSync(), isTrue, reason: p);
      }
    });
  });

  group('logo widgets', () {
    testWidgets('lockup reads as "Khidma" once and shows both names', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const KhidmaLogo()));
      expect(find.text('Khidma'), findsOneWidget);
      expect(find.text('خدمة'), findsOneWidget);
      expect(find.bySemanticsLabel('Khidma'), findsOneWidget);
      handle.dispose();
    });

    for (final dark in [false, true]) {
      testWidgets('mark and badge render in dark=$dark', (tester) async {
        await tester.pumpWidget(
          host(
            const Row(
              children: [
                KhidmaMark(size: 24),
                KhidmaMark(size: 120),
                KhidmaMarkBadge(),
              ],
            ),
            dark: dark,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(CustomPaint), findsWidgets);
      });
    }

    testWidgets('lockup fits a 200 px wide area', (tester) async {
      tester.view.physicalSize = const Size(200 * 3, 400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const KhidmaLogo(markSize: 40)));
      expect(tester.takeException(), isNull);
    });
  });
}
