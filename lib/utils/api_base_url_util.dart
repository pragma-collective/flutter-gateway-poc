import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiUrlConfig {
  static const String _baseUrlKey = 'api_base_url';
  static const String _defaultBaseUrl = 'https://api.cellfi.xyz'; // Replace with your default URL

  // Get the base URL, returning the default if not set
  Future<String> getBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;

      // Ensure URL does not end with a slash
      return baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    } catch (e) {
      debugPrint('💥 Error getting API base URL: $e');
      return _defaultBaseUrl;
    }
  }

  // Save a new base URL
  Future<bool> saveBaseUrl(String baseUrl) async {
    try {
      // Normalize the URL
      String normalizedUrl = baseUrl.trim();
      if (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }

      // URL validation should be done in the UI before calling this method

      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.setString(_baseUrlKey, normalizedUrl);
      debugPrint('🌐 API base URL set to: $normalizedUrl');
      return result;
    } catch (e) {
      debugPrint('💥 Error setting API base URL: $e');
      return false;
    }
  }

  // Reset to default URL
  Future<bool> resetToDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.setString(_baseUrlKey, _defaultBaseUrl);
      debugPrint('🔄 API base URL reset to default: $_defaultBaseUrl');
      return result;
    } catch (e) {
      debugPrint('💥 Error resetting API base URL: $e');
      return false;
    }
  }
}