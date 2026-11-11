import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../portfolio/data/supabase_portfolio_repository.dart'
    show randomFileId;
import '../../portfolio/domain/portfolio_domain.dart';
import '../../requests/data/supabase_requests_repository.dart'
    show mapRequestsException;
import '../../requests/domain/requests_domain.dart';
import '../domain/messages_domain.dart';

const chatBucket = 'chat-images';

/// Conversations through database functions (writes) and RLS-narrowed reads
/// (only the two members ever see a message); images in a private bucket.
class SupabaseMessagesRepository implements MessagesRepository {
  SupabaseMessagesRepository(this._client, {this.random});

  final sb.SupabaseClient _client;
  final Random? random;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw RequestsError(mapRequestsException(e));
    }
  }

  ChatMessage _message(Map<String, dynamic> r) => ChatMessage(
    id: (r['id'] as num).toInt(),
    fromCustomer: r['sender_is_customer'] == true,
    createdAt: DateTime.parse(r['created_at'] as String),
    body: r['body'] as String?,
    imagePath: r['image_path'] as String?,
  );

  @override
  Future<List<ConversationSummary>> conversations() => _guard(() async {
    final rows = await _client.rpc('my_conversations');
    return [
      for (final r in rows as List)
        ConversationSummary(
          id: r['conversation_id'] as String,
          offerId: r['offer_id'] as String,
          requestId: r['request_id'] as String,
          requestTitle: r['request_title'] as String,
          iAmCustomer: r['i_am_customer'] == true,
          otherName: r['other_name'] as String?,
          otherId: r['other_id'] as String?,
          lastBody: r['last_body'] as String?,
          lastHasImage: r['last_has_image'] == true,
          lastAt: r['last_at'] == null
              ? null
              : DateTime.parse(r['last_at'] as String),
          unread: (r['unread_count'] as num?)?.toInt() ?? 0,
          writable: r['writable'] == true,
        ),
    ];
  });

  @override
  Future<String> startConversation(String offerId) => _guard(() async {
    final id = await _client.rpc(
      'start_conversation',
      params: {'p_offer': offerId},
    );
    if (id is! String || id.isEmpty) {
      throw const RequestsError(RequestsFailure.unknown);
    }
    return id;
  });

  @override
  Future<List<ChatMessage>> messages(String conversationId) => _guard(() async {
    final rows = await _client
        .from('messages')
        .select('id, sender_is_customer, body, image_path, created_at')
        .eq('conversation_id', conversationId)
        .order('id', ascending: true)
        .limit(500);
    return [for (final r in rows) _message(r)];
  });

  @override
  Stream<List<ChatMessage>> watch(String conversationId) => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('id', ascending: true)
      .map((rows) => [for (final r in rows) _message(r)]);

  @override
  Future<void> send(String conversationId, String body) => _guard(() async {
    await _client.rpc(
      'send_message',
      params: {
        'p_conversation': conversationId,
        'p_body': body,
        'p_image_path': null,
      },
    );
  });

  @override
  Future<void> sendImage(String conversationId, PreparedPhoto photo) =>
      _guard(() async {
        if (photo.bytes.length > maxUploadBytes) {
          throw const RequestsError(RequestsFailure.invalidInput);
        }
        final path = '$conversationId/${randomFileId(random)}.jpg';
        final bucket = _client.storage.from(chatBucket);
        await bucket.uploadBinary(
          path,
          photo.bytes,
          fileOptions: const sb.FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
        try {
          await _client.rpc(
            'send_message',
            params: {
              'p_conversation': conversationId,
              'p_body': null,
              'p_image_path': path,
            },
          );
        } catch (_) {
          // Not part of the conversation: do not leave the file behind.
          try {
            await bucket.remove([path]);
          } catch (_) {}
          rethrow;
        }
      });

  @override
  Future<void> markRead(String conversationId, int upToId) => _guard(() async {
    await _client.rpc(
      'mark_conversation_read',
      params: {'p_conversation': conversationId, 'p_up_to': upToId},
    );
  });

  @override
  Stream<int> pulse() => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .order('id', ascending: false)
      .limit(1)
      .map((rows) => rows.isEmpty ? 0 : (rows.first['id'] as num).toInt());

  @override
  Future<String> imageUrl(String path) => _guard(() async {
    return _client.storage.from(chatBucket).createSignedUrl(path, 3600);
  });
}
