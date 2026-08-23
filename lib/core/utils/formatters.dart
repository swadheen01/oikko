import 'package:intl/intl.dart';

/// Consistent date/currency formatting across the app.
class Formatters {
  Formatters._();

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');
  static final _currencyFmt = NumberFormat.currency(locale: 'en_BD', symbol: '৳ ');

  static String date(DateTime dt) => _dateFmt.format(dt);
  static String dateTime(DateTime dt) => _dateTimeFmt.format(dt);
  static String currency(num amount) => _currencyFmt.format(amount);

  /// Normalizes a Bangladeshi phone number to a consistent stored format,
  /// e.g. "01712345678" -> "+8801712345678" (used for Firebase Auth /
  /// matching in the member-linking flow, section 4.9).
  static String toE164(String localPhone) {
    final digits = localPhone.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('880')) return '+$digits';
    if (digits.startsWith('01')) return '+880${digits.substring(1)}';
    return '+880$digits';
  }
}
