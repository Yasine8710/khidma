import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../marketplace/application/marketplace_providers.dart'
    show kDemoDataAllowed;
import '../../portfolio/application/portfolio_providers.dart';
import '../../portfolio/domain/portfolio_domain.dart';
import '../data/demo_freelance_repository.dart';
import '../data/image_picker_clip_picker.dart';
import '../domain/freelance_domain.dart';

/// Overridden in `main()` with the Supabase repository when a backend is
/// configured. Otherwise: demo data in development, empty in release.
final freelanceRepositoryProvider = Provider<FreelanceRepository>(
  (ref) => kDemoDataAllowed
      ? const DemoFreelanceRepository()
      : const NotConfiguredFreelanceRepository(),
);

final clipPickerProvider = Provider<ClipPicker>(
  (ref) => const ImagePickerClipPicker(),
);

/// Where the public testimonial page lives (`--dart-define=TESTIMONIAL_BASE_URL=
/// https://...`, no trailing slash needed). Empty: invitations cannot be
/// shared yet and the screen says so. Replaced in tests.
final testimonialBaseUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment('TESTIMONIAL_BASE_URL'),
);

/// `<base>/t/<token>`, or null while the base address is not configured or is
/// not an https address (a token must never be put in a plain http link).
String? testimonialLink(String baseUrl, String token) {
  final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(base);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
  if (uri.scheme != 'https') return null;
  return '$base/t/$token';
}

final digitalCategoriesProvider = FutureProvider<List<DigitalCategory>>(
  retry: (n, e) => null,
  (ref) => ref.watch(freelanceRepositoryProvider).categories(),
);

final freelancerSearchProvider = FutureProvider.autoDispose
    .family<List<FreelancerSummary>, FreelanceQuery>(
      retry: (n, e) => null,
      (ref, q) => ref.watch(freelanceRepositoryProvider).search(q),
    );

final freelancerProvider = FutureProvider.autoDispose
    .family<FreelancerSummary?, String>(
      retry: (n, e) => null,
      (ref, id) => ref.watch(freelanceRepositoryProvider).freelancer(id),
    );

final freelancerPortfolioProvider = FutureProvider.autoDispose
    .family<List<FreelancePortfolioItem>, String>(
      retry: (n, e) => null,
      (ref, id) => ref.watch(freelanceRepositoryProvider).portfolio(id),
    );

final freelancerTestimonialsProvider = FutureProvider.autoDispose
    .family<List<Testimonial>, String>(
      retry: (n, e) => null,
      (ref, id) => ref.watch(freelanceRepositoryProvider).testimonials(id),
    );

// Contact: the same reveal flow as the local professionals.

sealed class FreelanceContactState {
  const FreelanceContactState();
}

class FreelanceContactHidden extends FreelanceContactState {
  const FreelanceContactHidden();
}

class FreelanceContactLoading extends FreelanceContactState {
  const FreelanceContactLoading();
}

class FreelanceContactRevealed extends FreelanceContactState {
  const FreelanceContactRevealed(this.phone);
  final String phone;
}

class FreelanceContactFailed extends FreelanceContactState {
  const FreelanceContactFailed(this.failure);
  final FreelanceFailure failure;
}

/// The revealed number of one freelancer, kept only while the page is open.
final freelanceContactProvider = NotifierProvider.autoDispose
    .family<FreelanceContactController, FreelanceContactState, String>(
      FreelanceContactController.new,
    );

class FreelanceContactController extends Notifier<FreelanceContactState> {
  FreelanceContactController(this.freelancerId);
  final String freelancerId;

  String? _account() => ref.read(currentUserProvider)?.id;

  @override
  FreelanceContactState build() {
    ref.watch(currentUserProvider.select((u) => u?.id));
    return const FreelanceContactHidden();
  }

  Future<void> reveal() async {
    if (state is FreelanceContactLoading) return;
    final account = _account();
    state = const FreelanceContactLoading();
    FreelanceContactState result;
    try {
      final phone = await ref
          .read(freelanceRepositoryProvider)
          .revealContact(freelancerId);
      result = FreelanceContactRevealed(phone);
    } on FreelanceError catch (e) {
      result = FreelanceContactFailed(e.failure);
    } catch (_) {
      result = const FreelanceContactFailed(FreelanceFailure.unknown);
    }
    if (!ref.mounted || _account() != account) return;
    state = result;
  }
}

// Owner side.

/// The signed-in person's freelance record; null when they are not a
/// freelancer yet (or signed out).
final myFreelancerProvider = FutureProvider.autoDispose<MyFreelancer?>(
  retry: (n, e) => null,
  (ref) async {
    final user = ref.watch(currentUserProvider.select((u) => u?.id));
    if (user == null) return null;
    return ref.watch(freelanceRepositoryProvider).mine();
  },
);

final myFreelancePortfolioProvider =
    FutureProvider.autoDispose<List<FreelancePortfolioItem>>(
      retry: (n, e) => null,
      (ref) async {
        final user = ref.watch(currentUserProvider.select((u) => u?.id));
        if (user == null) return const [];
        return ref.watch(freelanceRepositoryProvider).portfolio(user);
      },
    );

final myInvitesProvider = FutureProvider.autoDispose<List<TestimonialInvite>>(
  retry: (n, e) => null,
  (ref) async {
    final user = ref.watch(currentUserProvider.select((u) => u?.id));
    if (user == null) return const [];
    return ref.watch(freelanceRepositoryProvider).invites();
  },
);

/// Every owner action. [busy] is true while one runs, so a double tap cannot
/// send two. Each returns the failure, or null on success.
final freelanceActionsProvider = NotifierProvider<FreelanceActions, bool>(
  FreelanceActions.new,
);

class FreelanceActions extends Notifier<bool> {
  @override
  bool build() => false;

  FreelanceRepository get _repo => ref.read(freelanceRepositoryProvider);

  Future<FreelanceFailure?> _run(
    Future<void> Function() action, {
    void Function()? reload,
  }) async {
    if (state) return null;
    state = true;
    try {
      await action();
      if (ref.mounted) reload?.call();
      return null;
    } on FreelanceError catch (e) {
      return e.failure;
    } on PortfolioError catch (e) {
      return switch (e.failure) {
        PortfolioFailure.tooLarge => FreelanceFailure.tooLarge,
        PortfolioFailure.notAnImage => FreelanceFailure.notAnImage,
        _ => FreelanceFailure.unknown,
      };
    } catch (_) {
      return FreelanceFailure.unknown;
    } finally {
      if (ref.mounted) state = false;
    }
  }

  void _reloadMine() => ref.invalidate(myFreelancerProvider);
  void _reloadPortfolio() => ref.invalidate(myFreelancePortfolioProvider);

  Future<FreelanceFailure?> become() =>
      _run(_repo.becomeFreelancer, reload: _reloadMine);

  Future<FreelanceFailure?> save(FreelanceInput input) =>
      _run(() => _repo.save(input), reload: _reloadMine);

  Future<FreelanceFailure?> setPublished(bool published) =>
      _run(() => _repo.setPublished(published), reload: _reloadMine);

  /// Picks, prepares and uploads one photo. A cancelled pick is a success.
  Future<FreelanceFailure?> addPhoto({
    required String title,
    String? description,
  }) => _run(() async {
    final bytes = await ref.read(photoPickerProvider).pick();
    if (bytes == null) return;
    final prepared = await ref.read(photoPreparerProvider)(bytes);
    await _repo.addPhoto(prepared, title: title, description: description);
  }, reload: _reloadPortfolio);

  Future<FreelanceFailure?> addClip({
    required String title,
    String? description,
  }) => _run(() async {
    final clip = await ref.read(clipPickerProvider).pick();
    if (clip == null) return;
    await _repo.addClip(clip, title: title, description: description);
  }, reload: _reloadPortfolio);

  Future<FreelanceFailure?> addLink(
    PortfolioKind kind,
    String url, {
    required String title,
    String? description,
  }) => _run(
    () => _repo.addLink(kind, url, title: title, description: description),
    reload: _reloadPortfolio,
  );

  Future<FreelanceFailure?> updateItem(
    String id, {
    required String title,
    String? description,
  }) => _run(
    () => _repo.updateItem(id, title: title, description: description),
    reload: _reloadPortfolio,
  );

  Future<FreelanceFailure?> removeItem(FreelancePortfolioItem item) =>
      _run(() => _repo.removeItem(item), reload: _reloadPortfolio);

  /// Creates an invitation. The token is returned once and never stored.
  Future<({String? token, FreelanceFailure? failure})> createInvite({
    String? label,
  }) async {
    String? token;
    final failure = await _run(() async {
      token = await _repo.createInvite(label: label);
    }, reload: () => ref.invalidate(myInvitesProvider));
    return (token: token, failure: failure);
  }

  Future<FreelanceFailure?> revokeInvite(String id) => _run(
    () => _repo.revokeInvite(id),
    reload: () => ref.invalidate(myInvitesProvider),
  );
}
