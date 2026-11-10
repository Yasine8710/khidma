import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/format/tunisian_phone.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'language_selector.dart';

/// Temporary landing screen until navigation (slice 1.2) and onboarding
/// (slice 1.4) exist. Shows the language picker and live formatting samples.
class FoundationScreen extends StatelessWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
          children: [
            const SizedBox(height: AppSpacing.xxl),
            Text(l10n.appName, style: text.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.tagline, style: text.bodyLarge?.copyWith(color: muted)),
            const SizedBox(height: AppSpacing.xxl),
            Text(l10n.chooseLanguage, style: text.titleMedium),
            const SizedBox(height: AppSpacing.md),
            const LanguageSelector(),
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.professionalsCount(12), style: text.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(formatTnd(1250.5, locale), style: text.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.priceOnQuote, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(TunisianPhone.display('20123456')!, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}
