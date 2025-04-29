import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cellfi_app/core/services/message_service.dart';
import 'package:cellfi_app/models/message.dart';

class MessageProcessorWidget extends StatefulWidget {
  final bool showDetails;

  const MessageProcessorWidget({super.key, this.showDetails = false});

  @override
  State<MessageProcessorWidget> createState() => _MessageProcessorWidgetState();
}

class _MessageProcessorWidgetState extends State<MessageProcessorWidget> {
  ProcessingEvent? _lastEvent;
  List<ProcessingEvent> _recentEvents = [];
  static const int maxEvents = 5;

  @override
  void initState() {
    super.initState();
    _setupListener();
  }

  void _setupListener() {
    Provider.of<MessageService>(context, listen: false)
        .processingEvents
        .listen(_handleEvent);
  }

  void _handleEvent(ProcessingEvent event) {
    if (mounted) {
      setState(() {
        _lastEvent = event;

        // Add to recent events list and keep only the latest events
        _recentEvents.insert(0, event);
        if (_recentEvents.length > maxEvents) {
          _recentEvents = _recentEvents.sublist(0, maxEvents);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lastEvent == null) {
      return const SizedBox.shrink();
    }

    // Show compact status if details not requested
    if (!widget.showDetails) {
      return _buildCompactStatus(context, _lastEvent!);
    }

    return _buildDetailedStatus(context);
  }

  Widget _buildCompactStatus(BuildContext context, ProcessingEvent event) {
    String statusText = '';
    IconData icon = Icons.info;
    Color color = Colors.grey;

    switch (event.status) {
      case ProcessingStatus.started:
        statusText = 'Processing messages...';
        icon = Icons.sync;
        color = Colors.blue;
        break;
      case ProcessingStatus.processing:
        statusText = 'Processing ${event.totalMessages} messages...';
        icon = Icons.sync;
        color = Colors.blue;
        break;
      case ProcessingStatus.messageSent:
        statusText = 'Sent ${event.processedCount}/${event.totalMessages}';
        icon = Icons.send;
        color = Colors.green;
        break;
      case ProcessingStatus.messageError:
        statusText = 'Failed to send a message';
        icon = Icons.error_outline;
        color = Colors.orange;
        break;
      case ProcessingStatus.completed:
        if (event.processedCount > 0) {
          statusText = 'Processed: ${event.processedCount} sent';
          icon = Icons.check_circle;
          color = Colors.green;
        } else if (event.failedCount > 0) {
          statusText = 'Processed: ${event.failedCount} failed';
          icon = Icons.error;
          color = Colors.orange;
        } else if (event.skippedCount > 0) {
          statusText = 'Processed: ${event.skippedCount} skipped';
          icon = Icons.skip_next;
          color = Colors.blue;
        } else {
          statusText = 'No messages to process';
          icon = Icons.info;
          color = Colors.grey;
        }
        break;
      case ProcessingStatus.error:
        statusText = 'Error processing messages';
        icon = Icons.error;
        color = Colors.red;
        break;
      case ProcessingStatus.cleanup:
        statusText = 'Cleaned up ${event.cleanedUpCount} failed messages';
        icon = Icons.delete_sweep;
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStatus(BuildContext context) {
    // First, show the most recent main event
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEventCard(_lastEvent!),

        // If we have recent events, show a history section
        if (_recentEvents.length > 1) ...[
          const SizedBox(height: 16),
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ..._recentEvents.skip(1).map((event) => _buildEventHistoryItem(event)),
        ],
      ],
    );
  }

  Widget _buildEventCard(ProcessingEvent event) {
    switch (event.status) {
      case ProcessingStatus.started:
        return _buildStartedStatus(context);
      case ProcessingStatus.processing:
        return _buildProcessingStatus(context, event);
      case ProcessingStatus.messageSent:
        return _buildMessageSentStatus(context, event);
      case ProcessingStatus.messageError:
        return _buildMessageErrorStatus(context, event);
      case ProcessingStatus.completed:
        return _buildCompletedStatus(context, event);
      case ProcessingStatus.error:
        return _buildErrorStatus(context, event);
      case ProcessingStatus.cleanup:
        return _buildCleanupStatus(context, event);
    }
  }

  Widget _buildEventHistoryItem(ProcessingEvent event) {
    String statusText = '';
    IconData icon = Icons.info;
    Color color = Colors.grey;

    switch (event.status) {
      case ProcessingStatus.started:
        statusText = 'Started processing messages';
        icon = Icons.play_arrow;
        color = Colors.blue;
        break;
      case ProcessingStatus.processing:
        statusText = 'Processing ${event.totalMessages} messages';
        icon = Icons.sync;
        color = Colors.blue;
        break;
      case ProcessingStatus.messageSent:
        statusText = 'Sent message to ${event.message?.sender ?? 'unknown'}';
        icon = Icons.send;
        color = Colors.green;
        break;
      case ProcessingStatus.messageError:
        statusText = 'Failed to send message to ${event.message?.sender ?? 'unknown'}';
        icon = Icons.error_outline;
        color = Colors.orange;
        break;
      case ProcessingStatus.completed:
        if (event.processedCount > 0) {
          statusText = 'Completed: ${event.processedCount} sent, ${event.failedCount} failed, ${event.skippedCount} skipped';
        } else {
          statusText = 'Completed: No messages to process';
        }
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case ProcessingStatus.error:
        statusText = 'Error processing messages: ${event.error?.split('\n').first ?? ''}';
        icon = Icons.error;
        color = Colors.red;
        break;
      case ProcessingStatus.cleanup:
        statusText = 'Cleaned up ${event.cleanedUpCount} failed messages';
        icon = Icons.delete_sweep;
        color = Colors.grey;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartedStatus(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Starting message processing...'),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingStatus(BuildContext context, ProcessingEvent event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text('Processing ${event.totalMessages} messages...'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageSentStatus(BuildContext context, ProcessingEvent event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Message sent successfully'),
                    const SizedBox(height: 4),
                    Text(
                      'Progress: ${event.processedCount}/${event.totalMessages}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            if (event.message != null) ...[
              const Divider(),
              Text(
                'To: ${event.message!.sender}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                event.message!.body,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageErrorStatus(BuildContext context, ProcessingEvent event) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Failed to send message'),
                      if (event.error != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.error!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (event.message != null) ...[
              const Divider(),
              Text(
                'To: ${event.message!.sender}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                event.message!.body,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedStatus(BuildContext context, ProcessingEvent event) {
    // Check if we have both processed and failed messages
    final hasActivity = event.processedCount > 0 || event.failedCount > 0 || event.skippedCount > 0;

    // Determine the main icon and color
    IconData statusIcon;
    Color statusColor;

    if (!hasActivity) {
      statusIcon = Icons.info;
      statusColor = Colors.grey;
    } else if (event.failedCount > 0) {
      statusIcon = Icons.warning;
      statusColor = Colors.orange;
    } else {
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Message processing completed'),
                    const SizedBox(height: 4),
                    hasActivity
                        ? Text(
                      '${event.processedCount} sent, ${event.failedCount} failed, ${event.skippedCount} skipped',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                        : Text(
                      'No messages to process',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),

            // Show list of successful messages if we have any
            if (event.successfulMessages.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Successfully sent:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              ...event.successfulMessages.take(3).map((msg) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      '• ${msg.sender}: ${msg.body.length > 30 ? '${msg.body.substring(0, 30)}...' : msg.body}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
              ),
              if (event.successfulMessages.length > 3)
                Text(
                  'and ${event.successfulMessages.length - 3} more...',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],

            // Show list of failed messages if we have any
            if (event.failedMessages.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Failed to send:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
              ),
              const SizedBox(height: 4),
              ...event.failedMessages.take(3).map((msg) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      '• ${msg.sender}: ${msg.body.length > 30 ? '${msg.body.substring(0, 30)}...' : msg.body}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
              ),
              if (event.failedMessages.length > 3)
                Text(
                  'and ${event.failedMessages.length - 3} more...',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorStatus(BuildContext context, ProcessingEvent event) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Error processing messages'),
                      if (event.error != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.error!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanupStatus(BuildContext context, ProcessingEvent event) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.delete_sweep, color: Colors.grey),
            const SizedBox(width: 16),
            Text('Cleaned up ${event.cleanedUpCount} failed messages'),
          ],
        ),
      ),
    );
  }
}