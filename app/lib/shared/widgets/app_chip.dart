import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_spacing.dart';

/// Selectable filter chip (category, price range, availability...): a
/// rectangular block with a heavy ink outline. Selected = the world colour
/// (with its text colour) and a hard shadow; unselected = paper, flat.
/// At least 40 high visually and 48x48 to hit; grows with text size.
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
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
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
              curve: Motion.slam,
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: scheme.onSurface,
                  width: AppInk.border,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: scheme.onSurface,
                          offset: Offset(rtl ? -3 : 3, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: AppSpacing.sm),
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
