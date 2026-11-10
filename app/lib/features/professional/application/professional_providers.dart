import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../marketplace/domain/marketplace_domain.dart';
import '../domain/professional_domain.dart';

/// Overridden in `main()` with the Supabase repository when a backend is
/// configured.
final professionalRepositoryProvider = Provider<ProfessionalRepository>(
  (ref) => const NotConfiguredProfessionalRepository(),
);

/// The signed-in professional's own profile (draft or published). Starts again
/// for each account, and is nothing while signed out.
final myProfessionalProvider = FutureProvider.autoDispose<ProfessionalDraft?>(
  retry: (n, e) => null,
  (ref) async {
    final user = ref.watch(currentUserProvider.select((u) => u?.id));
    if (user == null) return null;
    return ref.watch(professionalRepositoryProvider).fetchMine();
  },
);

/// Saves one step of the profile. [busy] is true while a save runs, so a double
/// tap cannot send two.
final professionalActionsProvider = NotifierProvider<ProfessionalActions, bool>(
  ProfessionalActions.new,
);

class ProfessionalActions extends Notifier<bool> {
  @override
  bool build() => false;

  /// Runs [action]; returns the failure, or null on success. Returns `busy`
  /// (and does nothing) while another save runs.
  Future<ProfessionalFailure?> _run(
    Future<void> Function(ProfessionalRepository repo) action,
  ) async {
    if (state) return ProfessionalFailure.busy;
    state = true;
    final account = ref.read(currentUserProvider)?.id;
    try {
      await action(ref.read(professionalRepositoryProvider));
      // Reload only after a success (a failed save must not disturb the
      // screen), and only for the account that made the change.
      if (ref.mounted && ref.read(currentUserProvider)?.id == account) {
        ref.invalidate(myProfessionalProvider);
      }
      return null;
    } on ProfessionalError catch (e) {
      return e.failure;
    } catch (_) {
      return ProfessionalFailure.unknown;
    } finally {
      if (ref.mounted) state = false;
    }
  }

  Future<ProfessionalFailure?> saveProfile(ProfessionalProfileInput input) =>
      _run((r) async => r.saveProfile(input));

  Future<ProfessionalFailure?> saveServices(Set<int> ids) =>
      _run((r) => r.setServices(ids));

  Future<ProfessionalFailure?> saveAreas(List<ServiceArea> areas) =>
      _run((r) => r.setAreas(areas));

  Future<ProfessionalFailure?> setPublished(bool published) =>
      _run((r) => r.setPublished(published));
}
