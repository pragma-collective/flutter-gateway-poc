import 'package:hive/hive.dart';
import '../model/message.dart';
import 'api_service.dart';
import '../util.dart';

class MessageService {
  final ApiService _apiService = ApiService();
  final Box<Message> _messageBox = Hive.box<Message>('messages');

  /// Processes all unprocessed messages in batch.
  Future<void> processUnsentMessages() async {
    final box = await getMessageBox(); // ✅ safe access

    final messages = box.values
        .where((msg) =>
    !msg.processed &&
        msg.retryCount < 2 &&
        CommandValidator.isValidCommand(msg.body))
        .toList();

    for (final msg in messages) {
      try {
        await _apiService.sendMessage(msg.sender, msg.body);
        msg.processed = true;
        await msg.save(); // ✅ save() is safe since msg is already from an open box
      } catch (e) {
        msg.retryCount += 1;
        await msg.save();
      }
    }
  }

  /// Optional cleanup for failed messages
  Future<void> deleteFailedMessages({int retryLimit = 3}) async {
    final failedMessages = _messageBox.values
        .where((msg) => msg.retryCount >= retryLimit)
        .toList();

    for (final msg in failedMessages) {
      await msg.delete();
      print("🗑️ Deleted message after $retryLimit retries: ${msg.body}");
    }
  }
}
