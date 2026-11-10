import 'dart:convert';

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
/// signed-in account changes. UI must read [visibleProfileProvider], not this
/// directly: while it reloads it still holds the previous person's data.
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

/// The profile of the account that is signed in *right now*, or null while it
/// loads, if it failed, or when nobody is signed in. Never another person's.
final visibleProfileProvider = Provider<AppProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  final async = ref.watch(myProfileProvider);
  if (user == null || async.isLoading) return null;
  final profile = async.value;
  return profile != null && profile.id == user.id ? profile : null;
});

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

const _pendingKey = 'pendingAccountChoice';
const pendingChoiceLifetime = Duration(days: 7);

/// "I want to offer services", chosen at sign-up, waiting for a session (with
/// email confirmation there is none until the link is opened). It belongs to
/// the email used at sign-up: only that account may act on it, and it expires.
class PendingAccountChoice {
  const PendingAccountChoice({required this.email, required this.createdAt});
  final String email; // lower-cased
  final DateTime createdAt;

  bool isFor(String? userEmail) =>
      userEmail != null && userEmail.trim().toLowerCase() == email;

  bool isExpired(DateTime now) =>
      now.difference(createdAt) > pendingChoiceLifetime;

  Map<String, Object> toJson() => {
    'type': 'professional',
    'email': email,
    'at': createdAt.millisecondsSinceEpoch,
  };

  static PendingAccountChoice? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map || m['type'] != 'professional') return null;
      final email = m['email'];
      final at = m['at'];
      if (email is! String || email.isEmpty || at is! int) return null;
      return PendingAccountChoice(
        email: email,
        createdAt: DateTime.fromMillisecondsSinceEpoch(at),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Overridable clock, so expiry is testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final pendingAccountChoiceProvider =
    NotifierProvider<PendingChoiceController, PendingAccountChoice?>(
      PendingChoiceController.new,
    );

class PendingChoiceController extends Notifier<PendingAccountChoice?> {
  @override
  PendingAccountChoice? build() {
    final choice = PendingAccountChoice.tryParse(
      ref.read(keyValueStoreProvider).getString(_pendingKey),
    );
    if (choice == null || choice.isExpired(ref.read(clockProvider)())) {
      return null;
    }
    return choice;
  }

  /// Remember a professional choice for [email]; any other type forgets. The
  /// in-memory value is authoritative for this session; a failed write only
  /// means it may not survive a restart (it is identity-bound and expires, so
  /// a stale copy cannot grant anything to anyone else).
  Future<void> remember(AccountType type, String email) =>
      type == AccountType.professional
      ? _set(
          PendingAccountChoice(
            email: email.trim().toLowerCase(),
            createdAt: ref.read(clockProvider)(),
          ),
        )
      : _set(null);

  Future<void> forget() => _set(null);

  Future<void> _set(PendingAccountChoice? choice) async {
    state = choice;
    try {
      await ref
          .read(keyValueStoreProvider)
          .setString(
            _pendingKey,
            choice == null ? '' : jsonEncode(choice.toJson()),
          );
    } catch (_) {}
  }
}

/// Applies a pending professional choice once *that account* has a session.
/// Mounted from the app root. A different account never triggers it. If the
/// call fails (offline) the choice stays and the Profile screen offers the
/// same action manually.
final accountSetupProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final choice = ref.watch(pendingAccountChoiceProvider);
  if (user == null || choice == null) return;
  if (choice.isExpired(ref.read(clockProvider)())) {
    Future.microtask(
      () => ref.read(pendingAccountChoiceProvider.notifier).forget(),
    );
    return;
  }
  if (!choice.isFor(user.email)) return;
  Future.microtask(() async {
    final result = await ref
        .read(profileActionsProvider.notifier)
        .becomeProfessional();
    // Clear only if it is still the same choice for the same signed-in person.
    final now = ref.read(currentUserProvider);
    final current = ref.read(pendingAccountChoiceProvider);
    if (result.isOk && identical(current, choice) && now?.id == user.id) {
      await ref.read(pendingAccountChoiceProvider.notifier).forget();
    }
  });
});
