import 'package:hive_flutter/hive_flutter.dart';
import '../model/message.dart';
import 'service/message_service.dart';
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

  final processor = MessageService();
  await processor.processUnsentMessages();
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

  final processor = MessageService();
  await processor.processUnsentMessages();
}