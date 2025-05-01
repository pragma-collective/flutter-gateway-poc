import 'package:flutter/foundation.dart';
import 'package:cellfi_app/core/services/api_service.dart';
import 'package:cellfi_app/utils/token_util.dart';
import 'package:cellfi_app/utils/isar_helper.dart';

class DeviceRegistrationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool isLoading = true;
  String? error;
  bool isDeviceRegistered = false;

  DeviceRegistrationProvider() {
    // We can reset the client on init to ensure it uses the latest URL
    _apiService.resetClient();
  }

  Future<void> register() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _apiService.registerDevice();

      // If we reach here, registration was successful
      isDeviceRegistered = true;

      // Ensure Isar is initialized after registration
      // This helps prevent the issue with database initialization after registration
      if (!IsarHelper.isIsarReady()) {
        debugPrint("🔄 Initializing Isar after successful device registration");
        try {
          await IsarHelper.initIsar();
          debugPrint("✅ Isar successfully initialized after registration");
        } catch (isarError) {
          debugPrint("⚠️ Non-critical error initializing Isar after registration: $isarError");
          // We don't want to fail the registration process if Isar init fails
          // The app will try again later
        }
      }
    } catch (e) {
      error = e.toString();
      isDeviceRegistered = false;
      debugPrint("❌ Device registration error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkDevice() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final token = await TokenUtil.getApiToken();

      if (token == null || token.isEmpty) {
        error = "No API token found";
        isDeviceRegistered = false;
        isLoading = false;
        notifyListeners();
        return;
      }

      await _apiService.checkDevice();

      // If we get here without an exception, the device is registered
      isDeviceRegistered = true;

      // Also ensure Isar is initialized
      if (!IsarHelper.isIsarReady()) {
        debugPrint("🔄 Initializing Isar after successful device check");
        try {
          await IsarHelper.initIsar();
          debugPrint("✅ Isar successfully initialized after device check");
        } catch (isarError) {
          debugPrint("⚠️ Non-critical error initializing Isar after device check: $isarError");
          // We don't want to fail the device check if Isar init fails
        }
      }
    } catch (e) {
      error = e.toString();
      isDeviceRegistered = false;
      debugPrint("❌ Device check error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Reset state (useful when logging out or clearing app data)
  void reset() {
    isLoading = true;
    error = null;
    isDeviceRegistered = false;
    _apiService.resetClient();
    notifyListeners();
  }
}