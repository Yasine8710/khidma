import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Placeholder until Phase 3 (discovery). Honest empty state, no fake data.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: EmptyState(
        icon: Icons.search_rounded,
        title: l10n.homeEmptyTitle,
        body: l10n.homeEmptyBody,
      ),
    );
  }
}
