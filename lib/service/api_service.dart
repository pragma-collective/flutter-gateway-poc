import 'package:dio/dio.dart';
import '../util.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.31.36:8000/api', // Replace with your actual API
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  Future<void> sendMessage(String phoneNumber, String message) async {
    try {
      final token = await TokenUtil.getStoredFcmToken();
      if (token == null) {
        throw Exception('Missing FCM token. Cannot send message.');
      }

      final response = await _dio.post(
        '/sms/message.send/', // Replace with your endpoint
        data: {
          'token': token,
          'mobile': phoneNumber,
          'message': message
        },
      );

      if (response.statusCode == 200) {
        print("✅ Message sent successfully");
      } else {
        throw Exception("❌ Unexpected status code: ${response.statusCode}");
      }
    } on DioException catch (e) {
      print("🚨 Dio error: ${e.message}");
      rethrow;
    } catch (e) {
      print("🚨 Unknown error: $e");
      rethrow;
    }
  }
}
