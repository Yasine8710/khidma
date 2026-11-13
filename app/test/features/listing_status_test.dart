import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/features/auth/application/auth_providers.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/billing/application/billing_providers.dart';
import 'package:khidma/features/billing/domain/billing_domain.dart';
import 'package:khidma/features/billing/presentation/listing_status_card.dart';
import 'package:khidma/features/requests/data/supabase_requests_repository.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../support/fake_billing.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

void main() {
  setUpAll(loadAppFonts);

  Future<void> host(WidgetTester tester, ListingStatus? status) async {
    final repo = FakeBillingRepository()..listing = status;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingRepositoryProvider.overrideWithValue(repo),
          currentUserProvider.overrideWithValue(_ali),
        ],
        child: bareApp(
          const Scaffold(
            body: SingleChildScrollView(child: ListingStatusCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nothing when not enforced or when paid', (tester) async {
    await host(tester, const ListingStatus(enforced: false, listed: true));
    expect(find.byType(DecoratedBox), findsNothing);
    await host(
      tester,
      ListingStatus(
        enforced: true,
        listed: true,
        paidUntil: DateTime(2026, 12, 1),
      ),
    );
    expect(find.text('Profil masqué'), findsNothing);
    expect(find.text('Essai gratuit'), findsNothing);
    await host(tester, null);
    expect(find.text('Profil masqué'), findsNothing);
  });

  testWidgets('hidden: says why, that jobs go on, and leads to payment', (
    tester,
  ) async {
    await host(tester, const ListingStatus(enforced: true, listed: false));
    expect(find.text('Profil masqué'), findsOneWidget);
    expect(
      find.textContaining('Vos chantiers en cours continuent'),
      findsOneWidget,
    );
    expect(find.text('Régler mon abonnement'), findsOneWidget);
  });

  testWidgets('trial: shows its end date', (tester) async {
    await host(
      tester,
      ListingStatus(
        enforced: true,
        listed: true,
        trialEndsAt: DateTime(2026, 12, 13),
      ),
    );
    expect(find.text('Essai gratuit'), findsOneWidget);
    expect(find.textContaining('13'), findsOneWidget);
  });

  test('the offer refusal maps to its own failure', () {
    expect(
      mapRequestsException(
        const sb.PostgrestException(
          message: 'subscription_required',
          code: 'P0001',
        ),
      ),
      RequestsFailure.subscriptionRequired,
    );
  });
}
