import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/features/freelance/application/freelance_providers.dart';
import 'package:khidma/features/freelance/data/image_picker_clip_picker.dart';
import 'package:khidma/features/freelance/data/supabase_freelance_repository.dart';
import 'package:khidma/features/freelance/domain/freelance_domain.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

const _uid = '11111111-1111-4111-8111-111111111111';
final _token = 'ab' * 32;

void main() {
  group('validation helpers', () {
    test('video links mirror the database pattern', () {
      for (final ok in [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://youtube.com/watch?v=dQw4w9WgXcQ&t=10',
        'https://youtu.be/dQw4w9WgXcQ',
        'https://vimeo.com/123456789',
        'https://www.vimeo.com/12345',
      ]) {
        expect(FreelanceRules.videoLinkOk(ok), isTrue, reason: ok);
      }
      for (final bad in [
        '',
        'http://youtu.be/dQw4w9WgXcQ',
        'https://youtu.be/abc',
        'https://vimeo.com/12',
        'https://evil.com/watch?v=dQw4w9WgXcQ',
        'https://youtube.com.evil.com/watch?v=dQw4w9WgXcQ',
        'javascript:alert(1)',
        'https://youtu.be/dQw4w9WgXcQ extra',
        'https://example.com/',
      ]) {
        expect(FreelanceRules.videoLinkOk(bad), isFalse, reason: bad);
      }
    });

    test('links must be https with a real host', () {
      expect(FreelanceRules.linkOk('https://example.com'), isTrue);
      expect(FreelanceRules.linkOk('https://a-b.example.tn/work?id=1'), isTrue);
      expect(FreelanceRules.linkOk('http://example.com'), isFalse);
      expect(FreelanceRules.linkOk('https://localhost'), isFalse);
      expect(FreelanceRules.linkOk('https://exa mple.com'), isFalse);
      expect(FreelanceRules.linkOk('ftp://example.com'), isFalse);
      expect(
        FreelanceRules.linkOk('https://example.com/${'a' * 300}'),
        isFalse,
      );
    });

    test('titles, names, headlines and bios follow the limits', () {
      expect(FreelanceRules.titleOk('ab'), isTrue);
      expect(FreelanceRules.titleOk(' a '), isFalse);
      expect(FreelanceRules.nameOk('A' * 81), isFalse);
      expect(FreelanceRules.headlineOk('Dev'), isFalse);
      expect(FreelanceRules.headlineOk('Développeur'), isTrue);
      expect(FreelanceRules.bioOk('x' * 2001), isFalse);
      expect(FreelanceRules.bioOk(null), isTrue);
    });

    test('tags are trimmed, distinct and capped', () {
      expect(
        FreelanceRules.parseTags(' React, node ,, react ,Figma', max: 12),
        ['React', 'node', 'Figma'],
      );
      expect(FreelanceRules.parseTags('a,b,c,d', max: 2), ['a', 'b']);
      expect(FreelanceRules.parseTags('x، y', max: 5), ['x', 'y']);
      expect(FreelanceRules.tagsOk('a,b,c', max: 2), isFalse);
      expect(FreelanceRules.tagsOk('a' * 31, max: 5), isFalse);
      expect(FreelanceRules.tagsOk('', max: 5), isTrue);
    });

    test('dinars convert to millimes and back', () {
      expect(FreelanceRules.dinarsToMillimes('300'), 300000);
      expect(FreelanceRules.dinarsToMillimes('12,5'), 12500);
      expect(FreelanceRules.dinarsToMillimes('0.001'), 1);
      expect(FreelanceRules.dinarsToMillimes('-1'), isNull);
      expect(FreelanceRules.dinarsToMillimes('abc'), isNull);
      expect(FreelanceRules.dinarsToMillimes('100001'), isNull);
      expect(FreelanceRules.millimesToDinars(300000), '300');
      expect(FreelanceRules.millimesToDinars(12500), '12.5');
      expect(FreelanceRules.millimesToDinars(null), '');
    });

    test('clip extension accepts mp4 and webm only', () {
      expect(clipExtension('a.MP4'), 'mp4');
      expect(clipExtension('/x/y/clip.webm'), 'webm');
      expect(clipExtension('IMG_1.mov'), isNull);
      expect(clipExtension('noext'), isNull);
    });

    test('invite links need a configured https address', () {
      expect(
        testimonialLink('https://t.example.tn', _token),
        'https://t.example.tn/t/$_token',
      );
      expect(
        testimonialLink('https://t.example.tn///', _token),
        'https://t.example.tn/t/$_token',
      );
      expect(testimonialLink('', _token), isNull);
      expect(testimonialLink('http://t.example.tn', _token), isNull);
      expect(testimonialLink('not a url', _token), isNull);
    });

    test('invite status', () {
      final now = DateTime(2026, 1, 10);
      TestimonialInvite inv({DateTime? used, required DateTime exp}) =>
          TestimonialInvite(
            id: 'i',
            expiresAt: exp,
            createdAt: now,
            usedAt: used,
          );
      expect(
        inv(exp: now.add(const Duration(days: 1))).statusAt(now),
        InviteStatus.open,
      );
      expect(inv(exp: now).statusAt(now), InviteStatus.expired);
      expect(
        inv(used: now, exp: now.add(const Duration(days: 1))).statusAt(now),
        InviteStatus.used,
      );
    });

    test('search words cannot inject filter syntax', () {
      final out = sanitizeSearchWord('a,b)(c*%_"\\d');
      expect(out.contains(RegExp(r'[,()*%_"\\]')), isFalse);
      expect(out.split(RegExp(r'\s+')), ['a', 'b', 'c', 'd']);
      expect(sanitizeSearchWord('  react '), 'react');
    });
  });

  group('error mapping never forwards server text', () {
    FreelanceFailure map(String code, String message) => mapFreelanceException(
      sb.PostgrestException(message: message, code: code),
    );

    test('tags from the database', () {
      expect(map('P0001', 'not_verified'), FreelanceFailure.notVerified);
      expect(map('P0001', 'incomplete'), FreelanceFailure.incomplete);
      expect(map('P0001', 'suspended'), FreelanceFailure.suspended);
      expect(map('P0001', 'limit_reached'), FreelanceFailure.limitReached);
      expect(map('P0001', 'invalid_input'), FreelanceFailure.invalidInput);
      expect(map('P0001', 'rate_limited'), FreelanceFailure.rateLimited);
      expect(map('P0001', 'secret internal text'), FreelanceFailure.unknown);
      expect(map('P0002', 'not found'), FreelanceFailure.notFound);
      expect(map('42501', 'permission denied'), FreelanceFailure.forbidden);
      expect(map('23514', 'check violation'), FreelanceFailure.invalidInput);
      expect(map('PGRST301', 'jwt'), FreelanceFailure.notSignedIn);
      expect(map('XX000', 'boom'), FreelanceFailure.unknown);
    });

    test('storage and network', () {
      expect(
        mapFreelanceException(
          const sb.StorageException('x', statusCode: '413'),
        ),
        FreelanceFailure.tooLarge,
      );
      expect(
        mapFreelanceException(
          const sb.StorageException('x', statusCode: '415'),
        ),
        FreelanceFailure.unsupportedFormat,
      );
      expect(
        mapFreelanceException(http.ClientException('offline')),
        FreelanceFailure.network,
      );
    });
  });

  group('wire format', () {
    late List<http.Request> requests;

    SupabaseFreelanceRepository build({
      Object? Function(http.Request r)? answer,
      String? uid = _uid,
    }) {
      requests = [];
      return SupabaseFreelanceRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient.streaming((request, bodyStream) async {
            final body = await bodyStream.bytesToString();
            final r = http.Request(request.method, request.url)
              ..body = body
              ..headers.addAll(request.headers);
            requests.add(r);
            final out = answer?.call(r) ?? <String, Object?>{};
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode(out))),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        ),
        userId: () => uid,
      );
    }

    Map<String, Object?> row({
      String id = 'f1',
      Object? pro = const {
        'avatar_path': 'f1/a.jpg',
        'verification_status': 'verified',
      },
    }) => {
      'user_id': id,
      'display_name': 'Amine',
      'headline': 'Développeur web',
      'bio': 'Une présentation assez longue.',
      'primary_category_id': 1,
      'skills': ['React', 'Node'],
      'languages': ['Français'],
      'years_experience': 5,
      'starting_price_millimes': 300000,
      'price_unit': 'hour',
      'availability': 'busy',
      'is_published': true,
      'rating_avg': 4.5,
      'review_count': 2,
      'professional_profiles': pro,
    };

    test(
      'search sends only public filters and maps the embedded avatar',
      () async {
        final repo = build(answer: (r) => [row()]);
        final list = await repo.search(
          const FreelanceQuery(text: 'rea,ct', categoryId: 3),
        );
        final r = requests.single;
        expect(r.method, 'GET');
        expect(r.url.path, '/rest/v1/freelancer_profiles');
        final q = r.url.queryParameters;
        expect(q['is_published'], 'eq.true');
        expect(q['primary_category_id'], 'eq.3');
        expect(q['or'], contains('display_name.ilike.*rea ct*'));
        expect(q['select'], contains('professional_profiles(avatar_path'));
        expect(q['select'], isNot(contains('phone')));
        expect(
          q['order'],
          'rating_avg.desc.nullslast,review_count.desc.nullslast',
        );
        final f = list.single;
        expect(f.name, 'Amine');
        expect(f.isVerified, isTrue);
        expect(f.priceUnit, PriceUnit.hour);
        expect(f.availability, Availability.busy);
        expect(f.startingPriceMillimes, 300000);
        expect(f.skills, ['React', 'Node']);
        expect(f.rating, 4.5);
        expect(
          f.avatarUrl,
          'https://abc.supabase.co/storage/v1/object/public/avatars/f1/a.jpg',
        );
      },
    );

    test(
      'an embed returned as a list still works, a missing one is unverified',
      () async {
        final repo = build(
          answer: (r) => [
            row(
              pro: [
                {'avatar_path': null, 'verification_status': 'verified'},
              ],
            ),
            row(id: 'f2', pro: null),
          ],
        );
        final list = await repo.search(const FreelanceQuery());
        expect(list.first.isVerified, isTrue);
        expect(list.first.avatarUrl, isNull);
        expect(list.last.isVerified, isFalse);
      },
    );

    test(
      'portfolio resolves files to public urls and keeps external links',
      () async {
        final repo = build(
          answer: (r) => [
            {
              'id': 'a',
              'kind': 'image',
              'title': 'Site',
              'description': null,
              'path': '$_uid/x.jpg',
              'url': null,
              'sort_order': 0,
            },
            {
              'id': 'b',
              'kind': 'video_link',
              'title': 'Démo',
              'description': 'd',
              'path': null,
              'url': 'https://youtu.be/dQw4w9WgXcQ',
              'sort_order': 1,
            },
          ],
        );
        final items = await repo.portfolio('f1');
        expect(requests.single.url.queryParameters['freelancer_id'], 'eq.f1');
        expect(
          items[0].url,
          contains('/object/public/freelance-media/$_uid/x.jpg'),
        );
        expect(items[0].kind.opensInApp, isTrue);
        expect(items[1].kind, PortfolioKind.videoLink);
        expect(items[1].url, 'https://youtu.be/dQw4w9WgXcQ');
      },
    );

    test('testimonials: only published ones are asked for', () async {
      final repo = build(
        answer: (r) => [
          {
            'id': 't1',
            'author_name': 'Client',
            'project_title': null,
            'rating': 5,
            'body': 'Très bon travail, merci.',
            'created_at': '2026-03-01T10:00:00Z',
          },
        ],
      );
      final list = await repo.testimonials('f1');
      expect(requests.single.url.queryParameters['status'], 'eq.published');
      expect(list.single.rating, 5);
      expect(list.single.createdAt, isNotNull);
    });

    test('revealContact calls the function with the id only', () async {
      final repo = build(answer: (r) => '+21620123456');
      expect(await repo.revealContact('f1'), '+21620123456');
      final r = requests.single;
      expect(r.url.path, '/rest/v1/rpc/reveal_freelancer_contact');
      expect(jsonDecode(r.body), {'p_freelancer': 'f1'});
    });

    test('an empty reveal answer is "not found"', () async {
      final repo = build(answer: (r) => '');
      await expectLater(
        repo.revealContact('f1'),
        throwsA(
          isA<FreelanceError>().having(
            (e) => e.failure,
            'failure',
            FreelanceFailure.notFound,
          ),
        ),
      );
    });

    test('becomeFreelancer calls the function', () async {
      await build().becomeFreelancer();
      expect(requests.single.url.path, '/rest/v1/rpc/become_freelancer');
    });

    test('save updates only the allowed columns of the own row', () async {
      await build().save(
        const FreelanceInput(
          name: ' Amine ',
          headline: 'Dev',
          bio: '  ',
          categoryId: 1,
          skills: ['a'],
          languages: [],
          yearsExperience: 3,
          startingPriceMillimes: 1000,
          priceUnit: PriceUnit.day,
          availability: Availability.offline,
        ),
      );
      final r = requests.single;
      expect(r.method, 'PATCH');
      expect(r.url.queryParameters['user_id'], 'eq.$_uid');
      final body = jsonDecode(r.body) as Map;
      expect(body.keys.toSet(), {
        'display_name',
        'headline',
        'bio',
        'primary_category_id',
        'skills',
        'languages',
        'years_experience',
        'starting_price_millimes',
        'price_unit',
        'availability',
      });
      expect(body['display_name'], 'Amine');
      expect(body['bio'], isNull, reason: 'blank bio is stored as null');
      expect(body['price_unit'], 'day');
    });

    test('setPublished sends is_published only', () async {
      await build().setPublished(true);
      final r = requests.single;
      expect(r.method, 'PATCH');
      expect(jsonDecode(r.body), {'is_published': true});
    });

    test('publishing refused by the database becomes a failure tag', () async {
      final client = sb.SupabaseClient(
        'https://abc.supabase.co',
        'sb_publishable_testkey',
        httpClient: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'code': 'P0001',
              'message': 'not_verified',
              'details': null,
              'hint': null,
            }),
            400,
            headers: {'content-type': 'application/json'},
            request: r,
          ),
        ),
      );
      final repo = SupabaseFreelanceRepository(client, userId: () => _uid);
      await expectLater(
        repo.setPublished(true),
        throwsA(
          isA<FreelanceError>().having(
            (e) => e.failure,
            'failure',
            FreelanceFailure.notVerified,
          ),
        ),
      );
    });

    test('addLink validates before sending and sends the right kind', () async {
      final repo = build(
        answer: (r) => {
          'id': 'n1',
          'kind': 'video_link',
          'title': 'Démo',
          'description': null,
          'path': null,
          'url': 'https://youtu.be/dQw4w9WgXcQ',
          'sort_order': 0,
        },
      );
      await expectLater(
        repo.addLink(
          PortfolioKind.videoLink,
          'https://evil.com/x',
          title: 'Démo',
        ),
        throwsA(isA<FreelanceError>()),
      );
      expect(requests, isEmpty, reason: 'nothing sent for a bad link');
      final item = await repo.addLink(
        PortfolioKind.videoLink,
        ' https://youtu.be/dQw4w9WgXcQ ',
        title: ' Démo ',
      );
      final body = jsonDecode(requests.single.body) as Map;
      expect(body['kind'], 'video_link');
      expect(body['freelancer_id'], _uid);
      expect(body['url'], 'https://youtu.be/dQw4w9WgXcQ');
      expect(body['title'], 'Démo');
      expect(body['path'], isNull);
      expect(item.id, 'n1');
    });

    test('addPhoto uploads to the public bucket under the own folder, then adds the row', () async {
      final repo = build(
        answer: (r) => r.url.path.startsWith('/storage/')
            ? {'Key': 'freelance-media/x'}
            : {
                'id': 'n1',
                'kind': 'image',
                'title': 'Photo',
                'description': null,
                'path': '$_uid/x.jpg',
                'url': null,
                'sort_order': 0,
              },
      );
      await repo.addPhoto(
        PreparedPhoto(
          bytes: Uint8List.fromList([1, 2, 3]),
          width: 1,
          height: 1,
        ),
        title: 'Photo',
      );
      final steps = [for (final r in requests) '${r.method} ${r.url.path}'];
      expect(
        steps.first,
        matches(
          r'^POST /storage/v1/object/freelance-media/' +
              _uid +
              r'/[0-9a-f-]{36}\.jpg$',
        ),
      );
      expect(steps.last, 'POST /rest/v1/freelancer_portfolio_items');
      final body = jsonDecode(requests.last.body) as Map;
      expect(body['kind'], 'image');
      expect(body['path'], matches('^$_uid/[0-9a-f-]{36}\\.jpg\$'));
    });

    test('a clip over 25 MB is refused before any upload', () async {
      final repo = build();
      await expectLater(
        repo.addClip(
          PickedClip(
            bytes: Uint8List(FreelanceRules.maxFileBytes + 1),
            extension: 'mp4',
          ),
          title: 'Clip',
        ),
        throwsA(
          isA<FreelanceError>().having(
            (e) => e.failure,
            'failure',
            FreelanceFailure.tooLarge,
          ),
        ),
      );
      expect(requests, isEmpty);
    });

    test('removing a file item deletes the file first, then the row', () async {
      await build(
        answer: (r) => r.url.path.startsWith('/storage/') ? <Object?>[] : {},
      ).removeItem(
        const FreelancePortfolioItem(
          id: 'i1',
          kind: PortfolioKind.videoFile,
          title: 'Clip',
          path: '$_uid/x.mp4',
        ),
      );
      final steps = [for (final r in requests) '${r.method} ${r.url.path}'];
      expect(
        steps.first,
        startsWith('DELETE /storage/v1/object/freelance-media'),
      );
      expect(steps.last, 'DELETE /rest/v1/freelancer_portfolio_items');
      expect(requests.last.url.queryParameters['id'], 'eq.i1');
    });

    test(
      'invites: the token comes back once, the listing has no secrets',
      () async {
        final repo = build(answer: (r) => _token);
        expect(await repo.createInvite(label: ' Sami '), _token);
        final r = requests.single;
        expect(r.url.path, '/rest/v1/rpc/create_testimonial_invite');
        expect(jsonDecode(r.body), {'p_label': 'Sami'});

        final list = build(
          answer: (r) => [
            {
              'id': 'i1',
              'label': null,
              'expires_at': '2026-05-01T00:00:00Z',
              'used_at': null,
              'created_at': '2026-04-01T00:00:00Z',
            },
          ],
        );
        final invites = await list.invites();
        expect(
          requests.single.url.queryParameters['select'],
          isNot(contains('token')),
        );
        expect(invites.single.id, 'i1');
      },
    );

    test('a token that is not 64 hex characters is rejected', () async {
      final repo = build(answer: (r) => 'nope');
      await expectLater(repo.createInvite(), throwsA(isA<FreelanceError>()));
    });

    test('revoking deletes the invite row', () async {
      await build().revokeInvite('i1');
      final r = requests.single;
      expect(r.method, 'DELETE');
      expect(r.url.path, '/rest/v1/freelancer_invites');
      expect(r.url.queryParameters['id'], 'eq.i1');
    });

    test('owner calls need an account', () async {
      final repo = build(uid: null);
      await expectLater(
        repo.save(
          const FreelanceInput(
            name: 'A',
            headline: null,
            bio: null,
            categoryId: null,
            skills: [],
            languages: [],
            yearsExperience: null,
            startingPriceMillimes: null,
            priceUnit: PriceUnit.project,
            availability: Availability.available,
          ),
        ),
        throwsA(
          isA<FreelanceError>().having(
            (e) => e.failure,
            'failure',
            FreelanceFailure.notSignedIn,
          ),
        ),
      );
      expect(requests, isEmpty);
    });
  });
}
