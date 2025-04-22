import 'package:dio/dio.dart';
import 'package:cellfi_app/service/device_registration_service.dart';
import 'package:cellfi_app/service/api_token_service.dart';

class ApiService {
  static const String _baseUrl = 'http://192.168.31.36:8000/api';

  /// Creates a Dio instance, optionally with auth headers
  Future<Dio> _getDio({bool withAuth = false}) async {
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
    };

    if (withAuth) {
      final apiToken = await ApiTokenService.getApiToken();
      if (apiToken != null) {
        headers['Authorization'] = 'Token $apiToken';
      }
    }

    return Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: headers,
    ));
  }

  /// Sends an SMS message to the backend
  Future<void> sendMessage(String phoneNumber, String message) async {
    try {
      final dio = await _getDio(withAuth: true);

      final response = await dio.post('/sms/message.send/', data: {
        'mobile': phoneNumber,
        'message': message,
      });

      if (response.statusCode == 200) {
        print("✅ Message sent successfully");
      } else {
        throw Exception("❌ Unexpected status: ${response.statusCode}");
      }
    } on DioException catch (e) {
      print("🚨 Dio error: ${e.message}");
      rethrow;
    } catch (e) {
      print("🚨 Unexpected error: $e");
      rethrow;
    }
  }

  /// Registers the current device and stores the api_token
  Future<void> registerDevice() async {
    final payload = await DeviceRegistrationService.getRegistrationPayload();

    if (payload == null) {
      throw Exception('❌ Missing device registration payload.');
    }

    try {
      final dio = await _getDio(); // no auth needed for device register

      final response = await dio.post('/device/device.register/', data: payload);

      if (response.statusCode == 200) {
        print("✅ Device registered: ${response.data}");

        final apiToken = response.data['api_token'];
        if (apiToken != null) {
          await ApiTokenService.saveApiToken(apiToken);
          print("🔐 API token stored securely.");
        }
      } else {
        throw Exception("❌ Unexpected status: ${response.statusCode}");
      }
    } catch (e) {
      print("🚨 Device registration failed: $e");
      rethrow;
    }
  }
}