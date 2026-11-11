import 'dart:async';

import 'package:khidma/features/messages/domain/messages_domain.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:khidma/features/requests/domain/requests_domain.dart';

/// In-memory messaging with a live stream per conversation, call recording and
/// failure hooks.
class FakeMessagesRepository implements MessagesRepository {
  FakeMessagesRepository({List<ConversationSummary>? conversations})
    : list = [...?conversations];

  final List<ConversationSummary> list;
  final Map<String, List<ChatMessage>> byConversation = {};
  final _controllers = <String, StreamController<List<ChatMessage>>>{};

  final sent = <(String, String)>[];
  final images = <(String, PreparedPhoto)>[];
  final reads = <String>[];
  final readUpTo = <int>[];
  final opened = <String>[];
  RequestsFailure? failNext;
  RequestsFailure? failOpen;
  bool streamFails = false;
  Completer<void>? gate;
  bool iAmCustomer = true;
  final pulseController = StreamController<int>.broadcast();
  int _n = 0;

  Future<void> _pre() async {
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw RequestsError(f);
    }
  }

  /// Delivers a message from the other side, live.
  void incoming(String conversationId, {String? body, String? image}) {
    _add(
      conversationId,
      ChatMessage(
        id: _next(conversationId),
        fromCustomer: !iAmCustomer,
        createdAt: DateTime(2026, 11, 10, 12, _n % 60),
        body: body,
        imagePath: image,
      ),
    );
  }

  /// A message id above every existing one (ids grow, like the database's).
  int _next(String conversationId) {
    var top = _n;
    for (final list in byConversation.values) {
      for (final m in list) {
        if (m.id > top) top = m.id;
      }
    }
    _n = top + 1;
    return _n;
  }

  void _add(String id, ChatMessage m) {
    (byConversation[id] ??= []).add(m);
    _controllers[id]?.add([...byConversation[id]!]);
  }

  @override
  Future<List<ConversationSummary>> conversations() async => [...list];

  @override
  Future<String> startConversation(String offerId) async {
    opened.add(offerId);
    final f = failOpen;
    if (f != null) {
      failOpen = null;
      throw RequestsError(f);
    }
    return list
            .where((c) => c.offerId == offerId)
            .map((c) => c.id)
            .firstOrNull ??
        'conv-$offerId';
  }

  @override
  Future<List<ChatMessage>> messages(String conversationId) async => [
    ...?byConversation[conversationId],
  ];

  @override
  Stream<List<ChatMessage>> watch(String conversationId) {
    if (streamFails) {
      return Stream.error(const RequestsError(RequestsFailure.network));
    }
    final c = _controllers.putIfAbsent(
      conversationId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    return (() async* {
      yield [...?byConversation[conversationId]];
      yield* c.stream;
    })();
  }

  @override
  Future<void> send(String conversationId, String body) async {
    sent.add((conversationId, body));
    await _pre();
    _add(
      conversationId,
      ChatMessage(
        id: _next(conversationId),
        fromCustomer: iAmCustomer,
        createdAt: DateTime(2026, 11, 10, 12, _n % 60),
        body: body,
      ),
    );
  }

  @override
  Future<void> sendImage(String conversationId, PreparedPhoto photo) async {
    images.add((conversationId, photo));
    await _pre();
    _add(
      conversationId,
      ChatMessage(
        id: _next(conversationId),
        fromCustomer: iAmCustomer,
        createdAt: DateTime(2026, 11, 10, 12, _n % 60),
        imagePath: '$conversationId/img$_n.jpg',
      ),
    );
  }

  @override
  Future<void> markRead(String conversationId, int upToId) async {
    reads.add(conversationId);
    readUpTo.add(upToId);
  }

  @override
  Stream<int> pulse() => pulseController.stream;

  @override
  Future<String> imageUrl(String path) async => 'https://example.invalid/$path';
}

ConversationSummary sampleConversation({
  String id = 'c1',
  String offerId = 'o1',
  bool iAmCustomer = true,
  String? otherName = 'Plomberie Ben Salah',
  int unread = 0,
  bool writable = true,
  String? lastBody = 'Bonjour',
  bool lastHasImage = false,
}) => ConversationSummary(
  id: id,
  offerId: offerId,
  requestId: 'r1',
  requestTitle: 'Fuite sous évier',
  iAmCustomer: iAmCustomer,
  otherName: iAmCustomer ? otherName : null,
  otherId: iAmCustomer ? 'demo-01' : null,
  lastBody: lastBody,
  lastHasImage: lastHasImage,
  lastAt: DateTime(2026, 11, 10),
  unread: unread,
  writable: writable,
);
