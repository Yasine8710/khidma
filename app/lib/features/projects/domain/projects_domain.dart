import '../../portfolio/domain/portfolio_domain.dart' show PreparedPhoto;
import '../../requests/domain/requests_domain.dart';

/// Most reference links on a project, and the rules they follow (also
/// enforced by the database).
const maxProjectLinks = 5;
const maxDeliveryPhotos = 10;
const maxRevisions = 20;

/// Plain https links only: no other scheme, no spaces, 300 characters at most.
bool isProjectLink(String s) =>
    s.length <= 300 &&
    RegExp(r'^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/\S*)?$').hasMatch(s);

/// A remote project: digital work with no place. Reuses the request, offer,
/// booking, chat and review machinery of local requests.
class RemoteProject {
  const RemoteProject({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.deliverables,
    this.budgetMin,
    this.budgetMax,
    this.neededBy,
    this.links = const [],
    this.offerCount = 0,
    this.myOfferStatus,
  });

  final String id;
  final String title;
  final String description;

  /// A digital category (not a local trade).
  final int categoryId;
  final String? deliverables;
  final double? budgetMin;
  final double? budgetMax;
  final DateTime? neededBy;
  final List<String> links;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int offerCount;

  /// The freelancer's own offer on it, when they made one ('pending', ...).
  final String? myOfferStatus;

  bool get isOpen =>
      status == RequestStatus.open && expiresAt.isAfter(DateTime.now());

  /// The same request as the shared offer and booking sections expect. They
  /// only read the id, status, expiry and offer count; category and place
  /// have no meaning for a remote project.
  QuoteRequest asRequest() => QuoteRequest(
    id: id,
    title: title,
    description: description,
    categoryId: 0,
    governorateId: 0,
    status: status,
    createdAt: createdAt,
    expiresAt: expiresAt,
    budgetTnd: budgetMin,
    neededBy: neededBy,
    offerCount: offerCount,
  );
}

class NewProject {
  const NewProject({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.deliverables,
    this.budgetMin,
    this.budgetMax,
    this.neededBy,
    this.links = const [],
  });

  final String title;
  final String description;
  final int categoryId;
  final String deliverables;
  final double? budgetMin;
  final double? budgetMax;
  final DateTime? neededBy;
  final List<String> links;
}

/// One hand-in of work on a remote job.
class Delivery {
  const Delivery({
    required this.id,
    required this.createdAt,
    this.note,
    this.link,
    this.paths = const [],
  });

  final String id;
  final DateTime createdAt;
  final String? note;
  final String? link;

  /// Files in the private deliveries bucket (open them with a signed link).
  final List<String> paths;
}

class Deliveries {
  const Deliveries({
    this.items = const [],
    this.revisionsUsed = 0,
    this.revisionsIncluded = 0,
  });

  final List<Delivery> items;
  final int revisionsUsed;
  final int revisionsIncluded;

  int get revisionsLeft =>
      (revisionsIncluded - revisionsUsed).clamp(0, maxRevisions);
}

abstract interface class ProjectsRepository {
  // customer
  Future<String> create(NewProject project);
  Future<List<RemoteProject>> mine();

  // freelancer
  Future<List<RemoteProject>> open({int? categoryId});
  Future<RemoteProject?> project(String id);
  Future<void> offer(
    String projectId, {
    required double price,
    required int days,
    required int revisions,
    String? message,
  });

  // both parties of a booking
  Future<Deliveries> deliveries(String bookingId);
  Future<void> deliver(
    String bookingId, {
    String? note,
    String? link,
    List<PreparedPhoto> photos = const [],
  });
  Future<void> requestRevision(String bookingId, String note);

  /// A short-lived link to one delivered file.
  Future<Uri> fileLink(String path);
}

class NotConfiguredProjectsRepository implements ProjectsRepository {
  const NotConfiguredProjectsRepository();
  static Never _fail() =>
      throw const RequestsError(RequestsFailure.notConfigured);
  @override
  Future<String> create(NewProject project) async => _fail();
  @override
  Future<List<RemoteProject>> mine() async => _fail();
  @override
  Future<List<RemoteProject>> open({int? categoryId}) async => _fail();
  @override
  Future<RemoteProject?> project(String id) async => _fail();
  @override
  Future<void> offer(
    String projectId, {
    required double price,
    required int days,
    required int revisions,
    String? message,
  }) async => _fail();
  @override
  Future<Deliveries> deliveries(String bookingId) async => _fail();
  @override
  Future<void> deliver(
    String bookingId, {
    String? note,
    String? link,
    List<PreparedPhoto> photos = const [],
  }) async => _fail();
  @override
  Future<void> requestRevision(String bookingId, String note) async => _fail();
  @override
  Future<Uri> fileLink(String path) async => _fail();
}
