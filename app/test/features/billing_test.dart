import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khidma/features/auth/application/auth_providers.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/billing/application/billing_providers.dart';
import 'package:khidma/features/billing/data/supabase_billing_repository.dart';
import 'package:khidma/features/billing/domain/billing_domain.dart';
import 'package:khidma/features/billing/presentation/billing_screen.dart';
import 'package:khidma/features/billing/presentation/payment_instructions_screen.dart';
import 'package:khidma/features/marketplace/application/contact_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_billing.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

MySubscription _active({int daysLeft = 12}) => MySubscription(
  planCode: 'standard',
  state: SubscriptionState.active,
  currentPeriodEnd: DateTime(2026, 12, 4),
  daysLeft: daysLeft,
);

void main() {
  setUpAll(loadAppFonts);

  group('amounts', () {
    test('trailing zeros are trimmed, decimals use the language separator', () {
      expect(formatTndAmount(20000), '20 TND');
      expect(formatTndAmount(25500), '25,5 TND');
      expect(formatTndAmount(25500, languageCode: 'ar'), '25,5 TND');
      expect(formatTndAmount(25500, languageCode: 'en'), '25.5 TND');
      expect(formatTndAmount(1), '0,001 TND');
      expect(formatTndAmount(30050), '30,05 TND');
      expect(formatTndAmount(1234567), '1234,567 TND');
    });
  });

  group('failure mapping', () {
    test('database tags become categories and no text is forwarded', () {
      BillingFailure map(String code, [String message = 'x']) =>
          mapBillingException(
            sb.PostgrestException(message: message, code: code),
          );
      expect(map('P0001', 'rate_limited'), BillingFailure.rateLimited);
      expect(map('P0001', 'invalid_input'), BillingFailure.invalid);
      expect(map('42501'), BillingFailure.forbidden);
      expect(map('P0002'), BillingFailure.notFound);
      expect(map('PGRST301'), BillingFailure.notSignedIn);
      expect(
        map('XX000', 'relation "payment_orders" broke'),
        BillingFailure.unknown,
      );
      expect(
        mapBillingException(const sb.FunctionException(status: 503)),
        BillingFailure.flouciUnavailable,
      );
      expect(
        mapBillingException(const sb.FunctionException(status: 502)),
        BillingFailure.unknown,
      );
      expect(
        mapBillingException(http.ClientException('down')),
        BillingFailure.network,
      );
      expect(mapBillingException(StateError('x')), BillingFailure.unknown);
    });
  });

  group('wire format', () {
    late List<http.Request> requests;
    Object Function(http.Request) responder = (_) => <Object>[];
    int status = 200;

    SupabaseBillingRepository build() {
      requests = [];
      return SupabaseBillingRepository(
        sb.SupabaseClient(
          'https://abc.supabase.co',
          'sb_publishable_testkey',
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(responder(r)),
              status,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
    }

    setUp(() {
      status = 200;
      responder = (_) => <Object>[];
    });

    test(
      'plans are read from the table, cheapest first by sort order',
      () async {
        responder = (_) => [
          {
            'code': 'standard',
            'name_fr': 'Standard',
            'name_ar': 'عادي',
            'name_en': 'Standard',
            'amount_millimes': 20000,
            'period_days': 30,
          },
        ];
        final plans = await build().plans();
        expect(plans.single.code, 'standard');
        expect(plans.single.amountMillimes, 20000);
        expect(plans.single.name('ar'), 'عادي');
        final r = requests.single;
        expect(r.url.path, '/rest/v1/subscription_plans');
        expect(r.url.queryParameters['order'], startsWith('sort_order.asc'));
        expect(r.url.queryParameters['select'], contains('amount_millimes'));
      },
    );

    test(
      'mySubscription calls the function; no row means never subscribed',
      () async {
        final repo = build();
        expect(await repo.mySubscription(), isNull);
        expect(requests.single.url.path, '/rest/v1/rpc/my_subscription');
        responder = (_) => [
          {
            'plan_code': 'plus',
            'status': 'past_due',
            'current_period_end': '2026-12-04T10:00:00Z',
            'days_left': 0,
          },
        ];
        final s = (await repo.mySubscription())!;
        expect(s.planCode, 'plus');
        expect(s.state, SubscriptionState.pastDue);
        expect(s.daysLeft, 0);
      },
    );

    test('my orders read only the own columns, newest first', () async {
      responder = (_) => [
        {
          'id': 'o1',
          'plan_code': 'standard',
          'amount_millimes': 20000,
          'method': 'bank_transfer',
          'status': 'awaiting_confirmation',
          'reference': 'KH-A1B2C3',
          'payer_note': 'envoye',
          'created_at': '2026-11-10T10:00:00Z',
          'paid_at': null,
        },
      ];
      final orders = await build().myOrders();
      expect(orders.single.method, PaymentMethod.bankTransfer);
      expect(orders.single.status, OrderStatus.awaitingConfirmation);
      expect(orders.single.payerNote, 'envoye');
      expect(orders.single.paidAt, isNull);
      expect(requests.single.url.path, '/rest/v1/payment_orders');
      expect(
        requests.single.url.queryParameters['order'],
        startsWith('created_at.desc'),
      );
    });

    test('createOrder sends plan and method and reads the one row', () async {
      responder = (_) => [
        {
          'id': 'o9',
          'reference': 'KH-ZZ99YY',
          'amount_millimes': 30000,
          'method': 'd17',
          'status': 'pending',
        },
      ];
      final o = await build().createOrder('plus', PaymentMethod.d17);
      expect(o.reference, 'KH-ZZ99YY');
      expect(o.planCode, 'plus');
      expect(o.method, PaymentMethod.d17);
      final r = requests.single;
      expect(r.url.path, '/rest/v1/rpc/create_payment_order');
      expect(jsonDecode(r.body), {'p_plan': 'plus', 'p_method': 'd17'});
    });

    test('markSent trims the note and sends null when it is empty', () async {
      responder = (_) => <String, Object?>{};
      final repo = build();
      await repo.markSent('o1', '  envoye le 12  ');
      expect(requests.last.url.path, '/rest/v1/rpc/mark_payment_sent');
      expect(jsonDecode(requests.last.body), {
        'p_order': 'o1',
        'p_note': 'envoye le 12',
      });
      await repo.markSent('o1', '   ');
      expect(jsonDecode(requests.last.body), {'p_order': 'o1', 'p_note': null});
      await repo.markSent('o1', null);
      expect(jsonDecode(requests.last.body), {'p_order': 'o1', 'p_note': null});
    });

    test('cancel sends the order', () async {
      await build().cancel('o1');
      expect(requests.single.url.path, '/rest/v1/rpc/cancel_payment_order');
      expect(jsonDecode(requests.single.body), {'p_order': 'o1'});
    });

    test('instructions: both, one, or none configured', () async {
      responder = (_) => {
        'bank': {
          'name': 'BIAT',
          'holder': 'Khidma',
          'rib': '08006000000123456789',
        },
        'd17': {'number': '22123456', 'holder': null},
      };
      final repo = build();
      var i = await repo.instructions();
      expect(requests.single.url.path, '/rest/v1/rpc/get_payment_instructions');
      expect(i.bank!.rib, '08006000000123456789');
      expect(i.bank!.name, 'BIAT');
      expect(i.d17!.number, '22123456');
      expect(i.d17!.holder, isNull);
      responder = (_) => {'bank': null, 'd17': null};
      i = await repo.instructions();
      expect(i.bank, isNull);
      expect(i.d17, isNull);
    });

    test('flouci: posts the order to the function with the api key, returns the https link', () async {
      responder = (_) => {'link': 'https://pay.flouci.example/x'};
      final link = await build().flouciLink('o1');
      expect(link, Uri.parse('https://pay.flouci.example/x'));
      final r = requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/functions/v1/flouci-payments/create');
      expect(r.headers['apikey'], 'sb_publishable_testkey');
      expect(jsonDecode(r.body), {'order_id': 'o1'});
    });

    test(
      'flouci: 503 means not available; a link that is not https is refused',
      () async {
        status = 503;
        responder = (_) => {'error': 'not_configured'};
        await expectLater(
          build().flouciLink('o1'),
          throwsA(
            isA<BillingError>().having(
              (e) => e.failure,
              'failure',
              BillingFailure.flouciUnavailable,
            ),
          ),
        );
        status = 200;
        for (final bad in [
          'http://pay.example/x',
          'javascript:alert(1)',
          'tel:123',
          '',
        ]) {
          responder = (_) => {'link': bad};
          await expectLater(
            build().flouciLink('o1'),
            throwsA(
              isA<BillingError>().having(
                (e) => e.failure,
                'failure',
                BillingFailure.unknown,
              ),
            ),
            reason: bad,
          );
        }
        responder = (_) => <String, Object?>{};
        await expectLater(
          build().flouciLink('o1'),
          throwsA(isA<BillingError>()),
        );
      },
    );

    test('a database error becomes a category without its text', () async {
      status = 400;
      responder = (_) => {
        'code': 'P0001',
        'message': 'rate_limited',
        'details': null,
        'hint': null,
      };
      await expectLater(
        build().createOrder('standard', PaymentMethod.d17),
        throwsA(
          isA<BillingError>().having(
            (e) => e.failure,
            'failure',
            BillingFailure.rateLimited,
          ),
        ),
      );
      responder = (_) => {
        'code': '42501',
        'message': 'forbidden',
        'details': null,
        'hint': null,
      };
      status = 403;
      await expectLater(
        build().createOrder('standard', PaymentMethod.d17),
        throwsA(
          isA<BillingError>().having(
            (e) => e.failure,
            'failure',
            BillingFailure.forbidden,
          ),
        ),
      );
    });

    test('without a backend every call says not configured', () async {
      const repo = NotConfiguredBillingRepository();
      for (final call in <Future<Object?> Function()>[
        repo.plans,
        repo.mySubscription,
        repo.myOrders,
        repo.instructions,
        () => repo.createOrder('standard', PaymentMethod.d17),
        () => repo.flouciLink('o'),
        () => repo.markSent('o', null),
        () => repo.cancel('o'),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<BillingError>().having(
              (e) => e.failure,
              'failure',
              BillingFailure.notConfigured,
            ),
          ),
        );
      }
    });
  });

  group('screen', () {
    late List<Uri> opened;
    bool canOpen = true;

    Future<void> open(
      WidgetTester tester,
      FakeBillingRepository repo, {
      String lang = 'fr',
    }) async {
      opened = [];
      canOpen = true;
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingRepositoryProvider.overrideWithValue(repo),
            currentUserProvider.overrideWithValue(_ali),
            urlOpenerProvider.overrideWithValue((uri) async {
              opened.add(uri);
              return canOpen;
            }),
          ],
          child: bareApp(const BillingScreen(), lang: lang),
        ),
      );
      await tester.pumpAndSettle();
    }

    PaymentOrder order(
      String id,
      PaymentMethod m,
      OrderStatus s, {
      int amount = 20000,
    }) => PaymentOrder(
      id: id,
      planCode: 'standard',
      amountMillimes: amount,
      method: m,
      status: s,
      reference: 'KH-$id',
      createdAt: DateTime(2026, 11, 10),
    );

    testWidgets(
      'shows status, end date, days left, plans, methods and payments',
      (tester) async {
        final repo = FakeBillingRepository(
          subscription: _active(),
          orders: [order('AAA111', PaymentMethod.d17, OrderStatus.paid)],
        );
        await open(tester, repo);
        expect(find.text('Abonnement'), findsOneWidget);
        expect(find.text('Actif'), findsOneWidget);
        expect(find.textContaining('2026'), findsWidgets);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('Standard'), findsOneWidget);
        expect(find.text('Plus'), findsOneWidget);
        expect(find.text('20 TND'), findsOneWidget);
        expect(find.text('30 TND'), findsOneWidget);
        expect(find.text('Flouci'), findsOneWidget);
        expect(find.text('D17'), findsOneWidget);
        expect(find.text('Virement bancaire'), findsOneWidget);
        expect(find.text('Payer'), findsOneWidget);
        expect(find.text('KH-AAA111 · 20 TND'), findsOneWidget);
        expect(find.text('Payé'), findsOneWidget);
      },
    );

    testWidgets('no subscription and no payments say so', (tester) async {
      await open(tester, FakeBillingRepository());
      expect(find.text('Aucun abonnement pour le moment.'), findsOneWidget);
      expect(find.text('Aucun paiement pour le moment.'), findsOneWidget);
    });

    testWidgets('an expired subscription shows its stamp and no days left', (
      tester,
    ) async {
      await open(
        tester,
        FakeBillingRepository(
          subscription: MySubscription(
            planCode: 'standard',
            state: SubscriptionState.expired,
            currentPeriodEnd: DateTime(2026, 10, 1),
            daysLeft: 0,
          ),
        ),
      );
      expect(find.text('Expiré'), findsOneWidget);
      expect(find.text('Jours restants'), findsNothing);
    });

    testWidgets(
      'Flouci: creates the order, asks for the link, opens it outside the app',
      (tester) async {
        final repo = FakeBillingRepository();
        await open(tester, repo);
        await tester.tap(find.text('Payer'));
        await tester.pumpAndSettle();
        expect(repo.created, [('standard', PaymentMethod.flouci)]);
        expect(repo.linkCalls, ['o1']);
        expect(opened, [Uri.parse('https://pay.flouci.example/abc')]);
        expect(
          find.textContaining('ouvert dans votre navigateur'),
          findsOneWidget,
        );
        // The new order shows in the list, still waiting.
        expect(find.text('En attente'), findsOneWidget);
      },
    );

    testWidgets('the second plan is the one ordered when chosen', (
      tester,
    ) async {
      final repo = FakeBillingRepository();
      await open(tester, repo);
      await tester.tap(find.text('Plus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payer'));
      await tester.pumpAndSettle();
      expect(repo.created.single.$1, 'plus');
    });

    testWidgets(
      'Flouci not configured: says to use D17 or the transfer, opens nothing',
      (tester) async {
        final repo = FakeBillingRepository()
          ..failLink = BillingFailure.flouciUnavailable;
        await open(tester, repo);
        await tester.tap(find.text('Payer'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            "Flouci n'est pas encore disponible, utilisez D17 ou le virement.",
          ),
          findsOneWidget,
        );
        expect(opened, isEmpty);
      },
    );

    testWidgets('a link no app can open says so', (tester) async {
      final repo = FakeBillingRepository();
      await open(tester, repo);
      canOpen = false;
      await tester.tap(find.text('Payer'));
      await tester.pumpAndSettle();
      expect(
        find.text("Impossible d'ouvrir le lien de paiement."),
        findsOneWidget,
      );
    });

    testWidgets(
      'D17: shows amount, reference, number; "J\'ai payé" sends the note',
      (tester) async {
        final repo = FakeBillingRepository();
        await open(tester, repo);
        await tester.tap(find.text('D17'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Payer'));
        await tester.pumpAndSettle();
        expect(repo.created, [('standard', PaymentMethod.d17)]);
        expect(repo.linkCalls, isEmpty);
        expect(find.text('Instructions de paiement'), findsOneWidget);
        expect(find.text('20 TND'), findsOneWidget);
        expect(find.text('KH-ABC123'), findsOneWidget);
        expect(find.text('22123456'), findsOneWidget);
        expect(
          find.text('08006000000123456789'),
          findsNothing,
          reason: 'D17 shows no RIB',
        );
        expect(
          find.textContaining('motif du virement ou la note D17'),
          findsOneWidget,
        );

        await tester.tap(find.text("J'ai payé"));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), ' envoye le 12 ');
        await tester.tap(find.text('Envoyer'));
        await tester.pumpAndSettle();
        expect(repo.sent, [('o1', 'envoye le 12')]);
        expect(find.text('À confirmer'), findsOneWidget);
        expect(find.textContaining('Notre équipe vérifie'), findsOneWidget);
        expect(find.text("J'ai payé"), findsNothing);
        expect(find.text('Annuler la commande'), findsOneWidget);
      },
    );

    testWidgets('the note dialog can be closed without sending', (
      tester,
    ) async {
      final repo = FakeBillingRepository();
      await open(tester, repo);
      await tester.tap(find.text('D17'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("J'ai payé"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(repo.sent, isEmpty);
      expect(find.text("J'ai payé"), findsOneWidget);
    });

    testWidgets(
      'bank transfer: shows the RIB and holder; cancelling goes back',
      (tester) async {
        final repo = FakeBillingRepository();
        await open(tester, repo);
        await tester.tap(find.text('Virement bancaire'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Payer'));
        await tester.pumpAndSettle();
        expect(repo.created, [('standard', PaymentMethod.bankTransfer)]);
        expect(find.text('08006000000123456789'), findsOneWidget);
        expect(find.text('BIAT'), findsOneWidget);
        expect(find.text('Khidma SARL'), findsOneWidget);
        expect(find.text('22123456'), findsNothing);
        await tester.tap(find.text('Annuler la commande'));
        await tester.pumpAndSettle();
        expect(repo.cancelled, ['o1']);
        expect(find.text('Instructions de paiement'), findsNothing);
        expect(
          find.text('Annulé'),
          findsOneWidget,
          reason: 'the list shows the cancelled order',
        );
      },
    );

    testWidgets('payment details not set up yet: says so, can still cancel', (
      tester,
    ) async {
      final repo = FakeBillingRepository()
        ..paymentInstructions = const PaymentInstructions();
      await open(tester, repo);
      await tester.tap(find.text('Virement bancaire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payer'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Les coordonnées de paiement ne sont pas encore disponibles.',
        ),
        findsOneWidget,
      );
      expect(find.text('Annuler la commande'), findsOneWidget);
    });

    testWidgets('the reference is copied to the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(tester, FakeBillingRepository());
      await tester.tap(find.text('D17'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Copier: Référence'));
      await tester.pumpAndSettle();
      expect(copied, 'KH-ABC123');
      expect(find.text('Copié'), findsOneWidget);
    });

    testWidgets(
      'an open manual order can be reopened from the list; a paid one cannot',
      (tester) async {
        final repo = FakeBillingRepository(
          orders: [
            order('OPEN01', PaymentMethod.bankTransfer, OrderStatus.pending),
            order('PAID01', PaymentMethod.d17, OrderStatus.paid),
          ],
        );
        await open(tester, repo);
        await tester.tap(find.text('KH-PAID01 · 20 TND'));
        await tester.pumpAndSettle();
        expect(find.text('Instructions de paiement'), findsNothing);
        await tester.tap(find.text('KH-OPEN01 · 20 TND'));
        await tester.pumpAndSettle();
        expect(find.text('Instructions de paiement'), findsOneWidget);
        expect(find.text('KH-OPEN01'), findsOneWidget);
      },
    );

    testWidgets('not a professional: shows the become-a-professional state', (
      tester,
    ) async {
      final repo = FakeBillingRepository()
        ..failCreate = BillingFailure.forbidden;
      await open(tester, repo);
      await tester.tap(find.text('Payer'));
      await tester.pumpAndSettle();
      expect(find.text("Devenez professionnel d'abord"), findsOneWidget);
      expect(find.text('Créer mon profil'), findsOneWidget);
      expect(find.text('Payer'), findsNothing);
    });

    testWidgets('too many orders says to try tomorrow', (tester) async {
      final repo = FakeBillingRepository()
        ..failCreate = BillingFailure.rateLimited;
      await open(tester, repo);
      await tester.tap(find.text('Payer'));
      await tester.pumpAndSettle();
      expect(
        find.text("Trop de commandes aujourd'hui. Réessayez demain."),
        findsOneWidget,
      );
    });

    testWidgets('no connection says so and the screen stays usable', (
      tester,
    ) async {
      final repo = FakeBillingRepository();
      await open(tester, repo);
      repo.failNext = BillingFailure.network;
      await tester.tap(find.text('Payer'));
      await tester.pumpAndSettle();
      expect(find.text('Pas de connexion. Réessayez.'), findsOneWidget);
      expect(find.text('Payer'), findsOneWidget);
    });

    testWidgets('payments not configured: shows an error with retry', (
      tester,
    ) async {
      final repo = FakeBillingRepository()
        ..failPlans = BillingFailure.notConfigured;
      await open(tester, repo);
      expect(
        find.text('Les paiements ne sont pas encore disponibles.'),
        findsOneWidget,
      );
      repo.failPlans = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Payer'), findsOneWidget);
    });

    testWidgets('a double tap sends one order', (tester) async {
      final repo = FakeBillingRepository();
      await open(tester, repo);
      repo.gate = Completer<void>();
      await tester.tap(find.text('Payer'));
      await tester.pump();
      await tester.tap(find.text('Payer'));
      await tester.pump();
      repo.gate!.complete();
      repo.gate = null;
      await tester.pumpAndSettle();
      expect(repo.created.length, 1);
    });

    for (final lang in ['fr', 'ar', 'en']) {
      testWidgets('2x text on a 320 px phone does not overflow ($lang)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320 * 2, 568 * 2);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final repo = FakeBillingRepository(
          subscription: _active(),
          orders: [
            order(
              'OPEN01',
              PaymentMethod.bankTransfer,
              OrderStatus.awaitingConfirmation,
              amount: 25500,
            ),
            order('PAID01', PaymentMethod.flouci, OrderStatus.paid),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              billingRepositoryProvider.overrideWithValue(repo),
              currentUserProvider.overrideWithValue(_ali),
            ],
            child: bareApp(const BillingScreen(), lang: lang),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$lang screen');
        // Scroll to the end: every row is built and laid out.
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$lang end');
        // And the instructions of the open order.
        await tester.scrollUntilVisible(
          find.textContaining('KH-OPEN01'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.textContaining('KH-OPEN01'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('KH-OPEN01'));
        await tester.pumpAndSettle();
        expect(find.byType(PaymentInstructionsScreen), findsOneWidget);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$lang instructions');
        await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$lang instructions end',
        );
      });
    }

    testWidgets('Arabic: right to left, Arabic texts, Western digits', (
      tester,
    ) async {
      await open(
        tester,
        FakeBillingRepository(subscription: _active()),
        lang: 'ar',
      );
      expect(screenDirection(tester), TextDirection.rtl);
      expect(find.text('الاشتراك'), findsOneWidget);
      expect(find.text('اختر الباقة'), findsOneWidget);
      expect(find.text('20 TND'), findsOneWidget);
      expect(find.text('ادفع'), findsOneWidget);
      await tester.tap(find.text('تحويل بنكي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ادفع'));
      await tester.pumpAndSettle();
      expect(find.text('تعليمات الدفع'), findsOneWidget);
      expect(find.text('08006000000123456789'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
