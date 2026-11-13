import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../portfolio/data/supabase_portfolio_repository.dart'
    show randomFileId;
import '../../portfolio/domain/portfolio_domain.dart' show PreparedPhoto;
import '../domain/billing_domain.dart';

const paymentProofsBucket = 'payment-proofs';

/// Maps Supabase errors to a [BillingFailure]. Server messages are read to
/// tell known tags apart and are never forwarded.
BillingFailure mapBillingException(Object error) {
  if (error is BillingError) return error.failure;
  if (error is TimeoutException) return BillingFailure.network;
  if (error is sb.FunctionException) {
    return switch (error.status) {
      503 => BillingFailure.flouciUnavailable,
      401 || 403 => BillingFailure.notSignedIn,
      404 => BillingFailure.notFound,
      _ => BillingFailure.unknown,
    };
  }
  if (error is sb.FunctionsFetchException) return BillingFailure.network;
  if (error is sb.PostgrestException) {
    switch (error.code) {
      case '28000':
      case 'PGRST301':
      case 'PGRST302':
        return BillingFailure.notSignedIn;
      case '42501':
        return BillingFailure.forbidden;
      case 'P0002':
        return BillingFailure.notFound;
      case 'P0001':
        if (error.message.contains('rate_limited')) {
          return BillingFailure.rateLimited;
        }
        if (error.message.contains('limit_reached')) {
          return BillingFailure.limitReached;
        }
        return BillingFailure.invalid;
      case '23514':
      case '22001':
        return BillingFailure.invalid;
    }
    return BillingFailure.unknown;
  }
  final name = error.runtimeType.toString();
  if (name.contains('ClientException') || name.contains('SocketException')) {
    return BillingFailure.network;
  }
  return BillingFailure.unknown;
}

/// Plans, orders and the subscription of the signed-in professional. Row Level
/// Security and the `*_payment_*` functions decide what the caller may do.
class SupabaseBillingRepository implements BillingRepository {
  SupabaseBillingRepository(
    this._client, {
    String? Function()? userId,
    this._random,
  }) : _userId = userId ?? (() => _client.auth.currentUser?.id);

  final sb.SupabaseClient _client;
  final String? Function() _userId;
  final Random? _random;

  @override
  Future<void> attachProof(String orderId, PreparedPhoto photo) =>
      _guard(() async {
        final uid = _userId();
        if (uid == null) throw const BillingError(BillingFailure.notSignedIn);
        final bucket = _client.storage.from(paymentProofsBucket);
        // The name is chosen first, so a lost answer can still be cleaned up.
        final path = '$uid/${randomFileId(_random)}.jpg';
        try {
          await bucket.uploadBinary(
            path,
            photo.bytes,
            fileOptions: const sb.FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
          await _client.rpc(
            'attach_payment_proof',
            params: {'p_order': orderId, 'p_path': path},
          );
        } catch (_) {
          // Not attached: do not leave the receipt behind. An attached file
          // cannot be removed (the database refuses), which is right.
          try {
            await bucket.remove([path]);
          } catch (_) {}
          rethrow;
        }
      });

  @override
  Future<int> proofCount(String orderId) => _guard(() async {
    final n = await _client.rpc(
      'my_payment_proof_count',
      params: {'p_order': orderId},
    );
    return n is num ? n.toInt() : 0;
  });

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw BillingError(mapBillingException(e));
    }
  }

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static String _str(Object? v) => v is String ? v : '';

  static int _int(Object? v) => v is num ? v.toInt() : 0;

  PaymentOrder _order(Map<String, dynamic> r, {String? planCode}) =>
      PaymentOrder(
        id: _str(r['id']),
        planCode: planCode ?? _str(r['plan_code']),
        amountMillimes: _int(r['amount_millimes']),
        method: PaymentMethod.fromWire(r['method']) ?? PaymentMethod.flouci,
        status: OrderStatus.fromWire(r['status']),
        reference: _str(r['reference']),
        payerNote: r['payer_note'] as String?,
        createdAt: _date(r['created_at']),
        paidAt: _date(r['paid_at']),
        adminNote: r['admin_note'] as String?,
      );

  @override
  Future<List<SubscriptionPlan>> plans() => _guard(() async {
    final rows = await _client
        .from('subscription_plans')
        .select('code, name_fr, name_ar, name_en, amount_millimes, period_days')
        .order('sort_order', ascending: true);
    return [
      for (final r in rows)
        SubscriptionPlan(
          code: _str(r['code']),
          nameFr: _str(r['name_fr']),
          nameAr: _str(r['name_ar']),
          nameEn: _str(r['name_en']),
          amountMillimes: _int(r['amount_millimes']),
          periodDays: _int(r['period_days']),
        ),
    ];
  });

  @override
  Future<MySubscription?> mySubscription() => _guard(() async {
    final rows = await _client.rpc('my_subscription') as List;
    if (rows.isEmpty) return null;
    final r = rows.first as Map<String, dynamic>;
    final end = _date(r['current_period_end']);
    if (end == null) return null;
    return MySubscription(
      planCode: _str(r['plan_code']),
      state: switch (r['status']) {
        'active' => SubscriptionState.active,
        'past_due' => SubscriptionState.pastDue,
        'cancelled' => SubscriptionState.cancelled,
        _ => SubscriptionState.expired,
      },
      currentPeriodEnd: end,
      daysLeft: _int(r['days_left']),
    );
  });

  @override
  Future<List<PaymentOrder>> myOrders() => _guard(() async {
    final rows = await _client
        .from('payment_orders')
        .select(
          'id, plan_code, amount_millimes, method, status, reference, '
          'payer_note, created_at, paid_at, admin_note',
        )
        .order('created_at', ascending: false)
        .limit(50);
    return [for (final r in rows) _order(r)];
  });

  @override
  Future<PaymentOrder> createOrder(String planCode, PaymentMethod method) =>
      _guard(() async {
        final rows = await _client.rpc(
          'create_payment_order',
          params: {'p_plan': planCode, 'p_method': method.wire},
        ) as List;
        if (rows.isEmpty) throw const BillingError(BillingFailure.unknown);
        return _order(rows.first as Map<String, dynamic>, planCode: planCode);
      });

  @override
  Future<Uri> flouciLink(String orderId) => _guard(() async {
    final res = await _client.functions.invoke(
      'flouci-payments/create',
      body: {'order_id': orderId},
    );
    final data = res.data;
    final link = data is Map ? data['link'] : null;
    final uri = link is String ? Uri.tryParse(link) : null;
    // Only a secure web link is ever opened.
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const BillingError(BillingFailure.unknown);
    }
    return uri;
  });

  @override
  Future<void> markSent(String orderId, String? note) => _guard(() async {
    final n = note?.trim();
    await _client.rpc(
      'mark_payment_sent',
      params: {'p_order': orderId, 'p_note': n == null || n.isEmpty ? null : n},
    );
  });

  @override
  Future<void> cancel(String orderId) => _guard(() async {
    await _client.rpc('cancel_payment_order', params: {'p_order': orderId});
  });

  @override
  Future<PaymentInstructions> instructions() => _guard(() async {
    final data = await _client.rpc('get_payment_instructions');
    if (data is! Map) return const PaymentInstructions();
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    final bank = data['bank'];
    final d17 = data['d17'];
    final rib = bank is Map ? text(bank['rib']) : null;
    final number = d17 is Map ? text(d17['number']) : null;
    return PaymentInstructions(
      bank: rib == null
          ? null
          : BankDetails(
              name: text((bank as Map)['name']),
              holder: text(bank['holder']),
              rib: rib,
            ),
      d17: number == null
          ? null
          : D17Details(number: number, holder: text((d17 as Map)['holder'])),
    );
  });
}
