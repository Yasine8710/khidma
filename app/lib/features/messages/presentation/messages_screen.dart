import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/signed_out_prompt.dart';
import '../../requests/presentation/ledger_widgets.dart';
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
          photo: 'assets/photos/onb-trust.jpg',
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
          ? EmptyState(
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
              child: ListView.builder(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.lg,
                ),
                itemCount: list.length + 1,
                itemBuilder: (context, i) => i == 0
                    ? const LedgerRule(strong: true)
                    : _Row(conversation: list[i - 1]),
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
                  style: Theme.of(context).textTheme.headlineMedium,
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

class _Row extends StatelessWidget {
  const _Row({required this.conversation});

  final ConversationSummary conversation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final c = conversation;
    final title = conversationTitle(l10n, c);
    final preview =
        c.lastHasImage && (c.lastBody == null || c.lastBody!.isEmpty)
        ? l10n.chatImageSent
        : (c.lastBody ?? '');
    final unread = c.unread > 0;
    return LedgerRow(
      semanticLabel:
          '$title, ${c.requestTitle}'
          '${unread ? ', ${l10n.chatUnread(c.unread)}' : ''}',
      onTap: () => context.push(AppRoutes.chatPath(c.id)),
      leading: InitialsBlock(name: title, size: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: unread
                      ? text.titleMedium
                      : text.titleMedium?.copyWith(fontWeight: FontWeight.w400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (c.lastAt != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _when(c.lastAt!, locale),
                  style: text.labelSmall?.copyWith(color: muted),
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
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    preview,
                    style: unread
                        ? text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                        : text.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ExcludeSemantics(child: CountStamp(count: c.unread)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
