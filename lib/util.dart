import 'package:hive_flutter/hive_flutter.dart';
import '../model/message.dart';
import 'package:another_telephony/telephony.dart';
import 'package:path_provider/path_provider.dart';

Future<void> handleIncomingMessage(String sender, String body) async {
  final box = Hive.box<Message>('messages');

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
