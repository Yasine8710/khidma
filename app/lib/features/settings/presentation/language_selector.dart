import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/aligned_text.dart';

/// Language list. Each option is labelled in its own language so users can
/// always find theirs. Reused by onboarding and by Profile settings.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(localeProvider);
    final scheme = Theme.of(context).colorScheme;
    final options = <(Locale, String)>[
      (const Locale('fr'), l10n.languageFrench),
      (const Locale('ar'), l10n.languageArabic),
      (const Locale('en'), l10n.languageEnglish),
    ];

    return Column(
      children: [
        for (final (locale, label) in options)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: Semantics(
              button: true,
              selected: locale == current,
              localeForSubtree: locale,
              child: Material(
                color: locale == current
                    ? scheme.primaryContainer
                    : scheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(
                    color: locale == current ? scheme.primary : scheme.outline,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(localeProvider.notifier).setLocale(locale);
                  },
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AlignedText(
                            label,
                            textDirection: locale.isRtl
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (locale == current)
                          Icon(Icons.check_rounded, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
