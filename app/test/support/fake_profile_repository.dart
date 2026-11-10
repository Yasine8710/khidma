import 'dart:async';

import 'package:khidma/features/profile/domain/profile_domain.dart';

/// In-memory profile store for tests, with call recording and failure hooks.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile});

  AppProfile? profile;
  ProfileFailure? failNext;
  Completer<void>? gate;

  int fetchCalls = 0;
  int becomeProfessionalCalls = 0;
  final updates = <({String fullName, String? phone, String language})>[];

  Future<void> _pre() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw ProfileError(f);
    }
  }

  @override
  Future<AppProfile> fetchMine() async {
    fetchCalls++;
    await _pre();
    return profile ?? (throw const ProfileError(ProfileFailure.notSignedIn));
  }

  @override
  Future<AppProfile> updateMine({
    required String fullName,
    required String? phone,
    required String preferredLanguage,
  }) async {
    updates.add((
      fullName: fullName,
      phone: phone,
      language: preferredLanguage,
    ));
    await _pre();
    final p = profile!;
    profile = AppProfile(
      id: p.id,
      fullName: fullName.trim(),
      phone: phone,
      preferredLanguage: preferredLanguage,
      isCustomer: p.isCustomer,
      isProfessional: p.isProfessional,
    );
    return profile!;
  }

  @override
  Future<void> becomeProfessional() async {
    becomeProfessionalCalls++;
    await _pre();
    profile = profile?.copyWith(isProfessional: true);
  }
}
