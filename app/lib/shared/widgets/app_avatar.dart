import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Round avatar: the network image when available, otherwise white initials
/// on a colour picked from the name (always the same for the same person).
/// A failed or not-yet-loaded image shows initials, never a blank or
/// broken-image icon. Set [decorative] when the name is already shown next
/// to it, so screen readers do not read it twice.
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

  static final _punct = RegExp(r'^\p{P}', unicode: true);

  /// "Karim Ben Salah" -> "KB", "خالد" -> "خ", "" -> "?". Uses grapheme
  /// clusters, so accents, skin tones and flags are not split.
  static String initialsOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        // Skip words that start with punctuation: "Salma (démo)" gives "S".
        .where((w) => w.isNotEmpty && !_punct.hasMatch(w))
        .toList();
    if (words.isEmpty) return '?';
    String first(String w) => w.characters.first.toUpperCase();
    if (words.length == 1) return first(words.first);
    return first(words.first) + first(words[1]);
  }

  /// Stable, platform-independent hash of the trimmed name.
  static int colorIndexOf(String name) {
    var h = 7;
    for (final u in name.trim().toLowerCase().codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final initials = Container(
      color: AppColors.avatar(colorIndexOf(name)),
      alignment: Alignment.center,
      child: Text(
        initialsOf(name),
        maxLines: 1,
        // The circle does not grow with the text size; keep the initials in.
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.paper,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
          height: 1,
        ),
      ),
    );

    final url = imageUrl;
    final px = size * MediaQuery.devicePixelRatioOf(context);
    final avatar = SizedBox(
      width: size,
      height: size,
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
