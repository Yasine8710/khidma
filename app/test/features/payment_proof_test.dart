import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/features/auth/application/auth_providers.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/billing/application/billing_providers.dart';
import 'package:khidma/features/billing/domain/billing_domain.dart';
import 'package:khidma/features/billing/presentation/payment_instructions_screen.dart';
import 'package:khidma/features/portfolio/application/portfolio_providers.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';

import '../support/fake_billing.dart';
import '../support/fake_portfolio.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

PaymentOrder _order({
  PaymentMethod method = PaymentMethod.bankTransfer,
  OrderStatus status = OrderStatus.awaitingConfirmation,
  String? note,
}) => PaymentOrder(
  id: 'o1',
  planCode: 'standard',
  amountMillimes: 20000,
  method: method,
  status: status,
  reference: 'KH-ABC123',
  adminNote: note,
);

void main() {
  setUpAll(loadAppFonts);

  Future<(FakeBillingRepository, FakePhotoPicker)> open(
    WidgetTester tester,
    PaymentOrder order, {
    Uint8List? pick,
  }) async {
    final repo = FakeBillingRepository(orders: [order]);
    final picker = FakePhotoPicker(pick);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingRepositoryProvider.overrideWithValue(repo),
          currentUserProvider.overrideWithValue(_ali),
          photoPickerProvider.overrideWithValue(picker),
          photoPreparerProvider.overrideWithValue(
            (b) async => PreparedPhoto(bytes: b, width: 10, height: 10),
          ),
        ],
        child: bareApp(PaymentInstructionsScreen(order: order)),
      ),
    );
    await tester.pumpAndSettle();
    return (repo, picker);
  }

  testWidgets('a manual order takes up to 3 receipts', (tester) async {
    final (repo, picker) = await open(tester, _order(), pick: Uint8List(8));
    expect(find.textContaining('une photo du reçu'), findsOneWidget);
    for (var i = 1; i <= 3; i++) {
      await tester.tap(find.text('Joindre un justificatif'));
      await tester.pumpAndSettle();
      expect(find.text('$i sur 3 justificatifs joints.'), findsOneWidget);
    }
    expect(repo.proofs['o1'], 3);
    final button = find.ancestor(
      of: find.text('Joindre un justificatif'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    expect(picker.picks, 3);
  });

  testWidgets('cancelling the picker attaches nothing', (tester) async {
    final (repo, picker) = await open(tester, _order());
    await tester.tap(find.text('Joindre un justificatif'));
    await tester.pumpAndSettle();
    expect(picker.picks, 1);
    expect(repo.proofs, isEmpty);
  });

  testWidgets('Flouci orders and closed orders have no receipt button', (
    tester,
  ) async {
    await open(
      tester,
      _order(method: PaymentMethod.flouci, status: OrderStatus.pending),
    );
    expect(find.text('Joindre un justificatif'), findsNothing);
  });

  testWidgets('a refused payment shows the admin note', (tester) async {
    await open(
      tester,
      _order(status: OrderStatus.rejected, note: 'Montant différent'),
    );
    expect(find.text('Paiement refusé : Montant différent'), findsOneWidget);
    expect(find.text('Joindre un justificatif'), findsNothing);
  });
}
