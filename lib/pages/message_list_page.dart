import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/message.dart';
import '../util.dart';
import '../service/api_service.dart';

class MessageListPage extends StatefulWidget {
  const MessageListPage({super.key});

  @override
  State<MessageListPage> createState() => _MessageListPageState();
}

class _MessageListPageState extends State<MessageListPage> {
  bool showOnlyUnprocessed = false;

  void toggleFilter() {
    setState(() {
      showOnlyUnprocessed = !showOnlyUnprocessed;
    });
  }

  void _sendMessageToApi(Message message) async {
    try {
      await ApiService().sendMessage(message.sender, message.body);
      message.processed = true;
      await message.save();

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

  @override
  Widget build(BuildContext context) {
    final messageBox = Hive.box<Message>('messages');

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
      body: ValueListenableBuilder(
        valueListenable: messageBox.listenable(),
        builder: (context, Box<Message> box, _) {
          List<Message> messages = box.values.toList().cast<Message>();

          if (showOnlyUnprocessed) {
            messages = messages.where((msg) => !msg.processed).toList();
          }

          if (messages.isEmpty) {
            return const Center(child: Text('No messages found.'));
          }

          return ListView.separated(
            itemCount: messages.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final message = messages[index];
              return ListTile(
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
                title: Text(message.sender),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message.body),
                    Text(
                      '📅 ${message.receivedAt.toLocal()}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!message.processed &&
                        CommandValidator.isValidCommand(message.body)) ...[
                      ElevatedButton(
                        onPressed: () => _sendMessageToApi(message),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          minimumSize: const Size(60, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Send', style: TextStyle(fontSize: 12)),
                      ),
                    ] else ...[
                      Text(
                        message.processed ? '✅ Sent' : '❌ Invalid',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    Text('🔁 ${message.retryCount}', style: const TextStyle(fontSize: 12)),
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
