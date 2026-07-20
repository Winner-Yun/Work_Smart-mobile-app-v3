import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';

class LanguageManager with ChangeNotifier {
  static final LanguageManager _instance = LanguageManager._internal();
  factory LanguageManager() => _instance;
  LanguageManager._internal();

  String _locale = 'km';
  final DatabaseHelper _db = DatabaseHelper();

  String get locale => _locale;

  Future<void> loadSettings() async {
    final String? savedLang = await _db.getConfig('language_code');
    if (savedLang != null) {
      _locale = savedLang;
    }
    notifyListeners();
  }

  Future<void> changeLanguage(String newLocale) async {
    if (_locale == newLocale) return;

    _locale = newLocale;
    await _db.saveConfig('language_code', newLocale);
    notifyListeners();
  }
}
