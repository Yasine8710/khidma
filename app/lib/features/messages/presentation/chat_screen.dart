import '../../trust/domain/trust_domain.dart';
import '../../trust/presentation/report_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_image.dart';
import '../../requests/domain/requests_domain.dart';
import '../../requests/presentation/ledger_widgets.dart' show TypeEmpty;
import '../application/messages_providers.dart';
import '../domain/messages_domain.dart';
import 'messages_screen.dart' show conversationTitle;

/// One conversation: bubbles, a composer, photos. Opening it (and every new
/// message while it is open) marks it read. A closed conversation is
/// read-only.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  int _lastReadId = -1;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _failureText(
    AppLocalizations l10n,
    RequestsFailure f, {
    bool photo = false,
  }) => switch (f) {
    RequestsFailure.rateLimited => l10n.chatRateLimited,
    RequestsFailure.notOpen => l10n.chatClosed,
    _ => photo ? l10n.chatPhotoFailed : l10n.chatSendFailed,
  };

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    final failure = await ref
        .read(messageActionsProvider.notifier)
        .send(widget.conversationId, body);
    if (!mounted) return;
    setState(
      () => _error = failure == null ? null : _failureText(l10n, failure),
    );
    // What was typed stays if sending failed; text typed while it was being
    // sent stays too (only the sent text is cleared).
    if (failure == null && _controller.text.trim() == body) _controller.clear();
  }

  Future<void> _sendImage() async {
    final l10n = AppLocalizations.of(context);
    final failure = await ref
        .read(messageActionsProvider.notifier)
        .sendImage(widget.conversationId);
    if (!mounted) return;
    setState(
      () => _error = failure == null
          ? null
          : _failureText(l10n, failure, photo: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = ref.watch(messageActionsProvider);
    final async = ref.watch(chatMessagesProvider(widget.conversationId));
    final messages = async.value ?? const <ChatMessage>[];
    final summary = (ref.watch(conversationsProvider).value ?? const [])
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;
    final writable = summary?.writable ?? true;
    final iAmCustomer = summary?.iAmCustomer;

    // Mark read when the newest message changes (a message arriving while the
    // chat is open counts as read).
    final newest = messages.isEmpty ? -1 : messages.last.id;
    if (newest != _lastReadId && messages.isNotEmpty) {
      _lastReadId = newest;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(messageActionsProvider.notifier)
              .markRead(widget.conversationId, newest);
        }
      });
    }

    final Widget list;
    if (async.hasError && messages.isEmpty) {
      // The banner above says what is wrong and offers a retry.
      list = const SizedBox.shrink();
    } else if (messages.isEmpty && !async.isLoading) {
      list = TypeEmpty(
        icon: Icons.chat_bubble_outline_rounded,
        title: l10n.chatEmpty,
        body: '',
      );
    } else {
      list = ListView.builder(
        reverse: true,
        padding: const EdgeInsetsDirectional.all(AppSpacing.md),
        itemCount: messages.length,
        itemBuilder: (context, i) {
          final m = messages[messages.length - 1 - i];
          // Messages carry a role: mine is the one written by my side.
          final mine = iAmCustomer != null && m.fromCustomer == iAmCustomer;
          return _Bubble(message: m, mine: mine, locale: locale);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          summary == null ? l10n.navMessages : conversationTitle(l10n, summary),
        ),
        actions: [
          ReportButton(
            target: ReportTarget.conversation,
            targetId: widget.conversationId,
          ),
        ],
        bottom: summary == null
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(
                  MediaQuery.textScalerOf(context).scale(18) +
                      AppSpacing.sm +
                      1,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                      bottom: BorderSide(
                        color: scheme.onSurface,
                        width: AppInk.border,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.gutter,
                      end: AppSpacing.gutter,
                      bottom: AppSpacing.sm,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        summary.requestTitle,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (async.hasError)
              Material(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.chatLiveFailed,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(
                          chatMessagesProvider(widget.conversationId),
                        ),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: list),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    _error!,
                    style: text.bodySmall?.copyWith(color: scheme.error),
                  ),
                ),
              ),
            if (!writable)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  border: BorderDirectional(
                    top: BorderSide(
                      color: scheme.onSurface,
                      width: AppInk.border,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.chatReadOnly,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // The composer: a hard-edged paper band under a heavy ink rule.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: BorderDirectional(
                    top: BorderSide(
                      color: scheme.onSurface,
                      width: AppInk.border + 1,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: l10n.chatAddImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        onPressed: busy ? null : _sendImage,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: maxMessageLength,
                          textInputAction: TextInputAction.newline,
                          buildCounter: (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                          decoration: InputDecoration(
                            hintText: l10n.chatInputHint,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filled(
                        tooltip: l10n.chatSend,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            side: BorderSide(
                              color: scheme.onSurface,
                              width: AppInk.border,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_upward_rounded),
                        onPressed: busy ? null : _send,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.locale,
  });

  final ChatMessage message;
  final bool mine;
  final Locale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // Mine in the world colour, theirs on paper; both with a heavy ink border
    // and a hard shadow toward the sender's side.
    final bg = mine ? scheme.primaryContainer : scheme.surface;
    final fg = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dx = (mine != rtl) ? 3.0 : -3.0;
    const r = Radius.circular(AppRadius.xl);
    final who = mine ? l10n.chatYouSent : l10n.chatThem;
    final body = message.body;
    final image = message.imagePath;

    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Semantics(
          container: true,
          label: '$who, ${formatTime(message.createdAt, locale)}',
          child: Container(
            margin: const EdgeInsetsDirectional.fromSTEB(
              4,
              AppSpacing.xs,
              4,
              AppSpacing.xs + 3,
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.sm + 2,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: bg,
              // The corner on the sender's side is squared off.
              borderRadius: BorderRadiusDirectional.only(
                topStart: r,
                topEnd: r,
                bottomStart: mine ? r : Radius.zero,
                bottomEnd: mine ? Radius.zero : r,
              ),
              border: Border.all(color: scheme.onSurface, width: AppInk.border),
              boxShadow: [
                BoxShadow(
                  color: scheme.onSurface,
                  offset: Offset(dx, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (image != null) _ChatImage(path: image),
                if (body != null && body.isNotEmpty) ...[
                  if (image != null) const SizedBox(height: AppSpacing.sm),
                  SelectableText(
                    body,
                    style: text.bodyLarge?.copyWith(color: fg),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatTime(message.createdAt, locale),
                  style: text.labelSmall?.copyWith(
                    color: mine ? fg : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatImage extends ConsumerWidget {
  const _ChatImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final url = ref.watch(chatImageUrlProvider(path));
    return SizedBox(
      width: 220,
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: url.when(
          data: (u) => PortfolioImage(
            url: u,
            semanticLabel: l10n.chatPhoto,
            cacheWidth: 440,
          ),
          loading: () => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          error: (_, _) => Center(
            child: IconButton(
              tooltip: l10n.retry,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(chatImageUrlProvider(path)),
            ),
          ),
        ),
      ),
    );
  }
}
