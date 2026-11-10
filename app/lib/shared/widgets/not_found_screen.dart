import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../l10n/generated/app_localizations.dart';
import 'empty_state.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.explore_off_outlined,
          title: l10n.notFoundTitle,
          body: l10n.notFoundBody,
          actionLabel: l10n.backToHome,
          onAction: () => context.go(AppRoutes.home),
        ),
      ),
    );
  }
}
