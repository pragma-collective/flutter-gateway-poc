import 'package:dio/dio.dart';
import '../../utils/token_util.dart';
import '../../utils/device_util.dart';
import '../../utils/api_base_url_util.dart';
import 'package:flutter/foundation.dart';
import 'package:cellfi_app/core/services/secure_storage_service.dart';

class ApiService {
  Dio? _authenticatedDio;

  /// Public accessor for an authenticated Dio instance
  Future<Dio> _getAuthenticatedDio() async {
    if (_authenticatedDio != null) return _authenticatedDio!;

    final apiToken = await TokenUtil.getApiToken();
    if (apiToken == null) {
      throw Exception(
          "❌ No API token found. Please register device.");
    }

    final apiConfig = ApiUrlConfig();
    final baseUrl = await apiConfig.getBaseUrl();
    if (baseUrl == '') {
      throw Exception(
          "❌ No Base URL found.");
    }

    final dio = Dio(BaseOptions(
      baseUrl: '$baseUrl/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiToken, // 🔄 Changed from Bearer token to X-API-Key
      },
    ));

    _authenticatedDio = dio;
    return dio;
  }

  /// Registers device and stores the API token
  Future<void> registerDevice() async {
    final fcmToken = await TokenUtil.fetchAndStoreFcmToken();
    final deviceId = await DeviceUtil.getDeviceId();
    final phoneNumber = await SecureStorageService.getPhoneNumber();

    final apiConfig = ApiUrlConfig();
    final baseUrl = await apiConfig.getBaseUrl();
    if (baseUrl == '') {
      throw Exception(
          "❌ No Base URL found.");
    }



    if (fcmToken == null) throw Exception('Missing FCM token');
    if (deviceId == null) throw Exception('Missing device ID');

    final dio = Dio(BaseOptions(
      baseUrl: '$baseUrl/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    final response = await dio.post('/device/device.register/', data: {
      'fcm_token': fcmToken,
      'device_id': deviceId,
      'mobile_number': phoneNumber
    });

    if (response.statusCode == 200 && response.data['api_token'] != null) {
      final apiToken = response.data['api_token'];
      await TokenUtil.storeApiToken(apiToken);
      debugPrint("✅ API token saved");
    } else {
      throw Exception("❌ Device registration failed");
    }
  }

  /// Sends a message using the authenticated Dio instance
  Future<void> sendMessage(String phoneNumber, String message) async {
    try {
      final dio = await _getAuthenticatedDio(); // Use auth-enabled client

      final response = await dio.post('/sms/message.send/', data: {
        'mobile': phoneNumber,
        'message': message,
      });

      if (response.statusCode == 200) {
        debugPrint("📤 Message sent successfully");
      } else {
        throw Exception("❌ Unexpected response: ${response.statusCode}");
      }
    } on DioException catch (e) {
      debugPrint("🚨 Dio error: ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("🚨 Message send error: $e");
      rethrow;
    }
  }
}