import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/features/profile/data/supabase_profile_repository.dart';
import 'package:khidma/features/profile/domain/profile_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Drives the real Supabase/PostgREST client against a recorded fake HTTP
/// layer, to prove exactly what goes over the wire.
class _Wire {
  _Wire(this.respond);
  final http.Response Function(http.Request) respond;
  final requests = <http.Request>[];

  SupabaseProfileRepository repo({String? userId = 'u1'}) {
    final client = MockClient((r) async {
      requests.add(r);
      final res = respond(r);
      // PostgREST reads response.request, which a hand-built Response lacks.
      return http.Response(
        res.body,
        res.statusCode,
        request: r,
        headers: res.headers,
      );
    });
    final supabase = sb.SupabaseClient(
      'https://abc.supabase.co',
      'sb_publishable_testkey',
      httpClient: client,
    );
    return SupabaseProfileRepository(supabase, userId: () => userId);
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

const _row = {
  'id': 'u1',
  'full_name': 'Ali',
  'phone': '+21620123456',
  'preferred_language': 'ar',
  'is_customer': true,
  'is_professional': false,
};

void main() {
  test(
    'fetchMine asks for exactly the allowed columns of the caller\'s own row',
    () async {
      final wire = _Wire((_) => _json(_row));
      final p = await wire.repo().fetchMine();
      final r = wire.requests.single;
      expect(r.method, 'GET');
      expect(r.url.path, '/rest/v1/profiles');
      expect(r.url.queryParameters['id'], 'eq.u1');
      expect(
        r.url.queryParameters['select'],
        'id,full_name,phone,preferred_language,is_customer,is_professional,avatar_path',
      );
      expect(r.url.queryParameters['select'], isNot(contains('*')));
      expect(
        r.headers['Accept'] ?? r.headers['accept'],
        contains('vnd.pgrst.object'),
      );
      expect(r.headers['apikey'], 'sb_publishable_testkey');
      expect(p.fullName, 'Ali');
      expect(p.phone, '+21620123456');
      expect(p.preferredLanguage, 'ar');
      expect(p.isProfessional, isFalse);
    },
  );

  test('updateMine sends only the three editable fields, filtered by id, phone null included', () async {
    final wire = _Wire(
      (_) => _json({..._row, 'phone': null, 'full_name': 'Ali B.'}),
    );
    final p = await wire.repo().updateMine(
      fullName: '  Ali B.  ',
      phone: null,
      preferredLanguage: 'fr',
    );
    final r = wire.requests.single;
    expect(r.method, 'PATCH');
    expect(r.url.queryParameters['id'], 'eq.u1');
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    expect(body, {
      'full_name': 'Ali B.',
      'phone': null,
      'preferred_language': 'fr',
    });
    expect(body.keys, isNot(contains('is_professional')));
    expect(body.keys, isNot(contains('id')));
    expect(
      r.headers['Prefer'] ?? r.headers['prefer'],
      contains('return=representation'),
    );
    expect(p.phone, isNull);
  });

  test(
    'becomeProfessional calls the RPC and sends no identity of its own',
    () async {
      final wire = _Wire(
        (_) => http.Response(
          'null',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await wire.repo().becomeProfessional();
      final r = wire.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/rest/v1/rpc/become_professional');
      expect(
        r.body,
        isNot(contains('u1')),
        reason: 'the database uses auth.uid(), not a parameter',
      );
      expect(
        ['', '{}', 'null'],
        contains(r.body),
        reason: 'no arguments at all: ${r.body}',
      );
    },
  );

  test('no signed-in user: nothing is sent', () async {
    final wire = _Wire((_) => _json(_row));
    await expectLater(
      wire.repo(userId: null).fetchMine(),
      throwsA(
        isA<ProfileError>().having(
          (e) => e.failure,
          'failure',
          ProfileFailure.notSignedIn,
        ),
      ),
    );
    await expectLater(
      wire
          .repo(userId: null)
          .updateMine(fullName: 'x', phone: null, preferredLanguage: 'fr'),
      throwsA(isA<ProfileError>()),
    );
    expect(wire.requests, isEmpty);
  });

  test(
    'server answers map to categories (expired session, bad data, unknown)',
    () async {
      Future<ProfileFailure> failureFor(
        int status,
        Map<String, Object?> body,
      ) async {
        final wire = _Wire((_) => _json(body, status));
        try {
          await wire.repo().fetchMine();
        } on ProfileError catch (e) {
          return e.failure;
        }
        fail('expected a failure');
      }

      expect(
        await failureFor(401, {'code': 'PGRST301', 'message': 'JWT expired'}),
        ProfileFailure.notSignedIn,
      );
      expect(
        await failureFor(403, {
          'code': '42501',
          'message': 'permission denied',
        }),
        ProfileFailure.notSignedIn,
      );
      expect(
        await failureFor(400, {'code': '23514', 'message': 'check violation'}),
        ProfileFailure.invalidData,
      );
      expect(
        await failureFor(500, {'code': 'XX000', 'message': 'boom'}),
        ProfileFailure.unknown,
      );
    },
  );

  test(
    'a dropped connection is a network failure; the message is never leaked',
    () async {
      final client = MockClient(
        (_) async =>
            throw http.ClientException('Failed host lookup: abc.supabase.co'),
      );
      final supabase = sb.SupabaseClient(
        'https://abc.supabase.co',
        'sb_publishable_testkey',
        httpClient: client,
      );
      final repo = SupabaseProfileRepository(supabase, userId: () => 'u1');
      await expectLater(
        repo.fetchMine(),
        throwsA(
          isA<ProfileError>()
              .having((e) => e.failure, 'failure', ProfileFailure.network)
              .having(
                (e) => e.toString(),
                'toString',
                isNot(contains('lookup')),
              ),
        ),
      );
    },
  );
}
