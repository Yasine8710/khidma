import 'dart:math' as math;

/// Normalizes text for matching: lower case, French accents removed, Arabic
/// diacritics/tatweel removed, alef/ya/ta-marbuta variants unified.
///
/// Mirrors the database function `public.search_normalize` (backend migration
/// 20261110000400); a test compares both on the same vectors. Used by the demo
/// data source and anywhere the app filters text locally.
String normalizeSearch(String? input) {
  final lower = (input ?? '').toLowerCase();
  // Latin accents, then Arabic: alef forms, alef maqsura, taa marbuta, Persian
  // ya and kaf, hamza on waw and ya. Escapes keep the mapping unambiguous.
  const from =
      'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœ\u0623\u0625\u0622\u0649\u0629\u06cc\u06a9\u0624\u0626';
  const to =
      'aaaaaaceeeeiiiinooooouuuuyyo\u0627\u0627\u0627\u064a\u0647\u064a\u0643\u0648\u064a';
  final out = StringBuffer();
  for (final rune in lower.runes) {
    // Arabic diacritics (U+064B..U+0652) and tatweel (U+0640) are dropped.
    if ((rune >= 0x064B && rune <= 0x0652) || rune == 0x0640) continue;
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    out.write(i >= 0 ? to[i] : ch);
  }
  return out.toString();
}

/// Great-circle distance in kilometres (haversine), the same formula as the
/// database search function.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return earthRadiusKm * 2 * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Longest search text that is considered (the database caps it too).
const maxSearchTextLength = 100;

/// A user's search text prepared for matching: capped, normalized, whitespace
/// collapsed and trimmed. Empty means "no text filter". Mirrors the database.
String prepareSearchText(String? input) {
  final capped = (input ?? '').length > maxSearchTextLength
      ? input!.substring(0, maxSearchTextLength)
      : (input ?? '');
  return normalizeSearch(capped).replaceAll(RegExp(r'\s+'), ' ').trim();
}
