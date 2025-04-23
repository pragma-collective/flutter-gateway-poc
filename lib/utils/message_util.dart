import 'package:another_telephony/telephony.dart';
import 'package:isar/isar.dart';
import 'package:cellfi_app/models/message.dart';
import 'package:cellfi_app/utils/isar_helper.dart';

/// Handle foreground incoming messages
Future<void> handleIncomingMessage(Isar isar, String sender, String body) async {
  final newMessage = Message()
    ..sender = sender
    ..body = body
    ..receivedAt = DateTime.now()
    ..processed = false
    ..retryCount = 0;

  await isar.writeTxn(() async {
    await isar.messages.put(newMessage);
  });

  // if (CommandValidator.isValidCommand(body)) {
  //   final processor = MessageService();
  //   await processor.processUnsentMessages(isar);
  // } else {
  //   print("❌ Ignored non-command message: \$body");
  // }
}

// For SMS sending
Future<void> sendSms(Telephony telephony, String phoneNumber, String messageContent) async {
  try {
    await telephony.sendSms(
      to: phoneNumber,
      message: messageContent,
    );
  } catch (e) {
    print('Error sending SMS: $e');
  }
}

// Safe background message handler
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  // Initialize Isar first - this is safe to call multiple times
  await IsarHelper.initIsar();

  final newMsg = Message()
    ..sender = message.address ?? 'Unknown'
    ..body = message.body ?? ''
    ..receivedAt = DateTime.now()
    ..processed = false
    ..retryCount = 0;

  try {
    final isar = IsarHelper.getIsarInstance();
    await isar.writeTxn(() async {
      await isar.messages.put(newMsg);
    });

    // Ensure we close Isar properly after a background operation
    await IsarHelper.closeIsar();
  } catch (e) {
    print('Error in background message handler: $e');
    // Try to close Isar even if there was an error
    await IsarHelper.closeIsar();
  }
}
