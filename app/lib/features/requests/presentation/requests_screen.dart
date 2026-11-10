import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/signed_out_prompt.dart';

/// Placeholder until Phase 5 (requests and offers). Needs an account.
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(currentUserProvider) != null;
    return SafeArea(
      child: signedIn
          ? EmptyState(
              icon: Icons.assignment_outlined,
              title: l10n.requestsEmptyTitle,
              body: l10n.requestsEmptyBody,
            )
          : SignedOutPrompt(
              icon: Icons.assignment_outlined,
              title: l10n.requestsSignedOutTitle,
              body: l10n.requestsSignedOutBody,
            ),
    );
  }
}
