import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/fade_in.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/khidma_logo.dart';
import '../application/auth_providers.dart';
import 'auth_texts.dart';
import '../domain/auth_domain.dart';

/// Shared frame for the auth screens, like the sign-in screens people know:
/// back button, the logo, a bold title with a muted subtitle, then the form
/// in a phone-width column, plus an honest notice when accounts are not
/// available (no backend configured). The header fades in once.
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
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeIn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const KhidmaLogo(markSize: 36),
                        const SizedBox(height: AppSpacing.xl + 4),
                        Semantics(
                          header: true,
                          child: Text(title, style: text.headlineSmall),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xs + 2),
                          Text(
                            subtitle!,
                            style: text.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl + 4),
                  if (!available) ...[
                    InlineNotice(
                      message: l10n.failureText(AuthFailure.notConfigured),
                      tone: NoticeTone.info,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum NoticeTone { error, info }

/// A short message on a soft tinted rounded block with an icon (never colour
/// alone). Announced to screen readers when it appears.
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
    final bg = error ? scheme.errorContainer : scheme.primaryContainer;
    final icon = error ? scheme.error : scheme.primary;
    final fg = error ? scheme.onSurface : scheme.onPrimaryContainer;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                color: icon,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
