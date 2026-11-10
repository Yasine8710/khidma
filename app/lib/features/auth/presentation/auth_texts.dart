import '../../../l10n/generated/app_localizations.dart';
import '../domain/auth_domain.dart';
import '../domain/auth_validators.dart';

extension AuthTexts on AppLocalizations {
  String failureText(AuthFailure f) => switch (f) {
    AuthFailure.invalidCredentials => failInvalidCredentials,
    AuthFailure.emailNotConfirmed => failEmailNotConfirmed,
    AuthFailure.weakPassword => failWeakPassword,
    AuthFailure.signUpDisabled => failSignUpDisabled,
    AuthFailure.rateLimited => failRateLimited,
    // Closing Apple's sheet is a choice, not an error; callers show nothing.
    AuthFailure.cancelled => '',
    AuthFailure.network => failNetwork,
    AuthFailure.notConfigured => failNotConfigured,
    AuthFailure.unknown => failUnknown,
  };

  String? emailProblemText(FieldProblem? p) => switch (p) {
    null => null,
    FieldProblem.required => errEmailRequired,
    _ => errEmailInvalid,
  };

  String? passwordProblemText(FieldProblem? p) => switch (p) {
    null => null,
    FieldProblem.required => errPasswordRequired,
    FieldProblem.passwordTooShort => errPasswordShort,
    FieldProblem.passwordTooLong => errPasswordLong,
    _ => errPasswordRequired,
  };

  String? nameProblemText(FieldProblem? p) =>
      p == null ? null : errNameRequired;
}
