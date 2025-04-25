import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for managing API base URL configuration
class ApiUrlConfig {
  // Singleton pattern
  static final ApiUrlConfig _instance = ApiUrlConfig._internal();
  factory ApiUrlConfig() => _instance;
  ApiUrlConfig._internal();

  static const String baseUrlKey = 'api_base_url';
  String? _baseUrl;

  /// Default URL to use if none is saved
  static const String defaultBaseUrl = 'https://api.cellfi.xyz';

  /// Gets the saved base URL from SharedPreferences
  /// Returns the cached value if available, otherwise fetches from storage
  Future<String> getBaseUrl() async {
    if (_baseUrl != null) return _baseUrl!;

    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(baseUrlKey) ?? defaultBaseUrl;
    return _baseUrl!;
  }

  /// Saves the base URL to SharedPreferences and updates the cached value
  Future<bool> saveBaseUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(baseUrlKey, url);
      _baseUrl = url;
      return true;
    } catch (e) {
      print('Error saving base URL: $e');
      return false;
    }
  }

  /// Clears the cached base URL, forcing a reload from storage on next getBaseUrl call
  void clearCache() {
    _baseUrl = null;
  }
}