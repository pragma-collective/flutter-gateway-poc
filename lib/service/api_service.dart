import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://test.local.me', // Replace with your actual API
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  Future<void> sendMessage(String sender, String body) async {
    try {
      final response = await _dio.post(
        '/messages', // Replace with your endpoint
        data: {
          'sender': sender,
          'body': body,
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
