import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/app_spacing.dart';

class NavItem {
  const NavItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The dock: a row of blocks with a heavy ink top edge. The active block
/// grows (it takes more of the width) and floods with the world colour, the
/// others shrink to icon + small label. The change is a springy slam. Items
/// are laid out with a Row, so the order mirrors automatically in RTL.
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
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: scheme.onSurface, width: AppInk.border),
          ),
        ),
        child: SafeArea(
          top: false,
          // Labels stay readable but do not grow with huge accessibility sizes.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    _DockSlot(
                      item: items[i],
                      selected: i == currentIndex,
                      last: i == items.length - 1,
                      onTap: () {
                        AppHaptics.selection();
                        onSelected(i);
                      },
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

class _DockSlot extends StatelessWidget {
  const _DockSlot({
    required this.item,
    required this.selected,
    required this.last,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = Motion.reduced(context);
    final bg = selected ? scheme.primaryContainer : Colors.transparent;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Expanded(
      flex: selected ? 5 : 3,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : Motion.base,
            curve: Motion.slam,
            decoration: BoxDecoration(
              color: bg,
              border: BorderDirectional(
                end: last
                    ? BorderSide.none
                    : BorderSide(color: scheme.onSurface, width: AppInk.border),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.15 : 1,
                  duration: reduce ? Duration.zero : Motion.base,
                  curve: Motion.slam,
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    size: 24,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
