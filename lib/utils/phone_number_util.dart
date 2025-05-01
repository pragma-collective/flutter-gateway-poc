import 'package:intl_phone_field/phone_number.dart';

class PhoneFormatter {
  /// Formats a phone number for display
  /// If parsing fails, returns the original number
  static String formatForDisplay(String phoneNumber) {
    // Basic formatting - add spaces for readability
    if (phoneNumber.startsWith('+')) {
      // Try to format like +XX XXX XXX XXXX
      String digits = phoneNumber.substring(1); // Remove the +

      if (digits.length > 2) {
        // Format country code
        String countryCode = digits.substring(0, 2);
        String remainingDigits = digits.substring(2);

        // Format the remaining digits in groups of 3 or 4
        String formatted = '+$countryCode';

        // Add spaces every 3 digits for better readability
        for (int i = 0; i < remainingDigits.length; i += 3) {
          int end = i + 3;
          if (end > remainingDigits.length) end = remainingDigits.length;
          formatted += ' ' + remainingDigits.substring(i, end);
        }

        return formatted.trim();
      }
    }

    // If we couldn't format it properly, just return the original
    return phoneNumber;
  }

  /// Formats a phone number for display from a PhoneNumber object
  static String formatFromPhoneNumber(PhoneNumber phoneNumber) {
    return '+${phoneNumber.countryCode} ${phoneNumber.number}';
  }

  /// Normalizes a phone number for API calls
  /// Ensures the number has a + prefix and no spaces or dashes
  static String normalizeForApi(String phoneNumber) {
    // Remove any non-digit characters except +
    String normalized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Fix the double plus sign issue - remove all + signs first
    normalized = normalized.replaceAll('+', '');

    // Now add just one + at the beginning
    normalized = '+$normalized';

    return normalized;
  }

  /// Normalizes a PhoneNumber object for API calls
  static String normalizePhoneNumberForApi(PhoneNumber phoneNumber) {
    return '+${phoneNumber.countryCode}${phoneNumber.number}';
  }

  /// Validates a phone number (basic validation)
  static bool isValidPhoneNumber(String phoneNumber) {
    // Remove any non-digit characters except +
    String normalized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Basic validation - at least 8 digits and at most 15 digits (E.164 standard)
    return normalized.length >= 8 && normalized.length <= 16;
  }
}