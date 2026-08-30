/// Phone number handling for Bangladeshi numbers.
///
/// The roster stores numbers the way the association writes them —
/// `01712345678`, sometimes with dashes. That's fine for dialling locally
/// but useless to WhatsApp, which addresses chats by full international
/// number: wa.me/8801712345678. Passing the local form opens WhatsApp on a
/// "phone number shared via url is invalid" error, which is what was
/// happening for all 400+ imported members.
class PhoneUtils {
  PhoneUtils._();

  static const _countryCode = '880';

  /// Digits only, with Bengali numerals folded to Latin.
  static String digitsOf(String raw) {
    const bn = '০১২৩৪৫৬৭৮৯';
    final buffer = StringBuffer();
    for (final ch in raw.split('')) {
      final bnIndex = bn.indexOf(ch);
      if (bnIndex >= 0) {
        buffer.write(bnIndex);
      } else if (RegExp(r'\d').hasMatch(ch)) {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// `8801XXXXXXXXX`, or null if the number can't be made sense of.
  ///
  /// Returning null rather than guessing matters: a handful of imported
  /// numbers are 10 or 12 digits (typos in the source document), and
  /// padding or truncating those would open a chat with a stranger.
  static String? toInternational(String raw) {
    var d = digitsOf(raw);
    if (d.isEmpty) return null;

    if (d.startsWith('00')) d = d.substring(2);          // 00880… -> 880…
    if (d.startsWith(_countryCode)) {
      final rest = d.substring(_countryCode.length);
      return rest.length == 10 && rest.startsWith('1') ? d : null;
    }
    if (d.length == 11 && d.startsWith('01')) {
      return '$_countryCode${d.substring(1)}';           // 01712… -> 8801712…
    }
    if (d.length == 10 && d.startsWith('1')) {
      return '$_countryCode$d';                          // 1712… -> 8801712…
    }
    return null;                                         // wrong length
  }

  static bool isValid(String raw) => toInternational(raw) != null;

  /// wa.me takes the number without a leading `+`.
  static String? whatsAppUrl(String raw) {
    final n = toInternational(raw);
    return n == null ? null : 'https://wa.me/$n';
  }

  /// `+880…` so the number works from any network, not just inside
  /// Bangladesh.
  static String? telUrl(String raw) {
    final n = toInternational(raw);
    return n == null ? null : 'tel:+$n';
  }

  static String? smsUrl(String raw) {
    final n = toInternational(raw);
    return n == null ? null : 'sms:+$n';
  }

  /// Readable grouping for display: `01712 345 678`.
  static String pretty(String raw) {
    final d = digitsOf(raw);
    if (d.length == 11 && d.startsWith('0')) {
      return '${d.substring(0, 5)} ${d.substring(5, 8)} ${d.substring(8)}';
    }
    return raw.trim();
  }
}
