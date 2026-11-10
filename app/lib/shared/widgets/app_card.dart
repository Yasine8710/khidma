import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Bordered surface card (see CardTheme). Tappable when [onTap] is set.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.lg),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Spoken name for tappable cards; defaults to the merged child text.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: semanticLabel,
      container: true,
      child: card,
    );
  }
}
