import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/portfolio/application/portfolio_providers.dart';
import 'package:khidma/features/portfolio/data/image_prep.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:khidma/features/profile/data/supabase_profile_repository.dart';
import 'package:khidma/features/profile/domain/profile_domain.dart';
import 'package:khidma/features/profile/presentation/avatar_editor.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_portfolio.dart';
import '../support/fake_profile_repository.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');
const _aliProfile = AppProfile(id: 'u1', fullName: 'Ali Ben Salah');

Uint8List _png(int w, int h) =>
    Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));

void main() {
  setUpAll(loadAppFonts);

  group('prepareAvatar', () {
    test('crops to the centre square and shrinks to 512 px', () {
      final out = prepareAvatar(_png(1200, 800));
      final back = img.decodeJpg(out)!;
      expect((back.width, back.height), (avatarSide, avatarSide));
      expect(out.length, lessThan(200 * 1024));
    });

    test('a small picture is cropped but never enlarged', () {
      final back = img.decodeJpg(prepareAvatar(_png(200, 120)))!;
      expect((back.width, back.height), (120, 120));
    });

    test('something that is not an image is refused', () {
      expect(
        () => prepareAvatar(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(
          isA<PortfolioError>().having(
            (e) => e.failure,
            'failure',
            PortfolioFailure.notAnImage,
          ),
        ),
      );
      expect(() => prepareAvatar(Uint8List(0)), throwsA(isA<PortfolioError>()));
    });
  });

  group('picture on the Profile tab', () {
    Future<(FakeProfileRepository, FakePhotoPicker)> open(
      WidgetTester tester, {
      Uint8List? picked,
    }) async {
      final repo = FakeProfileRepository(profile: _aliProfile);
      final picker = FakePhotoPicker(picked);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        profiles: repo,
        overrides: [photoPickerProvider.overrideWithValue(picker)],
      );
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      return (repo, picker);
    }

    testWidgets('choosing a photo uploads it', (tester) async {
      final (repo, picker) = await open(tester, picked: _png(640, 480));
      await tester.tap(find.byType(AvatarEditor));
      await tester.pumpAndSettle();
      expect(
        find.text('Supprimer la photo'),
        findsNothing,
        reason: 'no photo yet',
      );
      await tester.tap(find.text('Choisir une photo'));
      await tester.pumpAndSettle();
      expect(picker.picks, 1);
      expect(repo.avatarSets, 1);
      // With a photo, removing it is offered.
      await tester.tap(find.byType(AvatarEditor));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer la photo'), findsOneWidget);
      await tester.tap(find.text('Supprimer la photo'));
      await tester.pumpAndSettle();
      expect(repo.avatarRemovals, 1);
    });

    testWidgets('closing the picker changes nothing and shows no error', (
      tester,
    ) async {
      final (repo, picker) = await open(tester);
      await tester.tap(find.byType(AvatarEditor));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir une photo'));
      await tester.pumpAndSettle();
      expect(picker.picks, 1);
      expect(repo.avatarSets, 0);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a file that is not an image says so and uploads nothing', (
      tester,
    ) async {
      final (repo, _) = await open(
        tester,
        picked: Uint8List.fromList([1, 2, 3]),
      );
      await tester.tap(find.byType(AvatarEditor));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir une photo'));
      await tester.pumpAndSettle();
      expect(repo.avatarSets, 0);
      expect(
        find.textContaining('Impossible de mettre à jour'),
        findsOneWidget,
      );
    });

    testWidgets('a failed upload says so', (tester) async {
      final (repo, _) = await open(tester, picked: _png(100, 100));
      repo.failNext = ProfileFailure.network;
      await tester.tap(find.byType(AvatarEditor));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir une photo'));
      await tester.pumpAndSettle();
      expect(repo.avatarSets, 0);
      expect(
        find.textContaining('Impossible de mettre à jour'),
        findsOneWidget,
      );
    });
  });

  group('wire format', () {
    late List<http.BaseRequest> requests;
    SupabaseProfileRepository build({String? uid = 'u1'}) {
      requests = [];
      return SupabaseProfileRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient.streaming((request, bodyStream) async {
            requests.add(request);
            await bodyStream.drain<void>();
            final path = request.url.path;
            Object body = <String, Object?>{};
            if (request.method == 'GET' && path == '/rest/v1/profiles') {
              body = {'avatar_path': 'u1/avatar-1762800000000.jpg'};
            } else if (path.startsWith('/storage/v1/object/avatars')) {
              body = {'Key': 'avatars/x'};
            }
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode(body))),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        ),
        userId: () => uid,
      );
    }

    test('setAvatar uploads first, then points both profiles at it, then drops the old file', () async {
      await build().setAvatar(Uint8List.fromList([1, 2, 3]));
      final steps = [for (final r in requests) '${r.method} ${r.url.path}'];
      final upload = steps.indexWhere(
        (s) => s.startsWith('POST /storage/v1/object/avatars/u1/avatar-'),
      );
      final patchProfile = steps.indexOf('PATCH /rest/v1/profiles');
      final patchPro = steps.indexOf('PATCH /rest/v1/professional_profiles');
      final removeOld = steps.indexWhere(
        (s) => s.startsWith('DELETE /storage/v1/object/avatars'),
      );
      expect(upload, isNonNegative);
      expect(patchProfile, greaterThan(upload));
      expect(patchPro, greaterThan(upload));
      expect(removeOld, greaterThan(patchProfile), reason: 'old file last');
      final patch = requests.firstWhere(
        (r) => r.method == 'PATCH' && r.url.path == '/rest/v1/profiles',
      ) as http.Request;
      final path = (jsonDecode(patch.body) as Map)['avatar_path'] as String;
      expect(path, matches(r'^u1/avatar-\d{13}\.jpg$'));
      expect(patch.url.queryParameters['id'], 'eq.u1');
    });

    test('removeAvatar clears both rows and the file', () async {
      await build().removeAvatar();
      final patches = requests.where((r) => r.method == 'PATCH').toList();
      expect(patches, hasLength(2));
      for (final p in patches) {
        expect(jsonDecode((p as http.Request).body), {'avatar_path': null});
      }
      expect(
        requests.any(
          (r) =>
              r.method == 'DELETE' &&
              r.url.path.startsWith('/storage/v1/object/avatars'),
        ),
        isTrue,
      );
    });

    test('nobody signed in: nothing is sent', () async {
      await expectLater(
        build(uid: null).setAvatar(Uint8List.fromList([1])),
        throwsA(isA<ProfileError>()),
      );
      expect(requests, isEmpty);
    });
  });
}
