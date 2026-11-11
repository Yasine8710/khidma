import '../../location/domain/location_domain.dart';
import '../../../core/format/tunisian_phone.dart';
import '../../marketplace/domain/marketplace_domain.dart';

/// Limits that mirror the database (and are checked again there).
abstract final class ProfessionalRules {
  static const nameMin = 2;
  static const nameMax = 120;
  static const descriptionMin = 20;
  static const descriptionMax = 2000;
  static const yearsMax = 60;

  static bool nameOk(String? v) {
    final n = v?.trim().length ?? 0;
    return n >= nameMin && n <= nameMax;
  }

  static bool descriptionOk(String? v) {
    final n = v?.trim().length ?? 0;
    return n >= descriptionMin && n <= descriptionMax;
  }

  static bool yearsOk(int? v) => v == null || (v >= 0 && v <= yearsMax);
}

/// What the person has typed in the profile steps. Phone is as typed; it is
/// normalised (`+216...`) only when saved.
class ProfessionalProfileInput {
  const ProfessionalProfileInput({
    this.businessName,
    this.categoryId,
    this.description,
    this.yearsExperience,
    this.governorateId,
    this.cityId,
    this.neighborhoodId,
    this.phone,
    this.position,
  });

  final String? businessName;
  final int? categoryId;
  final String? description;
  final int? yearsExperience;
  final int? governorateId;
  final int? cityId;

  /// Kept only while the city is unchanged (a neighbourhood belongs to a city).
  final int? neighborhoodId;
  final String? phone;

  /// Where the pin goes (about 1 km). Null: the database uses the governorate.
  final LocationFix? position;
}

/// The signed-in professional's own profile, draft or published.
class ProfessionalDraft {
  const ProfessionalDraft({
    this.businessName,
    this.categoryId,
    this.description,
    this.yearsExperience,
    this.governorateId,
    this.cityId,
    this.neighborhoodId,
    this.phone,
    this.position,
    this.serviceCategoryIds = const {},
    this.areas = const [],
    this.availability = Availability.available,
    this.isPublished = false,
    this.verification = Verification.unverified,
  });

  final String? businessName;
  final int? categoryId;
  final String? description;
  final int? yearsExperience;
  final int? governorateId;
  final int? cityId;
  final int? neighborhoodId;

  /// E.164 (`+216...`), readable only by the owner.
  final String? phone;

  /// The pin on the map: the owner's own, or the governorate centre.
  final LocationFix? position;
  final Set<int> serviceCategoryIds;
  final List<ServiceArea> areas;
  final Availability availability;
  final bool isPublished;
  final Verification verification;

  /// What still blocks publishing (the database refuses an incomplete public
  /// profile, so the app says so first).
  List<ProfileGap> get gaps => [
    if (!ProfessionalRules.nameOk(businessName)) ProfileGap.name,
    if (categoryId == null) ProfileGap.category,
    if (!ProfessionalRules.descriptionOk(description)) ProfileGap.description,
    if (governorateId == null) ProfileGap.location,
    if (phone == null || !TunisianPhone.isValid(phone!)) ProfileGap.phone,
  ];

  bool get isComplete => gaps.isEmpty;
}

/// Counts shown on the dashboard. Numbers only: nobody learns who looked.
class ProfessionalActivity {
  const ProfessionalActivity({
    this.contactViews30d = 0,
    this.contactViewsTotal = 0,
    this.favorites = 0,
  });
  final int contactViews30d;
  final int contactViewsTotal;
  final int favorites;
}

enum ProfileGap { name, category, description, location, phone }

enum ProfessionalFailure {
  /// Another save is still running; this request was ignored.
  busy,
  network,
  notSignedIn,
  forbidden,

  /// The server refused the values (a rule the app did not catch first).
  invalid,
  notConfigured,
  unknown,
}

class ProfessionalError implements Exception {
  const ProfessionalError(this.failure);
  final ProfessionalFailure failure;
  @override
  String toString() => 'ProfessionalError($failure)';
}

abstract interface class ProfessionalRepository {
  Future<ProfessionalDraft> fetchMine();

  /// Saves the profile fields and returns the stored profile.
  Future<ProfessionalDraft> saveProfile(ProfessionalProfileInput input);

  /// Makes the extra services exactly [ids].
  Future<void> setServices(Set<int> ids);

  /// Makes the served areas exactly [areas].
  Future<void> setAreas(List<ServiceArea> areas);

  Future<void> setPublished(bool published);

  Future<void> setAvailability(Availability availability);

  Future<ProfessionalActivity> fetchActivity();
}

class NotConfiguredProfessionalRepository implements ProfessionalRepository {
  const NotConfiguredProfessionalRepository();
  Never _fail() =>
      throw const ProfessionalError(ProfessionalFailure.notConfigured);
  @override
  Future<ProfessionalDraft> fetchMine() async => _fail();
  @override
  Future<ProfessionalDraft> saveProfile(ProfessionalProfileInput input) async =>
      _fail();
  @override
  Future<void> setServices(Set<int> ids) async => _fail();
  @override
  Future<void> setAreas(List<ServiceArea> areas) async => _fail();
  @override
  Future<void> setPublished(bool published) async => _fail();
  @override
  Future<void> setAvailability(Availability availability) async => _fail();
  @override
  Future<ProfessionalActivity> fetchActivity() async => _fail();
}
