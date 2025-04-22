import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _phoneNumberKey = 'phone_number';
  static const _storage = FlutterSecureStorage();

  static Future<void> savePhoneNumber(String number) async {
    await _storage.write(key: _phoneNumberKey, value: number.trim());
  }

  static Future<String?> getPhoneNumber() async {
    return await _storage.read(key: _phoneNumberKey);
  }

  static Future<void> clearPhoneNumber() async {
    await _storage.delete(key: _phoneNumberKey);
  }
}
