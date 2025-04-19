import 'package:hive_flutter/hive_flutter.dart';
import '../model/message.dart';
import 'service/message_service.dart';

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