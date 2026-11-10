import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/signed_out_prompt.dart';

/// Placeholder until Phase 6 (messaging). Needs an account.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(currentUserProvider) != null;
    return SafeArea(
      child: signedIn
          ? EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: l10n.messagesEmptyTitle,
              body: l10n.messagesEmptyBody,
            )
          : SignedOutPrompt(
              icon: Icons.chat_bubble_outline_rounded,
              title: l10n.messagesSignedOutTitle,
              body: l10n.messagesSignedOutBody,
            ),
    );
  }
}
