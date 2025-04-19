import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/message.dart';

class MessageListPage extends StatelessWidget {
  const MessageListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final messageBox = Hive.box<Message>('messages');

    return Scaffold(
      appBar: AppBar(title: const Text('📄 Stored Messages')),
      body: ValueListenableBuilder(
        valueListenable: messageBox.listenable(),
        builder: (context, Box<Message> box, _) {
          final messages = box.values.toList().cast<Message>();

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
                  message.processed ? Icons.check_circle : Icons.hourglass_empty,
                  color: message.processed ? Colors.green : Colors.orange,
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
                trailing: Text("🔁 ${message.retryCount}"),
              );
            },
          );
        },
      ),
    );
  }
}
