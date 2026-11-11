import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/features/auth/application/auth_providers.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/messages/application/messages_providers.dart';
import 'package:khidma/features/messages/data/supabase_messages_repository.dart';
import 'package:khidma/features/messages/domain/messages_domain.dart';
import 'package:khidma/features/offers/application/offers_providers.dart';
import 'package:khidma/features/offers/domain/offers_domain.dart';
import 'package:khidma/features/portfolio/application/portfolio_providers.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:khidma/features/professional/application/professional_providers.dart';
import 'package:khidma/features/professional/domain/professional_domain.dart';
import 'package:khidma/features/requests/application/customer_offers_providers.dart';
import 'package:khidma/features/requests/application/requests_providers.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_auth_repository.dart';
import '../support/fake_customer_offers.dart';
import '../support/fake_messages.dart';
import '../support/fake_offers.dart';
import '../support/fake_portfolio.dart';
import '../support/fake_professional_repository.dart';
import '../support/fake_requests.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

Future<dynamic> _open(
  WidgetTester tester,
  FakeMessagesRepository repo,
  String route, {
  FakePhotoPicker? picker,
  Map<String, Object> prefs = const {},
  FakeAuthRepository? auth,
  List<dynamic> extra = const [],
}) async {
  final c = await pumpApp(
    tester,
    auth: auth ?? FakeAuthRepository(signedIn: _ali),
    prefs: prefs,
    overrides: [
      messagesRepositoryProvider.overrideWithValue(repo),
      photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
      photoPreparerProvider.overrideWithValue(
        (b) async => PreparedPhoto(bytes: b, width: 10, height: 10),
      ),
      ...extra.cast(),
    ],
  );
  c.read(routerProvider).go(route);
  await tester.pumpAndSettle();
  return c;
}

void main() {
  setUpAll(loadAppFonts);

  group('inbox', () {
    testWidgets('signed out: an invitation', (tester) async {
      await _open(
        tester,
        FakeMessagesRepository(),
        AppRoutes.messages,
        auth: FakeAuthRepository(),
      );
      expect(find.text('Connectez-vous pour discuter'), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      await _open(tester, FakeMessagesRepository(), AppRoutes.messages);
      expect(find.text('Aucun message'), findsOneWidget);
    });

    testWidgets(
      'who, what about, last message, unread badge; the customer is anonymous to the professional',
      (tester) async {
        final repo = FakeMessagesRepository(
          conversations: [
            sampleConversation(
              id: 'c1',
              unread: 3,
              lastBody: 'Je passe demain',
            ),
            sampleConversation(
              id: 'c2',
              offerId: 'o2',
              iAmCustomer: false,
              lastBody: '',
              lastHasImage: true,
            ),
          ],
        );
        await _open(tester, repo, AppRoutes.messages);
        expect(find.text('Plomberie Ben Salah'), findsOneWidget);
        expect(
          find.text('Client'),
          findsOneWidget,
          reason: 'the professional sees "Client", no name',
        );
        expect(find.text('Je passe demain'), findsOneWidget);
        expect(find.text('Photo envoyée'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      },
    );

    testWidgets('a conversation opens its chat', (tester) async {
      final repo = FakeMessagesRepository(
        conversations: [sampleConversation()],
      );
      await _open(tester, repo, AppRoutes.messages);
      await tester.tap(find.text('Plomberie Ben Salah'));
      await tester.pumpAndSettle();
      expect(find.text('Aucun message. Dites bonjour !'), findsOneWidget);
    });

    testWidgets('the inbox reloads when a message arrives anywhere', (
      tester,
    ) async {
      final repo = FakeMessagesRepository(
        conversations: [sampleConversation(unread: 0, lastBody: 'ancien')],
      );
      await _open(tester, repo, AppRoutes.messages);
      expect(find.text('ancien'), findsOneWidget);
      repo.list[0] = sampleConversation(unread: 1, lastBody: 'nouveau');
      repo.pulseController.add(5);
      await tester.pumpAndSettle();
      expect(find.text('nouveau'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('signing out clears the inbox', (tester) async {
      final auth = FakeAuthRepository(signedIn: _ali);
      final repo = FakeMessagesRepository(
        conversations: [sampleConversation(lastBody: 'Secret')],
      );
      await _open(tester, repo, AppRoutes.messages, auth: auth);
      expect(find.text('Secret'), findsOneWidget);
      auth.emit(null);
      await tester.pumpAndSettle();
      expect(find.text('Secret'), findsNothing);
      expect(find.text('Connectez-vous pour discuter'), findsOneWidget);
    });
  });

  group('chat', () {
    testWidgets(
      'send text: appears, input clears, trimmed; no empty messages',
      (tester) async {
        final repo = FakeMessagesRepository(
          conversations: [sampleConversation()],
        );
        await _open(tester, repo, AppRoutes.chatPath('c1'));
        await tester.tap(find.byTooltip('Envoyer'));
        await tester.pumpAndSettle();
        expect(repo.sent, isEmpty, reason: 'blank is not sent');
        await tester.enterText(
          find.byType(TextField),
          '  Bonjour, vous êtes libre demain ?  ',
        );
        await tester.tap(find.byTooltip('Envoyer'));
        await tester.pumpAndSettle();
        expect(repo.sent.single.$2, 'Bonjour, vous êtes libre demain ?');
        expect(find.text('Bonjour, vous êtes libre demain ?'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
      },
    );

    testWidgets(
      'a message from the other side arrives live and is marked read',
      (tester) async {
        final repo = FakeMessagesRepository(
          conversations: [sampleConversation(unread: 1)],
        );
        await _open(tester, repo, AppRoutes.chatPath('c1'));
        repo.incoming('c1', body: 'Oui, demain 10h');
        await tester.pumpAndSettle();
        expect(find.text('Oui, demain 10h'), findsOneWidget);
        expect(repo.reads, isNotEmpty);
      },
    );

    testWidgets('text typed while a message is being sent is not erased', (
      tester,
    ) async {
      final repo = FakeMessagesRepository(
        conversations: [sampleConversation()],
      );
      await _open(tester, repo, AppRoutes.chatPath('c1'));
      await tester.enterText(find.byType(TextField), 'premier');
      final gate = repo.gate = Completer<void>();
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'deuxième en cours');
      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.sent.single.$2, 'premier');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'deuxième en cours',
      );
    });

    testWidgets('reading is reported up to the newest message shown', (
      tester,
    ) async {
      final repo = FakeMessagesRepository(
        conversations: [sampleConversation(unread: 2)],
      );
      repo.byConversation['c1'] = [
        ChatMessage(
          id: 41,
          fromCustomer: false,
          createdAt: DateTime(2026, 11, 9, 10),
          body: 'a',
        ),
        ChatMessage(
          id: 42,
          fromCustomer: false,
          createdAt: DateTime(2026, 11, 9, 11),
          body: 'b',
        ),
      ];
      await _open(tester, repo, AppRoutes.chatPath('c1'));
      expect(repo.readUpTo.last, 42);
      repo.incoming('c1', body: 'c');
      await tester.pumpAndSettle();
      expect(
        repo.readUpTo.last,
        greaterThan(42),
        reason: 'a later message is acknowledged only when shown',
      );
    });

    testWidgets(
      'the live connection failing offers a retry even when messages are shown',
      (tester) async {
        final repo = FakeMessagesRepository(
          conversations: [sampleConversation()],
        );
        repo.byConversation['c1'] = [
          ChatMessage(
            id: 1,
            fromCustomer: false,
            createdAt: DateTime(2026, 11, 9),
            body: 'déjà là',
          ),
        ];
        repo.streamFails = true;
        await _open(tester, repo, AppRoutes.chatPath('c1'));
        expect(find.text('Réessayer'), findsOneWidget);
        repo.streamFails = false;
        await tester.tap(find.text('Réessayer'));
        await tester.pumpAndSettle();
        expect(find.text('Réessayer'), findsNothing);
        expect(find.text('déjà là'), findsOneWidget);
      },
    );

    testWidgets(
      'a failed send keeps the text and explains; the rate limit has its own words',
      (tester) async {
        final repo = FakeMessagesRepository(
          conversations: [sampleConversation()],
        );
        await _open(tester, repo, AppRoutes.chatPath('c1'));
        await tester.enterText(find.byType(TextField), 'important');
        repo.failNext = RequestsFailure.network;
        await tester.tap(find.byTooltip('Envoyer'));
        await tester.pumpAndSettle();
        expect(find.text('Message non envoyé. Réessayez.'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'important',
        );
        repo.failNext = RequestsFailure.rateLimited;
        await tester.tap(find.byTooltip('Envoyer'));
        await tester.pumpAndSettle();
        expect(
          find.text('Vous écrivez trop vite. Patientez un instant.'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Envoyer'));
        await tester.pumpAndSettle();
        expect(find.text('important'), findsOneWidget);
        expect(
          find.text('Message non envoyé. Réessayez.'),
          findsNothing,
          reason: 'cleared after success',
        );
      },
    );

    testWidgets('a double tap on send sends once', (tester) async {
      final repo = FakeMessagesRepository(
        conversations: [sampleConversation()],
      );
      await _open(tester, repo, AppRoutes.chatPath('c1'));
      await tester.enterText(find.byType(TextField), 'une fois');
      final gate = repo.gate = Completer<void>();
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pump();
      await tester.tap(find.byTooltip('Envoyer'), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.sent.length, 1);
    });

    testWidgets(
      'a photo is picked, prepared and sent; failures are explained',
      (tester) async {
        final repo = FakeMessagesRepository(
          conversations: [sampleConversation()],
        );
        final picker = FakePhotoPicker(Uint8List.fromList([1, 2, 3]));
        await _open(tester, repo, AppRoutes.chatPath('c1'), picker: picker);
        await tester.tap(find.byTooltip('Joindre une photo'));
        await tester.pumpAndSettle();
        expect(repo.images.single.$2.bytes.length, 3);
        repo.failNext = RequestsFailure.network;
        await tester.tap(find.byTooltip('Joindre une photo'));
        await tester.pumpAndSettle();
        expect(find.text('Photo non envoyée. Réessayez.'), findsOneWidget);
      },
    );

    testWidgets('cancelling the photo picker sends nothing', (tester) async {
      final repo = FakeMessagesRepository(
        conversations: [sampleConversation()],
      );
      await _open(
        tester,
        repo,
        AppRoutes.chatPath('c1'),
        picker: FakePhotoPicker(null),
      );
      await tester.tap(find.byTooltip('Joindre une photo'));
      await tester.pumpAndSettle();
      expect(repo.images, isEmpty);
    });

    testWidgets('a closed conversation is readable but has no composer', (
      tester,
    ) async {
      final repo = FakeMessagesRepository(
        conversations: [sampleConversation(writable: false)],
      );
      repo.byConversation['c1'] = [
        ChatMessage(
          id: 1,
          fromCustomer: false,
          createdAt: DateTime(2026, 11, 9, 10),
          body: 'Avant la fin',
        ),
      ];
      await _open(tester, repo, AppRoutes.chatPath('c1'));
      expect(find.text('Avant la fin'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(
        find.text(
          'Cette conversation est terminée : vous pouvez la relire, mais plus y écrire.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('my messages and theirs are told apart for assistive tech', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = FakeMessagesRepository(
        conversations: [sampleConversation()],
      );
      repo.byConversation['c1'] = [
        ChatMessage(
          id: 1,
          fromCustomer: true,
          createdAt: DateTime(2026, 11, 9, 10),
          body: 'de moi',
        ),
        ChatMessage(
          id: 2,
          fromCustomer: false,
          createdAt: DateTime(2026, 11, 9, 11),
          body: 'de lui',
        ),
      ];
      await _open(tester, repo, AppRoutes.chatPath('c1'));
      expect(find.bySemanticsLabel(RegExp('^Vous, ')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Interlocuteur, ')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('live updates failing say so (and the history still shows)', (
      tester,
    ) async {
      final repo = FakeMessagesRepository(conversations: [sampleConversation()])
        ..streamFails = true;
      await _open(tester, repo, AppRoutes.chatPath('c1'));
      expect(
        find.text('Mise à jour en direct interrompue. Tirez pour actualiser.'),
        findsOneWidget,
      );
      // Let the (bounded) reconnection attempts run out.
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('another account never sees the previous account\'s messages', (
      tester,
    ) async {
      final auth = FakeAuthRepository(signedIn: _ali);
      final repo = FakeMessagesRepository(
        conversations: [sampleConversation()],
      );
      repo.byConversation['c1'] = [
        ChatMessage(
          id: 1,
          fromCustomer: true,
          createdAt: DateTime(2026, 11, 9),
          body: 'confidentiel',
        ),
      ];
      await _open(tester, repo, AppRoutes.chatPath('c1'), auth: auth);
      expect(find.text('confidentiel'), findsOneWidget);
      auth.emit(null);
      await tester.pumpAndSettle();
      expect(find.text('confidentiel'), findsNothing);
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
        final repo = FakeMessagesRepository(
          conversations: [sampleConversation(unread: 2)],
        );
        repo.byConversation['c1'] = [
          ChatMessage(
            id: 1,
            fromCustomer: true,
            createdAt: DateTime(2026, 11, 9, 10),
            body: 'Bonjour, pouvez-vous passer demain matin avec le matériel nécessaire ?',
          ),
          ChatMessage(
            id: 2,
            fromCustomer: false,
            createdAt: DateTime(2026, 11, 9, 11),
            imagePath: 'c1/x.jpg',
          ),
        ];
        final c = await _open(
          tester,
          repo,
          AppRoutes.messages,
          prefs: {'locale': lang},
        );
        expect(tester.takeException(), isNull, reason: '$lang inbox');
        c.read(routerProvider).push(AppRoutes.chatPath('c1'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$lang chat');
      });
    }
  });

  group('starting a conversation', () {
    testWidgets(
      'the customer asks a question from an offer card: opens the chat',
      (tester) async {
        final msgs = FakeMessagesRepository();
        final offers = FakeCustomerOffersRepository(
          offers: [sampleOffer(id: 'oa', pro: 'demo-01')],
        );
        final c = await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: _ali),
          overrides: [
            messagesRepositoryProvider.overrideWithValue(msgs),
            customerOffersRepositoryProvider.overrideWithValue(offers),
            requestsRepositoryProvider.overrideWithValue(
              FakeRequestsRepository([sampleRequest(offers: 1)]),
            ),
          ],
        );
        c.read(routerProvider).push(AppRoutes.requestPath('r-sample'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Poser une question'));
        await tester.pumpAndSettle();
        expect(msgs.opened, ['oa']);
        expect(find.text('Aucun message. Dites bonjour !'), findsOneWidget);
      },
    );

    testWidgets('a declined offer has no "ask" button', (tester) async {
      final offers = FakeCustomerOffersRepository(
        offers: [sampleOffer(id: 'oa', status: OfferStatus.declined)],
      );
      final c = await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        overrides: [
          messagesRepositoryProvider.overrideWithValue(
            FakeMessagesRepository(),
          ),
          customerOffersRepositoryProvider.overrideWithValue(offers),
          requestsRepositoryProvider.overrideWithValue(
            FakeRequestsRepository([sampleRequest(offers: 1)]),
          ),
        ],
      );
      c.read(routerProvider).push(AppRoutes.requestPath('r-sample'));
      await tester.pumpAndSettle();
      expect(find.text('Poser une question'), findsNothing);
    });

    testWidgets('a server refusal when opening is explained', (tester) async {
      final msgs = FakeMessagesRepository()..failOpen = RequestsFailure.notOpen;
      final offers = FakeCustomerOffersRepository(
        offers: [sampleOffer(id: 'oa')],
      );
      final c = await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: _ali),
        overrides: [
          messagesRepositoryProvider.overrideWithValue(msgs),
          customerOffersRepositoryProvider.overrideWithValue(offers),
          requestsRepositoryProvider.overrideWithValue(
            FakeRequestsRepository([sampleRequest(offers: 1)]),
          ),
        ],
      );
      c.read(routerProvider).push(AppRoutes.requestPath('r-sample'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poser une question'));
      await tester.pumpAndSettle();
      expect(find.text('Cette conversation est terminée.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets(
      'the professional writes to the customer from their own offer',
      (tester) async {
        final msgs = FakeMessagesRepository();
        final offers = FakeOffersRepository(
          open: [sampleOpen(mine: OfferStatus.pending)],
          offers: [
            MyOffer(
              id: 'mine',
              requestId: 'o-req',
              requestTitle: 'Fuite',
              priceTnd: 100,
              status: OfferStatus.pending,
              createdAt: DateTime(2026, 11, 9),
            ),
          ],
        );
        final c = await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: _ali),
          overrides: [
            messagesRepositoryProvider.overrideWithValue(msgs),
            offersRepositoryProvider.overrideWithValue(offers),
            professionalRepositoryProvider.overrideWithValue(
              FakeProfessionalRepository(
                draft: const ProfessionalDraft(
                  businessName: 'Pro',
                  categoryId: 1,
                  description: 'Une description assez longue.',
                  governorateId: 11,
                  phone: '+21620123456',
                  isPublished: true,
                ),
              ),
            ),
          ],
        );
        c.read(routerProvider).push(AppRoutes.proRequestPath('o-req'));
        await tester.pumpAndSettle();
        final btn = find.text('Écrire au client');
        await tester.ensureVisible(btn);
        await tester.pumpAndSettle();
        await tester.tap(btn);
        await tester.pumpAndSettle();
        expect(msgs.opened, ['mine']);
      },
    );
  });

  group('wire format', () {
    late List<http.BaseRequest> requests;
    SupabaseMessagesRepository build(Object Function(http.BaseRequest) answer) {
      requests = [];
      return SupabaseMessagesRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient.streaming((r, body) async {
            requests.add(r);
            await body.drain<void>();
            final a = answer(r);
            if (a is http.StreamedResponse) return a;
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode(a))),
              200,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }),
        ),
      );
    }

    test('the inbox comes from my_conversations', () async {
      final repo = build(
        (_) => [
          {
            'conversation_id': 'c1',
            'offer_id': 'o1',
            'request_id': 'r1',
            'request_title': 'T',
            'i_am_customer': true,
            'other_name': 'Pro',
            'other_id': 'p1',
            'last_body': 'hi',
            'last_has_image': false,
            'last_at': '2026-11-10T10:00:00Z',
            'unread_count': 2,
            'writable': true,
          },
        ],
      );
      final list = await repo.conversations();
      expect(requests.single.url.path, '/rest/v1/rpc/my_conversations');
      expect(list.single.unread, 2);
      expect(list.single.otherName, 'Pro');
      expect(list.single.writable, isTrue);
    });

    test('send text, mark read, start use the functions', () async {
      final repo = build(
        (r) =>
            r.url.path.endsWith('start_conversation') ? 'conv-1' : <Object>[],
      );
      expect(await repo.startConversation('o1'), 'conv-1');
      await repo.send('conv-1', 'Bonjour');
      await repo.markRead('conv-1', 7);
      final calls = requests.map((r) => r.url.path.split('/').last).toList();
      expect(calls, [
        'start_conversation',
        'send_message',
        'mark_conversation_read',
      ]);
      expect(jsonDecode((requests[1] as http.Request).body), {
        'p_conversation': 'conv-1',
        'p_body': 'Bonjour',
        'p_image_path': null,
      });
    });

    test('an image is uploaded to the private bucket under the conversation, then attached', () async {
      final repo = build(
        (r) => r.url.path.startsWith('/storage') ? {'Key': 'chat-images/x'} : 1,
      );
      await repo.sendImage(
        'conv-1',
        PreparedPhoto(bytes: Uint8List(50), width: 1, height: 1),
      );
      final up = requests.whereType<http.MultipartRequest>().single;
      expect(up.url.path, startsWith('/storage/v1/object/chat-images/conv-1/'));
      final send = requests.whereType<http.Request>().firstWhere(
        (r) => r.url.path.endsWith('send_message'),
      );
      final body = jsonDecode(send.body) as Map<String, dynamic>;
      expect(body['p_body'], isNull);
      expect(body['p_image_path'], startsWith('conv-1/'));
    });

    test(
      'if the message is refused, the uploaded image is removed again',
      () async {
        final repo = build((r) {
          if (r.url.path.startsWith('/storage') && r.method == 'POST') {
            return {'Key': 'x'};
          }
          if (r.url.path.endsWith('send_message')) {
            return http.StreamedResponse(
              Stream.value(
                utf8.encode('{"code":"P0001","message":"not_open"}'),
              ),
              400,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }
          return <Object>[];
        });
        await expectLater(
          repo.sendImage(
            'conv-1',
            PreparedPhoto(bytes: Uint8List(50), width: 1, height: 1),
          ),
          throwsA(
            isA<RequestsError>().having(
              (e) => e.failure,
              'failure',
              RequestsFailure.notOpen,
            ),
          ),
        );
        expect(
          requests.any(
            (r) =>
                r.method == 'DELETE' &&
                r.url.path.startsWith('/storage/v1/object/chat-images'),
          ),
          isTrue,
        );
      },
    );

    test('an oversized image is refused before any request', () async {
      final repo = build((_) => <Object>[]);
      await expectLater(
        repo.sendImage(
          'c',
          PreparedPhoto(
            bytes: Uint8List(maxUploadBytes + 1),
            width: 1,
            height: 1,
          ),
        ),
        throwsA(isA<RequestsError>()),
      );
      expect(requests, isEmpty);
    });

    test('messages are read for one conversation, oldest first', () async {
      final repo = build(
        (_) => [
          {
            'id': 1,
            'sender_id': 'a',
            'body': 'x',
            'image_path': null,
            'created_at': '2026-11-10T10:00:00Z',
          },
        ],
      );
      final m = await repo.messages('c1');
      final q = requests.single.url.queryParameters;
      expect(q['conversation_id'], 'eq.c1');
      expect(q['order'], startsWith('id.asc'));
      expect(m.single.body, 'x');
    });

    test('chat image links are signed (private bucket)', () async {
      final repo = build(
        (_) => {'signedURL': '/object/sign/chat-images/c/x.jpg?token=t'},
      );
      expect(await repo.imageUrl('c/x.jpg'), contains('token=t'));
    });
  });

  test('the unread total sums the inbox', () async {
    final c = ProviderContainer(
      overrides: [
        messagesRepositoryProvider.overrideWithValue(
          FakeMessagesRepository(
            conversations: [
              sampleConversation(unread: 2),
              sampleConversation(id: 'c2', unread: 3),
            ],
          ),
        ),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(signedIn: _ali),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(currentUserProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    c.listen(conversationsProvider, (_, _) {});
    c.listen(unreadTotalProvider, (_, _) {});
    await c.read(conversationsProvider.future);
    expect(c.read(unreadTotalProvider), 5);
  });
}
