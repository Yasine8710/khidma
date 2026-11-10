import 'dart:async';

import 'package:khidma/core/format/tunisian_phone.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:khidma/features/professional/domain/professional_domain.dart';

/// In-memory professional profile with call recording and failure hooks. It
/// enforces the same publish rule as the database.
class FakeProfessionalRepository implements ProfessionalRepository {
  FakeProfessionalRepository({ProfessionalDraft? draft})
    : draft = draft ?? const ProfessionalDraft();

  ProfessionalDraft draft;
  ProfessionalFailure? failNext;
  Completer<void>? gate;

  /// Simulates a server that does not keep the phone.
  bool dropPhone = false;

  int fetchCalls = 0;
  final saved = <ProfessionalProfileInput>[];
  final servicesSaved = <Set<int>>[];
  final areasSaved = <List<ServiceArea>>[];
  final publishCalls = <bool>[];
  final availabilityCalls = <Availability>[];
  ProfessionalActivity activity = const ProfessionalActivity();
  bool failActivity = false;

  /// Makes every profile load after this fail (the save itself succeeds).
  bool reloadFails = false;

  Future<void> _pre() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw ProfessionalError(f);
    }
  }

  @override
  Future<ProfessionalDraft> fetchMine() async {
    fetchCalls++;
    await _pre();
    if (reloadFails && fetchCalls > 1) {
      throw const ProfessionalError(ProfessionalFailure.network);
    }
    return draft;
  }

  @override
  Future<ProfessionalDraft> saveProfile(ProfessionalProfileInput i) async {
    saved.add(i);
    await _pre();
    String? blank(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    draft = ProfessionalDraft(
      businessName: blank(i.businessName),
      categoryId: i.categoryId,
      description: blank(i.description),
      yearsExperience: i.yearsExperience,
      governorateId: i.governorateId,
      cityId: i.governorateId == null ? null : i.cityId,
      neighborhoodId: i.cityId == null ? null : i.neighborhoodId,
      phone: dropPhone || blank(i.phone) == null
          ? null
          : TunisianPhone.e164(i.phone!),
      serviceCategoryIds: draft.serviceCategoryIds,
      areas: draft.areas,
      availability: draft.availability,
      isPublished: draft.isPublished,
      verification: draft.verification,
    );
    return draft;
  }

  ProfessionalDraft _with({
    Set<int>? services,
    List<ServiceArea>? areas,
    bool? published,
  }) => ProfessionalDraft(
    businessName: draft.businessName,
    categoryId: draft.categoryId,
    description: draft.description,
    yearsExperience: draft.yearsExperience,
    governorateId: draft.governorateId,
    cityId: draft.cityId,
    neighborhoodId: draft.neighborhoodId,
    phone: draft.phone,
    serviceCategoryIds: services ?? draft.serviceCategoryIds,
    areas: areas ?? draft.areas,
    availability: draft.availability,
    isPublished: published ?? draft.isPublished,
    verification: draft.verification,
  );

  @override
  Future<void> setServices(Set<int> ids) async {
    servicesSaved.add({...ids});
    await _pre();
    draft = _with(services: {...ids});
  }

  @override
  Future<void> setAreas(List<ServiceArea> areas) async {
    areasSaved.add([...areas]);
    await _pre();
    draft = _with(areas: [...areas]);
  }

  @override
  Future<void> setAvailability(Availability availability) async {
    availabilityCalls.add(availability);
    await _pre();
    draft = ProfessionalDraft(
      businessName: draft.businessName,
      categoryId: draft.categoryId,
      description: draft.description,
      yearsExperience: draft.yearsExperience,
      governorateId: draft.governorateId,
      cityId: draft.cityId,
      neighborhoodId: draft.neighborhoodId,
      phone: draft.phone,
      serviceCategoryIds: draft.serviceCategoryIds,
      areas: draft.areas,
      availability: availability,
      isPublished: draft.isPublished,
      verification: draft.verification,
    );
  }

  @override
  Future<ProfessionalActivity> fetchActivity() async {
    await _pre();
    if (failActivity) {
      throw const ProfessionalError(ProfessionalFailure.network);
    }
    return activity;
  }

  @override
  Future<void> setPublished(bool published) async {
    publishCalls.add(published);
    await _pre();
    if (published && !draft.isComplete) {
      throw const ProfessionalError(ProfessionalFailure.invalid);
    }
    draft = _with(published: published);
  }
}
