import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Bordered surface card (see CardTheme). Tappable when [onTap] is set; the
/// whole card is then one button node (label + tap together), at least 48
/// high. Interactive children inside a tappable card keep their own nodes.
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

  /// Spoken name for tappable cards (e.g. professional name and profession).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    if (onTap == null) return Card(child: body);
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: body,
          ),
        ),
      ),
    );
  }
}
