import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token in secure storage; theme + language in shared preferences.
class Storage {
  static const _secure = FlutterSecureStorage();
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- auth tokens ----
  static Future<void> saveTokens(String access, String refresh) async {
    await _secure.write(key: 'token', value: access);
    await _secure.write(key: 'refreshToken', value: refresh);
  }

  static Future<void> saveToken(String token) =>
      _secure.write(key: 'token', value: token);
  static Future<String?> getToken() => _secure.read(key: 'token');
  static Future<String?> getRefreshToken() =>
      _secure.read(key: 'refreshToken');

  static Future<void> clearToken() async {
    await _secure.delete(key: 'token');
    await _secure.delete(key: 'refreshToken');
  }

  // ---- theme ----
  static String get themeMode => _prefs?.getString('themeMode') ?? 'light';
  static Future<void> setThemeMode(String v) async =>
      _prefs?.setString('themeMode', v);

  // ---- language ----
  static String get lang => _prefs?.getString('lang') ?? 'lo';
  static Future<void> setLang(String v) async => _prefs?.setString('lang', v);
}
