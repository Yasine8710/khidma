import 'dart:typed_data';

import '../../marketplace/domain/marketplace_domain.dart';
import '../../portfolio/domain/portfolio_domain.dart';

/// Limits that mirror the database (checked again there).
abstract final class FreelanceRules {
  static const nameMin = 2;
  static const nameMax = 80;
  static const headlineMin = 5;
  static const headlineMax = 100;
  static const bioMin = 20; // needed to publish
  static const bioMax = 2000;
  static const maxSkills = 12;
  static const maxLanguages = 6;
  static const maxTagLength = 30;
  static const yearsMax = 60;
  static const priceMaxMillimes = 100000000;
  static const titleMin = 2;
  static const titleMax = 100;
  static const descriptionMax = 500;
  static const urlMax = 300;
  static const maxPortfolioItems = 24;
  static const maxInviteLabel = 100;
  static const maxPendingInvites = 20;

  /// Largest photo or clip the bucket accepts.
  static const maxFileBytes = 25 * 1024 * 1024;

  /// Longest clip the picker offers.
  static const maxClipSeconds = 30;

  static bool nameOk(String? v) {
    final n = v?.trim().length ?? 0;
    return n >= nameMin && n <= nameMax;
  }

  static bool headlineOk(String? v) {
    final n = v?.trim().length ?? 0;
    return n >= headlineMin && n <= headlineMax;
  }

  /// A bio is optional while drafting; when given it must fit the limit.
  static bool bioOk(String? v) => (v?.trim().length ?? 0) <= bioMax;

  static bool titleOk(String? v) {
    final n = v?.trim().length ?? 0;
    return n >= titleMin && n <= titleMax;
  }

  static bool descriptionOk(String? v) =>
      (v?.trim().length ?? 0) <= descriptionMax;

  /// Same pattern as the database check for `video_link` items.
  static final _videoLink = RegExp(
    r'^https://(www\.)?(youtube\.com/watch\?v=[A-Za-z0-9_-]{6,20}'
    r'|youtu\.be/[A-Za-z0-9_-]{6,20}|vimeo\.com/[0-9]{5,12})'
    r'([&?][A-Za-z0-9=_&.-]*)?$',
  );

  /// Same pattern as the database check for `link` items.
  static final _link = RegExp(
    r'^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/[^\s]*)?$',
  );

  static bool videoLinkOk(String? v) {
    final s = v?.trim() ?? '';
    return s.length <= urlMax && _videoLink.hasMatch(s);
  }

  static bool linkOk(String? v) {
    final s = v?.trim() ?? '';
    return s.length <= urlMax && _link.hasMatch(s);
  }

  /// Splits "a, b,, c" into trimmed, non-empty, distinct, short items. At most
  /// [max] are kept; the rest are dropped (the form shows the count).
  static List<String> parseTags(String? raw, {required int max}) {
    final out = <String>[];
    for (final part in (raw ?? '').split(RegExp(r'[,،;\n]'))) {
      final s = part.trim();
      if (s.isEmpty || s.length > maxTagLength) continue;
      if (out.any((e) => e.toLowerCase() == s.toLowerCase())) continue;
      out.add(s);
      if (out.length == max) break;
    }
    return out;
  }

  /// Whether [raw] has items that [parseTags] would drop for being too long or
  /// beyond the maximum.
  static bool tagsOk(String? raw, {required int max}) {
    final parts = [
      for (final p in (raw ?? '').split(RegExp(r'[,،;\n]')))
        if (p.trim().isNotEmpty) p.trim(),
    ];
    if (parts.any((p) => p.length > maxTagLength)) return false;
    return parseTags(raw, max: 1000).length <= max;
  }

  /// "350" or "350,5" (dinars) to millimes. Null for anything else.
  static int? dinarsToMillimes(String? raw) {
    final s = (raw ?? '').trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    if (v == null || !v.isFinite || v < 0) return null;
    final m = (v * 1000).round();
    return m > priceMaxMillimes ? null : m;
  }

  static String millimesToDinars(int? millimes) {
    if (millimes == null) return '';
    if (millimes % 1000 == 0) return '${millimes ~/ 1000}';
    return (millimes / 1000)
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '');
  }
}

class DigitalCategory with Localized {
  const DigitalCategory({
    required this.id,
    required this.slug,
    required this.nameFr,
    required this.nameAr,
    required this.nameEn,
    this.icon = 'laptop',
    this.sortOrder = 0,
  });

  final int id;
  final String slug;
  @override
  final String nameFr;
  @override
  final String nameAr;
  @override
  final String nameEn;
  final String icon;
  final int sortOrder;
}

enum PriceUnit {
  project,
  hour,
  day;

  static PriceUnit parse(Object? v) =>
      PriceUnit.values.firstWhere((u) => u.name == v, orElse: () => project);
}

/// What a list row and the public page need about one freelancer. Built only
/// from public columns: the phone number is never part of it.
class FreelancerSummary {
  const FreelancerSummary({
    required this.id,
    required this.name,
    required this.headline,
    required this.categoryId,
    this.bio = '',
    this.skills = const [],
    this.languages = const [],
    this.yearsExperience,
    this.startingPriceMillimes,
    this.priceUnit = PriceUnit.project,
    this.availability = Availability.available,
    this.verification = Verification.unverified,
    this.rating = 0,
    this.reviewCount = 0,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String headline;
  final int categoryId;
  final String bio;
  final List<String> skills;
  final List<String> languages;
  final int? yearsExperience;
  final int? startingPriceMillimes;
  final PriceUnit priceUnit;
  final Availability availability;
  final Verification verification;

  /// Average of the published testimonials; meaningful only when
  /// [reviewCount] is above zero.
  final double rating;
  final int reviewCount;
  final String? avatarUrl;

  bool get isVerified => verification == Verification.verified;
}

enum PortfolioKind {
  image('image'),
  videoFile('video_file'),
  videoLink('video_link'),
  link('link');

  const PortfolioKind(this.wire);
  final String wire;

  static PortfolioKind parse(Object? v) => PortfolioKind.values.firstWhere(
    (k) => k.wire == v,
    orElse: () => PortfolioKind.link,
  );

  /// Photos are shown large inside the app; everything else opens outside.
  bool get opensInApp => this == PortfolioKind.image;
}

class FreelancePortfolioItem {
  const FreelancePortfolioItem({
    required this.id,
    required this.kind,
    required this.title,
    this.description = '',
    this.path,
    this.url,
    this.sortOrder = 0,
  });

  final String id;
  final PortfolioKind kind;
  final String title;
  final String description;

  /// Storage path for photos and clips.
  final String? path;

  /// Public address: of the file for photos and clips, the external address
  /// for video links and links.
  final String? url;
  final int sortOrder;
}

class Testimonial {
  const Testimonial({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.body,
    this.projectTitle,
    this.createdAt,
  });

  final String id;
  final String authorName;
  final String? projectTitle;
  final int rating;
  final String body;
  final DateTime? createdAt;
}

enum InviteStatus { open, used, expired }

class TestimonialInvite {
  const TestimonialInvite({
    required this.id,
    required this.expiresAt,
    required this.createdAt,
    this.label,
    this.usedAt,
  });

  final String id;
  final String? label;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime createdAt;

  InviteStatus statusAt(DateTime now) => usedAt != null
      ? InviteStatus.used
      : (!expiresAt.isAfter(now) ? InviteStatus.expired : InviteStatus.open);
}

/// The signed-in freelancer's own record (editable, published or not).
class MyFreelancer {
  const MyFreelancer({
    this.name,
    this.headline,
    this.bio,
    this.categoryId,
    this.skills = const [],
    this.languages = const [],
    this.yearsExperience,
    this.startingPriceMillimes,
    this.priceUnit = PriceUnit.project,
    this.availability = Availability.available,
    this.isPublished = false,
    this.verification = Verification.unverified,
  });

  final String? name;
  final String? headline;
  final String? bio;
  final int? categoryId;
  final List<String> skills;
  final List<String> languages;
  final int? yearsExperience;
  final int? startingPriceMillimes;
  final PriceUnit priceUnit;
  final Availability availability;
  final bool isPublished;

  /// One identity check shared with the local professional profile.
  final Verification verification;

  bool get isVerified => verification == Verification.verified;
}

/// The editable fields, as saved.
class FreelanceInput {
  const FreelanceInput({
    required this.name,
    required this.headline,
    required this.bio,
    required this.categoryId,
    required this.skills,
    required this.languages,
    required this.yearsExperience,
    required this.startingPriceMillimes,
    required this.priceUnit,
    required this.availability,
  });

  final String? name;
  final String? headline;
  final String? bio;
  final int? categoryId;
  final List<String> skills;
  final List<String> languages;
  final int? yearsExperience;
  final int? startingPriceMillimes;
  final PriceUnit priceUnit;
  final Availability availability;
}

/// A short clip picked on the device, checked for size and format.
class PickedClip {
  const PickedClip({required this.bytes, required this.extension});
  final Uint8List bytes;

  /// `mp4` or `webm`.
  final String extension;
}

/// Picks one short clip. Null when the person cancels. Throws
/// [FreelanceError] for a clip that is too big or in an unsupported format.
abstract interface class ClipPicker {
  Future<PickedClip?> pick();
}

class FreelanceQuery {
  const FreelanceQuery({this.text, this.categoryId, this.limit = 30});
  final String? text;
  final int? categoryId;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is FreelanceQuery &&
      other.text == text &&
      other.categoryId == categoryId &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(text, categoryId, limit);
}

enum FreelanceFailure {
  network,
  notSignedIn,
  forbidden,
  notConfigured,

  /// Publishing needs a verified identity.
  notVerified,

  /// Publishing needs a contact phone and a complete page.
  incomplete,
  suspended,

  /// 24 portfolio items, or 20 open invitations.
  limitReached,
  invalidInput,
  rateLimited,
  notFound,
  tooLarge,

  /// Clip in a format other than mp4 or webm.
  unsupportedFormat,

  /// A picked photo that cannot be read.
  notAnImage,
  unknown,
}

class FreelanceError implements Exception {
  const FreelanceError(this.failure);
  final FreelanceFailure failure;
  @override
  String toString() => 'FreelanceError($failure)';
}

abstract interface class FreelanceRepository {
  /// Whether the data is made up (the UI shows a notice).
  bool get isDemo;

  Future<List<DigitalCategory>> categories();
  Future<List<FreelancerSummary>> search(FreelanceQuery query);

  /// One published freelancer, or null (unknown, draft, unverified and
  /// suspended all look the same).
  Future<FreelancerSummary?> freelancer(String id);
  Future<List<FreelancePortfolioItem>> portfolio(String id);
  Future<List<Testimonial>> testimonials(String id);

  /// The phone number (E.164). Needs a registered account; rate limited.
  Future<String> revealContact(String id);

  // Owner side.

  /// The signed-in person's freelance record, or null when there is none.
  Future<MyFreelancer?> mine();
  Future<void> becomeFreelancer();
  Future<void> save(FreelanceInput input);
  Future<void> setPublished(bool published);

  Future<FreelancePortfolioItem> addPhoto(
    PreparedPhoto photo, {
    required String title,
    String? description,
  });
  Future<FreelancePortfolioItem> addClip(
    PickedClip clip, {
    required String title,
    String? description,
  });
  Future<FreelancePortfolioItem> addLink(
    PortfolioKind kind,
    String url, {
    required String title,
    String? description,
  });
  Future<void> updateItem(
    String id, {
    required String title,
    String? description,
  });
  Future<void> removeItem(FreelancePortfolioItem item);

  Future<List<TestimonialInvite>> invites();

  /// Creates an invitation and returns its secret token (64 hex characters).
  Future<String> createInvite({String? label});
  Future<void> revokeInvite(String id);
}

/// Used when there is no backend and demo data is off: honestly empty.
class NotConfiguredFreelanceRepository implements FreelanceRepository {
  const NotConfiguredFreelanceRepository();

  static const _nc = FreelanceError(FreelanceFailure.notConfigured);

  @override
  bool get isDemo => false;
  @override
  Future<List<DigitalCategory>> categories() async => const [];
  @override
  Future<List<FreelancerSummary>> search(FreelanceQuery query) async =>
      const [];
  @override
  Future<FreelancerSummary?> freelancer(String id) async => null;
  @override
  Future<List<FreelancePortfolioItem>> portfolio(String id) async => const [];
  @override
  Future<List<Testimonial>> testimonials(String id) async => const [];
  @override
  Future<String> revealContact(String id) async => throw _nc;
  @override
  Future<MyFreelancer?> mine() async => throw _nc;
  @override
  Future<void> becomeFreelancer() async => throw _nc;
  @override
  Future<void> save(FreelanceInput input) async => throw _nc;
  @override
  Future<void> setPublished(bool published) async => throw _nc;
  @override
  Future<FreelancePortfolioItem> addPhoto(
    PreparedPhoto photo, {
    required String title,
    String? description,
  }) async => throw _nc;
  @override
  Future<FreelancePortfolioItem> addClip(
    PickedClip clip, {
    required String title,
    String? description,
  }) async => throw _nc;
  @override
  Future<FreelancePortfolioItem> addLink(
    PortfolioKind kind,
    String url, {
    required String title,
    String? description,
  }) async => throw _nc;
  @override
  Future<void> updateItem(
    String id, {
    required String title,
    String? description,
  }) async => throw _nc;
  @override
  Future<void> removeItem(FreelancePortfolioItem item) async => throw _nc;
  @override
  Future<List<TestimonialInvite>> invites() async => throw _nc;
  @override
  Future<String> createInvite({String? label}) async => throw _nc;
  @override
  Future<void> revokeInvite(String id) async => throw _nc;
}
