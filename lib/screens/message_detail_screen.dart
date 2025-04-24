import 'package:flutter/material.dart';
import 'package:cellfi_app/models/message.dart';
import 'package:cellfi_app/core/services/api_service.dart';
import 'package:cellfi_app/utils/command_validator.dart';
import 'package:cellfi_app/utils/isar_helper.dart';

class MessageDetailScreen extends StatefulWidget {
  final Message message;

  const MessageDetailScreen({super.key, required this.message});

  @override
  State<MessageDetailScreen> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends State<MessageDetailScreen> {
  bool _isSending = false;
  String? _apiResponse;

  Future<void> _sendToApi() async {
    setState(() {
      _isSending = true;
      _apiResponse = null;
    });

    try {
      await ApiService().sendMessage(widget.message.sender, widget.message.body);

      final isar = IsarHelper.getIsarInstance();
      await isar.writeTxn(() async {
        widget.message.processed = true;
        await isar.messages.put(widget.message);
      });

      setState(() {
        _apiResponse = "✅ Message sent successfully!";
      });
    } catch (e) {
      setState(() {
        _apiResponse = "❌ Failed to send message: $e";
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;

    return Scaffold(
      appBar: AppBar(title: const Text("Message Details")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📱 From: ${msg.sender}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text("💬 Body:", style: TextStyle(fontSize: 14)),
            Text(msg.body, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Text("📅 Received: ${msg.receivedAt.toLocal()}"),
            Text("🔁 Retry Count: ${msg.retryCount}"),
            Text("✅ Processed: ${msg.processed}"),
            const SizedBox(height: 24),

            if (CommandValidator.isValidCommand(msg.body)) ...[
              _isSending
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                onPressed: _sendToApi,
                icon: const Icon(Icons.send),
                label: const Text("Send to API"),
              ),
            ] else ...[
              Text(
                msg.processed
                    ? "✅ Already sent"
                    : "❌ Invalid command format",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],

            if (_apiResponse != null) ...[
              const SizedBox(height: 20),
              Text("📡 Response: $_apiResponse", style: const TextStyle(fontSize: 14)),
            ]
          ],
        ),
      ),
    );
  }
}
