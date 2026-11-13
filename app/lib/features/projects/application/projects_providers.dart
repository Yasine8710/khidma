import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../marketplace/application/contact_providers.dart'
    show urlOpenerProvider;
import '../../portfolio/application/portfolio_providers.dart';
import '../../portfolio/domain/portfolio_domain.dart';
import '../../requests/domain/requests_domain.dart';
import '../domain/projects_domain.dart';

/// Overridden in `main()` with the Supabase repository when configured.
final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => const NotConfiguredProjectsRepository(),
);

/// The signed-in customer's remote projects (empty while signed out).
final myProjectsProvider = FutureProvider.autoDispose<List<RemoteProject>>(
  retry: (n, e) => null,
  (ref) {
    if (ref.watch(currentUserProvider.select((u) => u?.id)) == null) {
      return Future.value(const []);
    }
    return ref.watch(projectsRepositoryProvider).mine();
  },
);

/// Open remote projects for freelancers, by digital category (null: all).
final openProjectsProvider = FutureProvider.autoDispose
    .family<List<RemoteProject>, int?>(
      retry: (n, e) => null,
      (ref, category) =>
          ref.watch(projectsRepositoryProvider).open(categoryId: category),
    );

/// One project as a freelancer sees it.
final projectProvider = FutureProvider.autoDispose
    .family<RemoteProject?, String>(
      retry: (n, e) => null,
      (ref, id) => ref.watch(projectsRepositoryProvider).project(id),
    );

final deliveriesProvider = FutureProvider.autoDispose
    .family<Deliveries, String>(
      retry: (n, e) => null,
      (ref, bookingId) =>
          ref.watch(projectsRepositoryProvider).deliveries(bookingId),
    );

/// Creates projects, sends offers, hands in and reviews work. The state is
/// true while a call runs (a double tap sends once).
final projectActionsProvider = NotifierProvider<ProjectActions, bool>(
  ProjectActions.new,
);

class ProjectActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<({T? value, RequestsFailure? failure})> _run<T>(
    Future<T> Function(ProjectsRepository repo) action,
  ) async {
    if (state) return (value: null, failure: RequestsFailure.unknown);
    state = true;
    try {
      return (
        value: await action(ref.read(projectsRepositoryProvider)),
        failure: null,
      );
    } on RequestsError catch (e) {
      return (value: null, failure: e.failure);
    } catch (_) {
      return (value: null, failure: RequestsFailure.unknown);
    } finally {
      if (ref.mounted) state = false;
    }
  }

  Future<({String? id, RequestsFailure? failure})> create(
    NewProject project,
  ) async {
    final r = await _run((repo) => repo.create(project));
    if (r.value != null && ref.mounted) ref.invalidate(myProjectsProvider);
    return (id: r.value, failure: r.failure);
  }

  Future<RequestsFailure?> offer(
    String projectId, {
    required double price,
    required int days,
    required int revisions,
    String? message,
  }) async {
    final r = await _run(
      (repo) => repo
          .offer(
            projectId,
            price: price,
            days: days,
            revisions: revisions,
            message: message,
          )
          .then((_) => true),
    );
    if (r.failure == null && ref.mounted) {
      ref.invalidate(projectProvider(projectId));
    }
    return r.failure;
  }

  Future<RequestsFailure?> deliver(
    String bookingId, {
    String? note,
    String? link,
    List<PreparedPhoto> photos = const [],
  }) async {
    final r = await _run(
      (repo) => repo
          .deliver(bookingId, note: note, link: link, photos: photos)
          .then((_) => true),
    );
    if (ref.mounted) ref.invalidate(deliveriesProvider(bookingId));
    return r.failure;
  }

  Future<RequestsFailure?> requestRevision(
    String bookingId,
    String note,
  ) async {
    final r = await _run(
      (repo) => repo.requestRevision(bookingId, note).then((_) => true),
    );
    if (ref.mounted) ref.invalidate(deliveriesProvider(bookingId));
    return r.failure;
  }

  /// Picks one photo for a delivery (null when cancelled or unreadable).
  Future<PreparedPhoto?> pickPhoto() async {
    try {
      final bytes = await ref.read(photoPickerProvider).pick();
      if (bytes == null) return null;
      return await ref.read(photoPreparerProvider)(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Opens a delivered file through a short-lived link.
  Future<bool> openFile(String path) async {
    try {
      final link = await ref.read(projectsRepositoryProvider).fileLink(path);
      return await ref.read(urlOpenerProvider)(link);
    } catch (_) {
      return false;
    }
  }
}
