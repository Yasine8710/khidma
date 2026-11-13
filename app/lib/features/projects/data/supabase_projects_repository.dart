import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../portfolio/data/supabase_portfolio_repository.dart'
    show randomFileId;
import '../../portfolio/domain/portfolio_domain.dart' show PreparedPhoto;
import '../../requests/data/supabase_requests_repository.dart'
    show mapRequestsException;
import '../../requests/domain/requests_domain.dart';
import '../domain/projects_domain.dart';

const deliveriesBucket = 'deliveries';

/// Remote projects through the `*_remote_*` database functions; deliveries in
/// a private bucket that only the two parties of a booking can read.
class SupabaseProjectsRepository implements ProjectsRepository {
  SupabaseProjectsRepository(this._client, {this._random});

  final sb.SupabaseClient _client;
  final Random? _random;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw RequestsError(mapRequestsException(e));
    }
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static RemoteProject _project(Map<String, dynamic> r) => RemoteProject(
    id: r['id'] as String,
    title: (r['title'] as String?) ?? '',
    description: (r['description'] as String?) ?? '',
    categoryId: (r['digital_category_id'] as num?)?.toInt() ?? 0,
    deliverables: r['deliverables'] as String?,
    budgetMin: (r['budget_tnd'] as num?)?.toDouble(),
    budgetMax: (r['budget_max_tnd'] as num?)?.toDouble(),
    neededBy: r['needed_by'] is String
        ? DateTime.tryParse(r['needed_by'] as String)
        : null,
    links: [
      for (final l in (r['reference_links'] as List?) ?? const [])
        if (l is String) l,
    ],
    status: RequestStatus.values.firstWhere(
      (s) => s.name == r['status'],
      orElse: () => RequestStatus.expired,
    ),
    createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
    expiresAt: DateTime.parse(r['expires_at'] as String).toLocal(),
    offerCount: (r['offers_count'] as num?)?.toInt() ?? 0,
    myOfferStatus: r['my_offer_status'] as String?,
  );

  @override
  Future<String> create(NewProject p) => _guard(() async {
    final links = [
      for (final l in p.links)
        if (l.trim().isNotEmpty) l.trim(),
    ];
    if (links.length > maxProjectLinks || !links.every(isProjectLink)) {
      throw const RequestsError(RequestsFailure.invalidInput);
    }
    final id = await _client.rpc(
      'create_remote_request',
      params: {
        'p_title': p.title.trim(),
        'p_description': p.description.trim(),
        'p_digital_category': p.categoryId,
        'p_deliverables': p.deliverables.trim(),
        'p_budget_min': p.budgetMin,
        'p_budget_max': p.budgetMax,
        'p_needed_by': p.neededBy == null ? null : _day(p.neededBy!),
        'p_links': links,
      },
    );
    return id as String;
  });

  @override
  Future<List<RemoteProject>> mine() => _guard(() async {
    final rows = await _client.rpc('my_remote_requests') as List;
    return [for (final r in rows) _project(r as Map<String, dynamic>)];
  });

  @override
  Future<List<RemoteProject>> open({int? categoryId}) => _guard(() async {
    final rows = await _client.rpc(
      'list_remote_requests',
      params: {'p_category': categoryId, 'p_limit': 50},
    ) as List;
    return [for (final r in rows) _project(r as Map<String, dynamic>)];
  });

  @override
  Future<RemoteProject?> project(String id) => _guard(() async {
    final rows = await _client.rpc(
      'get_remote_request',
      params: {'p_request': id},
    ) as List;
    return rows.isEmpty ? null : _project(rows.first as Map<String, dynamic>);
  });

  @override
  Future<void> offer(
    String projectId, {
    required double price,
    required int days,
    required int revisions,
    String? message,
  }) => _guard(() async {
    final text = message?.trim();
    await _client.rpc(
      'submit_remote_offer',
      params: {
        'p_request': projectId,
        'p_price': price,
        'p_days': days,
        'p_revisions': revisions,
        'p_message': text == null || text.isEmpty ? null : text,
      },
    );
  });

  @override
  Future<Deliveries> deliveries(String bookingId) => _guard(() async {
    final rows = await _client.rpc(
      'booking_deliveries',
      params: {'p_booking': bookingId},
    ) as List;
    var used = 0;
    var included = 0;
    final items = <Delivery>[];
    for (final raw in rows) {
      final r = raw as Map<String, dynamic>;
      used = (r['revisions_used'] as num?)?.toInt() ?? used;
      included = (r['revisions_included'] as num?)?.toInt() ?? included;
      items.add(
        Delivery(
          id: r['id'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          note: r['note'] as String?,
          link: r['link'] as String?,
          paths: [
            for (final p in (r['paths'] as List?) ?? const [])
              if (p is String) p,
          ],
        ),
      );
    }
    return Deliveries(
      items: items,
      revisionsUsed: used,
      revisionsIncluded: included,
    );
  });

  @override
  Future<void> deliver(
    String bookingId, {
    String? note,
    String? link,
    List<PreparedPhoto> photos = const [],
  }) => _guard(() async {
    final n = note?.trim();
    final l = link?.trim();
    if (photos.length > maxDeliveryPhotos ||
        (l != null && l.isNotEmpty && !isProjectLink(l))) {
      throw const RequestsError(RequestsFailure.invalidInput);
    }
    final bucket = _client.storage.from(deliveriesBucket);
    final paths = [
      for (var i = 0; i < photos.length; i++)
        '$bookingId/${randomFileId(_random)}.jpg',
    ];
    try {
      for (var i = 0; i < photos.length; i++) {
        await bucket.uploadBinary(
          paths[i],
          photos[i].bytes,
          fileOptions: const sb.FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
      }
      await _client.rpc(
        'deliver_booking',
        params: {
          'p_booking': bookingId,
          'p_note': n == null || n.isEmpty ? null : n,
          'p_link': l == null || l.isEmpty ? null : l,
          'p_paths': paths,
        },
      );
    } catch (_) {
      // Not handed in: remove what was uploaded (handed-in files cannot be
      // removed, the database refuses).
      if (paths.isNotEmpty) {
        try {
          await bucket.remove(paths);
        } catch (_) {}
      }
      rethrow;
    }
  });

  @override
  Future<void> requestRevision(String bookingId, String note) =>
      _guard(() async {
        await _client.rpc(
          'request_revision',
          params: {'p_booking': bookingId, 'p_note': note.trim()},
        );
      });

  @override
  Future<Uri> fileLink(String path) => _guard(() async {
    final url = await _client.storage
        .from(deliveriesBucket)
        .createSignedUrl(path, 120);
    return Uri.parse(url);
  });
}
