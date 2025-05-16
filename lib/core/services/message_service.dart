import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:cellfi_app/models/message.dart';
import 'package:cellfi_app/utils/isar_helper.dart';
import 'package:cellfi_app/utils/command_validator.dart';
import 'api_service.dart';

class MessageService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;
  Timer? _processingTimer;

  // Set to track messages that are currently being processed
  // Using message IDs to identify messages
  final Set<int> _processingMessages = {};

  // Stream controller for notifying about message processing events
  final _messageProcessingController = StreamController<ProcessingEvent>.broadcast();

  // Expose stream for UI components to listen to
  Stream<ProcessingEvent> get processingEvents => _messageProcessingController.stream;

  // Current processing status
  bool get isProcessing => _isProcessing;

  // Performance tracking
  int _avgProcessingTimeMs = 0;
  int _totalProcessed = 0;

  MessageService() {
    // Start automatic processing if not already running
    // startAutomaticProcessing();
  }

  /// Starts automatic processing of messages at regular intervals
  void startAutomaticProcessing({Duration interval = const Duration(minutes: 2)}) {
    stopAutomaticProcessing(); // Cancel any existing timer

    _processingTimer = Timer.periodic(interval, (_) async {
      try {
        final isar = IsarHelper.getIsarInstance();
        await processUnsentMessages(isar);
      } catch (e) {
        debugPrint('❌ Error in automatic processing: $e');
      }
    });

    debugPrint('✅ Automatic message processing started with interval: ${interval.inMinutes} minutes');
  }

  /// Stops automatic processing
  void stopAutomaticProcessing() {
    _processingTimer?.cancel();
    _processingTimer = null;
  }

  @override
  void dispose() {
    stopAutomaticProcessing();
    _messageProcessingController.close();
    super.dispose();
  }

  /// Processes all unprocessed messages in batch.
  Future<void> processUnsentMessages(Isar isar) async {
    // Check if processing is already in progress at the service level
    if (_isProcessing) {
      debugPrint('⏳ Already processing messages, skipping');
      return;
    }

    final processingStartTime = DateTime.now();
    _isProcessing = true;
    _messageProcessingController.add(ProcessingEvent(status: ProcessingStatus.started));

    try {
      // Get all unprocessed messages with retry count less than 2
      // Pre-filter here to avoid loading unnecessary messages
      final unprocessedMessages = await isar.messages
          .filter()
          .processedEqualTo(false)
          .retryCountLessThan(2)
          .sortBySenderDesc()  // Process newer messages first
          .limit(50)      // Limit batch size for better performance
          .findAll();

      // Further filter to valid commands only
      final validMessages = unprocessedMessages
          .where((msg) => CommandValidator.isValidCommand(msg.body))
          .toList();

      debugPrint('📤 Found ${validMessages.length} valid unprocessed messages to process');

      _messageProcessingController.add(
          ProcessingEvent(
              status: ProcessingStatus.processing,
              totalMessages: validMessages.length
          )
      );

      int processedCount = 0;
      int failedCount = 0;
      int skippedCount = 0;

      // Create lists to capture results for UI update
      final List<Message> successfulMessages = [];
      final List<Message> failedMessages = [];

      // Process messages in batches for better UI responsiveness
      final batchSize = 5;
      for (var i = 0; i < validMessages.length; i += batchSize) {
        final end = (i + batchSize < validMessages.length) ? i + batchSize : validMessages.length;
        final batch = validMessages.sublist(i, end);

        await Future.wait(
            batch.map((msg) async {
              // Skip if this message is already being processed
              if (_processingMessages.contains(msg.id)) {
                debugPrint('⏭️ Skipping message ${msg.id} - already being processed');
                skippedCount++;
                return;
              }

              // Mark this message as being processed
              _processingMessages.add(msg.id);

              try {
                // Double-check that the message hasn't been processed by another thread
                final freshMessage = await isar.messages.get(msg.id);
                if (freshMessage == null || freshMessage.processed) {
                  debugPrint('⏭️ Skipping message ${msg.id} - already processed or deleted');
                  _processingMessages.remove(msg.id);
                  skippedCount++;
                  return;
                }

                final msgStartTime = DateTime.now();
                debugPrint('🚀 Sending message ${msg.id} to API: ${msg.body}');

                // Send the message
                await _apiService.sendMessage(msg.sender, msg.body);

                // Track performance
                final msgDuration = DateTime.now().difference(msgStartTime).inMilliseconds;
                _updatePerformanceMetrics(msgDuration);

                // Mark as processed
                await isar.writeTxn(() async {
                  // Get fresh instance again before updating to avoid conflicts
                  final messageToUpdate = await isar.messages.get(msg.id);
                  if (messageToUpdate != null && !messageToUpdate.processed) {
                    messageToUpdate.processed = true;
                    await isar.messages.put(messageToUpdate);
                    debugPrint('✅ Message ${msg.id} marked as processed (took $msgDuration ms)');

                    // Add to successful messages
                    successfulMessages.add(messageToUpdate);
                  }
                });

                processedCount++;

                // Notify listeners about this successful message
                _messageProcessingController.add(
                    ProcessingEvent(
                        status: ProcessingStatus.messageSent,
                        message: msg,
                        processedCount: processedCount,
                        totalMessages: validMessages.length,
                        processingTimeMs: msgDuration
                    )
                );

              } catch (e) {
                debugPrint('❌ Error sending message ${msg.id}: $e');

                // Update retry count
                await isar.writeTxn(() async {
                  // Get fresh instance again before updating to avoid conflicts
                  final messageToUpdate = await isar.messages.get(msg.id);
                  if (messageToUpdate != null) {
                    messageToUpdate.retryCount += 1;
                    await isar.messages.put(messageToUpdate);

                    // Add to failed messages
                    failedMessages.add(messageToUpdate);
                  }
                });

                failedCount++;

                // Notify listeners about this failed message
                _messageProcessingController.add(
                    ProcessingEvent(
                        status: ProcessingStatus.messageError,
                        message: msg,
                        error: e.toString(),
                        failedCount: failedCount
                    )
                );
              } finally {
                // Unmark this message as being processed
                _processingMessages.remove(msg.id);
              }
            })
        );

        // Small delay between batches to keep UI responsive
        if (i + batchSize < validMessages.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Calculate total processing time
      final totalProcessingTime = DateTime.now().difference(processingStartTime).inMilliseconds;

      // Refresh the provider to update the UI after processing
      notifyListeners();

      // Final summary event
      _messageProcessingController.add(
          ProcessingEvent(
              status: ProcessingStatus.completed,
              processedCount: processedCount,
              failedCount: failedCount,
              skippedCount: skippedCount,
              totalMessages: validMessages.length,
              successfulMessages: successfulMessages,
              failedMessages: failedMessages,
              processingTimeMs: totalProcessingTime
          )
      );

      debugPrint('✅ Message processing completed in $totalProcessingTime ms: $processedCount sent, $failedCount failed, $skippedCount skipped');
      if (processedCount > 0) {
        debugPrint('📊 Average processing time: $_avgProcessingTimeMs ms per message');
      }

    } catch (e) {
      debugPrint('🚨 Error during message processing: $e');
      _messageProcessingController.add(
          ProcessingEvent(
              status: ProcessingStatus.error,
              error: e.toString()
          )
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Process a single message
  Future<bool> processSingleMessage(Isar isar, Message message) async {
    // Skip if this message is already being processed
    if (_processingMessages.contains(message.id)) {
      debugPrint('⏭️ Skipping message ${message.id} - already being processed');
      return false;
    }

    // Skip if message is already processed
    if (message.processed) {
      debugPrint('⏭️ Skipping message ${message.id} - already processed');
      return false;
    }

    // Mark this message as being processed
    _processingMessages.add(message.id);

    final msgStartTime = DateTime.now();

    try {
      debugPrint('🚀 Processing single message ${message.id}: ${message.body}');

      // Notify start of processing
      _messageProcessingController.add(
          ProcessingEvent(
              status: ProcessingStatus.processing,
              message: message,
              totalMessages: 1
          )
      );

      // Send the message
      await _apiService.sendMessage(message.sender, message.body);

      // Calculate duration
      final duration = DateTime.now().difference(msgStartTime).inMilliseconds;
      _updatePerformanceMetrics(duration);

      // Mark as processed
      await isar.writeTxn(() async {
        // Get fresh instance to make sure we have the latest state
        final freshMessage = await isar.messages.get(message.id);
        if (freshMessage != null) {
          freshMessage.processed = true;
          await isar.messages.put(freshMessage);

          // Update our reference to have the latest state
          message.processed = freshMessage.processed;
          message.retryCount = freshMessage.retryCount;
        } else {
          // Fall back to updating the provided message
          message.processed = true;
          await isar.messages.put(message);
        }
      });

      // Trigger UI update
      notifyListeners();

      _messageProcessingController.add(
          ProcessingEvent(
              status: ProcessingStatus.messageSent,
              message: message,
              processedCount: 1,
              totalMessages: 1,
              successfulMessages: [message],
              processingTimeMs: duration
          )
      );

      debugPrint('✅ Single message ${message.id} processed successfully in $duration ms');
      return true;
    } catch (e) {
      debugPrint('❌ Error processing single message ${message.id}: $e');

      await isar.writeTxn(() async {
        // Get fresh instance to make sure we have the latest state
        final freshMessage = await isar.messages.get(message.id);
        if (freshMessage != null) {
          freshMessage.retryCount += 1;
          await isar.messages.put(freshMessage);

          // Update our reference to have the latest state
          message.retryCount = freshMessage.retryCount;
        } else {
          // Fall back to updating the provided message
          message.retryCount += 1;
          await isar.messages.put(message);
        }
      });

      // Trigger UI update
      notifyListeners();

      _messageProcessingController.add(
          ProcessingEvent(
              status: ProcessingStatus.messageError,
              message: message,
              error: e.toString(),
              failedMessages: [message]
          )
      );

      return false;
    } finally {
      // Unmark this message as being processed
      _processingMessages.remove(message.id);
    }
  }

  /// Optional cleanup for failed messages
  Future<void> deleteFailedMessages(Isar isar, {int retryLimit = 3}) async {
    final failedMessages = await isar.messages
        .filter()
        .retryCountGreaterThan(retryLimit)
        .findAll();

    await isar.writeTxn(() async {
      for (final msg in failedMessages) {
        await isar.messages.delete(msg.id);
        debugPrint("🗑️ Deleted message after $retryLimit retries: ${msg.body}");
      }
    });

    if (failedMessages.isNotEmpty) {
      // Trigger UI update
      notifyListeners();

      _messageProcessingController.add(
          ProcessingEvent(
              status: ProcessingStatus.cleanup,
              cleanedUpCount: failedMessages.length
          )
      );
    }
  }

  /// Reset a message for retry
  Future<void> resetMessage(Isar isar, Message message) async {
    await isar.writeTxn(() async {
      // Get fresh instance to make sure we have the latest state
      final freshMessage = await isar.messages.get(message.id);
      if (freshMessage != null) {
        freshMessage.processed = false;
        freshMessage.retryCount = 0;
        await isar.messages.put(freshMessage);

        // Update our reference
        message.processed = false;
        message.retryCount = 0;

        debugPrint('🔄 Reset message ${message.id} for retry');
      }
    });

    // Trigger UI update
    notifyListeners();
  }

  /// Update performance metrics
  void _updatePerformanceMetrics(int newDurationMs) {
    if (_totalProcessed == 0) {
      _avgProcessingTimeMs = newDurationMs;
    } else {
      // Weighted moving average (80% old, 20% new)
      _avgProcessingTimeMs = (_avgProcessingTimeMs * 4 + newDurationMs) ~/ 5;
    }
    _totalProcessed++;
  }
}

/// Status of message processing
enum ProcessingStatus {
  started,
  processing,
  messageSent,
  messageError,
  completed,
  error,
  cleanup
}

/// Event data for message processing updates
class ProcessingEvent {
  final ProcessingStatus status;
  final Message? message;
  final String? error;
  final int processedCount;
  final int failedCount;
  final int skippedCount;
  final int totalMessages;
  final int cleanedUpCount;
  final List<Message> successfulMessages;
  final List<Message> failedMessages;
  final int processingTimeMs;

  ProcessingEvent({
    required this.status,
    this.message,
    this.error,
    this.processedCount = 0,
    this.failedCount = 0,
    this.skippedCount = 0,
    this.totalMessages = 0,
    this.cleanedUpCount = 0,
    this.successfulMessages = const [],
    this.failedMessages = const [],
    this.processingTimeMs = 0,
  });
}