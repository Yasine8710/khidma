import 'dart:convert';

/// Field problems the UI turns into localized messages.
enum FieldProblem { required, invalidEmail, passwordTooShort, passwordTooLong }

const minPasswordLength = 8;
// Supabase Auth: minimum counted in Unicode characters, maximum in UTF-8
// bytes (bcrypt reads at most 72). Arabic letters are 2 bytes, emoji 4.
const maxPasswordBytes = 72;

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

FieldProblem? validateEmail(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return FieldProblem.required;
  if (v.length > 254 || !_email.hasMatch(v)) return FieldProblem.invalidEmail;
  return null;
}

/// Passwords are not trimmed: spaces may be intentional.
FieldProblem? validateNewPassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return FieldProblem.required;
  if (v.runes.length < minPasswordLength) {
    return FieldProblem.passwordTooShort;
  }
  if (utf8.encode(v).length > maxPasswordBytes) {
    return FieldProblem.passwordTooLong;
  }
  return null;
}

/// Sign-in only checks presence: an old account may predate today's policy.
FieldProblem? validateExistingPassword(String? value) =>
    (value ?? '').isEmpty ? FieldProblem.required : null;

FieldProblem? validateName(String? value) =>
    (value ?? '').trim().isEmpty ? FieldProblem.required : null;
