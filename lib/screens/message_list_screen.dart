import 'package:flutter/material.dart';
import 'package:cellfi_app/models/message.dart';
import 'package:cellfi_app/core/services/api_service.dart';
import 'package:cellfi_app/utils/command_validator.dart';
import 'package:cellfi_app/screens/message_detail_screen.dart';
import 'package:cellfi_app/utils/isar_helper.dart';
import 'package:isar/isar.dart';

class MessageListScreen extends StatefulWidget {
  const MessageListScreen({super.key});

  @override
  State<MessageListScreen> createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  bool showOnlyUnprocessed = false;

  void toggleFilter() {
    setState(() {
      showOnlyUnprocessed = !showOnlyUnprocessed;
    });
  }

  Future<void> _sendMessageToApi(Message message) async {
    try {
      await ApiService().sendMessage(message.body);
      final isar = IsarHelper.getIsarInstance();
      await isar.writeTxn(() async {
        message.processed = true;
        await isar.messages.put(message);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Sent to API')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to send message: $e')),
      );
    }
  }

  Stream<List<Message>> watchMessages() {
    final isar = IsarHelper.getIsarInstance();
    final query = isar.messages
        .filter()
        .optional(showOnlyUnprocessed, (q) => q.processedEqualTo(false))
        .sortByReceivedAtDesc()
        .build();
    return query.watch(fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📄 Stored Messages'),
        actions: [
          IconButton(
            icon: Icon(
              showOnlyUnprocessed ? Icons.filter_alt_off : Icons.filter_alt,
            ),
            tooltip: showOnlyUnprocessed ? 'Show All' : 'Show Unprocessed Only',
            onPressed: toggleFilter,
          )
        ],
      ),
      body: StreamBuilder<List<Message>>(
        stream: watchMessages(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data!;
          if (messages.isEmpty) {
            return const Center(child: Text('No messages found.'));
          }

          return ListView.separated(
            itemCount: messages.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final message = messages[index];
              return ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessageDetailScreen(message: message),
                    ),
                  );
                },
                leading: Icon(
                  message.processed
                      ? Icons.check_circle
                      : CommandValidator.isValidCommand(message.body)
                      ? Icons.hourglass_top
                      : Icons.block,
                  color: message.processed
                      ? Colors.green
                      : CommandValidator.isValidCommand(message.body)
                      ? Colors.orange
                      : Colors.redAccent,
                ),
                title: Text(
                  message.sender,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '📅 ${message.receivedAt.toLocal()}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      message.processed
                          ? '✅ Sent'
                          : CommandValidator.isValidCommand(message.body)
                          ? '⏳ Pending'
                          : '❌ Invalid',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '🔁 ${message.retryCount}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
