import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/motion/motion.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/signed_out_prompt.dart';
import '../../requests/presentation/flow_widgets.dart';
import '../application/messages_providers.dart';
import '../domain/messages_domain.dart';

/// The inbox: my conversations, most recent first, with unread counts.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(currentUserProvider) != null;
    if (!signedIn) {
      return SafeArea(
        child: SignedOutPrompt(
          icon: Icons.chat_bubble_outline_rounded,
          title: l10n.messagesSignedOutTitle,
          body: l10n.messagesSignedOutBody,
        ),
      );
    }
    final async = ref.watch(conversationsProvider);
    final list = async.value;
    final Widget body;
    if (list != null) {
      body = list.isEmpty
          ? CalmEmpty(
              icon: Icons.chat_bubble_outline_rounded,
              title: l10n.messagesEmptyTitle,
              body: l10n.messagesEmptyBody,
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(conversationsProvider);
                try {
                  await ref.read(conversationsProvider.future);
                } catch (_) {}
              },
              child: ListView.separated(
                padding: const EdgeInsetsDirectional.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.lg,
                ),
                itemCount: list.length,
                // Hairlines start under the text, like a phone's inbox.
                separatorBuilder: (_, _) => const Hairline(
                  indent: AppSpacing.gutter + _avatar + AppSpacing.md,
                ),
                itemBuilder: (context, i) =>
                    _Row(conversation: list[i], index: i),
              ),
            );
    } else if (async.hasError) {
      body = ErrorState(onRetry: () => ref.invalidate(conversationsProvider));
    } else {
      body = const SkeletonGroup(
        child: Padding(
          padding: EdgeInsetsDirectional.all(AppSpacing.gutter),
          child: Skeleton(height: 72, radius: AppRadius.lg),
        ),
      );
    }
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                header: true,
                child: Text(
                  l10n.navMessages,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Who a conversation is with: the professional's public name, or "Customer".
String conversationTitle(AppLocalizations l10n, ConversationSummary c) =>
    c.iAmCustomer && (c.otherName?.isNotEmpty ?? false)
    ? c.otherName!
    : (c.iAmCustomer ? l10n.offerProUnknown : l10n.chatTitleClient);

/// Today's messages show the time, older ones the date.
String _when(DateTime at, Locale locale) {
  final now = DateTime.now();
  final local = at.toLocal();
  final today =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  return today ? formatTime(local, locale) : formatDate(local, locale);
}

/// Avatar size in the inbox.
const double _avatar = 52;

/// One conversation, like a phone's inbox: avatar, name and time, what the
/// request is, the last message and the unread count. The whole row opens
/// the chat and is one button for assistive tech.
class _Row extends StatelessWidget {
  const _Row({required this.conversation, this.index = 0});

  final ConversationSummary conversation;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final c = conversation;
    final title = conversationTitle(l10n, c);
    final preview =
        c.lastHasImage && (c.lastBody == null || c.lastBody!.isEmpty)
        ? l10n.chatImageSent
        : (c.lastBody ?? '');
    final unread = c.unread > 0;
    void open() => context.push(AppRoutes.chatPath(c.id));

    final row = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonAvatar(name: title, size: _avatar),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: text.titleMedium?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (c.lastAt != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _when(c.lastAt!, locale),
                        style: text.bodySmall?.copyWith(
                          color: unread ? scheme.primary : muted,
                          fontWeight: unread ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  c.requestTitle,
                  style: text.bodySmall?.copyWith(color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (preview.isNotEmpty || unread) ...[
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          style: unread
                              ? text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                )
                              : text.bodyMedium?.copyWith(color: muted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: AppSpacing.sm),
                        ExcludeSemantics(child: UnreadBadge(count: c.unread)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return StaggerIn(
      index: index,
      child: Semantics(
        container: true,
        button: true,
        label:
            '$title, ${c.requestTitle}'
            '${unread ? ', ${l10n.chatUnread(c.unread)}' : ''}',
        onTap: open,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: open, excludeFromSemantics: true, child: row),
        ),
      ),
    );
  }
}
