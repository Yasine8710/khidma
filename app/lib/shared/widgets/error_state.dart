import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'empty_state.dart';

/// Generic failure state with a retry action. Pass [title]/[body] for
/// specific errors; the defaults suit network failures.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.onRetry, this.title, this.body});

  final VoidCallback onRetry;
  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: title ?? l10n.errorTitle,
      body: body ?? l10n.errorBody,
      actionLabel: l10n.retry,
      onAction: onRetry,
    );
  }
}
