import 'package:flutter/material.dart';

/// A network photo with a quiet placeholder while loading and when it fails.
class PortfolioImage extends StatelessWidget {
  const PortfolioImage({
    super.key,
    required this.url,
    required this.semanticLabel,
    this.cacheWidth,
    this.fit = BoxFit.cover,
  });

  final String url;
  final String semanticLabel;
  final int? cacheWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
      ),
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Image.network(
        url,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => placeholder,
        frameBuilder: (_, child, frame, sync) =>
            frame == null && !sync ? placeholder : child,
      ),
    );
  }
}
