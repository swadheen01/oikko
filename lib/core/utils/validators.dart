/// Form-field validators used across auth, profile, and finance forms.
class Validators {
  Validators._();

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'ফোন নম্বর দিন';
    }
    final cleaned = value.trim().replaceAll(' ', '');
    final regex = RegExp(r'^01[3-9]\d{8}$');
    if (!regex.hasMatch(cleaned)) {
      return 'সঠিক ফোন নম্বর দিন (যেমন: 01712345678)';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'ইমেইল দিন';
    final regex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value.trim())) return 'সঠিক ইমেইল দিন';
    return null;
  }

  /// Accepts either an email or a Bangladeshi phone number as the
  /// login identifier.
  static String? emailOrPhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'ইমেইল বা ফোন নম্বর দিন';
    final v = value.trim();
    final isEmail = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(v);
    final isPhone = RegExp(r'^01[3-9]\d{8}$').hasMatch(v);
    if (!isEmail && !isPhone) return 'সঠিক ইমেইল বা ফোন নম্বর দিন';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'পাসওয়ার্ড দিন';
    if (value.length < 6) return 'পাসওয়ার্ড কমপক্ষে ৬ ক্যারেক্টার হতে হবে';
    return null;
  }

  static String? required(String? value, {String message = 'এই ঘরটি পূরণ করুন'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return 'পরিমাণ দিন';
    final parsed = num.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return 'সঠিক পরিমাণ দিন';
    return null;
  }
}