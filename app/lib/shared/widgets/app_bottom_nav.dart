import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class NavItem {
  const NavItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The tab bar: a solid ink band across the bottom, like the counter of a
/// workshop. The active tab gets a terracotta bar on its top edge and full
/// paper-white text; the others are dimmed. Items are laid out with a Row,
/// so the order mirrors automatically in RTL.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final band = dark ? AppColors.darkSurface : AppColors.ink;
    return Material(
      color: band,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: dark
              ? const Border(top: BorderSide(color: AppColors.darkBorder))
              : null,
        ),
        child: SafeArea(
          top: false,
          // Labels stay readable but do not grow with huge accessibility sizes.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () {
                        AppHaptics.selection();
                        onSelected(i);
                      },
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

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final on = dark ? AppColors.darkInk : AppColors.background;
    final color = selected ? on : on.withValues(alpha: 0.62);
    final accent = dark ? AppColors.darkPrimary : AppColors.primary;
    return InkWell(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 3,
                width: selected ? 36 : 0,
                color: accent,
              ),
              const SizedBox(height: AppSpacing.sm),
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
