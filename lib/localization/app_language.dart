import 'package:flutter/material.dart';

enum AppLanguage {
  english(Locale('en'), 'English', 'English'),
  shona(Locale('sn'), 'Shona', 'ChiShona'),
  ndebele(Locale('nd'), 'Ndebele', 'isiNdebele'),
  zulu(Locale('zu'), 'isiZulu', 'isiZulu'),
  xhosa(Locale('xh'), 'isiXhosa', 'isiXhosa'),
  swahili(Locale('sw'), 'Swahili', 'Kiswahili'),
  afrikaans(Locale('af'), 'Afrikaans', 'Afrikaans'),
  french(Locale('fr'), 'French', 'Français'),
  portuguese(Locale('pt'), 'Portuguese', 'Português');

  const AppLanguage(this.locale, this.label, this.nativeLabel);

  final Locale locale;
  final String label;
  final String nativeLabel;

  static AppLanguage fromCode(String? code) {
    for (final language in values) {
      if (language.locale.languageCode == code) return language;
    }
    return AppLanguage.english;
  }
}
