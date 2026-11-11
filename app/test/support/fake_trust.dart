import 'dart:async';

import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';
import 'package:khidma/features/trust/domain/trust_domain.dart';

/// In-memory reports and verification with call recording and failure hooks.
class FakeTrustRepository implements TrustRepository {
  FakeTrustRepository({VerificationInfo? info})
    : info = info ?? const VerificationInfo(status: VerificationStatus.none);

  VerificationInfo info;
  final reports = <(ReportTarget, String, ReportReason, String?)>[];
  final submitted = <List<PreparedPhoto>>[];
  int cancels = 0;
  RequestsFailure? failNext;
  Completer<void>? gate;

  Future<void> _maybeFail() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw RequestsError(f);
    }
  }

  @override
  Future<void> report(
    ReportTarget target,
    String targetId,
    ReportReason reason,
    String? details,
  ) async {
    reports.add((target, targetId, reason, details));
    await _maybeFail();
  }

  @override
  Future<VerificationInfo> myVerification() async => info;

  @override
  Future<void> submitVerification(List<PreparedPhoto> documents) async {
    submitted.add(documents);
    await _maybeFail();
    info = const VerificationInfo(status: VerificationStatus.pending);
  }

  @override
  Future<void> cancelVerification() async {
    cancels++;
    await _maybeFail();
    info = const VerificationInfo(status: VerificationStatus.cancelled);
  }
}
