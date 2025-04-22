import 'package:another_telephony/telephony.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cellfi_app/models/message.dart';

/// Open Hive box safely for messages
Future<Box<Message>> getMessageBox() async {
  if (!Hive.isBoxOpen('messages')) {
    return await Hive.openBox<Message>('messages');
  }
  return Hive.box<Message>('messages');
}

/// Handle foreground incoming messages
Future<void> handleIncomingMessage(String sender, String body) async {
  final box = await getMessageBox();

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

/// Handle SMS when received in the background (must be a top-level function)
@pragma('vm:entry-point')
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