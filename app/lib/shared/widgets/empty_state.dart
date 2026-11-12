import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/app_spacing.dart';
import 'app_button.dart';

/// Centered empty state, typographic: a glyph sticker, a big Anton title, an
/// explanatory body and an optional loud action.
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StateVisual(icon: icon, photo: photo),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                style: text.headlineMedium,
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
    );
  }
}

/// The picture above a state's title: a glyph on a world-colour sticker
/// block (ink frame, hard shadow) that slams in once. Photos are no longer
/// shipped, so a given [photo] is ignored. Decoration only.
class StateVisual extends StatelessWidget {
  const StateVisual({super.key, required this.icon, this.photo});

  final IconData icon;

  /// Ignored (kept so older call sites compile).
  final String? photo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = StickerBox(
      color: scheme.primaryContainer,
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Icon(icon, size: 44, color: scheme.onPrimaryContainer),
    );
    if (Motion.reduced(context)) return ExcludeSemantics(child: block);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: Motion.slow,
        curve: Motion.slam,
        builder: (context, t, child) => Transform.rotate(
          angle: (1 - t) * -0.2,
          child: Transform.scale(scale: t, child: child),
        ),
        child: block,
      ),
    );
  }
}
