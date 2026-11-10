import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../domain/marketplace_domain.dart';

/// Maps Supabase/PostgREST errors to a [MarketplaceFailure]. Pure and tested;
/// database messages are never forwarded.
MarketplaceFailure mapMarketplaceException(Object error) {
  if (error is MarketplaceError) return error.failure;
  if (error is TimeoutException) return MarketplaceFailure.network;
  if (error is sb.PostgrestException) {
    switch (error.code) {
      case '28000': // not authenticated (reveal needs an account)
        return MarketplaceFailure.notSignedIn;
      case 'P0002': // reveal: no such published professional
        return MarketplaceFailure.notFound;
      case 'P0001':
        return error.message.contains('rate_limited')
            ? MarketplaceFailure.rateLimited
            : MarketplaceFailure.unknown;
      case '42501': // permission denied: grants or policies are wrong
        return MarketplaceFailure.forbidden;
      case 'PGRST301': // JWT expired or invalid
      case 'PGRST302':
        return MarketplaceFailure.notSignedIn;
    }
    return MarketplaceFailure.unknown;
  }
  final name = error.runtimeType.toString();
  if (name.contains('ClientException') || name.contains('SocketException')) {
    return MarketplaceFailure.network;
  }
  return MarketplaceFailure.unknown;
}

/// Reads reference data and runs search through PostgREST. Everything it can
/// reach is public by design (Row Level Security and column grants decide);
/// no contact details are ever requested.
class SupabaseMarketplaceRepository implements MarketplaceRepository {
  SupabaseMarketplaceRepository(this._client);
  final sb.SupabaseClient _client;

  @override
  bool get isDemo => false;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw MarketplaceError(mapMarketplaceException(e));
    }
  }

  static const _nameCols = 'name_fr, name_ar, name_en';

  @override
  Future<List<ServiceCategory>> categories() => _guard(() async {
    final rows = await _client
        .from('service_categories')
        .select(
          'id, slug, $_nameCols, description_fr, description_ar, description_en, icon, sort_order',
        )
        .order('sort_order', ascending: true);
    return [for (final r in rows) _category(r)];
  });

  @override
  Future<List<Governorate>> governorates() => _guard(() async {
    final rows = await _client
        .from('governorates')
        .select('id, code, $_nameCols')
        .order('id', ascending: true);
    return [
      for (final r in rows)
        Governorate(
          id: r['id'] as int,
          code: r['code'] as String,
          nameFr: r['name_fr'] as String,
          nameAr: r['name_ar'] as String,
          nameEn: r['name_en'] as String,
        ),
    ];
  });

  @override
  Future<List<City>> cities({int? governorateId}) => _guard(() async {
    final base = _client
        .from('cities')
        .select('id, governorate_id, $_nameCols');
    final rows = await (governorateId == null
        ? base
              .order('governorate_id', ascending: true)
              .order('name_fr', ascending: true)
        : base
              .eq('governorate_id', governorateId)
              .order('name_fr', ascending: true));
    return [
      for (final r in rows)
        City(
          id: r['id'] as int,
          governorateId: r['governorate_id'] as int,
          nameFr: r['name_fr'] as String,
          nameAr: r['name_ar'] as String,
          nameEn: r['name_en'] as String,
        ),
    ];
  });

  @override
  Future<List<ProfessionalSummary>> search(SearchQuery q) => _guard(() async {
    final text = q.text?.trim();
    // Only filters that are set are sent; the function's defaults do the rest.
    final params = <String, dynamic>{
      if (text != null && text.isNotEmpty) 'p_query': text,
      'p_category': ?q.categoryId,
      'p_governorate': ?q.governorateId,
      'p_city': ?q.cityId,
      'p_min_rating': ?q.minRating,
      if (q.availableOnly) 'p_available_only': true,
      if (q.hasPosition) 'p_lat': q.latitude,
      if (q.hasPosition) 'p_lng': q.longitude,
      if (q.hasPosition) 'p_radius_km': ?q.radiusKm,
      'p_sort': q.sort.name,
      'p_limit': q.limit,
      'p_offset': q.offset,
    };
    final rows = await _client.rpc('search_professionals', params: params);
    return [
      for (final r in (rows as List)) _summary(r as Map<String, dynamic>),
    ];
  });

  /// The same public columns the search returns; Row Level Security hides
  /// anything unpublished, so "no row" covers unknown, deleted and draft alike.
  @override
  Future<ProfessionalSummary?> professional(String id) => _guard(() async {
    final row = await _client
        .from('professional_profiles')
        .select(
          'user_id, business_name, primary_category_id, description, years_experience, '
          'governorate_id, city_id, neighborhood_id, latitude, longitude, availability, '
          'verification_status, rating_avg, review_count',
        )
        .eq('user_id', id)
        .eq('is_published', true)
        .maybeSingle();
    return row == null ? null : _summary(row);
  });

  @override
  Future<ProfessionalDetails> details(String id) => _guard(() async {
    final services = await _client
        .from('professional_services')
        .select('category_id')
        .eq('professional_id', id);
    final areas = await _client
        .from('service_areas')
        .select('governorate_id, city_id')
        .eq('professional_id', id)
        .order('id', ascending: true);
    return ProfessionalDetails(
      serviceCategoryIds: [for (final r in services) r['category_id'] as int],
      areas: [
        for (final r in areas)
          ServiceArea(
            governorateId: r['governorate_id'] as int,
            cityId: r['city_id'] as int?,
          ),
      ],
    );
  });

  @override
  Future<String> revealContact(String id) => _guard(() async {
    final phone = await _client.rpc(
      'reveal_professional_contact',
      params: {'p_professional': id},
    );
    if (phone is! String || phone.isEmpty) {
      throw const MarketplaceError(MarketplaceFailure.notFound);
    }
    return phone;
  });

  ServiceCategory _category(Map<String, dynamic> r) => ServiceCategory(
    id: r['id'] as int,
    slug: r['slug'] as String,
    nameFr: r['name_fr'] as String,
    nameAr: r['name_ar'] as String,
    nameEn: r['name_en'] as String,
    descriptionFr: (r['description_fr'] as String?) ?? '',
    descriptionAr: (r['description_ar'] as String?) ?? '',
    descriptionEn: (r['description_en'] as String?) ?? '',
    icon: (r['icon'] as String?) ?? 'build',
    sortOrder: (r['sort_order'] as int?) ?? 0,
  );

  ProfessionalSummary _summary(Map<String, dynamic> r) => ProfessionalSummary(
    id: r['user_id'] as String,
    name: (r['business_name'] as String?) ?? '',
    categoryId: r['primary_category_id'] as int,
    description: (r['description'] as String?) ?? '',
    yearsExperience: r['years_experience'] as int?,
    governorateId: r['governorate_id'] as int?,
    cityId: r['city_id'] as int?,
    neighborhoodId: r['neighborhood_id'] as int?,
    latitude: (r['latitude'] as num?)?.toDouble(),
    longitude: (r['longitude'] as num?)?.toDouble(),
    availability: Availability.values.firstWhere(
      (a) => a.name == r['availability'],
      orElse: () => Availability.offline,
    ),
    verification: Verification.values.firstWhere(
      (v) => v.name == r['verification_status'],
      orElse: () => Verification.unverified,
    ),
    rating: (r['rating_avg'] as num?)?.toDouble() ?? 0,
    reviewCount: (r['review_count'] as int?) ?? 0,
    distanceKm: (r['distance_km'] as num?)?.toDouble(),
  );
}
