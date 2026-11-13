import 'dart:async';

import 'package:khidma/features/billing/domain/billing_domain.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';

const standardPlan = SubscriptionPlan(
  code: 'standard',
  nameFr: 'Standard',
  nameAr: 'عادي',
  nameEn: 'Standard',
  amountMillimes: 20000,
  periodDays: 30,
);

const plusPlan = SubscriptionPlan(
  code: 'plus',
  nameFr: 'Plus',
  nameAr: 'بلس',
  nameEn: 'Plus',
  amountMillimes: 30000,
  periodDays: 30,
);

/// In-memory billing with call recording and failure hooks.
class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository({
    this.planList = const [standardPlan, plusPlan],
    this.subscription,
    List<PaymentOrder>? orders,
    this.paymentInstructions = const PaymentInstructions(
      bank: BankDetails(
        name: 'BIAT',
        holder: 'Khidma SARL',
        rib: '08006000000123456789',
      ),
      d17: D17Details(number: '22123456', holder: 'Khidma'),
    ),
  }) : orders = orders ?? [];

  List<SubscriptionPlan> planList;
  MySubscription? subscription;
  final List<PaymentOrder> orders;
  PaymentInstructions paymentInstructions;

  BillingFailure? failNext;
  BillingFailure? failCreate;
  BillingFailure? failLink;
  BillingFailure? failPlans;
  Completer<void>? gate;

  final created = <(String, PaymentMethod)>[];
  final linkCalls = <String>[];
  final sent = <(String, String?)>[];
  final cancelled = <String>[];
  final proofs = <String, int>{};
  Uri link = Uri.parse('https://pay.flouci.example/abc');

  Future<void> _pre() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw BillingError(f);
    }
  }

  @override
  Future<List<SubscriptionPlan>> plans() async {
    await _pre();
    final f = failPlans;
    if (f != null) throw BillingError(f);
    return planList;
  }

  @override
  Future<MySubscription?> mySubscription() async => subscription;

  @override
  Future<List<PaymentOrder>> myOrders() async => List.of(orders);

  @override
  Future<PaymentOrder> createOrder(
    String planCode,
    PaymentMethod method,
  ) async {
    await _pre();
    created.add((planCode, method));
    final f = failCreate;
    if (f != null) throw BillingError(f);
    final plan = planList.firstWhere((p) => p.code == planCode);
    final existing = orders.where(
      (o) => o.method == method && o.planCode == planCode && o.status.isOpen,
    );
    if (existing.isNotEmpty) return existing.first;
    final order = PaymentOrder(
      id: 'o${orders.length + 1}',
      planCode: planCode,
      amountMillimes: plan.amountMillimes,
      method: method,
      status: OrderStatus.pending,
      reference: 'KH-ABC12${orders.length + 3}',
      createdAt: DateTime(2026, 11, 12),
    );
    orders.insert(0, order);
    return order;
  }

  @override
  Future<Uri> flouciLink(String orderId) async {
    linkCalls.add(orderId);
    final f = failLink;
    if (f != null) throw BillingError(f);
    return link;
  }

  void _replace(String id, OrderStatus status, {String? note}) {
    final i = orders.indexWhere((o) => o.id == id);
    final o = orders[i];
    orders[i] = PaymentOrder(
      id: o.id,
      planCode: o.planCode,
      amountMillimes: o.amountMillimes,
      method: o.method,
      status: status,
      reference: o.reference,
      payerNote: note ?? o.payerNote,
      createdAt: o.createdAt,
    );
  }

  @override
  Future<void> markSent(String orderId, String? note) async {
    await _pre();
    sent.add((orderId, note));
    _replace(orderId, OrderStatus.awaitingConfirmation, note: note);
  }

  @override
  Future<void> cancel(String orderId) async {
    await _pre();
    cancelled.add(orderId);
    _replace(orderId, OrderStatus.cancelled);
  }

  @override
  Future<PaymentInstructions> instructions() async => paymentInstructions;

  @override
  Future<void> attachProof(String orderId, PreparedPhoto photo) async {
    await _pre();
    final n = proofs[orderId] ?? 0;
    if (n >= maxPaymentProofs) {
      throw const BillingError(BillingFailure.limitReached);
    }
    proofs[orderId] = n + 1;
  }

  @override
  Future<int> proofCount(String orderId) async => proofs[orderId] ?? 0;
}
