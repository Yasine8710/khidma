import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/khidma_logo.dart';
import '../application/auth_providers.dart';
import 'auth_texts.dart';
import '../domain/auth_domain.dart';

/// Shared frame for the auth screens: back button, then a flat colour header
/// block (world colour, ink rule under it) holding the logo and a giant Anton
/// title with its subtitle, then the form in a phone-width column, plus an
/// honest notice when accounts are not available (no backend configured).
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final available = ref.watch(authAvailableProvider);
    // The giant title keeps a ceiling on text scaling so it wraps, not clips.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      border: Border(
                        bottom: BorderSide(
                          color: scheme.onSurface,
                          width: AppInk.border,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.gutter,
                        AppSpacing.lg,
                        AppSpacing.gutter,
                        AppSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KhidmaLogo(markSize: 30),
                          const SizedBox(height: AppSpacing.xl),
                          _SlamIn(
                            child: Semantics(
                              header: true,
                              child: Text(
                                title,
                                textScaler: scaler,
                                style: text.displaySmall?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              subtitle!,
                              style: text.bodyLarge?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.gutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!available) ...[
                          InlineNotice(
                            message: l10n.failureText(
                              AuthFailure.notConfigured,
                            ),
                            tone: NoticeTone.info,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        ...children,
                      ],
                    ),
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

/// The title slams in once (rise + overshoot); instant with Reduce Motion.
class _SlamIn extends StatelessWidget {
  const _SlamIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow,
      curve: Motion.slam,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 28),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

enum NoticeTone { error, info }

/// A short message in a heavy-framed slip with an icon (never color alone). Announced
/// to screen readers when it appears.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.tone = NoticeTone.error,
  });

  final String message;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = tone == NoticeTone.error;
    // A flat paper slip in a heavy frame: error in the error ink, info in
    // plain ink on sunken paper.
    final fg = error ? scheme.error : scheme.onSurface;
    final bg = error ? scheme.surface : scheme.surfaceContainerHighest;
    return Semantics(
      liveRegion: true,
      container: true,
      child: StickerBox(
        color: bg,
        offset: 0,
        borderColor: error ? scheme.error : scheme.onSurface,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                color: fg,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
