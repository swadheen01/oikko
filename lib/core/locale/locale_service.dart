import 'package:flutter/foundation.dart';

enum Language { bn, en }

class LocaleService {
  LocaleService._();

  static final ValueNotifier<Language> notifier = ValueNotifier(Language.bn);

  static Language get current => notifier.value;

  static bool get isEnglish => notifier.value == Language.en;

  static void toggle() {
    notifier.value = notifier.value == Language.bn ? Language.en : Language.bn;
  }
}
