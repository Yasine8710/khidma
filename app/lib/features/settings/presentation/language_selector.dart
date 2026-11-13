import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/aligned_text.dart';

/// Language list as a settings-style group: one white card, a row per
/// language, the chosen one on soft grey with a brand check.
/// Each option is labelled in its own language so users can always find
/// theirs. Reused by onboarding and by Profile settings.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(localeProvider);
    final options = <(Locale, String)>[
      (const Locale('fr'), l10n.languageFrench),
      (const Locale('ar'), l10n.languageArabic),
      (const Locale('en'), l10n.languageEnglish),
    ];

    return StickerBox(
      // Rows sit inside the hairline, so their fill never hides it.
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg - 1),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const Divider(),
                _LanguageRow(
                  locale: options[i].$1,
                  label: options[i].$2,
                  selected: options[i].$1 == current,
                  onTap: () {
                    AppHaptics.selection();
                    ref.read(localeProvider.notifier).setLocale(options[i].$1);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.locale,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Locale locale;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduce = Motion.reduced(context);
    final style = (locale.isRtl ? text.titleMedium : text.bodyLarge)?.copyWith(
      color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    return Semantics(
      button: true,
      selected: selected,
      localeForSubtree: locale,
      // The row's fill is a Material so the ink ripple shows on top of it.
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
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
                    style: style,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Same box either way, so rows never shift when chosen.
                ExcludeSemantics(
                  child: AnimatedContainer(
                    duration: reduce ? Duration.zero : Motion.fast,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? scheme.primary : scheme.surface,
                      border: Border.all(
                        color: selected ? scheme.primary : scheme.outline,
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: scheme.onPrimary,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
