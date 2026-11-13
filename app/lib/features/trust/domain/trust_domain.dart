import '../../portfolio/domain/portfolio_domain.dart';
import '../../requests/domain/requests_domain.dart';

/// Most documents one verification request can carry (also enforced by the
/// database).
const maxVerificationDocuments = 3;

/// Where a report is about. Reports on a review or a conversation are only
/// possible for what the reporter can see. The names are the values the
/// database function `report_content` takes; a [message] report carries the
/// message id and goes through `report_message`.
enum ReportTarget {
  professional,
  review,
  conversation,
  freelancer,
  testimonial,
  offer,
  message,
}

enum ReportReason {
  scam,
  payOutside,
  noShow,
  fake,
  abuse,
  spam,
  inappropriate,
  other;

  /// The value the database takes.
  String get dbName => switch (this) {
    payOutside => 'pay_outside',
    noShow => 'no_show',
    _ => name,
  };
}

/// Longest free text accepted with a report.
const maxReportDetails = 500;

enum VerificationStatus { none, pending, approved, rejected, cancelled }

class VerificationInfo {
  const VerificationInfo({required this.status, this.rejectReason});
  final VerificationStatus status;

  /// Why the last request was turned down (only for [VerificationStatus.rejected]).
  final String? rejectReason;
}

/// The signed-in person's own account state: a suspension (professionals
/// only) and the latest appeal against it.
class AccountStatus {
  const AccountStatus({
    this.suspended = false,
    this.suspendedUntil,
    this.reason,
    this.appeal,
    this.appealNote,
  });

  final bool suspended;

  /// Null while suspended means "until an admin lifts it".
  final DateTime? suspendedUntil;
  final String? reason;
  final AppealStatus? appeal;
  final String? appealNote;

  static const none = AccountStatus();

  factory AccountStatus.fromJson(Map<String, dynamic> j) => AccountStatus(
    suspended: j['suspended'] == true,
    suspendedUntil: j['suspended_until'] == null
        ? null
        : DateTime.parse(j['suspended_until'] as String).toLocal(),
    reason: j['reason'] as String?,
    appeal: switch (j['appeal_status']) {
      'open' => AppealStatus.open,
      'rejected' => AppealStatus.rejected,
      'lifted' => AppealStatus.lifted,
      _ => null,
    },
    appealNote: j['appeal_note'] as String?,
  );
}

enum AppealStatus { open, rejected, lifted }

/// Shortest and longest appeal text (also enforced by the database).
const minAppealLength = 10;
const maxAppealLength = 1000;

abstract interface class TrustRepository {
  Future<void> report(
    ReportTarget target,
    String targetId,
    ReportReason reason,
    String? details,
  );

  Future<VerificationInfo> myVerification();

  Future<AccountStatus> myAccountStatus();

  Future<void> submitAppeal(String message);

  /// Uploads [documents] to the private bucket, then sends them for review.
  /// Files from a failed attempt are removed again.
  Future<void> submitVerification(List<PreparedPhoto> documents);

  Future<void> cancelVerification();
}

class NotConfiguredTrustRepository implements TrustRepository {
  const NotConfiguredTrustRepository();
  @override
  Future<void> report(
    ReportTarget target,
    String targetId,
    ReportReason reason,
    String? details,
  ) async => throw const RequestsError(RequestsFailure.notConfigured);
  @override
  Future<VerificationInfo> myVerification() async =>
      throw const RequestsError(RequestsFailure.notConfigured);
  @override
  Future<AccountStatus> myAccountStatus() async => AccountStatus.none;
  @override
  Future<void> submitAppeal(String message) async =>
      throw const RequestsError(RequestsFailure.notConfigured);
  @override
  Future<void> submitVerification(List<PreparedPhoto> documents) async =>
      throw const RequestsError(RequestsFailure.notConfigured);
  @override
  Future<void> cancelVerification() async =>
      throw const RequestsError(RequestsFailure.notConfigured);
}
