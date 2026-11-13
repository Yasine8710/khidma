import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/portfolio_providers.dart';
import '../domain/portfolio_domain.dart';
import 'portfolio_image.dart';

/// Work photos on a public profile, as rounded squares three across (four
/// when wide). Nothing at all while loading, on failure or when there are
/// none; the profile's "Réalisations" tab names the section.
class PortfolioGallery extends ConsumerWidget {
  const PortfolioGallery({super.key, required this.professionalId});

  final String professionalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(portfolioProvider(professionalId)).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 520 ? 4 : 3;
        const gap = AppSpacing.sm;
        final side = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox.square(
                dimension: side,
                child: _Tile(item: items[i], index: i + 1, total: items.length),
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.index, required this.total});

  final PortfolioItem item;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.portfolioPhotoOf(index, total);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => _open(context, label),
      child: Pressable(
        onTap: () => _open(context, label),
        button: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: PortfolioImage(
            url: item.url,
            semanticLabel: label,
            cacheWidth: 360,
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, String label) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: PortfolioImage(
                  url: item.url,
                  semanticLabel: label,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            PositionedDirectional(
              top: AppSpacing.md,
              end: AppSpacing.md,
              child: SafeArea(
                child: IconButton.outlined(
                  tooltip: l10n.close,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
