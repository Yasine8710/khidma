import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../portfolio/data/supabase_portfolio_repository.dart'
    show randomFileId;
import '../../portfolio/domain/portfolio_domain.dart';
import '../../requests/data/supabase_requests_repository.dart'
    show mapRequestsException;
import '../../requests/domain/requests_domain.dart';
import '../domain/trust_domain.dart';

const verificationBucket = 'verification-docs';

/// Reports and verification through database functions. Documents go to a
/// private bucket that only the owner and admins can read; they are deleted
/// as soon as an admin decides.
class SupabaseTrustRepository implements TrustRepository {
  SupabaseTrustRepository(
    this._client, {
    String? Function()? userId,
    this._random,
  }) : _userId = userId ?? (() => _client.auth.currentUser?.id);

  final sb.SupabaseClient _client;
  final String? Function() _userId;
  final Random? _random;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw RequestsError(mapRequestsException(e));
    }
  }

  @override
  Future<void> report(
    ReportTarget target,
    String targetId,
    ReportReason reason,
    String? details,
  ) => _guard(() async {
    final text = details?.trim();
    final body = text == null || text.isEmpty ? null : text;
    if (target == ReportTarget.message) {
      final id = int.tryParse(targetId);
      if (id == null) throw const RequestsError(RequestsFailure.invalidInput);
      await _client.rpc(
        'report_message',
        params: {'p_message': id, 'p_reason': reason.dbName, 'p_details': body},
      );
      return;
    }
    await _client.rpc(
      'report_content',
      params: {
        'p_type': target.name,
        'p_target': targetId,
        'p_reason': reason.dbName,
        'p_details': body,
      },
    );
  });

  @override
  Future<AccountStatus> myAccountStatus() => _guard(() async {
    if (_userId() == null) return AccountStatus.none;
    final data = await _client.rpc('my_account_status');
    return data is Map<String, dynamic>
        ? AccountStatus.fromJson(data)
        : AccountStatus.none;
  });

  @override
  Future<void> submitAppeal(String message) => _guard(() async {
    final text = message.trim();
    if (text.length < minAppealLength || text.length > maxAppealLength) {
      throw const RequestsError(RequestsFailure.invalidInput);
    }
    await _client.rpc('submit_appeal', params: {'p_message': text});
  });

  @override
  Future<VerificationInfo> myVerification() => _guard(() async {
    final rows = await _client.rpc('my_verification') as List;
    if (rows.isEmpty) {
      return const VerificationInfo(status: VerificationStatus.none);
    }
    final r = rows.first as Map<String, dynamic>;
    return VerificationInfo(
      status: VerificationStatus.values.firstWhere(
        (s) => s.name == r['status'],
        orElse: () => VerificationStatus.none,
      ),
      rejectReason: r['reject_reason'] as String?,
    );
  });

  @override
  Future<void> submitVerification(List<PreparedPhoto> documents) =>
      _guard(() async {
        final uid = _userId();
        if (uid == null) {
          throw const RequestsError(RequestsFailure.notSignedIn);
        }
        if (documents.isEmpty || documents.length > maxVerificationDocuments) {
          throw const RequestsError(RequestsFailure.invalidInput);
        }
        final bucket = _client.storage.from(verificationBucket);
        // Names are chosen up front and all of them are cleaned up on failure:
        // an upload whose answer was lost may still have saved the file.
        final paths = [
          for (var i = 0; i < documents.length; i++)
            '$uid/${randomFileId(_random)}.jpg',
        ];
        try {
          for (var i = 0; i < documents.length; i++) {
            await bucket.uploadBinary(
              paths[i],
              documents[i].bytes,
              fileOptions: const sb.FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );
          }
          await _client.rpc('submit_verification', params: {'p_paths': paths});
        } catch (_) {
          // Nothing was submitted (the files are not attached to a request):
          // do not leave identity documents behind. If the answer was lost
          // after the request was saved, the removal is refused by the
          // database for attached files, which is the right outcome.
          try {
            await bucket.remove(paths);
          } catch (_) {}
          rethrow;
        }
      });

  @override
  Future<void> cancelVerification() => _guard(() async {
    await _client.rpc('cancel_verification');
  });
}
