import '../../portfolio/domain/portfolio_domain.dart';
import '../../requests/domain/requests_domain.dart';

/// Most documents one verification request can carry (also enforced by the
/// database).
const maxVerificationDocuments = 3;

/// Where a report is about. Reports on a review or a conversation are only
/// possible for what the reporter can see. The names are the values the
/// database function `report_content` takes.
enum ReportTarget {
  professional,
  review,
  conversation,
  freelancer,
  testimonial,
}

enum ReportReason { spam, fake, abuse, scam, inappropriate, other }

/// Longest free text accepted with a report.
const maxReportDetails = 500;

enum VerificationStatus { none, pending, approved, rejected, cancelled }

class VerificationInfo {
  const VerificationInfo({required this.status, this.rejectReason});
  final VerificationStatus status;

  /// Why the last request was turned down (only for [VerificationStatus.rejected]).
  final String? rejectReason;
}

abstract interface class TrustRepository {
  Future<void> report(
    ReportTarget target,
    String targetId,
    ReportReason reason,
    String? details,
  );

  Future<VerificationInfo> myVerification();

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
  Future<void> submitVerification(List<PreparedPhoto> documents) async =>
      throw const RequestsError(RequestsFailure.notConfigured);
  @override
  Future<void> cancelVerification() async =>
      throw const RequestsError(RequestsFailure.notConfigured);
}
