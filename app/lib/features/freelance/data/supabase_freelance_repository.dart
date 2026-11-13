import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../marketplace/domain/marketplace_domain.dart';
import '../../portfolio/data/supabase_portfolio_repository.dart'
    show randomFileId;
import '../../portfolio/domain/portfolio_domain.dart';
import '../domain/freelance_domain.dart';

const freelanceMediaBucket = 'freelance-media';

/// Maps Supabase errors to a [FreelanceFailure]. Pure and tested; database
/// messages are never forwarded to the screen.
FreelanceFailure mapFreelanceException(Object error) {
  if (error is FreelanceError) return error.failure;
  if (error is TimeoutException) return FreelanceFailure.network;
  if (error is sb.StorageException) {
    switch (error.statusCode) {
      case '413':
        return FreelanceFailure.tooLarge;
      case '400':
      case '415':
        return FreelanceFailure.unsupportedFormat;
      case '401':
        return FreelanceFailure.notSignedIn;
      case '403':
        return FreelanceFailure.forbidden;
    }
    return FreelanceFailure.unknown;
  }
  if (error is sb.PostgrestException) {
    switch (error.code) {
      case '28000':
      case 'PGRST301':
      case 'PGRST302':
        return FreelanceFailure.notSignedIn;
      case 'P0002':
        return FreelanceFailure.notFound;
      case '42501':
        return FreelanceFailure.forbidden;
      case '23514': // a check constraint (length, pattern) refused the value
        return FreelanceFailure.invalidInput;
      case 'P0001':
        final m = error.message;
        if (m.contains('not_verified')) return FreelanceFailure.notVerified;
        if (m.contains('incomplete')) return FreelanceFailure.incomplete;
        if (m.contains('suspended')) return FreelanceFailure.suspended;
        if (m.contains('limit_reached')) return FreelanceFailure.limitReached;
        if (m.contains('invalid_input')) return FreelanceFailure.invalidInput;
        if (m.contains('rate_limited')) return FreelanceFailure.rateLimited;
        return FreelanceFailure.unknown;
    }
    return FreelanceFailure.unknown;
  }
  final name = error.runtimeType.toString();
  if (name.contains('ClientException') || name.contains('SocketException')) {
    return FreelanceFailure.network;
  }
  return FreelanceFailure.unknown;
}

/// Removes the characters that have a meaning inside a PostgREST filter value
/// or an ILIKE pattern, so a typed word is only ever a word.
String sanitizeSearchWord(String raw) =>
    raw.replaceAll(RegExp(r'[,()*%_\\"\x00-\x1f]'), ' ').trim();

/// Freelance services through PostgREST, RPCs and Storage. What anyone can
/// read is decided by Row Level Security and column grants; no phone number
/// is ever requested outside [revealContact].
class SupabaseFreelanceRepository implements FreelanceRepository {
  SupabaseFreelanceRepository(
    this._client, {
    String? Function()? userId,
    this._random,
  }) : _userId = userId ?? (() => _client.auth.currentUser?.id);

  final sb.SupabaseClient _client;
  final String? Function() _userId;
  final Random? _random;

  @override
  bool get isDemo => false;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw FreelanceError(mapFreelanceException(e));
    }
  }

  String _uid() {
    final uid = _userId();
    if (uid == null) throw const FreelanceError(FreelanceFailure.notSignedIn);
    return uid;
  }

  static const _cols =
      'user_id, display_name, headline, bio, primary_category_id, skills, '
      'languages, years_experience, starting_price_millimes, price_unit, '
      'availability, is_published, rating_avg, review_count';
  static const _withPro =
      '$_cols, professional_profiles(avatar_path, verification_status, verified_until)';

  @override
  Future<List<DigitalCategory>> categories() => _guard(() async {
    final rows = await _client
        .from('digital_categories')
        .select('id, slug, name_fr, name_ar, name_en, icon, sort_order')
        .order('sort_order', ascending: true);
    return [
      for (final r in rows)
        DigitalCategory(
          id: (r['id'] as num).toInt(),
          slug: r['slug'] as String,
          nameFr: r['name_fr'] as String,
          nameAr: r['name_ar'] as String,
          nameEn: r['name_en'] as String,
          icon: (r['icon'] as String?) ?? 'laptop',
          sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
        ),
    ];
  });

  @override
  Future<List<FreelancerSummary>> search(FreelanceQuery q) => _guard(() async {
    var query = _client
        .from('freelancer_profiles')
        .select(_withPro)
        .eq('is_published', true);
    final cat = q.categoryId;
    if (cat != null) query = query.eq('primary_category_id', cat);
    final word = sanitizeSearchWord(q.text ?? '');
    if (word.isNotEmpty) {
      query = query.or('display_name.ilike.*$word*,headline.ilike.*$word*');
    }
    final rows = await query
        .order('rating_avg', ascending: false)
        .order('review_count', ascending: false)
        .limit(q.limit);
    return [for (final r in rows) _summary(r)];
  });

  @override
  Future<FreelancerSummary?> freelancer(String id) => _guard(() async {
    final row = await _client
        .from('freelancer_profiles')
        .select(_withPro)
        .eq('user_id', id)
        .eq('is_published', true)
        .maybeSingle();
    return row == null ? null : _summary(row);
  });

  @override
  Future<List<FreelancePortfolioItem>> portfolio(String id) => _guard(() async {
    final rows = await _client
        .from('freelancer_portfolio_items')
        .select('id, kind, title, description, path, url, sort_order')
        .eq('freelancer_id', id)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return [for (final r in rows) _item(r)];
  });

  @override
  Future<List<Testimonial>> testimonials(String id) => _guard(() async {
    final rows = await _client
        .from('testimonials')
        .select('id, author_name, project_title, rating, body, created_at')
        .eq('freelancer_id', id)
        .eq('status', 'published')
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        Testimonial(
          id: r['id'] as String,
          authorName: r['author_name'] as String,
          projectTitle: r['project_title'] as String?,
          rating: (r['rating'] as num).toInt(),
          body: r['body'] as String,
          createdAt: DateTime.tryParse('${r['created_at']}'),
        ),
    ];
  });

  @override
  Future<String> revealContact(String id) => _guard(() async {
    final phone = await _client.rpc(
      'reveal_freelancer_contact',
      params: {'p_freelancer': id},
    );
    if (phone is! String || phone.isEmpty) {
      throw const FreelanceError(FreelanceFailure.notFound);
    }
    return phone;
  });

  // Owner side.

  @override
  Future<MyFreelancer?> mine() => _guard(() async {
    final uid = _uid();
    final row = await _client
        .from('freelancer_profiles')
        .select(_withPro)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    final s = _summary(row);
    return MyFreelancer(
      name: row['display_name'] as String?,
      headline: row['headline'] as String?,
      bio: row['bio'] as String?,
      categoryId: (row['primary_category_id'] as num?)?.toInt(),
      skills: s.skills,
      languages: s.languages,
      yearsExperience: s.yearsExperience,
      startingPriceMillimes: s.startingPriceMillimes,
      priceUnit: s.priceUnit,
      availability: s.availability,
      isPublished: row['is_published'] == true,
      verification: s.verification,
    );
  });

  @override
  Future<void> becomeFreelancer() =>
      _guard(() async => _client.rpc('become_freelancer'));

  static String? _blankToNull(String? v) {
    final s = v?.trim();
    return s == null || s.isEmpty ? null : s;
  }

  @override
  Future<void> save(FreelanceInput i) => _guard(() async {
    final uid = _uid();
    await _client
        .from('freelancer_profiles')
        .update({
          'display_name': _blankToNull(i.name),
          'headline': _blankToNull(i.headline),
          'bio': _blankToNull(i.bio),
          'primary_category_id': i.categoryId,
          'skills': i.skills,
          'languages': i.languages,
          'years_experience': i.yearsExperience,
          'starting_price_millimes': i.startingPriceMillimes,
          'price_unit': i.priceUnit.name,
          'availability': i.availability.name,
        })
        .eq('user_id', uid);
  });

  @override
  Future<void> setPublished(bool published) => _guard(() async {
    final uid = _uid();
    await _client
        .from('freelancer_profiles')
        .update({'is_published': published})
        .eq('user_id', uid);
  });

  Future<FreelancePortfolioItem> _addFile(
    List<int> bytes, {
    required String extension,
    required String contentType,
    required PortfolioKind kind,
    required String title,
    String? description,
  }) async {
    final uid = _uid();
    if (bytes.length > FreelanceRules.maxFileBytes) {
      throw const FreelanceError(FreelanceFailure.tooLarge);
    }
    final path = '$uid/${randomFileId(_random)}.$extension';
    final bucket = _client.storage.from(freelanceMediaBucket);
    await bucket.uploadBinary(
      path,
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      fileOptions: sb.FileOptions(contentType: contentType, upsert: false),
    );
    const cols = 'id, kind, title, description, path, url, sort_order';
    try {
      final row = await _client
          .from('freelancer_portfolio_items')
          .insert({
            'freelancer_id': uid,
            'kind': kind.wire,
            'title': title.trim(),
            'description': _blankToNull(description),
            'path': path,
          })
          .select(cols)
          .single();
      return _item(row);
    } catch (_) {
      // The answer may have been lost after the row was saved: if it exists,
      // the file is part of the page and must stay.
      try {
        final saved = await _client
            .from('freelancer_portfolio_items')
            .select(cols)
            .eq('path', path)
            .maybeSingle();
        if (saved != null) return _item(saved);
      } catch (_) {}
      try {
        await bucket.remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<FreelancePortfolioItem> addPhoto(
    PreparedPhoto photo, {
    required String title,
    String? description,
  }) => _guard(
    () => _addFile(
      photo.bytes,
      extension: 'jpg',
      contentType: 'image/jpeg',
      kind: PortfolioKind.image,
      title: title,
      description: description,
    ),
  );

  @override
  Future<FreelancePortfolioItem> addClip(
    PickedClip clip, {
    required String title,
    String? description,
  }) => _guard(() {
    final ext = clip.extension == 'webm' ? 'webm' : 'mp4';
    return _addFile(
      clip.bytes,
      extension: ext,
      contentType: ext == 'webm' ? 'video/webm' : 'video/mp4',
      kind: PortfolioKind.videoFile,
      title: title,
      description: description,
    );
  });

  @override
  Future<FreelancePortfolioItem> addLink(
    PortfolioKind kind,
    String url, {
    required String title,
    String? description,
  }) => _guard(() async {
    final uid = _uid();
    final ok = switch (kind) {
      PortfolioKind.videoLink => FreelanceRules.videoLinkOk(url),
      PortfolioKind.link => FreelanceRules.linkOk(url),
      _ => false,
    };
    if (!ok) throw const FreelanceError(FreelanceFailure.invalidInput);
    final row = await _client
        .from('freelancer_portfolio_items')
        .insert({
          'freelancer_id': uid,
          'kind': kind.wire,
          'title': title.trim(),
          'description': _blankToNull(description),
          'url': url.trim(),
        })
        .select('id, kind, title, description, path, url, sort_order')
        .single();
    return _item(row);
  });

  @override
  Future<void> updateItem(
    String id, {
    required String title,
    String? description,
  }) => _guard(() async {
    await _client
        .from('freelancer_portfolio_items')
        .update({
          'title': title.trim(),
          'description': _blankToNull(description),
        })
        .eq('id', id);
  });

  @override
  Future<void> removeItem(FreelancePortfolioItem item) => _guard(() async {
    // The file first: if that fails the item stays listed and can be removed
    // again (removing a missing file is harmless).
    final path = item.path;
    if (path != null) {
      await _client.storage.from(freelanceMediaBucket).remove([path]);
    }
    await _client.from('freelancer_portfolio_items').delete().eq('id', item.id);
  });

  @override
  Future<List<TestimonialInvite>> invites() => _guard(() async {
    final rows = await _client
        .from('freelancer_invites')
        .select('id, label, expires_at, used_at, created_at')
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        TestimonialInvite(
          id: r['id'] as String,
          label: r['label'] as String?,
          expiresAt: DateTime.parse('${r['expires_at']}'),
          usedAt: r['used_at'] == null
              ? null
              : DateTime.parse('${r['used_at']}'),
          createdAt: DateTime.parse('${r['created_at']}'),
        ),
    ];
  });

  @override
  Future<String> createInvite({String? label}) => _guard(() async {
    final token = await _client.rpc(
      'create_testimonial_invite',
      params: {'p_label': _blankToNull(label)},
    );
    if (token is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) {
      throw const FreelanceError(FreelanceFailure.unknown);
    }
    return token;
  });

  @override
  Future<void> revokeInvite(String id) => _guard(() async {
    await _client.from('freelancer_invites').delete().eq('id', id);
  });

  // Row mapping.

  FreelancePortfolioItem _item(Map<String, dynamic> r) {
    final kind = PortfolioKind.parse(r['kind']);
    final path = r['path'] as String?;
    final url = path != null
        ? _client.storage.from(freelanceMediaBucket).getPublicUrl(path)
        : r['url'] as String?;
    return FreelancePortfolioItem(
      id: r['id'] as String,
      kind: kind,
      title: (r['title'] as String?) ?? '',
      description: (r['description'] as String?) ?? '',
      path: path,
      url: url,
      sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  List<String> _strings(Object? v) => [
    if (v is List)
      for (final e in v) '$e',
  ];

  FreelancerSummary _summary(Map<String, dynamic> r) {
    final embed = r['professional_profiles'];
    final pro = embed is Map
        ? embed
        : (embed is List && embed.isNotEmpty && embed.first is Map
              ? embed.first as Map
              : null);
    final avatar = pro?['avatar_path'] as String?;
    return FreelancerSummary(
      id: r['user_id'] as String,
      name: (r['display_name'] as String?) ?? '',
      headline: (r['headline'] as String?) ?? '',
      categoryId: (r['primary_category_id'] as num?)?.toInt() ?? 0,
      bio: (r['bio'] as String?) ?? '',
      skills: _strings(r['skills']),
      languages: _strings(r['languages']),
      yearsExperience: (r['years_experience'] as num?)?.toInt(),
      startingPriceMillimes: (r['starting_price_millimes'] as num?)?.toInt(),
      priceUnit: PriceUnit.parse(r['price_unit']),
      availability: Availability.values.firstWhere(
        (a) => a.name == r['availability'],
        orElse: () => Availability.offline,
      ),
      verification: parseVerification(
        pro?['verification_status'],
        pro?['verified_until'],
      ),
      rating: (r['rating_avg'] as num?)?.toDouble() ?? 0,
      reviewCount: (r['review_count'] as num?)?.toInt() ?? 0,
      avatarUrl: avatar == null || avatar.isEmpty
          ? null
          : _client.storage.from('avatars').getPublicUrl(avatar),
    );
  }
}
