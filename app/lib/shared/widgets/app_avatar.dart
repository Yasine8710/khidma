import 'package:flutter/material.dart';

/// Round avatar: network image when available, otherwise initials. A failed
/// or missing image falls back to initials, never to a broken-image icon.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// "Karim Ben Salah" -> "KB", "خالد" -> "خ", "" -> "?".
  static String initialsOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    String first(String w) => String.fromCharCode(w.runes.first).toUpperCase();
    if (words.length == 1) return first(words.first);
    return first(words.first) + first(words[1]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initialsOf(name),
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: scheme.onPrimaryContainer, fontSize: size * 0.36),
      ),
    );
    final url = imageUrl;
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: url == null || url.isEmpty
              ? initials
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  errorBuilder: (_, _, _) => initials,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : initials,
                ),
        ),
      ),
    );
  }
}
