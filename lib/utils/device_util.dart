import 'package:device_info_plus/device_info_plus.dart';

class DeviceUtil {
  static Future<String?> getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } catch (e) {
      print("⚠️ Failed to get device ID: $e");
      return null;
    }
  }
}