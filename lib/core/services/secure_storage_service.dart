import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:cellfi_app/utils/phone_number_util.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // Keys for stored values
  static const String _phoneNumberKey = 'phone_number';
  static const String _phoneCountryKey = 'phone_country_code';

  // Save phone number
  static Future<void> savePhoneNumber(String phoneNumber) async {
    try {
      // Normalize the phone number for API usage
      final normalizedNumber = PhoneFormatter.normalizeForApi(phoneNumber);

      // Save the normalized phone number
      await _storage.write(key: _phoneNumberKey, value: normalizedNumber);

      debugPrint('📱 Phone number saved to secure storage: $normalizedNumber');
    } catch (e) {
      debugPrint('💥 Error saving phone number: $e');
      rethrow;
    }
  }

  // Save phone number with country code
  static Future<void> savePhoneWithCountry(String phoneNumber, String countryCode) async {
    try {
      await _storage.write(key: _phoneNumberKey, value: phoneNumber);
      await _storage.write(key: _phoneCountryKey, value: countryCode);

      debugPrint('📱 Phone number and country code saved to secure storage');
    } catch (e) {
      debugPrint('💥 Error saving phone details: $e');
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

  // Get phone country code
  static Future<String?> getPhoneCountryCode() async {
    try {
      final countryCode = await _storage.read(key: _phoneCountryKey);
      return countryCode;
    } catch (e) {
      debugPrint('💥 Error retrieving phone country code: $e');
      return null;
    }
  }

  // Delete phone number
  static Future<void> deletePhoneNumber() async {
    try {
      await _storage.delete(key: _phoneNumberKey);
      await _storage.delete(key: _phoneCountryKey);
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