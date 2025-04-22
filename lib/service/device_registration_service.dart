import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class DeviceRegistrationService {
  /// Retrieves a stable device ID based on platform
  static Future<String?> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        return android.id; // Unique to device
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        return ios.identifierForVendor; // Unique to app install
      }
    } catch (e) {
      print("❌ Failed to get device ID: $e");
    }

    return null;
  }

  /// Retrieves the FCM token
  static Future<String?> getFcmToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      print("❌ Failed to get FCM token: $e");
      return null;
    }
  }

  /// Returns a combined registration payload
  static Future<Map<String, dynamic>?> getRegistrationPayload({int? userId}) async {
    final deviceId = await getDeviceId();
    final token = await getFcmToken();

    if (deviceId == null || token == null) {
      print("⚠️ Cannot create registration payload: missing data.");
      return null;
    }

    return {
      'device_id': deviceId,
      'fcm_token': token,
      'platform': Platform.operatingSystem,
      if (userId != null) 'user_id': userId,
    };
  }
}