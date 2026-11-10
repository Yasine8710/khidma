const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';
const _easternPersian = '۰۱۲۳۴۵۶۷۸۹';

/// Converts Arabic-Indic and Persian digits to Western 0-9. Khidma shows
/// Western digits in every language (usual in Tunisia), and users may type
/// either form into phone fields.
String toWesternDigits(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    var i = _arabicIndic.indexOf(ch);
    if (i < 0) i = _easternPersian.indexOf(ch);
    out.write(i >= 0 ? i.toString() : ch);
  }
  return out.toString();
}
