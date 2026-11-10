/// Field problems the UI turns into localized messages.
enum FieldProblem { required, invalidEmail, passwordTooShort, passwordTooLong }

const minPasswordLength = 8;
const maxPasswordLength = 72; // bcrypt (used by Supabase Auth) ignores the rest

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
  if (v.length < minPasswordLength) return FieldProblem.passwordTooShort;
  if (v.length > maxPasswordLength) return FieldProblem.passwordTooLong;
  return null;
}

/// Sign-in only checks presence: an old account may predate today's policy.
FieldProblem? validateExistingPassword(String? value) =>
    (value ?? '').isEmpty ? FieldProblem.required : null;

FieldProblem? validateName(String? value) =>
    (value ?? '').trim().isEmpty ? FieldProblem.required : null;
