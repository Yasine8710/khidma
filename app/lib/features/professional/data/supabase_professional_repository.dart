import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/format/tunisian_phone.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../domain/professional_domain.dart';

/// Maps Supabase errors to a [ProfessionalFailure]. Database messages are
/// never forwarded.
ProfessionalFailure mapProfessionalException(Object error) {
  if (error is ProfessionalError) return error.failure;
  if (error is TimeoutException) return ProfessionalFailure.network;
  if (error is sb.PostgrestException) {
    switch (error.code) {
      case '28000':
      case 'PGRST301':
      case 'PGRST302':
        return ProfessionalFailure.notSignedIn;
      case '42501':
        return ProfessionalFailure.forbidden;
      case '23514': // check constraint (incomplete public profile, lengths)
      case '23503': // foreign key (inactive category, wrong city/governorate)
      case '22001':
      case 'P0001':
        return ProfessionalFailure.invalid;
    }
    return ProfessionalFailure.unknown;
  }
  final name = error.runtimeType.toString();
  if (name.contains('ClientException') || name.contains('SocketException')) {
    return ProfessionalFailure.network;
  }
  return ProfessionalFailure.unknown;
}

/// The signed-in professional's own profile through PostgREST. Row Level
/// Security limits every call to the caller's rows; the phone is read with the
/// owner-only function because no table grant exposes it.
class SupabaseProfessionalRepository implements ProfessionalRepository {
  SupabaseProfessionalRepository(this._client, {String? Function()? userId})
    : _userId = userId ?? (() => _client.auth.currentUser?.id);

  final sb.SupabaseClient _client;
  final String? Function() _userId;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw ProfessionalError(mapProfessionalException(e));
    }
  }

  String _uid() {
    final id = _userId();
    if (id == null) {
      throw const ProfessionalError(ProfessionalFailure.notSignedIn);
    }
    return id;
  }

  static const _cols =
      'business_name, primary_category_id, description, years_experience, '
      'governorate_id, city_id, neighborhood_id, availability, is_published, verification_status';

  @override
  Future<ProfessionalDraft> fetchMine() => _guard(() async {
    final uid = _uid();
    final row = await _client
        .from('professional_profiles')
        .select(_cols)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) {
      throw const ProfessionalError(ProfessionalFailure.forbidden);
    }
    final phone = await _client.rpc('get_my_professional_contact');
    final services = await _client
        .from('professional_services')
        .select('category_id')
        .eq('professional_id', uid);
    final areas = await _client
        .from('service_areas')
        .select('governorate_id, city_id')
        .eq('professional_id', uid)
        .order('id', ascending: true);
    return ProfessionalDraft(
      businessName: row['business_name'] as String?,
      categoryId: row['primary_category_id'] as int?,
      description: row['description'] as String?,
      yearsExperience: row['years_experience'] as int?,
      governorateId: row['governorate_id'] as int?,
      cityId: row['city_id'] as int?,
      neighborhoodId: row['neighborhood_id'] as int?,
      phone: phone is String && phone.isNotEmpty ? phone : null,
      serviceCategoryIds: {for (final r in services) r['category_id'] as int},
      areas: [
        for (final r in areas)
          ServiceArea(
            governorateId: r['governorate_id'] as int,
            cityId: r['city_id'] as int?,
          ),
      ],
      availability: switch (row['availability']) {
        'busy' => Availability.busy,
        'offline' => Availability.offline,
        _ => Availability.available,
      },
      isPublished: row['is_published'] == true,
      verification: switch (row['verification_status']) {
        'verified' => Verification.verified,
        'pending' => Verification.pending,
        'rejected' => Verification.rejected,
        _ => Verification.unverified,
      },
    );
  });

  @override
  Future<ProfessionalDraft> saveProfile(ProfessionalProfileInput input) async {
    await _guard(() async {
      final phone = input.phone == null || input.phone!.trim().isEmpty
          ? null
          : TunisianPhone.e164(input.phone!);
      if (input.phone != null &&
          input.phone!.trim().isNotEmpty &&
          phone == null) {
        throw const ProfessionalError(ProfessionalFailure.invalid);
      }
      await _client
          .from('professional_profiles')
          .update({
            'business_name': _blankToNull(input.businessName),
            'primary_category_id': input.categoryId,
            'description': _blankToNull(input.description),
            'years_experience': input.yearsExperience,
            'governorate_id': input.governorateId,
            // A city belongs to a governorate: never send one without it.
            'city_id': input.governorateId == null ? null : input.cityId,
            // A neighbourhood belongs to a city: without one it is cleared.
            'neighborhood_id':
                input.governorateId == null || input.cityId == null
                ? null
                : input.neighborhoodId,
            'contact_phone': phone,
          })
          .eq('user_id', _uid());
    });
    return fetchMine();
  }

  @override
  Future<void> setServices(Set<int> ids) => _guard(() async {
    final uid = _uid();
    final rows = await _client
        .from('professional_services')
        .select('category_id')
        .eq('professional_id', uid);
    final current = {for (final r in rows) r['category_id'] as int};
    final add = ids.difference(current);
    final remove = current.difference(ids);
    // Add first: a failure half-way never leaves fewer services than before.
    if (add.isNotEmpty) {
      await _client.from('professional_services').insert([
        for (final id in add) {'professional_id': uid, 'category_id': id},
      ]);
    }
    if (remove.isNotEmpty) {
      await _client
          .from('professional_services')
          .delete()
          .eq('professional_id', uid)
          .inFilter('category_id', remove.toList());
    }
  });

  @override
  Future<void> setAreas(List<ServiceArea> areas) => _guard(() async {
    final uid = _uid();
    final rows = await _client
        .from('service_areas')
        .select('id, governorate_id, city_id')
        .eq('professional_id', uid);
    String key(int g, int? c) => '$g/${c ?? 0}';
    final wanted = {for (final a in areas) key(a.governorateId, a.cityId): a};
    final have = {
      for (final r in rows)
        key(r['governorate_id'] as int, r['city_id'] as int?): r['id'] as int,
    };
    final add = [
      for (final e in wanted.entries)
        if (!have.containsKey(e.key)) e.value,
    ];
    final removeIds = [
      for (final e in have.entries)
        if (!wanted.containsKey(e.key)) e.value,
    ];
    if (add.isNotEmpty) {
      await _client.from('service_areas').insert([
        for (final a in add)
          {
            'professional_id': uid,
            'governorate_id': a.governorateId,
            'city_id': a.cityId,
          },
      ]);
    }
    if (removeIds.isNotEmpty) {
      await _client
          .from('service_areas')
          .delete()
          .eq('professional_id', uid)
          .inFilter('id', removeIds);
    }
  });

  @override
  Future<void> setPublished(bool published) => _guard(() async {
    await _client
        .from('professional_profiles')
        .update({'is_published': published})
        .eq('user_id', _uid());
  });

  @override
  Future<void> setAvailability(Availability availability) => _guard(() async {
    await _client
        .from('professional_profiles')
        .update({'availability': availability.name})
        .eq('user_id', _uid());
  });

  @override
  Future<ProfessionalActivity> fetchActivity() => _guard(() async {
    final rows = await _client.rpc('get_my_activity');
    final row = rows is List && rows.isNotEmpty
        ? rows.first as Map<String, dynamic>
        : rows is Map<String, dynamic>
        ? rows
        : null;
    if (row == null) return const ProfessionalActivity();
    return ProfessionalActivity(
      contactViews30d: (row['reveals_30d'] as num?)?.toInt() ?? 0,
      contactViewsTotal: (row['reveals_total'] as num?)?.toInt() ?? 0,
      favorites: (row['favorites_count'] as num?)?.toInt() ?? 0,
    );
  });

  static String? _blankToNull(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}
