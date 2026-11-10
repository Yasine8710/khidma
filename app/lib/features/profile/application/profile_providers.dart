import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/storage/preferences_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/profile_domain.dart';

/// Overridden in `main()` with the Supabase repository when a backend exists.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => const NotConfiguredProfileRepository(),
);

/// The signed-in user's profile; null when signed out. Re-fetched whenever the
/// signed-in account changes, so one person's data never shows for another.
final myProfileProvider = FutureProvider.autoDispose<AppProfile?>(
  // No silent background retries: failures show a retry button instead.
  retry: (retryCount, error) => null,
  (ref) async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;
    final profile = await ref.watch(profileRepositoryProvider).fetchMine();
    if (profile.id != user.id) throw const ProfileError(ProfileFailure.unknown);
    return profile;
  },
);

class ProfileResult {
  const ProfileResult.ok() : failure = null;
  const ProfileResult.failed(this.failure);
  final ProfileFailure? failure;
  bool get isOk => failure == null;
}

final profileActionsProvider = NotifierProvider<ProfileActions, bool>(
  ProfileActions.new,
);

/// Runs profile writes and exposes "in flight" (state) to disable buttons.
class ProfileActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<ProfileResult> _run(
    Future<void> Function(ProfileRepository) action,
  ) async {
    if (state) return const ProfileResult.failed(ProfileFailure.unknown);
    state = true;
    try {
      await action(ref.read(profileRepositoryProvider));
      ref.invalidate(myProfileProvider);
      return const ProfileResult.ok();
    } on ProfileError catch (e) {
      return ProfileResult.failed(e.failure);
    } catch (_) {
      return const ProfileResult.failed(ProfileFailure.unknown);
    } finally {
      state = false;
    }
  }

  /// Saves the editable fields. If the preferred language changed, the app
  /// switches to it too, so the profile and the UI never disagree.
  Future<ProfileResult> save({
    required String fullName,
    required String? phone,
    required String preferredLanguage,
  }) async {
    final result = await _run((r) async {
      await r.updateMine(
        fullName: fullName,
        phone: phone,
        preferredLanguage: preferredLanguage,
      );
    });
    if (result.isOk) {
      await ref
          .read(localeProvider.notifier)
          .setLocale(Locale(preferredLanguage));
    }
    return result;
  }

  Future<ProfileResult> becomeProfessional() =>
      _run((r) => r.becomeProfessional());
}

const _pendingKey = 'pendingAccountType';

/// An account type chosen at sign-up that could not be applied yet (with email
/// confirmation there is no session until the link is opened). Applied on the
/// first signed-in session, then cleared. Stored on this device only.
final pendingAccountTypeProvider =
    NotifierProvider<PendingAccountType, AccountType?>(PendingAccountType.new);

class PendingAccountType extends Notifier<AccountType?> {
  @override
  AccountType? build() =>
      ref.read(keyValueStoreProvider).getString(_pendingKey) == 'professional'
      ? AccountType.professional
      : null;

  Future<void> set(AccountType? type) async {
    state = type == AccountType.professional ? type : null;
    try {
      await ref
          .read(keyValueStoreProvider)
          .setString(_pendingKey, state == null ? '' : 'professional');
    } catch (_) {}
  }
}

/// Applies a pending "I want to offer services" choice once a session exists.
/// Mounted from the app root. If it fails (offline), the choice stays pending
/// and the Profile screen still offers the same action manually.
final accountSetupProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final pending = ref.watch(pendingAccountTypeProvider);
  if (user == null || pending != AccountType.professional) return;
  Future.microtask(() async {
    final result = await ref
        .read(profileActionsProvider.notifier)
        .becomeProfessional();
    if (result.isOk) {
      await ref.read(pendingAccountTypeProvider.notifier).set(null);
    }
  });
});
