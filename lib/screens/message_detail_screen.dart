import 'package:flutter/material.dart';
import 'package:cellfi_app/models/message.dart';
import 'package:cellfi_app/core/services/api_service.dart';
import 'package:cellfi_app/utils/command_validator.dart';
import 'package:cellfi_app/utils/isar_helper.dart';
import 'package:cellfi_app/core/services/message_service.dart';
import 'package:provider/provider.dart';
import 'package:cellfi_app/widgets/message_processor_widget.dart';

class MessageDetailScreen extends StatefulWidget {
  final Message message;

  const MessageDetailScreen({super.key, required this.message});

  @override
  State<MessageDetailScreen> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends State<MessageDetailScreen> {
  bool _isSending = false;
  String? _apiResponse;
  bool _isListeningToProcessing = false;
  bool _processingCompleted = false;
  bool _needsRefresh = false;

  @override
  void initState() {
    super.initState();

    // Start listening to processing events if message is not yet processed
    if (!widget.message.processed) {
      _startListeningToProcessing();
    }

    // Check for fresh message state
    _refreshMessageState();
  }

  @override
  void dispose() {
    _isListeningToProcessing = false;
    super.dispose();
  }

  Future<void> _refreshMessageState() async {
    try {
      final isar = IsarHelper.getIsarInstance();
      final freshMessage = await isar.messages.get(widget.message.id);

      if (freshMessage != null && mounted) {
        if (freshMessage.processed != widget.message.processed ||
            freshMessage.retryCount != widget.message.retryCount) {
          setState(() {
            widget.message.processed = freshMessage.processed;
            widget.message.retryCount = freshMessage.retryCount;
            _needsRefresh = false;
          });
        }
      }
    } catch (e) {
      debugPrint("💥 Error refreshing message state: $e");
    }
  }

  void _startListeningToProcessing() {
    if (_isListeningToProcessing) return;

    _isListeningToProcessing = true;

    final messageService = Provider.of<MessageService>(context, listen: false);
    messageService.processingEvents.listen((event) {
      if (!mounted || !_isListeningToProcessing) return;

      // Check if this event is about our message
      if (event.message != null && event.message!.id == widget.message.id) {
        if (event.status == ProcessingStatus.messageSent) {
          setState(() {
            _apiResponse = "✅ Message sent successfully!";
            _processingCompleted = true;
            _isSending = false;
            // Update our message state
            widget.message.processed = true;
          });
        } else if (event.status == ProcessingStatus.messageError) {
          setState(() {
            _apiResponse = "❌ Failed to send message: ${event.error}";
            _isSending = false;
            _needsRefresh = true;
          });
        }
      }

      // Check for completed batch that might include our message
      if (event.status == ProcessingStatus.completed) {
        // Check if our message is in the successful messages
        final ourMessageSuccess = event.successfulMessages.any((m) => m.id == widget.message.id);
        final ourMessageFailed = event.failedMessages.any((m) => m.id == widget.message.id);

        if (ourMessageSuccess) {
          setState(() {
            _apiResponse = "✅ Message sent successfully!";
            _processingCompleted = true;
            _isSending = false;
            widget.message.processed = true;
          });
        } else if (ourMessageFailed) {
          setState(() {
            _apiResponse = "❌ Failed to send message";
            _isSending = false;
            _needsRefresh = true;
          });
        } else if (!_processingCompleted) {
          // If our message wasn't specifically mentioned, refresh to get latest state
          _refreshMessageState();
        }
      }
    });
  }

  Future<void> _sendToApi() async {
    setState(() {
      _isSending = true;
      _apiResponse = null;
    });

    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      final isar = IsarHelper.getIsarInstance();

      // Process this specific message
      final success = await messageService.processSingleMessage(isar, widget.message);

      if (success) {
        setState(() {
          _apiResponse = "✅ Message sent successfully!";
          _processingCompleted = true;
        });
      } else {
        setState(() {
          _apiResponse = "❌ Failed to send message";
          _needsRefresh = true;
        });
      }
    } catch (e) {
      setState(() {
        _apiResponse = "❌ Error: $e";
      });
    } finally {
      setState(() {
        _isSending = false;
      });

      // Refresh the message state to get the latest retry count
      await _refreshMessageState();
    }
  }

  Future<void> _resetMessage() async {
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      final isar = IsarHelper.getIsarInstance();

      await messageService.resetMessage(isar, widget.message);

      setState(() {
        _apiResponse = "⚙️ Message reset and ready to send";
        _processingCompleted = false;
      });
    } catch (e) {
      setState(() {
        _apiResponse = "❌ Error resetting message: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isValidCommand = CommandValidator.isValidCommand(msg.body);

    // If we need to refresh the message state, do it now
    if (_needsRefresh) {
      _refreshMessageState();
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Message Details")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildStatusIcon(msg),
                        const SizedBox(width: 8),
                        Text("From: ${msg.sender}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("Message:", style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(msg.body, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Received: ${_formatDateTime(msg.receivedAt)}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text("Retry Count: ${msg.retryCount}",
                            style: TextStyle(
                              fontSize: 12,
                              color: msg.retryCount > 0 ? Colors.orange : Colors.grey,
                              fontWeight: msg.retryCount > 0 ? FontWeight.bold : FontWeight.normal,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Processing status
            const MessageProcessorWidget(showDetails: true),

            const SizedBox(height: 16),

            // Action buttons
            if (isValidCommand) ...[
              if (msg.processed) ...[
                // Message already processed
                _buildStatusCard(
                    icon: Icons.check_circle,
                    color: Colors.green,
                    title: "Message Sent",
                    message: "This message has already been processed and sent to the API."
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _resetMessage,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Reset & Resend"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
              ] else ...[
                // Message needs processing
                _isSending
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sendToApi,
                        icon: const Icon(Icons.send),
                        label: const Text("Send to API"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ]
            ] else ...[
              // Invalid command format
              _buildStatusCard(
                  icon: Icons.block,
                  color: Colors.red,
                  title: "Invalid Command Format",
                  message: "This message doesn't match any valid command pattern and won't be sent to the API."
              ),
            ],

            if (_apiResponse != null) ...[
              const SizedBox(height: 20),
              _buildStatusCard(
                  icon: _apiResponse!.startsWith("✅") ? Icons.check_circle :
                  _apiResponse!.startsWith("⚙️") ? Icons.settings : Icons.error,
                  color: _apiResponse!.startsWith("✅") ? Colors.green :
                  _apiResponse!.startsWith("⚙️") ? Colors.blue : Colors.red,
                  title: "API Response",
                  message: _apiResponse!
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(Message message) {
    if (message.processed) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else if (message.retryCount > 0) {
      return Badge(
        label: Text(message.retryCount.toString()),
        child: const Icon(Icons.error_outline, color: Colors.orange),
      );
    } else if (CommandValidator.isValidCommand(message.body)) {
      return const Icon(Icons.pending, color: Colors.blue);
    } else {
      return const Icon(Icons.sms, color: Colors.grey);
    }
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Today at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}