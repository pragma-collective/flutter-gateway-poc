import 'package:isar/isar.dart';
import 'package:cellfi_app/models/message.dart';
import 'api_service.dart';
import 'package:cellfi_app/utils/command_validator.dart';

class MessageService {
  final ApiService _apiService = ApiService();

  /// Processes all unprocessed messages in batch.
  Future<void> processUnsentMessages(Isar isar) async {
    final messages = await isar.messages
        .filter()
        .processedEqualTo(false)
        .retryCountLessThan(2)
        .findAll();

    final validMessages = messages
        .where((msg) => CommandValidator.isValidCommand(msg.body))
        .toList();

    for (final msg in validMessages) {
      try {
        await _apiService.sendMessage(msg.body);
        await isar.writeTxn(() async {
          msg.processed = true;
          await isar.messages.put(msg);
        });
      } catch (e) {
        await isar.writeTxn(() async {
          msg.retryCount += 1;
          await isar.messages.put(msg);
        });
      }
    }
  }

  /// Optional cleanup for failed messages
  Future<void> deleteFailedMessages(Isar isar, {int retryLimit = 3}) async {
    final failedMessages = await isar.messages
        .filter()
        .retryCountGreaterThan(retryLimit)
        .findAll();

    await isar.writeTxn(() async {
      for (final msg in failedMessages) {
        await isar.messages.delete(msg.id);
        print("🗑️ Deleted message after $retryLimit retries: ${msg.body}");
      }
    });
  }
}