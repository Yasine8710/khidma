import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Placeholder until Phase 5 (requests and offers).
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: EmptyState(
        icon: Icons.assignment_outlined,
        title: l10n.requestsEmptyTitle,
        body: l10n.requestsEmptyBody,
      ),
    );
  }
}
