import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenUtil {
  static const _storage = FlutterSecureStorage();
  static const _fcmKey = 'fcm_token';
  static const _apiTokenKey = 'api_token';

  static Future<String?> fetchAndStoreFcmToken() async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await _storage.write(key: _fcmKey, value: fcmToken);
    }

    return fcmToken;
  }

  static Future<String?> getStoredFcmToken() async {
    return await _storage.read(key: _fcmKey);
  }

  static Future<void> storeApiToken(String token) async {
    await _storage.write(key: _apiTokenKey, value: token);
  }

  static Future<String?> getApiToken() async {
    return await _storage.read(key: _apiTokenKey);
  }
}
