import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _tokenKey = 'auth_token';
  static const _serverUrlKey = 'server_url';
  static const _defaultServerUrl = 'http://192.168.1.10:8000';

  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  Future<SharedPreferences> get _storage async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> saveToken(String token) async {
    final prefs = await _storage;
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await _storage;
    return prefs.getString(_tokenKey);
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = await _storage;
    await prefs.setString(_serverUrlKey, url);
  }

  Future<String> getServerUrl() async {
    final prefs = await _storage;
    return prefs.getString(_serverUrlKey) ?? _defaultServerUrl;
  }

  Future<void> clear() async {
    final prefs = await _storage;
    await prefs.remove(_tokenKey);
    await prefs.remove(_serverUrlKey);
  }
}
