import '../../portfolio/domain/portfolio_domain.dart';
import '../../requests/domain/requests_domain.dart';

/// Longest message body (also enforced by the database).
const maxMessageLength = 2000;

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.offerId,
    required this.requestId,
    required this.requestTitle,
    required this.iAmCustomer,
    required this.unread,
    required this.writable,
    this.otherName,
    this.otherId,
    this.lastBody,
    this.lastHasImage = false,
    this.lastAt,
  });

  final String id;
  final String offerId;
  final String requestId;
  final String requestTitle;
  final bool iAmCustomer;

  /// The professional's public name (null for the customer's side: customers
  /// stay anonymous to professionals).
  final String? otherName;
  final String? otherId;
  final String? lastBody;
  final bool lastHasImage;
  final DateTime? lastAt;
  final int unread;

  /// False once the offer or request is closed: readable, not writable.
  final bool writable;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromCustomer,
    required this.createdAt,
    this.body,
    this.imagePath,
  });

  final int id;

  /// Written by the customer (true) or the professional (false). Messages
  /// carry a role, never a user id.
  final bool fromCustomer;
  final DateTime createdAt;
  final String? body;

  /// A path in the private chat bucket; shown through a signed link.
  final String? imagePath;
}

abstract interface class MessagesRepository {
  Future<List<ConversationSummary>> conversations();

  /// Opens (or reopens) the conversation about an offer; returns its id.
  Future<String> startConversation(String offerId);

  /// The messages of a conversation, oldest first.
  Future<List<ChatMessage>> messages(String conversationId);

  /// The same list, kept up to date while listened to.
  Stream<List<ChatMessage>> watch(String conversationId);

  Future<void> send(String conversationId, String body);
  Future<void> sendImage(String conversationId, PreparedPhoto photo);

  /// Marks messages up to [upToId] (what was actually shown) as read.
  Future<void> markRead(String conversationId, int upToId);

  /// Changes whenever any message in any of my conversations changes: the
  /// inbox refreshes on it. Emits the newest message id.
  Stream<int> pulse();

  /// A short-lived link to a chat image.
  Future<String> imageUrl(String path);
}

class NotConfiguredMessagesRepository implements MessagesRepository {
  const NotConfiguredMessagesRepository();
  Never _fail() => throw const RequestsError(RequestsFailure.notConfigured);
  @override
  Future<List<ConversationSummary>> conversations() async => const [];
  @override
  Future<String> startConversation(String offerId) async => _fail();
  @override
  Future<List<ChatMessage>> messages(String conversationId) async => const [];
  @override
  Stream<List<ChatMessage>> watch(String conversationId) =>
      Stream.value(const []);
  @override
  Future<void> send(String conversationId, String body) async => _fail();
  @override
  Future<void> sendImage(String conversationId, PreparedPhoto photo) async =>
      _fail();
  @override
  Future<void> markRead(String conversationId, int upToId) async {}
  @override
  Stream<int> pulse() => const Stream.empty();
  @override
  Future<String> imageUrl(String path) async => _fail();
}
