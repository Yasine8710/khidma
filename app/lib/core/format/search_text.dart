import 'dart:math' as math;

/// Normalizes text for matching: lower case, French accents removed, Arabic
/// diacritics/tatweel removed, alef/ya/ta-marbuta variants unified.
///
/// Mirrors the database function `public.search_normalize` (backend migration
/// 20261110000400); a test compares both on the same vectors. Used by the demo
/// data source and anywhere the app filters text locally.
String normalizeSearch(String? input) {
  final lower = (input ?? '').toLowerCase();
  // Latin accents, then Arabic: alef with hamza above/below/madda, alef maqsura,
  // taa marbuta. Written as escapes so the mapping is unambiguous.
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœأإآىة';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoااايه';
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
