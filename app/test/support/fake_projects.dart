import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:khidma/features/projects/domain/projects_domain.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';

RemoteProject sampleProject({
  String id = 'p1',
  RequestStatus status = RequestStatus.open,
  String? myOfferStatus,
}) => RemoteProject(
  id: id,
  title: 'Logo pour ma boutique',
  description: 'Un logo pour ma boutique de miel à Sfax.',
  categoryId: 1,
  deliverables: 'PNG et SVG',
  budgetMin: 100,
  budgetMax: 300,
  links: const ['https://pinterest.com/board/miel'],
  status: status,
  createdAt: DateTime(2026, 11, 13),
  expiresAt: DateTime.now().add(const Duration(days: 10)),
  myOfferStatus: myOfferStatus,
);

/// In-memory remote projects with call recording and a failure hook.
class FakeProjectsRepository implements ProjectsRepository {
  FakeProjectsRepository({List<RemoteProject>? projects, this.delivered})
    : projects = projects ?? [];

  final List<RemoteProject> projects;
  Deliveries? delivered;
  RequestsFailure? failNext;
  final created = <NewProject>[];
  final offers = <(String, double, int, int, String?)>[];
  final deliveries_ = <(String, String?, String?, int)>[];
  final revisions = <(String, String)>[];
  final opened = <String>[];

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw RequestsError(f);
    }
  }

  @override
  Future<String> create(NewProject project) async {
    _maybeFail();
    created.add(project);
    final p = sampleProject(id: 'new${created.length}');
    projects.add(p);
    return p.id;
  }

  @override
  Future<List<RemoteProject>> mine() async => [...projects];

  @override
  Future<List<RemoteProject>> open({int? categoryId}) async => [
    for (final p in projects)
      if (p.isOpen) p,
  ];

  @override
  Future<RemoteProject?> project(String id) async =>
      projects.where((p) => p.id == id).firstOrNull;

  @override
  Future<void> offer(
    String projectId, {
    required double price,
    required int days,
    required int revisions,
    String? message,
  }) async {
    _maybeFail();
    offers.add((projectId, price, days, revisions, message));
  }

  @override
  Future<Deliveries> deliveries(String bookingId) async =>
      delivered ?? const Deliveries();

  @override
  Future<void> deliver(
    String bookingId, {
    String? note,
    String? link,
    List<PreparedPhoto> photos = const [],
  }) async {
    _maybeFail();
    deliveries_.add((bookingId, note, link, photos.length));
  }

  @override
  Future<void> requestRevision(String bookingId, String note) async {
    _maybeFail();
    revisions.add((bookingId, note));
  }

  @override
  Future<Uri> fileLink(String path) async {
    opened.add(path);
    return Uri.parse('https://x.supabase.co/sign/$path');
  }
}
