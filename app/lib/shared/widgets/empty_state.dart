import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Centered illustration-free empty state: icon in a tinted circle, title,
/// explanatory body and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.photo,
  });

  /// Bundled photo shown instead of the icon badge.
  final String? photo;

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StateVisual(icon: icon, photo: photo),
            const SizedBox(height: AppSpacing.xl),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The picture above a state's title: a rounded photo when one is given (and
/// loads), otherwise the icon in a tinted circle. Decoration only.
class StateVisual extends StatelessWidget {
  const StateVisual({super.key, required this.icon, this.photo});

  final IconData icon;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 32,
        color: scheme.brightness == Brightness.light
            ? scheme.primary
            : scheme.onPrimaryContainer,
      ),
    );
    if (photo == null) return badge;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Image.asset(
        photo!,
        width: double.infinity,
        height: 190,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => badge,
      ),
    );
  }
}
