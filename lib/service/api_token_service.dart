import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiTokenService {
  static const _apiTokenKey = 'api_token';
  static const _storage = FlutterSecureStorage();

  static Future<void> saveApiToken(String token) async {
    await _storage.write(key: _apiTokenKey, value: token);
  }

  static Future<String?> getApiToken() async {
    return await _storage.read(key: _apiTokenKey);
  }

  static Future<void> clearApiToken() async {
    await _storage.delete(key: _apiTokenKey);
  }
}