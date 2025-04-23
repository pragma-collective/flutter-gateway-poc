import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cellfi_app/models/message.dart';
import 'package:cellfi_app/utils/isar_helper.dart';

class MessageProvider extends ChangeNotifier {
  Isar? _isar;
  List<Message> _messages = [];
  bool _loading = true;

  List<Message> get messages => _messages;
  bool get isLoading => _loading;

  Future<void> _ensureIsarInitialized() async {
    if (_isar != null) return;

    final dir = await getApplicationDocumentsDirectory();
    _isar ??= IsarHelper.getIsarInstance(); // ✅ Use the initialized instance
  }

  Future<void> loadMessages() async {
    _loading = true;
    notifyListeners();

    await _ensureIsarInitialized();

    final query = _isar!.messages
        .where()
        .sortByReceivedAtDesc();

    _messages = await query.findAll();
    _loading = false;
    notifyListeners();
  }

  Future<void> refresh() async => loadMessages();

  Future<void> markAsProcessed(Message message) async {
    if (_isar == null) await _ensureIsarInitialized();
    await _isar!.writeTxn(() async {
      message.processed = true;
      await _isar!.messages.put(message);
    });
    await refresh();
  }

  Stream<List<Message>> watchMessages() {
    _isar ??= Isar.getInstance('default');
    return _isar!.messages
        .where()
        .sortByReceivedAtDesc()
        .watch(fireImmediately: true);
  }
}