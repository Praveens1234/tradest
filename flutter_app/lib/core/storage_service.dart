import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _tokenKey = 'auth_token';
  static const _serverUrlKey = 'server_url';
  static const _defaultServerUrl = 'http://192.168.1.10:8000';

  static const _lastEaIdKey = 'last_ea_id';
  static const _lastSymbolKey = 'last_symbol';
  static const _lastPeriodKey = 'last_period';
  static const _lastFromDateKey = 'last_from_date';
  static const _lastToDateKey = 'last_to_date';
  static const _lastDepositKey = 'last_deposit';
  static const _lastCurrencyKey = 'last_currency';
  static const _lastLeverageKey = 'last_leverage';
  static const _lastModelKey = 'last_model';
  static const _kThemeMode = 'theme_mode';

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

  Future<void> saveLastBacktestParams({
    required int eaId,
    required String symbol,
    required String period,
    required String fromDate,
    required String toDate,
    required double deposit,
    required String currency,
    required int leverage,
    required int model,
  }) async {
    final prefs = await _storage;
    await prefs.setInt(_lastEaIdKey, eaId);
    await prefs.setString(_lastSymbolKey, symbol);
    await prefs.setString(_lastPeriodKey, period);
    await prefs.setString(_lastFromDateKey, fromDate);
    await prefs.setString(_lastToDateKey, toDate);
    await prefs.setDouble(_lastDepositKey, deposit);
    await prefs.setString(_lastCurrencyKey, currency);
    await prefs.setInt(_lastLeverageKey, leverage);
    await prefs.setInt(_lastModelKey, model);
  }

  Future<Map<String, dynamic>> getLastBacktestParams() async {
    final prefs = await _storage;
    return {
      'ea_id': prefs.getInt(_lastEaIdKey),
      'symbol': prefs.getString(_lastSymbolKey) ?? 'EURUSD',
      'period': prefs.getString(_lastPeriodKey) ?? 'H1',
      'from_date': prefs.getString(_lastFromDateKey) ?? '2024.01.01',
      'to_date': prefs.getString(_lastToDateKey) ?? '2024.12.31',
      'deposit': prefs.getDouble(_lastDepositKey) ?? 10000.0,
      'currency': prefs.getString(_lastCurrencyKey) ?? 'USD',
      'leverage': prefs.getInt(_lastLeverageKey) ?? 100,
      'model': prefs.getInt(_lastModelKey) ?? 1,
    };
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await _storage;
    await prefs.setString(_kThemeMode, mode);
  }

  Future<String> getThemeMode() async {
    final prefs = await _storage;
    return prefs.getString(_kThemeMode) ?? 'system';
  }

  // Logout only clears the token, not the server URL or preferences.
  Future<void> clear() async {
    final prefs = await _storage;
    await prefs.remove(_tokenKey);
  }
}
