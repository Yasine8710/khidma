import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Placeholder until Phase 6 (messaging).
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: l10n.messagesEmptyTitle,
        body: l10n.messagesEmptyBody,
      ),
    );
  }
}
