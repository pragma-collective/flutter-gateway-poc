import 'package:flutter/foundation.dart';
import 'package:cellfi_app/core/services/api_service.dart';

class DeviceRegistrationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool isLoading = true;
  String? error;

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
}