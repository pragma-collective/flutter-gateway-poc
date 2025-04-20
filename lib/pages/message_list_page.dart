import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/message.dart';

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
                  message.processed ? Icons.check_circle : Icons.hourglass_top,
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
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(message.processed ? '✅ Sent' : '⏳ Pending'),
                    Text('🔁 ${message.retryCount}'),
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
