import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // Keys for stored values
  static const String _phoneNumberKey = 'phone_number';

  // Save phone number
  static Future<void> savePhoneNumber(String phoneNumber) async {
    try {
      await _storage.write(key: _phoneNumberKey, value: phoneNumber);
      debugPrint('📱 Phone number saved to secure storage');
    } catch (e) {
      debugPrint('💥 Error saving phone number: $e');
      rethrow;
    }
  }

  // Get phone number
  static Future<String?> getPhoneNumber() async {
    try {
      final phoneNumber = await _storage.read(key: _phoneNumberKey);
      return phoneNumber;
    } catch (e) {
      debugPrint('💥 Error retrieving phone number: $e');
      return null;
    }
  }

  // Delete phone number
  static Future<void> deletePhoneNumber() async {
    try {
      await _storage.delete(key: _phoneNumberKey);
      debugPrint('🗑️ Phone number deleted from secure storage');
    } catch (e) {
      debugPrint('💥 Error deleting phone number: $e');
      rethrow;
    }
  }

  // Clear all secure storage
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('🧹 All secure storage cleared');
    } catch (e) {
      debugPrint('💥 Error clearing secure storage: $e');
      rethrow;
    }
  }
}