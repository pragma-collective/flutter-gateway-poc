import 'package:hive/hive.dart';
import '../model/message.dart';
import 'api_service.dart';

class MessageService {
  final ApiService _apiService = ApiService();
  final Box<Message> _messageBox = Hive.box<Message>('messages');

  /// Processes all unprocessed messages in batch.
  Future<void> processUnsentMessages() async {
    final messagesToProcess =
    _messageBox.values.where((msg) => !msg.processed).toList();

    for (final message in messagesToProcess) {
      try {
        await _apiService.sendMessage(message.sender, message.body);
        message.processed = true;
        await message.save();
        print("✅ Message processed: ${message.body}");
      } catch (e) {
        message.retryCount += 1;
        await message.save();
        print("🔁 Retry #${message.retryCount} for message: ${message.body}");
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
