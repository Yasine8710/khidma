import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/khidma_logo.dart';
import '../application/auth_providers.dart';
import 'auth_texts.dart';
import '../domain/auth_domain.dart';

/// Shared frame for the auth screens: back button, phone-width column, logo,
/// title and subtitle, plus an honest notice when accounts are not available
/// (no backend configured).
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
    final available = ref.watch(authAvailableProvider);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: KhidmaLogo(markSize: 36),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  header: true,
                  child: Text(title, style: text.headlineMedium),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle!,
                    style: text.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
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
    );
  }
}

enum NoticeTone { error, info }

/// A short message in a tinted box with an icon (never color alone). Announced
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
    final fg = error
        ? (scheme.brightness == Brightness.dark ? scheme.error : scheme.error)
        : scheme.onPrimaryContainer;
    final bg = error
        ? Color.alphaBlend(scheme.error.withValues(alpha: 0.10), scheme.surface)
        : scheme.primaryContainer;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: fg.withValues(alpha: 0.4)),
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
