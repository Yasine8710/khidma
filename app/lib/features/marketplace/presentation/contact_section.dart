import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/tunisian_phone.dart';
import '../../../core/motion/motion.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../auth/application/auth_providers.dart';
import '../application/contact_providers.dart';
import '../application/marketplace_providers.dart';
import '../domain/marketplace_domain.dart';

/// The contact block of a profile: a soft card with a phone tile and the
/// title, then [child].
class ContactCard extends StatelessWidget {
  const ContactCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StickerBox(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.call_outlined,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Contact: the number is fetched only when a signed-in person asks, and only
/// kept while this screen is open.
class ContactSection extends ConsumerWidget {
  const ContactSection({super.key, required this.professionalId});

  final String professionalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final signedIn = ref.watch(currentUserProvider) != null;
    final isDemo = ref.watch(isDemoDataProvider);
    final state = ref.watch(contactProvider(professionalId));

    final Widget body;
    if (isDemo) {
      body = Text(l10n.contactDemo, style: text.bodyMedium);
    } else if (!signedIn) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.contactWhy, style: text.bodySmall?.copyWith(color: muted)),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.contactSignIn,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.login),
          ),
        ],
      );
    } else {
      body = switch (state) {
        ContactRevealed(:final phone) => _Revealed(phone: phone),
        ContactLoading() => AppButton(
          label: l10n.contactShow,
          variant: AppButtonVariant.secondary,
          isLoading: true,
          onPressed: null,
        ),
        ContactFailed(:final failure) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _failureText(l10n, failure),
              style: text.bodyMedium,
              semanticsLabel: _failureText(l10n, failure),
            ),
            if (failure != MarketplaceFailure.rateLimited &&
                failure != MarketplaceFailure.notFound) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: l10n.retry,
                variant: AppButtonVariant.secondary,
                onPressed: () =>
                    ref.read(contactProvider(professionalId).notifier).reveal(),
              ),
            ],
          ],
        ),
        ContactHidden() => AppButton(
          label: l10n.contactShow,
          variant: AppButtonVariant.secondary,
          onPressed: () =>
              ref.read(contactProvider(professionalId).notifier).reveal(),
        ),
      };
    }

    return ContactCard(title: l10n.contactTitle, child: body);
  }

  static String _failureText(AppLocalizations l10n, MarketplaceFailure f) =>
      switch (f) {
        MarketplaceFailure.rateLimited => l10n.contactRateLimited,
        MarketplaceFailure.notFound => l10n.contactNotFound,
        MarketplaceFailure.notConfigured => l10n.contactDemo,
        _ => l10n.contactFailed,
      };
}

class _Revealed extends ConsumerWidget {
  const _Revealed({required this.phone});

  final String phone;

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await ref.read(urlOpenerProvider)(uri);
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.contactLaunchFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shown = TunisianPhone.display(phone);
    final tel = TunisianPhone.e164(phone);
    final wa = TunisianPhone.whatsapp(phone);
    if (shown == null || tel == null || wa == null) {
      // The server returned something that is not a Tunisian number: show
      // nothing dialable rather than guess.
      return Text(l10n.contactFailed);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone numbers read left to right in every language.
        Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText(
            shown,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.contactCall,
                icon: Icons.call_rounded,
                onPressed: () => _open(context, ref, Uri.parse('tel:$tel')),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: l10n.contactWhatsApp,
                icon: Icons.chat_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: () =>
                    _open(context, ref, Uri.parse('https://wa.me/$wa')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
