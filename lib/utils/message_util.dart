import 'package:another_telephony/telephony.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
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

/// Handle SMS when received in the background (must be a top-level function)
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [MessageSchema],
    directory: dir.path,
    inspector: false, // disable in background
    name: 'default'
  );

  final newMsg = Message()
    ..sender = message.address ?? 'Unknown'
    ..body = message.body ?? ''
    ..receivedAt = DateTime.now()
    ..processed = false
    ..retryCount = 0;

  await isar.writeTxn(() async {
    await isar.messages.put(newMsg);
  });

  await isar.close(); // Optional: close to free resources
}

Future<void> sendSms(Telephony telephony, String phoneNumber, String messageContent) async {
  final permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
  if (permissionsGranted ?? false) {
    telephony.sendSms(
      to: phoneNumber,
      message: messageContent,
    );
    print("📤 SMS sent to \$phoneNumber");
  } else {
    print("❌ SMS permission not granted");
  }
}
