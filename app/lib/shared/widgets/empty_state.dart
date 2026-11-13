import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'app_button.dart';
import 'fade_in.dart';

/// Centered empty state: a soft tinted circle with a line icon, a short
/// title, one line of help and an optional button. Fades in once.
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

  /// Ignored (photos are no longer shipped); kept for older call sites.
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
          child: FadeIn(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StateVisual(icon: icon, photo: photo),
                const SizedBox(height: AppSpacing.lg + 4),
                Text(
                  title,
                  style: text.titleLarge,
                  textAlign: TextAlign.center,
                ),
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
                  AppButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    expand: false,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The picture above a state's title: a line icon in a soft grey circle.
/// Photos are no longer shipped, so a given [photo] is ignored. Decoration
/// only.
class StateVisual extends StatelessWidget {
  const StateVisual({super.key, required this.icon, this.photo});

  final IconData icon;

  /// Ignored (kept so older call sites compile).
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 38, color: scheme.primary),
      ),
    );
  }
}
