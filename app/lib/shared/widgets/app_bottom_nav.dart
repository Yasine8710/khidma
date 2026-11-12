import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../core/motion/motion.dart';

class NavItem {
  const NavItem(this.icon, this.selectedIcon, this.label, {this.badge = 0});
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Unread count shown as a small dot/number on the icon (0 = none).
  final int badge;
}

/// The tab bar: icon + label for every tab, the active one in the brand
/// colour with a filled icon and a small pop. A hairline separates it from
/// the content. Items are laid out with a Row, so the order mirrors in RTL.
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
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          // Labels stay readable but do not grow with huge accessibility sizes.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    _Tab(
                      item: items[i],
                      selected: i == currentIndex,
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

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = Motion.reduced(context);
    final fg = selected ? scheme.primary : scheme.onSurfaceVariant;
    Widget icon = Icon(
      selected ? item.selectedIcon : item.icon,
      size: 24,
      color: fg,
    );
    if (item.badge > 0) {
      icon = Badge(
        label: Text(item.badge > 9 ? '9+' : '${item.badge}'),
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        child: icon,
      );
    }
    return Expanded(
      // InkWell provides tap and focus semantics; the inner node names it.
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: selected,
          label: item.label,
          excludeSemantics: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected && !reduce ? 1.08 : 1,
                duration: reduce ? Duration.zero : Motion.base,
                curve: Motion.settle,
                child: icon,
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: reduce ? Duration.zero : Motion.fast,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
