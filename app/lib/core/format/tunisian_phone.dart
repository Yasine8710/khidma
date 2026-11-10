import 'digits.dart';

/// Tunisian phone numbers: +216 followed by 8 digits.
///
/// Accepted first digits are 2-5, 7 and 9. Sources agree on mobile 2/4/5/9
/// and landline 7; 3 is accepted so a real number is not rejected, but is
/// unverified against the current INT numbering plan.
abstract final class TunisianPhone {
  static final _national = RegExp(r'^[234579]\d{7}$');

  /// Returns the 8-digit national number, or null when invalid.
  /// Accepts `20123456`, `+216 20 123 456`, `00216 20-123-456`, `216...`.
  static String? parse(String input) {
    var s = toWesternDigits(input).replaceAll(RegExp(r'[\s\-.()‎‏]'), '');
    if (s.startsWith('+216')) {
      s = s.substring(4);
    } else if (s.startsWith('00216')) {
      s = s.substring(5);
    } else if (s.length == 11 && s.startsWith('216')) {
      s = s.substring(3);
    }
    return _national.hasMatch(s) ? s : null;
  }

  static bool isValid(String input) => parse(input) != null;

  /// `+216 20 123 456`, or null when invalid.
  static String? display(String input) {
    final n = parse(input);
    if (n == null) return null;
    return '+216 ${n.substring(0, 2)} ${n.substring(2, 5)} ${n.substring(5)}';
  }

  /// `+21620123456` for `tel:` links, or null when invalid.
  static String? e164(String input) {
    final n = parse(input);
    return n == null ? null : '+216$n';
  }

  /// `21620123456` for `wa.me/` links, or null when invalid.
  static String? whatsapp(String input) {
    final n = parse(input);
    return n == null ? null : '216$n';
  }
}
