import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 0)
class Message extends HiveObject {
  @HiveField(0)
  late String sender;

  @HiveField(1)
  late String body;

  @HiveField(2)
  late DateTime receivedAt;

  @HiveField(3)
  late bool processed;

  @HiveField(4)
  late int retryCount;

  Message({
    required this.sender,
    required this.body,
    required this.receivedAt,
    this.processed = false,
    this.retryCount = 0,
  });
}