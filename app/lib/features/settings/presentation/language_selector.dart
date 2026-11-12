import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/aligned_text.dart';

/// Language list as ruled register rows: the chosen one carries a check.
/// Each option is labelled in its own language so users can always find
/// theirs. Reused by onboarding and by Profile settings.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(localeProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final options = <(Locale, String)>[
      (const Locale('fr'), l10n.languageFrench),
      (const Locale('ar'), l10n.languageArabic),
      (const Locale('en'), l10n.languageEnglish),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant),
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const Divider(),
            _row(context, ref, options[i], current, scheme, text),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    (Locale, String) option,
    Locale current,
    ColorScheme scheme,
    TextTheme text,
  ) {
    final (locale, label) = option;
    final selected = locale == current;
    return Semantics(
      button: true,
      selected: selected,
      localeForSubtree: locale,
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          ref.read(localeProvider.notifier).setLocale(locale);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AlignedText(
                    label,
                    textDirection: locale.isRtl
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: (selected ? text.titleMedium : text.bodyLarge)
                        ?.copyWith(color: scheme.onSurface),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Same box either way, so rows never shift when chosen.
                SizedBox(
                  width: 24,
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 22,
                          color: scheme.onSurface,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
