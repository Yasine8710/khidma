/// What a person chooses to be when signing up. There is deliberately no
/// admin option: admins are created by the platform owner in the database.
enum AccountType { customer, professional }

/// The signed-in person's own profile (the `profiles` row, owner-only data).
class AppProfile {
  const AppProfile({
    required this.id,
    this.fullName,
    this.phone,
    this.preferredLanguage = 'fr',
    this.isCustomer = true,
    this.isProfessional = false,
  });

  final String id;
  final String? fullName;

  /// E.164 (`+216...`), private to the owner.
  final String? phone;
  final String preferredLanguage;
  final bool isCustomer;
  final bool isProfessional;

  AppProfile copyWith({
    String? fullName,
    String? phone,
    String? preferredLanguage,
    bool? isProfessional,
  }) => AppProfile(
    id: id,
    fullName: fullName ?? this.fullName,
    phone: phone ?? this.phone,
    preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    isCustomer: isCustomer,
    isProfessional: isProfessional ?? this.isProfessional,
  );
}

enum ProfileFailure {
  network,
  invalidData,
  notSignedIn,
  notConfigured,
  unknown,
}

class ProfileError implements Exception {
  const ProfileError(this.failure);
  final ProfileFailure failure;
  @override
  String toString() => 'ProfileError($failure)';
}

abstract interface class ProfileRepository {
  Future<AppProfile> fetchMine();

  /// Only these three fields are editable by the owner (the database enforces
  /// the same with column grants). A null [phone] clears it.
  Future<AppProfile> updateMine({
    required String fullName,
    required String? phone,
    required String preferredLanguage,
  });

  /// Opt in to offering services. Idempotent; does not touch customer access.
  Future<void> becomeProfessional();
}

class NotConfiguredProfileRepository implements ProfileRepository {
  const NotConfiguredProfileRepository();
  Never _fail() => throw const ProfileError(ProfileFailure.notConfigured);
  @override
  Future<AppProfile> fetchMine() async => _fail();
  @override
  Future<AppProfile> updateMine({
    required String fullName,
    required String? phone,
    required String preferredLanguage,
  }) async => _fail();
  @override
  Future<void> becomeProfessional() async => _fail();
}
