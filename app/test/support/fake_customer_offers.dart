import 'dart:async';

import 'package:khidma/features/offers/domain/offers_domain.dart';
import 'package:khidma/features/requests/domain/customer_offers_domain.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';

/// In-memory customer side of offers, enforcing the database rules that matter
/// to the screen (one winner, only pending offers move).
class FakeCustomerOffersRepository implements CustomerOffersRepository {
  FakeCustomerOffersRepository({List<ReceivedOffer>? offers, this.bookingValue})
    : offerList = [...?offers];

  final List<ReceivedOffer> offerList;
  CustomerBooking? bookingValue;

  final calls = <String>[];
  RequestsFailure? failNext;
  bool failBooking = false;
  Completer<void>? gate;

  Future<void> _pre() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw RequestsError(f);
    }
  }

  @override
  Future<List<ReceivedOffer>> offers(String requestId) async => [...offerList];

  ReceivedOffer _with(ReceivedOffer o, OfferStatus s) => ReceivedOffer(
    id: o.id,
    professionalId: o.professionalId,
    priceTnd: o.priceTnd,
    status: s,
    createdAt: o.createdAt,
    message: o.message,
    estimatedDays: o.estimatedDays,
  );

  @override
  Future<String> accept(String offerId) async {
    calls.add('accept:$offerId');
    await _pre();
    for (var i = 0; i < offerList.length; i++) {
      final o = offerList[i];
      if (o.id == offerId) {
        offerList[i] = _with(o, OfferStatus.accepted);
        bookingValue = CustomerBooking(
          id: 'b1',
          professionalId: o.professionalId,
          priceTnd: o.priceTnd,
          status: BookingStatus.scheduled,
        );
      } else if (o.isPending) {
        offerList[i] = _with(o, OfferStatus.declined);
      }
    }
    return 'b1';
  }

  @override
  Future<void> decline(String offerId) async {
    calls.add('decline:$offerId');
    await _pre();
    final i = offerList.indexWhere((o) => o.id == offerId);
    offerList[i] = _with(offerList[i], OfferStatus.declined);
  }

  @override
  Future<CustomerBooking?> booking(String requestId) async {
    if (failBooking) throw const RequestsError(RequestsFailure.network);
    return bookingValue;
  }

  void _step(BookingStatus s) {
    final b = bookingValue!;
    bookingValue = CustomerBooking(
      id: b.id,
      professionalId: b.professionalId,
      priceTnd: b.priceTnd,
      status: s,
    );
  }

  @override
  Future<void> confirmCompleted(String bookingId) async {
    calls.add('confirm:$bookingId');
    await _pre();
    _step(BookingStatus.completed);
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    calls.add('cancel:$bookingId');
    await _pre();
    _step(BookingStatus.cancelled);
  }
}

ReceivedOffer sampleOffer({
  String id = 'a',
  String pro = 'demo-01',
  double price = 150,
  OfferStatus status = OfferStatus.pending,
  int? days,
  String? message,
}) => ReceivedOffer(
  id: id,
  professionalId: pro,
  priceTnd: price,
  status: status,
  createdAt: DateTime(2026, 11, 10),
  estimatedDays: days,
  message: message,
);
