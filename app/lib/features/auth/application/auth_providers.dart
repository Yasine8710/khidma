import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../domain/auth_domain.dart';

/// Overridden in `main()` with the Supabase repository when a backend is
/// configured. Defaults to "not configured", so a fresh checkout still runs.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const NotConfiguredAuthRepository(),
);

/// False when no backend is configured: auth screens then say so.
final authAvailableProvider = Provider<bool>(
  (ref) => ref.watch(authRepositoryProvider).isAvailable,
);

/// The signed-in user (null when signed out), live.
final authUserProvider = StreamProvider<AuthUser?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.currentUser;
  yield* repo.authStateChanges;
});

/// Emits when a password-recovery link was opened (see AuthRepository).
final passwordRecoveryProvider = StreamProvider<void>(
  (ref) => ref.watch(authRepositoryProvider).passwordRecoveryRequests,
);

/// Convenience: the user right now, null while loading or signed out.
final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authUserProvider).value,
);

/// Result of an auth action for the UI: either done or a [failure].
class AuthActionResult {
  const AuthActionResult.ok([this.outcome]) : failure = null;
  const AuthActionResult.failed(this.failure) : outcome = null;
  final AuthFailure? failure;
  final SignUpOutcome? outcome;
  bool get isOk => failure == null;
}

final authActionsProvider = NotifierProvider<AuthActions, bool>(
  AuthActions.new,
);

/// Runs auth actions and exposes whether one is in flight (state = loading),
/// so buttons can show a spinner and ignore double taps.
class AuthActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<AuthActionResult> _run(
    Future<SignUpOutcome?> Function(AuthRepository repo) action,
  ) async {
    if (state) return const AuthActionResult.failed(AuthFailure.unknown);
    state = true;
    try {
      final outcome = await action(ref.read(authRepositoryProvider));
      return AuthActionResult.ok(outcome);
    } on AuthError catch (e) {
      return AuthActionResult.failed(e.failure);
    } catch (_) {
      return const AuthActionResult.failed(AuthFailure.unknown);
    } finally {
      state = false;
    }
  }

  Future<AuthActionResult> signIn(String email, String password) =>
      _run((r) async {
        await r.signIn(email: email, password: password);
        return null;
      });

  Future<AuthActionResult> signUp({
    required String email,
    required String password,
    required String fullName,
  }) => _run(
    (r) => r.signUp(
      email: email,
      password: password,
      fullName: fullName,
      language: ref.read(localeProvider).languageCode,
    ),
  );

  Future<AuthActionResult> signInWithApple() => _run((r) async {
    await r.signInWithApple();
    return null;
  });

  Future<AuthActionResult> sendPasswordReset(String email) => _run((r) async {
    await r.sendPasswordReset(email);
    return null;
  });

  Future<AuthActionResult> updatePassword(String newPassword) =>
      _run((r) async {
        await r.updatePassword(newPassword);
        return null;
      });

  Future<AuthActionResult> signOut() => _run((r) async {
    await r.signOut();
    return null;
  });
}
