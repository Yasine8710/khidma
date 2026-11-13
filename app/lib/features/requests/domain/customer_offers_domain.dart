import '../../offers/domain/offers_domain.dart';
import 'requests_domain.dart';

/// An offer on the customer's own request.
class ReceivedOffer {
  const ReceivedOffer({
    required this.id,
    required this.professionalId,
    required this.priceTnd,
    required this.status,
    required this.createdAt,
    this.message,
    this.estimatedDays,
    this.revisions,
  });

  final String id;
  final String professionalId;
  final double priceTnd;
  final OfferStatus status;
  final DateTime createdAt;
  final String? message;
  final int? estimatedDays;

  /// Revisions included (remote projects only).
  final int? revisions;

  bool get isPending => status == OfferStatus.pending;
}

/// The job created when an offer is accepted, as the customer sees it.
class CustomerBooking {
  const CustomerBooking({
    required this.id,
    required this.professionalId,
    required this.priceTnd,
    required this.status,
  });

  final String id;
  final String professionalId;
  final double priceTnd;
  final BookingStatus status;

  bool get canConfirm => status == BookingStatus.pendingConfirmation;
  bool get canCancel =>
      status == BookingStatus.scheduled || status == BookingStatus.inProgress;
}

/// The customer's side of the offers on a request.
abstract interface class CustomerOffersRepository {
  /// All offers on the request, newest first.
  Future<List<ReceivedOffer>> offers(String requestId);

  /// Accepts one offer: the request is awarded, the others are declined and a
  /// booking is created. Returns the booking id.
  Future<String> accept(String offerId);

  Future<void> decline(String offerId);

  /// The booking of an awarded request, if any.
  Future<CustomerBooking?> booking(String requestId);

  /// The customer confirms the work is done (only after the professional
  /// marked it done).
  Future<void> confirmCompleted(String bookingId);

  Future<void> cancelBooking(String bookingId);
}

class NotConfiguredCustomerOffersRepository
    implements CustomerOffersRepository {
  const NotConfiguredCustomerOffersRepository();
  Never _fail() => throw const RequestsError(RequestsFailure.notConfigured);
  @override
  Future<List<ReceivedOffer>> offers(String requestId) async => _fail();
  @override
  Future<String> accept(String offerId) async => _fail();
  @override
  Future<void> decline(String offerId) async => _fail();
  @override
  Future<CustomerBooking?> booking(String requestId) async => _fail();
  @override
  Future<void> confirmCompleted(String bookingId) async => _fail();
  @override
  Future<void> cancelBooking(String bookingId) async => _fail();
}
