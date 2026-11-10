/// A signed-in account, as far as the UI needs to know.
class AuthUser {
  const AuthUser({required this.id, required this.email, this.fullName});
  final String id;
  final String email;
  final String? fullName;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.fullName == fullName;

  @override
  int get hashCode => Object.hash(id, email, fullName);
}

/// Why an auth action failed, in terms the UI can explain to a person.
enum AuthFailure {
  invalidCredentials,
  emailNotConfirmed,
  weakPassword,
  signUpDisabled,
  rateLimited,
  network,
  notConfigured,
  unknown,
}

/// Thrown by [AuthRepository] methods; never carries a password or token.
class AuthError implements Exception {
  const AuthError(this.failure);
  final AuthFailure failure;

  @override
  String toString() => 'AuthError($failure)';
}

enum SignUpOutcome {
  /// Email confirmation is off: the user is signed in immediately.
  signedIn,

  /// A confirmation email was sent (or, for an already registered address,
  /// pretended to be: Supabase hides whether an address exists).
  confirmationRequired,
}

abstract interface class AuthRepository {
  /// False when no backend is configured; every action then fails with
  /// [AuthFailure.notConfigured].
  bool get isAvailable;

  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
    required String language,
  });
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
}

/// Used when the app runs without a backend (fresh checkout). Honest: every
/// action says "not configured"; nothing is pretended.
class NotConfiguredAuthRepository implements AuthRepository {
  const NotConfiguredAuthRepository();

  @override
  bool get isAvailable => false;
  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  Never _fail() => throw const AuthError(AuthFailure.notConfigured);

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
    required String language,
  }) async => _fail();
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => _fail();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> sendPasswordReset(String email) async => _fail();
}
