import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../models/message.dart';
import '../utils/isar_helper.dart';

class MessageProvider extends ChangeNotifier {
  bool _isLoading = true;
  List<Message> _messages = [];

  bool get isLoading => _isLoading;
  List<Message> get messages => _messages;

  /// Load messages from Isar database
  Future<void> loadMessages() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Make sure Isar is initialized
      await IsarHelper.initialized;

      final isar = IsarHelper.getIsarInstance();
      _messages = await isar.messages.where().sortByReceivedAtDesc().findAll();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint("💥 Error loading messages: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force refresh the message list
  Future<void> refresh() async {
    try {
      // Make sure Isar is initialized
      await IsarHelper.initialized;

      final isar = IsarHelper.getIsarInstance();
      _messages = await isar.messages.where().sortByReceivedAtDesc().findAll();
      notifyListeners();
    } catch (e) {
      debugPrint("💥 Error refreshing messages: $e");
    }
  }

  /// Watch messages stream for real-time updates
  Stream<List<Message>> watchMessages() {
    try {
      final isar = IsarHelper.getIsarInstance();
      return isar.messages.where().sortByReceivedAtDesc().watch(fireImmediately: true);
    } catch (e) {
      debugPrint("💥 Error watching messages: $e");
      return Stream.value([]);
    }
  }

  /// Add a new message
  Future<void> addMessage(Message message) async {
    try {
      final isar = IsarHelper.getIsarInstance();
      await isar.writeTxn(() async {
        await isar.messages.put(message);
      });
      await refresh();
    } catch (e) {
      debugPrint("💥 Error adding message: $e");
    }
  }

  /// Update a message
  Future<void> updateMessage(Message message) async {
    try {
      final isar = IsarHelper.getIsarInstance();
      await isar.writeTxn(() async {
        await isar.messages.put(message);
      });
      await refresh();
    } catch (e) {
      debugPrint("💥 Error updating message: $e");
    }
  }

  /// Delete a message
  Future<void> deleteMessage(int id) async {
    try {
      final isar = IsarHelper.getIsarInstance();
      await isar.writeTxn(() async {
        await isar.messages.delete(id);
      });
      await refresh();
    } catch (e) {
      debugPrint("💥 Error deleting message: $e");
    }
  }
}