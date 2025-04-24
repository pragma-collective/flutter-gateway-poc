import 'package:isar/isar.dart';

part 'message.g.dart';

@collection
class Message {
  Id id = Isar.autoIncrement;

  late String sender;
  late String body;
  late DateTime receivedAt;

  bool processed = false;
  int retryCount = 0;
}