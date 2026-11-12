import 'dart:async';

import 'package:khidma/features/freelance/data/demo_freelance_repository.dart';
import 'package:khidma/features/freelance/domain/freelance_domain.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';

/// In-memory freelance backend for tests, with the same publishing rule as
/// the database (verified identity needed) and a record of what was done.
class FakeFreelanceRepository implements FreelanceRepository {
  FakeFreelanceRepository({
    this.me,
    List<FreelancerSummary>? freelancers,
    List<FreelancePortfolioItem>? items,
    List<Testimonial>? testimonials,
    List<TestimonialInvite>? invites,
    this.phone = '+21620123456',
  }) : freelancers = [...?freelancers],
       items = [...?items],
       _testimonials = [...?testimonials],
       _invites = [...?invites];

  MyFreelancer? me;
  final List<FreelancerSummary> freelancers;
  final List<FreelancePortfolioItem> items;
  final List<Testimonial> _testimonials;
  final List<TestimonialInvite> _invites;
  final String phone;

  FreelanceFailure? failNext;
  Completer<void>? gate;

  int becomeCalls = 0;
  final saved = <FreelanceInput>[];
  final publishCalls = <bool>[];
  final photos = <(PreparedPhoto, String)>[];
  final clips = <(PickedClip, String)>[];
  final links = <({PortfolioKind kind, String url, String title})>[];
  final removed = <String>[];
  final revoked = <String>[];
  final queries = <FreelanceQuery>[];
  int reveals = 0;
  int _n = 0;

  @override
  bool get isDemo => false;

  Future<void> _maybeFail() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw FreelanceError(f);
    }
  }

  @override
  Future<List<DigitalCategory>> categories() async => demoDigitalCategories;

  @override
  Future<List<FreelancerSummary>> search(FreelanceQuery q) async {
    queries.add(q);
    await _maybeFail();
    return [
      for (final f in freelancers)
        if ((q.categoryId == null || f.categoryId == q.categoryId) &&
            (q.text == null ||
                '${f.name} ${f.headline}'.toLowerCase().contains(
                  q.text!.toLowerCase(),
                )))
          f,
    ];
  }

  @override
  Future<FreelancerSummary?> freelancer(String id) async {
    await _maybeFail();
    return freelancers.where((f) => f.id == id).firstOrNull;
  }

  @override
  Future<List<FreelancePortfolioItem>> portfolio(String id) async => [...items];

  @override
  Future<List<Testimonial>> testimonials(String id) async => [..._testimonials];

  @override
  Future<String> revealContact(String id) async {
    reveals++;
    await _maybeFail();
    return phone;
  }

  @override
  Future<MyFreelancer?> mine() async {
    await _maybeFail();
    return me;
  }

  @override
  Future<void> becomeFreelancer() async {
    becomeCalls++;
    await _maybeFail();
    me = const MyFreelancer();
  }

  @override
  Future<void> save(FreelanceInput i) async {
    await _maybeFail();
    saved.add(i);
    me = MyFreelancer(
      name: i.name,
      headline: i.headline,
      bio: i.bio,
      categoryId: i.categoryId,
      skills: i.skills,
      languages: i.languages,
      yearsExperience: i.yearsExperience,
      startingPriceMillimes: i.startingPriceMillimes,
      priceUnit: i.priceUnit,
      availability: i.availability,
      isPublished: me?.isPublished ?? false,
      verification: me?.verification ?? Verification.unverified,
    );
  }

  @override
  Future<void> setPublished(bool published) async {
    publishCalls.add(published);
    await _maybeFail();
    final m = me!;
    if (published && !m.isVerified) {
      throw const FreelanceError(FreelanceFailure.notVerified);
    }
    me = MyFreelancer(
      name: m.name,
      headline: m.headline,
      bio: m.bio,
      categoryId: m.categoryId,
      skills: m.skills,
      languages: m.languages,
      yearsExperience: m.yearsExperience,
      startingPriceMillimes: m.startingPriceMillimes,
      priceUnit: m.priceUnit,
      availability: m.availability,
      isPublished: published,
      verification: m.verification,
    );
  }

  FreelancePortfolioItem _add(
    PortfolioKind kind,
    String title, {
    String? path,
    String? url,
  }) {
    if (items.length >= FreelanceRules.maxPortfolioItems) {
      throw const FreelanceError(FreelanceFailure.limitReached);
    }
    final item = FreelancePortfolioItem(
      id: 'i${_n++}',
      kind: kind,
      title: title,
      path: path,
      url: url,
    );
    items.add(item);
    return item;
  }

  @override
  Future<FreelancePortfolioItem> addPhoto(
    PreparedPhoto photo, {
    required String title,
    String? description,
  }) async {
    await _maybeFail();
    photos.add((photo, title));
    return _add(
      PortfolioKind.image,
      title,
      path: 'u1/f$_n.jpg',
      url: 'https://example.invalid/f$_n.jpg',
    );
  }

  @override
  Future<FreelancePortfolioItem> addClip(
    PickedClip clip, {
    required String title,
    String? description,
  }) async {
    await _maybeFail();
    clips.add((clip, title));
    return _add(PortfolioKind.videoFile, title, path: 'u1/c$_n.mp4');
  }

  @override
  Future<FreelancePortfolioItem> addLink(
    PortfolioKind kind,
    String url, {
    required String title,
    String? description,
  }) async {
    await _maybeFail();
    links.add((kind: kind, url: url, title: title));
    return _add(kind, title, url: url);
  }

  @override
  Future<void> updateItem(
    String id, {
    required String title,
    String? description,
  }) async {
    await _maybeFail();
    final i = items.indexWhere((x) => x.id == id);
    final old = items[i];
    items[i] = FreelancePortfolioItem(
      id: old.id,
      kind: old.kind,
      title: title,
      path: old.path,
      url: old.url,
    );
  }

  @override
  Future<void> removeItem(FreelancePortfolioItem item) async {
    await _maybeFail();
    removed.add(item.id);
    items.removeWhere((x) => x.id == item.id);
  }

  @override
  Future<List<TestimonialInvite>> invites() async => [..._invites];

  @override
  Future<String> createInvite({String? label}) async {
    await _maybeFail();
    final now = DateTime.now();
    _invites.insert(
      0,
      TestimonialInvite(
        id: 'inv${_n++}',
        label: label?.trim().isEmpty ?? true ? null : label!.trim(),
        expiresAt: now.add(const Duration(days: 30)),
        createdAt: now,
      ),
    );
    return 'ab' * 32;
  }

  @override
  Future<void> revokeInvite(String id) async {
    await _maybeFail();
    revoked.add(id);
    _invites.removeWhere((x) => x.id == id);
  }
}

class FakeClipPicker implements ClipPicker {
  FakeClipPicker([this.next]);
  PickedClip? next;
  FreelanceFailure? fail;
  int picks = 0;

  @override
  Future<PickedClip?> pick() async {
    picks++;
    if (fail != null) throw FreelanceError(fail!);
    return next;
  }
}
