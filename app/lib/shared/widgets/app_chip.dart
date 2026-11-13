import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_spacing.dart';

/// Selectable filter chip (category, price range, availability...): a pill.
/// Unselected = white with a hairline; selected = soft grey with brand
/// text, a brand edge and a check (so the state never rests on colour
/// alone). At least 40 high visually and 48x48 to hit; grows with text size.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = Motion.reduced(context);
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final lead = icon ?? (selected ? Icons.check_rounded : null);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: () => onSelected(!selected),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          onSelected(!selected);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: reduce ? Duration.zero : Motion.fast,
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg - 2,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lead != null) ...[
                    Icon(lead, size: 18, color: fg),
                    const SizedBox(width: AppSpacing.xs + 2),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
