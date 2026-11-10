import '../../../core/format/search_text.dart';
import '../domain/marketplace_domain.dart';
import 'demo_data.dart';

/// In-memory marketplace for development. It implements the same search rules
/// as the database function `search_professionals` (filters, accent- and
/// Arabic-variant-insensitive text, distance, sort, paging); tests hold the
/// two to the same behavior.
class DemoMarketplaceRepository implements MarketplaceRepository {
  DemoMarketplaceRepository({List<ProfessionalSummary>? professionals})
    : _pros = professionals ?? buildDemoProfessionals();

  final List<ProfessionalSummary> _pros;

  @override
  bool get isDemo => true;

  @override
  Future<List<ServiceCategory>> categories() async => demoCategories;

  @override
  Future<List<Governorate>> governorates() async => demoGovernorates;

  @override
  Future<List<City>> cities({int? governorateId}) async => [
    for (final c in demoCities)
      if (governorateId == null || c.governorateId == governorateId) c,
  ];

  @override
  Future<List<ProfessionalSummary>> search(SearchQuery q) async {
    final text = normalizeSearch(q.text).trim();
    final located = q.hasPosition;

    ProfessionalSummary withDistance(ProfessionalSummary p) {
      if (!located || p.latitude == null || p.longitude == null) return p;
      return ProfessionalSummary(
        id: p.id,
        name: p.name,
        categoryId: p.categoryId,
        description: p.description,
        yearsExperience: p.yearsExperience,
        governorateId: p.governorateId,
        cityId: p.cityId,
        neighborhoodId: p.neighborhoodId,
        latitude: p.latitude,
        longitude: p.longitude,
        availability: p.availability,
        verification: p.verification,
        rating: p.rating,
        reviewCount: p.reviewCount,
        distanceKm: distanceKm(
          q.latitude!,
          q.longitude!,
          p.latitude!,
          p.longitude!,
        ),
      );
    }

    final matches = <ProfessionalSummary>[
      for (final p in _pros)
        if (_matches(withDistance(p), q, text)) withDistance(p),
    ];

    int byRating(ProfessionalSummary a, ProfessionalSummary b) {
      final r = b.rating.compareTo(a.rating);
      return r != 0 ? r : b.reviewCount.compareTo(a.reviewCount);
    }

    matches.sort((a, b) {
      int primary = 0;
      switch (q.sort) {
        case ProfessionalSort.nearest:
          final da = a.distanceKm;
          final db = b.distanceKm;
          if (da == null && db == null) {
            primary = 0;
          } else if (da == null) {
            primary = 1; // unknown positions last
          } else if (db == null) {
            primary = -1;
          } else {
            primary = da.compareTo(db);
          }
        case ProfessionalSort.reviews:
          primary = b.reviewCount.compareTo(a.reviewCount);
        case ProfessionalSort.rating:
        case ProfessionalSort.recent:
          primary = 0; // no update timestamps in demo data: rating order
      }
      if (primary != 0) return primary;
      final r = byRating(a, b);
      return r != 0 ? r : a.id.compareTo(b.id);
    });

    final limit = q.limit.clamp(1, 50);
    final offset = q.offset < 0 ? 0 : q.offset;
    return matches.skip(offset).take(limit).toList();
  }

  bool _matches(ProfessionalSummary p, SearchQuery q, String text) {
    if (q.availableOnly && p.availability != Availability.available) {
      return false;
    }
    if (q.minRating != null && p.rating < q.minRating!) return false;
    if (q.categoryId != null && p.categoryId != q.categoryId) return false;
    if (q.governorateId != null && p.governorateId != q.governorateId) {
      return false;
    }
    if (q.cityId != null && p.cityId != q.cityId) return false;
    if (q.hasPosition && q.radiusKm != null) {
      final d = p.distanceKm;
      if (d == null || d > q.radiusKm!) return false;
    }
    if (text.isEmpty) return true;
    return _haystack(p).contains(text);
  }

  /// Everything a text search looks at: name, description, profession and
  /// place names in all languages.
  String _haystack(ProfessionalSummary p) {
    final cat = demoCategories.firstWhere((c) => c.id == p.categoryId);
    final gov = demoGovernorates.where((g) => g.id == p.governorateId);
    final city = demoCities.where((c) => c.id == p.cityId);
    return normalizeSearch(
      [
        p.name,
        p.description,
        cat.nameFr,
        cat.nameAr,
        cat.nameEn,
        cat.slug,
        for (final g in gov) '${g.nameFr} ${g.nameAr} ${g.nameEn}',
        for (final c in city) '${c.nameFr} ${c.nameAr} ${c.nameEn}',
      ].join(' | '),
    );
  }
}
