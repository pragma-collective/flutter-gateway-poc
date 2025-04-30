import 'package:dio/dio.dart';
import '../../utils/token_util.dart';
import '../../utils/device_util.dart';
import '../../utils/api_base_url_util.dart';
import 'package:flutter/foundation.dart';
import 'package:cellfi_app/core/services/secure_storage_service.dart';

class ApiService {
  Dio? _authenticatedDio;
  String? _cachedBaseUrl;
  String? _cachedApiToken;

  /// Public accessor for an authenticated Dio instance
  Future<Dio> _getAuthenticatedDio() async {
    // Use cached instance if available
    if (_authenticatedDio != null) return _authenticatedDio!;

    // Get API token (use cached if available)
    final apiToken = _cachedApiToken ?? await TokenUtil.getApiToken();
    if (apiToken == null) {
      throw Exception(
          "❌ No API token found. Please register device.");
    }
    _cachedApiToken = apiToken;

    // Get base URL (use cached if available)
    final apiConfig = ApiUrlConfig();
    final baseUrl = _cachedBaseUrl ?? await apiConfig.getBaseUrl();
    if (baseUrl == '') {
      throw Exception(
          "❌ No Base URL found.");
    }
    _cachedBaseUrl = baseUrl;

    debugPrint("🔌 Creating authenticated Dio instance with ${baseUrl}/api");

    // Create optimized Dio instance
    final dio = Dio(BaseOptions(
      baseUrl: '$baseUrl/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      // Enable gzip for faster transfers
      responseType: ResponseType.json,
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiToken,
        'Accept-Encoding': 'gzip, deflate',
      },
      // Add validateStatus to accept 204 responses
      validateStatus: (status) {
        return status != null && status >= 200 && status < 300;
      },
    ));

    // Add performance optimization interceptors
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final startTime = DateTime.now();
          options.extra['startTime'] = startTime;
          return handler.next(options);
        },
        onResponse: (response, handler) {
          final startTime = response.requestOptions.extra['startTime'] as DateTime?;
          if (startTime != null) {
            final endTime = DateTime.now();
            final duration = endTime.difference(startTime).inMilliseconds;
            debugPrint('🕒 API request took $duration ms: ${response.requestOptions.path}');
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          final startTime = error.requestOptions.extra['startTime'] as DateTime?;
          if (startTime != null) {
            final endTime = DateTime.now();
            final duration = endTime.difference(startTime).inMilliseconds;
            debugPrint('🕒 API request failed after $duration ms: ${error.requestOptions.path}');
          }
          return handler.next(error);
        },
      ),
    );

    // Cache the instance
    _authenticatedDio = dio;
    return dio;
  }

  /// Registers device and stores the API token
  Future<void> registerDevice() async {
    final registrationStartTime = DateTime.now();

    final fcmToken = await TokenUtil.fetchAndStoreFcmToken();
    final deviceId = await DeviceUtil.getDeviceId();
    final phoneNumber = await SecureStorageService.getPhoneNumber();

    final apiConfig = ApiUrlConfig();
    final baseUrl = _cachedBaseUrl ?? await apiConfig.getBaseUrl();
    if (baseUrl == '') {
      throw Exception(
          "❌ No Base URL found.");
    }
    _cachedBaseUrl = baseUrl;

    if (fcmToken == null) throw Exception('Missing FCM token');
    if (deviceId == null) throw Exception('Missing device ID');

    debugPrint("🔌 Registering device with ${baseUrl}/api");

    final dio = Dio(BaseOptions(
      baseUrl: '$baseUrl/api',
      connectTimeout: const Duration(seconds: 15), // Increased timeout for registration
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
      headers: {
        'Content-Type': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
      },
      // Add validateStatus to accept 204 responses
      validateStatus: (status) {
        return status != null && status >= 200 && status < 300;
      },
    ));

    final response = await dio.post('/device/device.register/', data: {
      'fcm_token': fcmToken,
      'device_id': deviceId,
      'mobile_number': phoneNumber
    });

    if ((response.statusCode == 200 || response.statusCode == 204) &&
        response.data != null && response.data['api_token'] != null) {
      final apiToken = response.data['api_token'];
      await TokenUtil.storeApiToken(apiToken);
      _cachedApiToken = apiToken; // Cache the token

      final duration = DateTime.now().difference(registrationStartTime).inMilliseconds;
      debugPrint("✅ API token saved (registration took $duration ms)");
    } else {
      throw Exception("❌ Device registration failed");
    }
  }

  /// Sends a message using the authenticated Dio instance
  Future<void> sendMessage(String phoneNumber, String message) async {
    final sendStartTime = DateTime.now();

    try {
      final dio = await _getAuthenticatedDio(); // Use auth-enabled client
      final response = await dio.post('/sms/message.send/', data: {
        'phone_number': phoneNumber,
        'message': message,
      });

      final duration = DateTime.now().difference(sendStartTime).inMilliseconds;

      // Check for success status codes (including 204 No Content)
      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        if (response.statusCode == 204) {
          debugPrint("📤 Message sent successfully (status: 204 No Content) in $duration ms");
        } else {
          debugPrint("📤 Message sent successfully (status: ${response.statusCode}) in $duration ms");
        }
      } else {
        throw Exception("❌ Unexpected response: ${response.statusCode}");
      }
    } on DioException catch (e) {
      final duration = DateTime.now().difference(sendStartTime).inMilliseconds;
      debugPrint("🚨 Dio error after $duration ms: ${e.message}");

      // Special handling for 204 responses that might be incorrectly treated as errors
      if (e.response?.statusCode == 204) {
        debugPrint("📤 Message sent successfully (status: 204 No Content) in $duration ms");
        return; // This is actually a success
      }

      rethrow;
    } catch (e) {
      final duration = DateTime.now().difference(sendStartTime).inMilliseconds;
      debugPrint("🚨 Message send error after $duration ms: $e");
      rethrow;
    }
  }

  /// Reset the cached Dio instance when needed (e.g., when API URL changes)
  void resetClient() {
    _authenticatedDio = null;
    _cachedBaseUrl = null;
  }
}