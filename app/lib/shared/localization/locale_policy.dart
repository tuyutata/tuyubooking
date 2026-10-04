import 'package:flutter/widgets.dart';

/// Shared Chinese/English locale policy for every TuyuBooking platform.
///
/// Chinese remains the safe fallback. English becomes primary only when the
/// operating system explicitly requests it; bilingual widgets still render
/// the other language as secondary assistance.
abstract final class TuyuLocalePolicy {
  static const supportedLocales = <Locale>[Locale('zh'), Locale('en')];

  static Locale resolve(Locale? locale, Iterable<Locale> supported) {
    if (locale?.languageCode == 'en') {
      return supported.firstWhere(
        (item) => item.languageCode == 'en',
        orElse: () => const Locale('zh'),
      );
    }
    return const Locale('zh');
  }
}
