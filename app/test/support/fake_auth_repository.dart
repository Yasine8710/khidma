import 'dart:async';

import 'package:khidma/features/auth/domain/auth_domain.dart';

/// In-memory auth for tests. Records calls, can fail on demand, and can hold a
/// call open (via [gate]) to test loading states.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? signedIn, this.available = true})
    : _current = signedIn;

  final bool available;
  AuthUser? _current;
  final _changes = StreamController<AuthUser?>.broadcast();

  /// Registered accounts: email -> password.
  final accounts = <String, String>{};

  /// Throw this from the next call (then clear).
  AuthFailure? failNext;

  /// When set, calls wait for it before finishing.
  Completer<void>? gate;

  SignUpOutcome signUpOutcome = SignUpOutcome.confirmationRequired;

  final signInCalls = <({String email, String password})>[];
  final signUpCalls =
      <({String email, String password, String fullName, String language})>[];
  final resetCalls = <String>[];
  int signOutCalls = 0;

  @override
  bool get isAvailable => available;
  @override
  AuthUser? get currentUser => _current;
  @override
  Stream<AuthUser?> get authStateChanges => _changes.stream;

  /// Simulates a change from outside (token expiry, sign-in on another tab).
  void emit(AuthUser? user) {
    _current = user;
    _changes.add(user);
  }

  Future<void> _pre() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw AuthError(f);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls.add((email: email, password: password));
    await _pre();
    if (accounts[email.trim()] != password) {
      throw const AuthError(AuthFailure.invalidCredentials);
    }
    emit(
      AuthUser(
        id: 'u-${email.trim()}',
        email: email.trim(),
        fullName: 'Test User',
      ),
    );
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
    required String language,
  }) async {
    signUpCalls.add((
      email: email,
      password: password,
      fullName: fullName,
      language: language,
    ));
    await _pre();
    if (signUpOutcome == SignUpOutcome.signedIn) {
      emit(AuthUser(id: 'new', email: email.trim(), fullName: fullName.trim()));
    }
    return signUpOutcome;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetCalls.add(email);
    await _pre();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    await _pre();
    emit(null);
  }
}
