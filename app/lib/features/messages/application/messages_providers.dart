import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../portfolio/application/portfolio_providers.dart';
import '../../requests/domain/requests_domain.dart';
import '../domain/messages_domain.dart';

/// Overridden in `main()` with the Supabase repository when configured.
final messagesRepositoryProvider = Provider<MessagesRepository>(
  (ref) => const NotConfiguredMessagesRepository(),
);

String? _uid(Ref ref) => ref.watch(currentUserProvider.select((u) => u?.id));

/// Ticks when any message in my conversations changes (new message, new
/// conversation): the inbox reloads on it. Quiet when the live connection is
/// not available.
final inboxPulseProvider = StreamProvider.autoDispose<int>((ref) {
  if (_uid(ref) == null) return const Stream<int>.empty();
  return ref.watch(messagesRepositoryProvider).pulse();
});

/// The inbox. Starts again for each account.
final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationSummary>>(
      retry: (n, e) => null,
      (ref) {
        if (_uid(ref) == null) {
          return Future.value(const <ConversationSummary>[]);
        }
        // A new message anywhere makes this load again.
        ref.watch(inboxPulseProvider);
        return ref.watch(messagesRepositoryProvider).conversations();
      },
    );

/// How many messages wait for me across all conversations (tab badge).
final unreadTotalProvider = Provider.autoDispose<int>((ref) {
  final list = ref.watch(conversationsProvider).value ?? const [];
  return list.fold(0, (sum, c) => sum + c.unread);
});

/// A conversation's messages, live while listened to (empty for anyone who is
/// not signed in).
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>(
      // A dropped live connection is retried a few times, then left to the person.
      retry: (n, e) => n >= 3 ? null : Duration(seconds: 2 * (n + 1)),
      (ref, id) {
        if (_uid(ref) == null) return Stream.value(const <ChatMessage>[]);
        return ref.watch(messagesRepositoryProvider).watch(id);
      },
    );

/// A short-lived link for one chat image.
final chatImageUrlProvider = FutureProvider.autoDispose.family<String, String>(
  retry: (n, e) => null,
  (ref, path) => ref.watch(messagesRepositoryProvider).imageUrl(path),
);

/// Sending, reading and opening conversations. [busy] is true while a send
/// runs, so a double tap cannot send twice.
final messageActionsProvider = NotifierProvider<MessageActions, bool>(
  MessageActions.new,
);

class MessageActions extends Notifier<bool> {
  @override
  bool build() => false;

  /// Returns the failure, or null on success.
  Future<RequestsFailure?> send(String conversationId, String body) => _run(
    () => ref.read(messagesRepositoryProvider).send(conversationId, body),
  );

  /// Picks one photo, prepares it and sends it. Null on success or when the
  /// person cancels.
  Future<RequestsFailure?> sendImage(String conversationId) async {
    if (state) return null;
    state = true;
    try {
      final picked = await ref.read(photoPickerProvider).pick();
      if (picked == null) return null;
      final prepared = await ref.read(photoPreparerProvider)(picked);
      await ref
          .read(messagesRepositoryProvider)
          .sendImage(conversationId, prepared);
      return null;
    } on RequestsError catch (e) {
      return e.failure;
    } catch (_) {
      return RequestsFailure.invalidInput;
    } finally {
      if (ref.mounted) {
        state = false;
        ref.invalidate(conversationsProvider);
      }
    }
  }

  Future<RequestsFailure?> _run(Future<void> Function() action) async {
    if (state) return null;
    state = true;
    try {
      await action();
      return null;
    } on RequestsError catch (e) {
      return e.failure;
    } catch (_) {
      return RequestsFailure.unknown;
    } finally {
      if (ref.mounted) {
        state = false;
        ref.invalidate(conversationsProvider);
      }
    }
  }

  /// Opens the conversation about an offer: its id, or the failure.
  Future<(String?, RequestsFailure?)> open(String offerId) async {
    try {
      final id = await ref
          .read(messagesRepositoryProvider)
          .startConversation(offerId);
      if (ref.mounted) ref.invalidate(conversationsProvider);
      return (id, null);
    } on RequestsError catch (e) {
      return (null, e.failure);
    } catch (_) {
      return (null, RequestsFailure.unknown);
    }
  }

  /// Marks a conversation read (best effort: failing is not worth a message).
  Future<void> markRead(String conversationId, int upToId) async {
    try {
      await ref
          .read(messagesRepositoryProvider)
          .markRead(conversationId, upToId);
      if (ref.mounted) ref.invalidate(conversationsProvider);
    } catch (_) {}
  }
}
