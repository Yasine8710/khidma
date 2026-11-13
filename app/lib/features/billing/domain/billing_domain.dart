import '../../portfolio/domain/portfolio_domain.dart' show PreparedPhoto;

/// Why a billing call failed. Never carries server text.
enum BillingFailure {
  network,
  notSignedIn,

  /// Not a professional yet: there is nothing to subscribe.
  forbidden,
  rateLimited,
  invalid,
  notFound,
  notConfigured,

  /// The payment link could not be opened (no browser handled it).
  cannotOpen,

  /// The Flouci function answered "not configured" (503).
  flouciUnavailable,

  /// Already 3 proofs on this order.
  limitReached,
  busy,
  unknown,
}

/// Most proofs one order can carry (also enforced by the database).
const maxPaymentProofs = 3;

class BillingError implements Exception {
  const BillingError(this.failure);
  final BillingFailure failure;
  @override
  String toString() => 'BillingError($failure)';
}

enum PaymentMethod {
  flouci('flouci'),
  d17('d17'),
  bankTransfer('bank_transfer');

  const PaymentMethod(this.wire);
  final String wire;

  /// Paid by hand: the person writes the reference and an admin confirms.
  bool get isManual => this != flouci;

  static PaymentMethod? fromWire(Object? v) {
    for (final m in values) {
      if (m.wire == v) return m;
    }
    return null;
  }
}

enum OrderStatus {
  pending('pending'),
  awaitingConfirmation('awaiting_confirmation'),
  paid('paid'),
  failed('failed'),
  cancelled('cancelled'),
  rejected('rejected');

  const OrderStatus(this.wire);
  final String wire;

  /// Still open: the person can pay, say they paid, or cancel.
  bool get isOpen => this == pending || this == awaitingConfirmation;

  static OrderStatus fromWire(Object? v) {
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return pending;
  }
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.code,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    required this.amountMillimes,
    required this.periodDays,
  });

  final String code;
  final String nameFr;
  final String nameAr;
  final String nameEn;
  final int amountMillimes;
  final int periodDays;

  String name(String languageCode) => switch (languageCode) {
    'ar' => nameAr,
    'en' => nameEn,
    _ => nameFr,
  };
}

class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.planCode,
    required this.amountMillimes,
    required this.method,
    required this.status,
    required this.reference,
    this.payerNote,
    this.createdAt,
    this.paidAt,
    this.adminNote,
  });

  final String id;
  final String planCode;
  final int amountMillimes;
  final PaymentMethod method;
  final OrderStatus status;

  /// "KH-XXXXXX": what the person writes in the transfer motif or D17 note.
  final String reference;
  final String? payerNote;
  final DateTime? createdAt;
  final DateTime? paidAt;

  /// Why an admin refused the payment (only for [OrderStatus.rejected]).
  final String? adminNote;

  /// D17 and bank transfers are checked by hand, so they take proofs.
  bool get isManual => method != PaymentMethod.flouci;
}

enum SubscriptionState { active, pastDue, expired, cancelled }

/// Whether customers can see the professional right now. Only meaningful when
/// [enforced]: otherwise everyone is listed whatever they paid.
class ListingStatus {
  const ListingStatus({
    required this.enforced,
    required this.listed,
    this.trialEndsAt,
    this.paidUntil,
  });

  final bool enforced;
  final bool listed;
  final DateTime? trialEndsAt;
  final DateTime? paidUntil;

  /// Hidden from search, profile pages and new offers until paid.
  bool get hidden => enforced && !listed;

  /// Listed thanks to the free trial (nothing paid yet).
  bool get onTrial => enforced && listed && paidUntil == null;
}

class MySubscription {
  const MySubscription({
    required this.planCode,
    required this.state,
    required this.currentPeriodEnd,
    required this.daysLeft,
  });

  final String planCode;
  final SubscriptionState state;
  final DateTime currentPeriodEnd;
  final int daysLeft;
}

class BankDetails {
  const BankDetails({this.name, this.holder, required this.rib});
  final String? name;
  final String? holder;
  final String rib;
}

class D17Details {
  const D17Details({required this.number, this.holder});
  final String number;
  final String? holder;
}

/// Where manual payments go. A null part is not set up yet.
class PaymentInstructions {
  const PaymentInstructions({this.bank, this.d17});
  final BankDetails? bank;
  final D17Details? d17;
}

/// Millimes as TND with up to 3 decimals, trailing zeros trimmed: 20000 ->
/// "20 TND", 25500 -> "25,5 TND" (fr, ar) or "25.5 TND" (en). Western digits.
String formatTndAmount(int millimes, {String languageCode = 'fr'}) {
  final whole = millimes ~/ 1000;
  final frac = (millimes % 1000).toString().padLeft(3, '0');
  final trimmed = frac.replaceFirst(RegExp(r'0+$'), '');
  final sep = languageCode == 'en' ? '.' : ',';
  final number = trimmed.isEmpty ? '$whole' : '$whole$sep$trimmed';
  return '$number TND';
}

abstract interface class BillingRepository {
  Future<List<SubscriptionPlan>> plans();

  /// Null when the person never subscribed.
  Future<MySubscription?> mySubscription();

  Future<List<PaymentOrder>> myOrders();

  /// The same open order comes back when asked again.
  Future<PaymentOrder> createOrder(String planCode, PaymentMethod method);

  /// Asks the Flouci function for the payment link of [orderId].
  Future<Uri> flouciLink(String orderId);

  Future<void> markSent(String orderId, String? note);

  Future<void> cancel(String orderId);

  Future<PaymentInstructions> instructions();

  /// Uploads a receipt photo and attaches it to the caller's unpaid manual
  /// order. The file is removed again when attaching fails.
  Future<void> attachProof(String orderId, PreparedPhoto photo);

  Future<int> proofCount(String orderId);

  Future<ListingStatus?> listingStatus();
}

/// Used when no backend is configured: every call fails honestly.
class NotConfiguredBillingRepository implements BillingRepository {
  const NotConfiguredBillingRepository();
  Never _fail() => throw const BillingError(BillingFailure.notConfigured);
  @override
  Future<List<SubscriptionPlan>> plans() async => _fail();
  @override
  Future<MySubscription?> mySubscription() async => _fail();
  @override
  Future<List<PaymentOrder>> myOrders() async => _fail();
  @override
  Future<PaymentOrder> createOrder(
    String planCode,
    PaymentMethod method,
  ) async => _fail();
  @override
  Future<Uri> flouciLink(String orderId) async => _fail();
  @override
  Future<void> markSent(String orderId, String? note) async => _fail();
  @override
  Future<void> cancel(String orderId) async => _fail();
  @override
  Future<PaymentInstructions> instructions() async => _fail();
  @override
  Future<void> attachProof(String orderId, PreparedPhoto photo) async =>
      _fail();
  @override
  Future<int> proofCount(String orderId) async => _fail();
  @override
  Future<ListingStatus?> listingStatus() async => null;
}
