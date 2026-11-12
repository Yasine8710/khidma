import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Centered empty state: a framed photo or a plain line icon, a slab title,
/// an explanatory body and an optional action.
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

  /// Bundled photo shown (framed) instead of the icon.
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StateVisual(icon: icon, photo: photo),
              const SizedBox(height: AppSpacing.xl),
              Text(title, style: text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 48),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The picture above a state's title: a photo in a 1px rule frame when one
/// is given (and loads), otherwise a plain line icon in a small ruled
/// square. Never full-bleed, never tinted. Decoration only.
class StateVisual extends StatelessWidget {
  const StateVisual({super.key, required this.icon, this.photo});

  final IconData icon;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mark = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Icon(icon, size: 30, color: scheme.onSurfaceVariant),
    );
    if (photo == null) return ExcludeSemantics(child: mark);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Image.asset(
            photo!,
            width: double.infinity,
            height: 168,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => Center(child: mark),
          ),
        ),
      ),
    );
  }
}
