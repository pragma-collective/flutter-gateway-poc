import 'package:flutter/foundation.dart';
import 'package:cellfi_app/core/services/api_service.dart';

class DeviceRegistrationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool isLoading = true;
  String? error;
  String _baseUrl = '';

  Future<void> register() async {
    try {
      await _apiService.registerDevice();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void updateConfig({
    String? baseUrl,
    // Other optional parameters as needed
  }) {
    if (baseUrl != null && baseUrl != _baseUrl) {
      _baseUrl = baseUrl;
      // Update any API client or service that needs the new URL
    }

    // Update other config parameters similarly

    // Notify listeners if needed
    notifyListeners();
  }
}