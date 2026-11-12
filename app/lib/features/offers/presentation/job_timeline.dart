import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../requests/presentation/ledger_widgets.dart';
import '../domain/offers_domain.dart';
import 'offers_texts.dart';

/// The steps a job goes through, in order (a cancelled job leaves the track).
const jobSteps = [
  BookingStatus.scheduled,
  BookingStatus.inProgress,
  BookingStatus.pendingConfirmation,
  BookingStatus.completed,
];

/// A job's progress as a vertical stepped timeline, each step named once.
class JobTimeline extends StatelessWidget {
  const JobTimeline({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StepTimeline(
      steps: [for (final s in jobSteps) jobStatusLabel(l10n, s)],
      current: jobSteps.indexOf(status).clamp(0, jobSteps.length - 1),
      complete: status == BookingStatus.completed,
    );
  }
}

/// The compact form for a list row: the step squares, then the current
/// status as a stamp (a cancelled job shows only its stamp).
class JobTrack extends StatelessWidget {
  const JobTrack({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stamp = LedgerStamp(
      big: true,
      label: jobStatusLabel(l10n, status),
      tone: jobStatusTone(status),
    );
    if (status == BookingStatus.cancelled) return stamp;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StepTrack(
          count: jobSteps.length,
          current: jobSteps.indexOf(status),
          complete: status == BookingStatus.completed,
        ),
        stamp,
      ],
    );
  }
}
