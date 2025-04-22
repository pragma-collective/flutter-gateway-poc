import 'package:hive_flutter/hive_flutter.dart';
import '../model/message.dart';
import 'package:another_telephony/telephony.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<Box<Message>> getMessageBox() async {
  if (!Hive.isBoxOpen('messages')) {
    return await Hive.openBox<Message>('messages');
  }
  return Hive.box<Message>('messages');
}

Future<void> handleIncomingMessage(String sender, String body) async {
  final box = await getMessageBox(); // ✅ safe access

  await box.add(Message(
    sender: sender,
    body: body,
    receivedAt: DateTime.now(),
    processed: false,
    retryCount: 0,
  ));

  // if (CommandValidator.isValidCommand(body)) {
  //   final processor = MessageService();
  //   await processor.processUnsentMessages();
  // } else {
  //   print("❌ Ignored non-command message: $body");
  // }
}

@pragma('vm:entry-point') // Required for background isolate
void backgroundMessageHandler(SmsMessage message) async {
  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);
  Hive.registerAdapter(MessageAdapter());
  await Hive.openBox<Message>('messages');

  await Hive.box<Message>('messages').add(Message(
    sender: message.address ?? 'Unknown',
    body: message.body ?? '',
    receivedAt: DateTime.now(),
    processed: false,
    retryCount: 0,
  ));

  // final processor = MessageService();
  // await processor.processUnsentMessages();
}

class CommandValidator {
  static final List<RegExp> commandPatterns = [
    RegExp(r'^HELP$', caseSensitive: false),
    RegExp(r'^REGISTER\s+\S+$', caseSensitive: false),
    RegExp(r'^SEND\s+\d+(\.\d+)?\s+\S+\s+\S+$', caseSensitive: false),
    RegExp(r'^NOMINATE\s+\+?\d+\s+\+?\d+$', caseSensitive: false),
    RegExp(r'^ACCEPT\s+\S+$', caseSensitive: false),
    RegExp(r'^DENY\s+\S+$', caseSensitive: false),
    RegExp(r'^REQUEST\s+\d+(\.\d+)?\s+\S+\s+\S+$', caseSensitive: false),
  ];

  static bool isValidCommand(String message) {
    return commandPatterns.any((pattern) => pattern.hasMatch(message.trim()));
  }
}

class TokenUtil {
  static const _fcmTokenKey = 'fcm_token';
  static const _secureStorage = FlutterSecureStorage();

  /// Gets the current device token and stores it securely
  static Future<String?> getAndStoreFcmToken() async {
    try {
      // Request permission (especially on iOS)
      await FirebaseMessaging.instance.requestPermission();

      // Get current token
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        // Store securely
        await _secureStorage.write(key: _fcmTokenKey, value: token);
        print("📱 FCM Token retrieved and stored: $token");
      } else {
        print("⚠️ Failed to retrieve FCM token.");
      }

      return token;
    } catch (e) {
      print("❌ Error getting FCM token: $e");
      return null;
    }
  }

  /// Retrieves the stored FCM token (if any)
  static Future<String?> getStoredFcmToken() async {
    return await _secureStorage.read(key: _fcmTokenKey);
  }

  /// Removes the stored FCM token
  static Future<void> clearFcmToken() async {
    await _secureStorage.delete(key: _fcmTokenKey);
  }
}

Future<void> sendSms(Telephony telephony, String phoneNumber, String messageContent) async {
  final permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
  if (permissionsGranted ?? false) {
    telephony.sendSms(
      to: phoneNumber,
      message: messageContent,
    );
    print("📤 SMS sent to $phoneNumber");
  } else {
    print("❌ SMS permission not granted");
  }
}