import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// One onboarding page, set like a printed leaflet: a framed photo (never
/// full-bleed), a slab headline and a short body, all aligned to the start
/// edge, plus optional extra content (the language list). Scrolls on small
/// screens or large text.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    this.icon,
    this.photo,
    this.leading,
    required this.title,
    required this.body,
    this.extra,
    this.hideIconWhenCompact = false,
  });

  final IconData? icon;

  /// Bundled photo shown (framed) instead of the icon (value pages).
  final String? photo;

  /// Replaces the icon (e.g. the brand logo on the first page).
  final Widget? leading;
  final String title;
  final String body;
  final Widget? extra;

  /// On short screens or large text, drop the decoration so the content
  /// (e.g. the language list) is reachable without scrolling.
  final bool hideIconWhenCompact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final compact = media.size.height < 700 || media.textScaler.scale(10) > 13;
    // Only drop decoration when space is really tight (very short screen or
    // large text); the brand logo should survive on ordinary small screens.
    final tight = media.size.height < 560 || media.textScaler.scale(10) > 13;

    Widget? visual;
    if (photo != null) {
      visual = _FramedPhoto(
        asset: photo!,
        height: compact ? 176 : 260,
        icon: icon,
      );
    } else if (leading != null) {
      visual = Align(
        alignment: AlignmentDirectional.centerStart,
        child: leading,
      );
    } else if (icon != null) {
      visual = _RuledIcon(icon: icon!);
    }

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: box.maxHeight - AppSpacing.lg * 2,
          ),
          // The group sits in the middle of the page instead of hugging the
          // top with a dead zone below; it still scrolls when space is tight.
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (visual != null && !(tight && hideIconWhenCompact)) ...[
                  visual,
                  SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: text.headlineMedium,
                    textAlign: TextAlign.start,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  body,
                  style: text.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.start,
                ),
                if (extra != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  extra!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A photo in a 1px rule frame, like a print pasted into a ledger.
class _FramedPhoto extends StatelessWidget {
  const _FramedPhoto({required this.asset, required this.height, this.icon});

  final String asset;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.asset(
          asset,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          // Decoration only: the title says everything.
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => SizedBox(
            height: height,
            child: icon == null ? null : Center(child: _RuledIcon(icon: icon!)),
          ),
        ),
      ),
    );
  }
}

class _RuledIcon extends StatelessWidget {
  const _RuledIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Icon(icon, size: 30, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
