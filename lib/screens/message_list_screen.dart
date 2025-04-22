import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cellfi_app/models/message.dart';
import 'package:cellfi_app/core/services/api_service.dart';
import 'package:cellfi_app/utils/command_validator.dart';
import 'package:cellfi_app/screens/message_detail_screen.dart';

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

  void _sendMessageToApi(Message message) async {
    try {
      await ApiService().sendMessage(message.body);
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
