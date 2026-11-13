import 'dart:ui' show Locale;

/// A value with a name in each supported language.
mixin Localized {
  String get nameFr;
  String get nameAr;
  String get nameEn;

  /// The name in [locale]'s language, falling back to French.
  String nameFor(Locale locale) => switch (locale.languageCode) {
    'ar' => nameAr,
    'en' => nameEn,
    _ => nameFr,
  };
}

class ServiceCategory with Localized {
  const ServiceCategory({
    required this.id,
    required this.slug,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    this.descriptionFr = '',
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.icon = 'build',
    this.sortOrder = 0,
  });

  final int id;
  final String slug;
  @override
  final String nameFr;
  @override
  final String nameAr;
  @override
  final String nameEn;
  final String descriptionFr;
  final String descriptionAr;
  final String descriptionEn;

  /// A Material icon name (see `categoryIcon`).
  final String icon;
  final int sortOrder;

  String descriptionFor(Locale locale) => switch (locale.languageCode) {
    'ar' => descriptionAr,
    'en' => descriptionEn,
    _ => descriptionFr,
  };
}

class Governorate with Localized {
  const Governorate({
    required this.id,
    required this.code,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
  });
  final int id;
  final String code;
  @override
  final String nameFr;
  @override
  final String nameAr;
  @override
  final String nameEn;
}

class City with Localized {
  const City({
    required this.id,
    required this.governorateId,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
  });
  final int id;
  final int governorateId;
  @override
  final String nameFr;
  @override
  final String nameAr;
  @override
  final String nameEn;
}

/// A place a professional serves: a whole governorate (cityId null) or a city.
class ServiceArea {
  const ServiceArea({required this.governorateId, this.cityId});
  final int governorateId;
  final int? cityId;
}

/// What the profile screen shows beyond the card: other services and areas.
class ProfessionalDetails {
  const ProfessionalDetails({
    this.serviceCategoryIds = const [],
    this.areas = const [],
  });
  final List<int> serviceCategoryIds;
  final List<ServiceArea> areas;
}

enum Availability { available, busy, offline }

enum Verification { unverified, pending, verified, rejected }

/// Today's date in Tunisia (UTC+1 all year), where badge dates are read.
DateTime tunisToday([DateTime? now]) {
  final t = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 1));
  return DateTime.utc(t.year, t.month, t.day);
}

/// A database verification status, read with its validity date: a badge
/// whose `verified_until` has passed is shown as unverified (the database
/// turns it back daily; this closes the gap). Unknown values (such as
/// `revoked`) are unverified.
Verification parseVerification(Object? status, Object? until, {DateTime? now}) {
  final v = Verification.values.firstWhere(
    (v) => v.name == status,
    orElse: () => Verification.unverified,
  );
  if (v != Verification.verified || until is! String) return v;
  final date = DateTime.tryParse(until);
  if (date == null) return v;
  final day = DateTime.utc(date.year, date.month, date.day);
  return day.isBefore(tunisToday(now)) ? Verification.unverified : v;
}

/// What a professional card needs. Built only from public columns: contact
/// details are never part of it (they are revealed on request, see Phase 3.4).
class ProfessionalSummary {
  const ProfessionalSummary({
    required this.id,
    required this.name,
    required this.categoryId,
    this.description = '',
    this.yearsExperience,
    this.governorateId,
    this.cityId,
    this.neighborhoodId,
    this.latitude,
    this.longitude,
    this.availability = Availability.available,
    this.verification = Verification.unverified,
    this.rating = 0,
    this.reviewCount = 0,
    this.distanceKm,
    this.avatarUrl,
    this.verifiedUntil,
  });

  final String id;

  /// Last day the badge is valid (only on profile reads, not search results).
  final DateTime? verifiedUntil;

  /// Public address of the professional's own picture, when they added one.
  final String? avatarUrl;

  /// The public name (business or professional name).
  final String name;
  final int categoryId;
  final String description;
  final int? yearsExperience;
  final int? governorateId;
  final int? cityId;
  final int? neighborhoodId;
  final double? latitude;
  final double? longitude;
  final Availability availability;
  final Verification verification;

  /// Average rating 0-5. Meaningful only when [reviewCount] > 0.
  final double rating;
  final int reviewCount;

  /// Distance from the position used for the search, when one was given.
  final double? distanceKm;

  /// The same professional with a picture address (search results come from a
  /// function that does not carry it).
  ProfessionalSummary withAvatar(String? url) => ProfessionalSummary(
    id: id,
    name: name,
    categoryId: categoryId,
    description: description,
    yearsExperience: yearsExperience,
    governorateId: governorateId,
    cityId: cityId,
    neighborhoodId: neighborhoodId,
    latitude: latitude,
    longitude: longitude,
    availability: availability,
    verification: verification,
    rating: rating,
    reviewCount: reviewCount,
    distanceKm: distanceKm,
    avatarUrl: url,
    verifiedUntil: verifiedUntil,
  );

  bool get isVerified => verification == Verification.verified;
  bool get hasReviews => reviewCount > 0;
}

/// 'Recently active' is deliberately absent until a real activity signal
/// exists: profile edits are not one (they can be repeated to climb the list).
enum ProfessionalSort { rating, reviews, nearest }

/// A search request. All filters combine with AND.
class SearchQuery {
  const SearchQuery({
    this.text,
    this.categoryId,
    this.governorateId,
    this.cityId,
    this.minRating,
    this.availableOnly = false,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.sort = ProfessionalSort.rating,
    this.limit = 20,
    this.offset = 0,
  });

  final String? text;
  final int? categoryId;
  final int? governorateId;
  final int? cityId;
  final double? minRating;
  final bool availableOnly;

  /// The searcher's position (approximate). Needed for distance and radius.
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
  final ProfessionalSort sort;
  final int limit;
  final int offset;

  bool get hasPosition => latitude != null && longitude != null;

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.text == text &&
      other.categoryId == categoryId &&
      other.governorateId == governorateId &&
      other.cityId == cityId &&
      other.minRating == minRating &&
      other.availableOnly == availableOnly &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radiusKm == radiusKm &&
      other.sort == sort &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(
    text,
    categoryId,
    governorateId,
    cityId,
    minRating,
    availableOnly,
    latitude,
    longitude,
    radiusKm,
    sort,
    limit,
    offset,
  );

  SearchQuery copyWith({
    String? text,
    int? categoryId,
    int? governorateId,
    int? cityId,
    double? minRating,
    bool? availableOnly,
    double? latitude,
    double? longitude,
    double? radiusKm,
    ProfessionalSort? sort,
    int? limit,
    int? offset,
    bool clearText = false,
    bool clearCategory = false,
    bool clearGovernorate = false,
    bool clearCity = false,
    bool clearMinRating = false,
    bool clearPosition = false,
    bool clearRadius = false,
  }) => SearchQuery(
    text: clearText ? null : (text ?? this.text),
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    governorateId: clearGovernorate
        ? null
        : (governorateId ?? this.governorateId),
    cityId: clearCity ? null : (cityId ?? this.cityId),
    minRating: clearMinRating ? null : (minRating ?? this.minRating),
    availableOnly: availableOnly ?? this.availableOnly,
    latitude: clearPosition ? null : (latitude ?? this.latitude),
    longitude: clearPosition ? null : (longitude ?? this.longitude),
    radiusKm: clearRadius ? null : (radiusKm ?? this.radiusKm),
    sort: sort ?? this.sort,
    limit: limit ?? this.limit,
    offset: offset ?? this.offset,
  );
}

enum MarketplaceFailure {
  network,
  notSignedIn,
  forbidden,
  notConfigured,

  /// The reveal limit (40 per hour) was reached.
  rateLimited,

  /// The professional is gone or not published.
  notFound,

  /// The 200-favorites cap was reached.
  limitReached,
  unknown,
}

class MarketplaceError implements Exception {
  const MarketplaceError(this.failure);
  final MarketplaceFailure failure;
  @override
  String toString() => 'MarketplaceError($failure)';
}

abstract interface class MarketplaceRepository {
  /// Whether the data is made up for development. UI shows a visible notice.
  bool get isDemo;

  Future<List<ServiceCategory>> categories();
  Future<List<Governorate>> governorates();
  Future<List<City>> cities({int? governorateId});
  Future<List<ProfessionalSummary>> search(SearchQuery query);

  /// One published professional by id, or null if there is none (unpublished,
  /// deleted or unknown ids look the same on purpose).
  Future<ProfessionalSummary?> professional(String id);

  /// The published professionals among [ids], in the order given. Unknown or
  /// unpublished ids are simply absent.
  Future<List<ProfessionalSummary>> professionals(List<String> ids);

  /// Other services and service areas of a published professional.
  Future<ProfessionalDetails> details(String id);

  /// The phone number (E.164) of a published professional. Needs a registered
  /// account and is rate limited on the server: it is never part of a list or
  /// a profile load. Throws [MarketplaceError].
  Future<String> revealContact(String id);
}

/// Used when there is no backend and demo data is not enabled: honestly empty.
class EmptyMarketplaceRepository implements MarketplaceRepository {
  const EmptyMarketplaceRepository();
  @override
  bool get isDemo => false;
  @override
  Future<List<ServiceCategory>> categories() async => const [];
  @override
  Future<List<Governorate>> governorates() async => const [];
  @override
  Future<List<City>> cities({int? governorateId}) async => const [];
  @override
  Future<List<ProfessionalSummary>> search(SearchQuery query) async => const [];
  @override
  Future<ProfessionalSummary?> professional(String id) async => null;
  @override
  Future<List<ProfessionalSummary>> professionals(List<String> ids) async =>
      const [];
  @override
  Future<ProfessionalDetails> details(String id) async =>
      const ProfessionalDetails();
  @override
  Future<String> revealContact(String id) async =>
      throw const MarketplaceError(MarketplaceFailure.notConfigured);
}
