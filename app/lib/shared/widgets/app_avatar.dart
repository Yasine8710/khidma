import 'package:flutter/material.dart';

/// Round avatar with a hairline ring: network image when available,
/// otherwise slab initials on sunken paper. A failed
/// or not-yet-loaded image shows initials, never a blank or broken-image
/// icon. Set [decorative] when the name is already shown next to it, so
/// screen readers do not read it twice.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
    this.decorative = false,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool decorative;

  /// "Karim Ben Salah" -> "KB", "خالد" -> "خ", "" -> "?". Uses grapheme
  /// clusters, so accents, skin tones and flags are not split.
  static String initialsOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    String first(String w) => w.characters.first.toUpperCase();
    if (words.length == 1) return first(words.first);
    return first(words.first) + first(words[1]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A monogram: slab initials in ink on sunken paper.
    final initials = Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        initialsOf(name),
        maxLines: 1,
        // The circle does not grow with the text size; keep the monogram in.
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontSize: size * 0.38,
          height: 1,
        ),
      ),
    );

    final url = imageUrl;
    final px = size * MediaQuery.devicePixelRatioOf(context);
    final avatar = Container(
      width: size,
      height: size,
      // A thin rule ring, drawn over the picture's edge.
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipOval(
        child: url == null || url.isEmpty
            ? initials
            : Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: px.isFinite && px >= 1 ? px.round() : null,
                errorBuilder: (_, _, _) => initials,
                // Initials until the first frame is decoded (no blank flash).
                frameBuilder: (_, child, frame, sync) =>
                    frame == null && !sync ? initials : child,
              ),
      ),
    );

    if (decorative || name.trim().isEmpty) {
      return ExcludeSemantics(child: avatar);
    }
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: avatar,
    );
  }
}
