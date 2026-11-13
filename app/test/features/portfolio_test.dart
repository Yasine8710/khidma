import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/portfolio/application/portfolio_providers.dart';
import 'package:khidma/features/portfolio/data/image_prep.dart';
import 'package:khidma/features/portfolio/data/supabase_portfolio_repository.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_portfolio.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

/// A photo-like image: noise makes the JPEG big, like a real photo.
img.Image _noise(int w, int h, {int seed = 1}) {
  final r = Random(seed);
  final image = img.Image(width: w, height: h);
  for (final p in image) {
    p
      ..r = r.nextInt(256)
      ..g = r.nextInt(256)
      ..b = r.nextInt(256);
  }
  return image;
}

Uint8List _png(img.Image i) => Uint8List.fromList(img.encodePng(i));

PreparedPhoto _photo([int n = 100]) =>
    PreparedPhoto(bytes: Uint8List(n), width: 10, height: 10);

void main() {
  setUpAll(loadAppFonts);

  group('preparePhoto', () {
    test('shrinks to 1600 px, stays under the upload limit, is a JPEG', () {
      final out = preparePhoto(_png(_noise(2400, 1800)));
      expect(out.width, 1600);
      expect(out.height, 1200);
      expect(out.bytes.length, lessThanOrEqualTo(maxUploadBytes));
      expect(out.bytes.sublist(0, 2), [0xFF, 0xD8], reason: 'JPEG magic');
      final back = img.decodeJpg(out.bytes)!;
      expect((back.width, back.height), (1600, 1200));
    });

    test('a small photo is not enlarged', () {
      final out = preparePhoto(_png(_noise(300, 200)));
      expect((out.width, out.height), (300, 200));
    });

    test('portrait photos shrink by their height', () {
      final out = preparePhoto(_png(_noise(1800, 2400)));
      expect((out.width, out.height), (1200, 1600));
    });

    test('metadata (GPS, camera) does not survive', () {
      final src = _noise(200, 100);
      src.exif.gpsIfd.data[0x0002] = img.IfdValueAscii('36.8N');
      src.exif.imageIfd.data[0x010f] = img.IfdValueAscii('SecretCam');
      final jpg = Uint8List.fromList(img.encodeJpg(src));
      expect(
        img.decodeJpg(jpg)!.exif.isEmpty,
        isFalse,
        reason: 'input has exif',
      );
      final out = preparePhoto(jpg);
      final raw = latin1.decode(out.bytes, allowInvalid: true);
      expect(raw, isNot(contains('Exif')), reason: 'no EXIF block at all');
      expect(raw, isNot(contains('SecretCam')));
    });

    test('orientation is applied, not lost', () {
      final src = _noise(200, 100);
      src.exif.imageIfd.orientation = 6; // rotated 90 degrees clockwise
      final out = preparePhoto(Uint8List.fromList(img.encodeJpg(src)));
      expect((out.width, out.height), (100, 200));
    });

    test('not a photo, empty, or enormous: refused with the right reason', () {
      PortfolioFailure? f(Uint8List b) {
        try {
          preparePhoto(b);
        } on PortfolioError catch (e) {
          return e.failure;
        }
        return null;
      }

      expect(
        f(Uint8List.fromList(utf8.encode('<html>not an image</html>'))),
        PortfolioFailure.notAnImage,
      );
      expect(
        f(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00, 0x01])),
        PortfolioFailure.notAnImage,
        reason: 'truncated jpeg',
      );
      expect(f(Uint8List(0)), PortfolioFailure.tooLarge);
      expect(f(Uint8List(maxOriginalBytes + 1)), PortfolioFailure.tooLarge);
    });
  });

  group('upload repository over a recorded HTTP layer', () {
    late List<http.BaseRequest> requests;
    int insertStatus = 201;
    int storageStatus = 200;
    bool rowExistsAfterFailure = false;

    SupabasePortfolioRepository build({String? uid = 'u1'}) {
      requests = [];
      return SupabasePortfolioRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient.streaming((request, bodyStream) async {
            requests.add(request);
            await bodyStream.drain<void>();
            final path = request.url.path;
            if (path.startsWith('/storage/v1/object/portfolio/') &&
                request.method == 'POST') {
              return http.StreamedResponse(
                Stream.value(utf8.encode(jsonEncode({'Key': 'portfolio/x'}))),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            if (path == '/rest/v1/portfolio_items' &&
                request.method == 'POST') {
              final isErr = insertStatus != 201;
              return http.StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode(
                      isErr
                          ? {'code': 'P0001', 'message': 'portfolio_limit'}
                          : {'id': 'row-1', 'path': 'u1/p.jpg'},
                    ),
                  ),
                ),
                insertStatus,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            if (request.method == 'DELETE' &&
                path.startsWith('/storage/v1/object/portfolio') &&
                storageStatus != 200) {
              return http.StreamedResponse(
                Stream.value(utf8.encode(jsonEncode({'message': 'x'}))),
                storageStatus,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            if (request.method == 'GET' &&
                path == '/rest/v1/portfolio_items' &&
                rowExistsAfterFailure) {
              return http.StreamedResponse(
                Stream.value(
                  utf8.encode(jsonEncode({'id': 'row-1', 'path': 'u1/p.jpg'})),
                ),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            return http.StreamedResponse(
              Stream.value(utf8.encode('[]')),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        ),
        userId: () => uid,
        random: Random(7),
      );
    }

    test('random file ids are v4 UUIDs and differ', () {
      final a = randomFileId(Random(1));
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(a),
        isTrue,
        reason: a,
      );
      expect(randomFileId(Random(1)), a, reason: 'seeded: deterministic');
      expect(randomFileId(), isNot(randomFileId()));
    });

    test('add uploads a JPEG into the own folder, then lists it', () async {
      final repo = build();
      final item = await repo.add(_photo(300));
      final upload = requests.first;
      expect(upload.method, 'POST');
      expect(upload.url.path, startsWith('/storage/v1/object/portfolio/u1/'));
      expect(upload.url.path, endsWith('.jpg'));
      final file = (upload as http.MultipartRequest).files.single;
      expect(file.contentType.mimeType, 'image/jpeg');
      expect(file.length, 300);
      expect(upload.headers['x-upsert'], 'false');
      final insert = requests.firstWhere(
        (r) => r.url.path == '/rest/v1/portfolio_items',
      );
      expect((insert as http.Request).body, contains('"professional_id":"u1"'));
      expect(
        item.url,
        'https://abc.supabase.co/storage/v1/object/public/portfolio/u1/p.jpg',
      );
      expect(item.id, 'row-1');
    });

    test(
      'if the row cannot be saved, the uploaded file is removed again',
      () async {
        final repo = build();
        insertStatus = 400;
        await expectLater(
          repo.add(_photo()),
          throwsA(
            isA<PortfolioError>().having(
              (e) => e.failure,
              'failure',
              PortfolioFailure.limitReached,
            ),
          ),
        );
        insertStatus = 201;
        final cleanup = requests.where(
          (r) =>
              r.method == 'DELETE' &&
              r.url.path.startsWith('/storage/v1/object/portfolio'),
        );
        expect(cleanup, isNotEmpty);
      },
    );

    test('an oversized photo or a missing session sends nothing', () async {
      final repo = build();
      await expectLater(
        repo.add(
          PreparedPhoto(
            bytes: Uint8List(maxUploadBytes + 1),
            width: 1,
            height: 1,
          ),
        ),
        throwsA(
          isA<PortfolioError>().having(
            (e) => e.failure,
            'failure',
            PortfolioFailure.tooLarge,
          ),
        ),
      );
      expect(requests, isEmpty);
      final none = build(uid: null);
      await expectLater(none.add(_photo()), throwsA(isA<PortfolioError>()));
      expect(requests, isEmpty);
    });

    test('remove deletes the file first, then the row', () async {
      final repo = build();
      await repo.remove(
        const PortfolioItem(id: 'row-1', path: 'u1/p.jpg', url: 'x'),
      );
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'DELETE /storage/v1/object/portfolio',
        'DELETE /rest/v1/portfolio_items',
      ]);
      expect(requests.last.url.queryParameters['id'], 'eq.row-1');
    });

    test(
      'if the file cannot be deleted, the row stays (retry is possible)',
      () async {
        final repo = build();
        storageStatus = 500;
        await expectLater(
          repo.remove(
            const PortfolioItem(id: 'row-1', path: 'u1/p.jpg', url: 'x'),
          ),
          throwsA(isA<PortfolioError>()),
        );
        storageStatus = 200;
        expect(
          requests.where((r) => r.url.path == '/rest/v1/portfolio_items'),
          isEmpty,
        );
      },
    );

    test('a lost answer after the row was saved keeps the file', () async {
      final repo = build();
      insertStatus = 500; // the client sees a failure...
      rowExistsAfterFailure = true; // ...but the row is there
      final item = await repo.add(_photo());
      expect(item.id, 'row-1');
      expect(
        requests.where(
          (r) => r.method == 'DELETE' && r.url.path.startsWith('/storage'),
        ),
        isEmpty,
      );
      insertStatus = 201;
      rowExistsAfterFailure = false;
    });

    test('list reads the professional\'s items oldest first', () async {
      final repo = build();
      await repo.list('p9');
      final q = requests.single.url.queryParameters;
      expect(q['professional_id'], 'eq.p9');
      expect(q['order'], startsWith('created_at.asc'));
    });

    test('errors map to categories', () {
      PortfolioFailure s(String code) => mapPortfolioException(
        sb.StorageException('secret', statusCode: code),
      );
      expect(s('413'), PortfolioFailure.tooLarge);
      expect(s('415'), PortfolioFailure.notAnImage);
      expect(s('403'), PortfolioFailure.forbidden);
      expect(s('401'), PortfolioFailure.notSignedIn);
      expect(s('500'), PortfolioFailure.unknown);
      expect(
        mapPortfolioException(
          const sb.PostgrestException(
            message: 'portfolio_limit',
            code: 'P0001',
          ),
        ),
        PortfolioFailure.limitReached,
      );
    });
  });

  group('portfolio screens', () {
    Future<dynamic> open(
      WidgetTester tester,
      FakePortfolioRepository repo, {
      FakePhotoPicker? picker,
      Map<String, Object> prefs = const {},
    }) async {
      final c = await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        prefs: prefs,
        overrides: [
          portfolioRepositoryProvider.overrideWithValue(repo),
          photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
          photoPreparerProvider.overrideWithValue(
            (b) async => _photo(b.length),
          ),
        ],
      );
      c.read(routerProvider).push(AppRoutes.proPortfolio);
      await tester.pumpAndSettle();
      return c;
    }

    PortfolioItem item(int i) => PortfolioItem(
      id: 'i$i',
      path: 'u1/$i.jpg',
      url: 'https://example.invalid/$i.jpg',
    );

    testWidgets('empty: says so; adding a photo uploads the prepared bytes', (
      tester,
    ) async {
      final repo = FakePortfolioRepository();
      final picker = FakePhotoPicker(Uint8List.fromList([1, 2, 3]));
      await open(tester, repo, picker: picker);
      expect(find.text('Aucune photo pour le moment.'), findsOneWidget);
      expect(find.text('0 sur 12 photos'), findsOneWidget);
      await tester.tap(find.text('Ajouter une photo'));
      await tester.pumpAndSettle();
      expect(repo.uploads.single.bytes.length, 3);
      expect(find.text('1 sur 12 photos'), findsOneWidget);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      final repo = FakePortfolioRepository();
      await open(tester, repo, picker: FakePhotoPicker(null));
      await tester.tap(find.text('Ajouter une photo'));
      await tester.pumpAndSettle();
      expect(repo.uploads, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a double tap uploads once', (tester) async {
      final repo = FakePortfolioRepository()..gate = Completer<void>();
      final picker = FakePhotoPicker(Uint8List.fromList([1]));
      await open(tester, repo, picker: picker);
      await tester.tap(find.text('Ajouter une photo'));
      await tester.pump();
      await tester.tap(
        find.text('Préparation de la photo…'),
        warnIfMissed: false,
      );
      await tester.pump();
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(repo.uploads.length, 1);
      expect(picker.picks, 1);
    });

    testWidgets('failures are explained', (tester) async {
      final repo = FakePortfolioRepository();
      await open(
        tester,
        repo,
        picker: FakePhotoPicker(Uint8List.fromList([1])),
      );
      final cases = {
        PortfolioFailure.tooLarge: 'Cette photo est trop lourde, même réduite. Choisissez-en une autre.',
        PortfolioFailure.limitReached:
            'Vous avez atteint la limite de 12 photos.',
        PortfolioFailure.network: 'Connexion impossible. Réessayez.',
      };
      for (final e in cases.entries) {
        repo.failNext = e.key;
        await tester.tap(find.text('Ajouter une photo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text(e.value), findsOneWidget, reason: '${e.key}');
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
            .clearSnackBars();
        await tester.pumpAndSettle();
      }
      expect(find.text('0 sur 12 photos'), findsOneWidget);
    });

    testWidgets('at 12 photos adding is disabled', (tester) async {
      final repo = FakePortfolioRepository([
        for (var i = 0; i < 12; i++) item(i),
      ]);
      await open(tester, repo);
      expect(find.text('12 sur 12 photos'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Ajouter une photo'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final add = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Ajouter une photo'),
          matching: find.bySubtype<FilledButton>(),
        ),
      );
      expect(add.onPressed, isNull);
    });

    testWidgets('removing asks first, then deletes', (tester) async {
      final repo = FakePortfolioRepository([item(0), item(1)]);
      await open(tester, repo);
      await tester.tap(find.byTooltip('Supprimer la photo (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer cette photo ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(repo.removed, isEmpty);
      await tester.tap(find.byTooltip('Supprimer la photo (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer la photo'));
      await tester.pumpAndSettle();
      expect(repo.removed, ['i0']);
      expect(find.text('1 sur 12 photos'), findsOneWidget);
    });

    testWidgets(
      'the public profile shows the gallery only when there are photos',
      (tester) async {
        final repo = FakePortfolioRepository([item(0), item(1)]);
        final c = await open(tester, repo);
        c.read(routerProvider).go(AppRoutes.professionalPath('demo-01'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Réalisations'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        // "Réalisations" is now a tab: it scrolls the photos into view.
        await tester.tap(find.text('Réalisations'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Photo 1 sur 2'), findsWidgets);
        await tester.tap(find.byType(InkWell).last, warnIfMissed: false);
      },
    );

    testWidgets('no photos: no empty heading on the public profile', (
      tester,
    ) async {
      final c = await open(tester, FakePortfolioRepository());
      c.read(routerProvider).go(AppRoutes.professionalPath('demo-01'));
      await tester.pumpAndSettle();
      expect(find.text('Réalisations'), findsNothing);
    });

    for (final lang in ['fr', 'ar', 'en']) {
      testWidgets('fits a small phone at 1.5x text ($lang)', (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await open(
          tester,
          FakePortfolioRepository([for (var i = 0; i < 5; i++) item(i)]),
          prefs: {'locale': lang},
        );
        expect(tester.takeException(), isNull, reason: lang);
      });
    }
  });
}
