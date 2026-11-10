import 'dart:async';
import 'dart:typed_data';

import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';

/// In-memory portfolio with failure hooks and a record of what was uploaded.
class FakePortfolioRepository implements PortfolioRepository {
  FakePortfolioRepository([List<PortfolioItem>? items]) : items = [...?items];

  final List<PortfolioItem> items;
  final uploads = <PreparedPhoto>[];
  final removed = <String>[];
  PortfolioFailure? failNext;
  Completer<void>? gate;
  int _n = 0;

  @override
  Future<List<PortfolioItem>> list(String professionalId) async => [...items];

  @override
  Future<PortfolioItem> add(PreparedPhoto photo) async {
    uploads.add(photo);
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw PortfolioError(f);
    }
    if (items.length >= maxPortfolioPhotos) {
      throw const PortfolioError(PortfolioFailure.limitReached);
    }
    final item = PortfolioItem(
      id: 'i${_n++}',
      path: 'u1/f$_n.jpg',
      url: 'https://example.invalid/f$_n.jpg',
    );
    items.add(item);
    return item;
  }

  @override
  Future<void> remove(PortfolioItem item) async {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw PortfolioError(f);
    }
    removed.add(item.id);
    items.removeWhere((x) => x.id == item.id);
  }
}

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker([this.next]);
  Uint8List? next;
  int picks = 0;

  @override
  Future<Uint8List?> pick() async {
    picks++;
    return next;
  }
}
