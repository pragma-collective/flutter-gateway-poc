import 'dart:async';

import 'package:another_telephony/telephony.dart';
import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart';
import 'package:cellfi_app/models/message.dart';
import 'package:cellfi_app/utils/isar_helper.dart';
import 'package:cellfi_app/utils/command_validator.dart';
import 'package:cellfi_app/core/services/periodic_worker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Set to track recently processed SMS to avoid duplicates
final Set<String> _processedSmsSignatures = <String>{};

/// Create a unique signature for an SMS message to prevent duplicates
String _createSmsSignature(String sender, String body, [DateTime? time]) {
  final timeComponent = time?.millisecondsSinceEpoch.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
  // Use only first 50 chars of body to avoid excessive memory usage
  final truncatedBody = body.length > 50 ? body.substring(0, 50) : body;
  return '$sender:$truncatedBody:${timeComponent.substring(timeComponent.length - 5)}';
}

/// Handle foreground incoming messages
Future<void> handleIncomingMessage(String sender, String body) async {
  try {
    // Create a signature to detect duplicates
    final signature = _createSmsSignature(sender, body);

    // Check if we've already processed this message recently
    if (_processedSmsSignatures.contains(signature)) {
      debugPrint("⏭️ Skipping duplicate SMS from $sender");
      return;
    }

    // Mark as processed
    _processedSmsSignatures.add(signature);

    // Clean up the signature cache periodically
    _cleanupSmsSignatures();

    // Make sure Isar is initialized first
    debugPrint("📱 Ensuring Isar is initialized before handling SMS");
    await IsarHelper.initialized;

    // Only proceed if Isar is properly initialized
    final isar = IsarHelper.getIsarInstance();

    // Check if a message with identical sender and body already exists in the database
    final existingMessages = await isar.messages
        .filter()
        .senderEqualTo(sender)
        .and()
        .bodyEqualTo(body)
        .findAll();

    // If a very similar message was received in the last minute, consider it a duplicate
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

    final recentDuplicate = existingMessages.any((msg) =>
        msg.receivedAt.isAfter(oneMinuteAgo));

    if (recentDuplicate) {
      debugPrint("⏭️ Skipping duplicate SMS (found in database) from $sender");
      return;
    }

    // Create and save the new message
    final newMessage = Message()
      ..sender = sender
      ..body = body
      ..receivedAt = now
      ..processed = false
      ..retryCount = 0;

    await isar.writeTxn(() async {
      await isar.messages.put(newMessage);
    });

    debugPrint("📥 New message received from $sender: $body");

    // If valid command, trigger processing after a short delay
    if (CommandValidator.isValidCommand(body)) {
      debugPrint("✅ Valid command detected, scheduling processing");

      // Store the last processing request time to avoid duplicate triggers
      await _updateLastProcessingRequest();

      // Use a small delay to avoid database contention
      Future.delayed(const Duration(milliseconds: 800), () {
        PeriodicWorkerService.processMessagesNow();
      });
    } else {
      debugPrint("❌ Ignored non-command message: $body");
    }
  } catch (e) {
    debugPrint("💥 Error handling incoming message: $e");

    // If the error is because Isar isn't initialized, queue the message for later processing
    if (e.toString().contains("Isar database not initialized")) {
      _queueMessageForLaterProcessing(sender, body);
    }
  }
}

// Queue for messages that couldn't be processed immediately
final List<Map<String, String>> _pendingMessages = [];

/// Queue a message for later processing when Isar is ready
void _queueMessageForLaterProcessing(String sender, String body) {
  debugPrint("⏳ Queuing message for later processing: $sender");
  _pendingMessages.add({
    'sender': sender,
    'body': body,
    'timestamp': DateTime.now().millisecondsSinceEpoch.toString()
  });

  // Set up a delayed processor to check the queue
  Future.delayed(const Duration(seconds: 2), () => _processPendingMessages());
}

/// Process any pending messages in the queue
Future<void> _processPendingMessages() async {
  if (_pendingMessages.isEmpty) return;

  try {
    // Check if Isar is ready now
    if (!await _isIsarReady()) {
      // Retry again later
      debugPrint("⏳ Isar still not ready, will retry pending messages later");
      Future.delayed(const Duration(seconds: 2), () => _processPendingMessages());
      return;
    }

    debugPrint("🔄 Processing ${_pendingMessages.length} pending queued messages");

    // Make a copy of the queue to avoid modification during iteration
    final messagesToProcess = List<Map<String, String>>.from(_pendingMessages);
    _pendingMessages.clear();

    for (final msgData in messagesToProcess) {
      await handleIncomingMessage(msgData['sender']!, msgData['body']!);
    }

    debugPrint("✅ Finished processing queued messages");
  } catch (e) {
    debugPrint("💥 Error processing pending messages: $e");

    // If we failed, put the messages back in the queue and try again later
    if (_pendingMessages.isEmpty) {
      Future.delayed(const Duration(seconds: 3), () => _processPendingMessages());
    }
  }
}

/// Check if Isar is ready to use
Future<bool> _isIsarReady() async {
  try {
    // Check if the initialization future is complete
    final completer = Completer<bool>();

    // Use a timeout to avoid hanging indefinitely
    IsarHelper.initialized.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {
          if (!completer.isCompleted) completer.complete(false);
          return;
        }
    ).then((_) {
      if (!completer.isCompleted) completer.complete(true);
    }).catchError((e) {
      if (!completer.isCompleted) completer.complete(false);
    });

    final isInitialized = await completer.future;

    if (!isInitialized) return false;

    // Try to get the instance as a final check
    try {
      IsarHelper.getIsarInstance();
      return true;
    } catch (e) {
      return false;
    }
  } catch (e) {
    return false;
  }
}

/// Clean up the SMS signature cache to prevent memory leaks
void _cleanupSmsSignatures({int maxSize = 100}) {
  if (_processedSmsSignatures.length > maxSize) {
    debugPrint('Cleaning up SMS signature cache (size: ${_processedSmsSignatures.length})');

    // Keep only the most recent signatures (approximately half)
    final signaturesToKeep = _processedSmsSignatures.toList().sublist(
        _processedSmsSignatures.length ~/ 2
    ).toSet();

    _processedSmsSignatures.clear();
    _processedSmsSignatures.addAll(signaturesToKeep);

    debugPrint('SMS signature cache cleaned (new size: ${_processedSmsSignatures.length})');
  }
}

/// Track last processing request time to prevent duplicates
Future<void> _updateLastProcessingRequest() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sms_processing_request', DateTime.now().millisecondsSinceEpoch);
  } catch (e) {
    debugPrint('❌ Error updating last processing request time: $e');
  }
}

/// For SMS sending
Future<void> sendSms(Telephony telephony, String phoneNumber, String messageContent) async {
  try {
    await telephony.sendSms(
      to: phoneNumber,
      message: messageContent,
    );
    debugPrint("📤 SMS sent to $phoneNumber");
  } catch (e) {
    debugPrint('❌ Error sending SMS: $e');
  }
}

/// Safe background message handler
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  // We need to be careful with Isar in background
  Isar? isar;

  try {
    final sender = message.address ?? 'Unknown';
    final body = message.body ?? '';

    // Create a signature to detect duplicates
    final signature = _createSmsSignature(sender, body);

    // Check if we've already processed this message recently
    if (_processedSmsSignatures.contains(signature)) {
      debugPrint("⏭️ Skipping duplicate SMS from $sender in background");
      return;
    }

    // Mark as processed
    _processedSmsSignatures.add(signature);

    // Initialize Isar first - this is safe to call multiple times
    await IsarHelper.initIsar();

    // Get the Isar instance
    isar = IsarHelper.getIsarInstance();

    // Check for duplicates in database
    final existingMessages = await isar.messages
        .filter()
        .senderEqualTo(sender)
        .and()
        .bodyEqualTo(body)
        .findAll();

    // If a very similar message was received in the last minute, consider it a duplicate
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

    final recentDuplicate = existingMessages.any((msg) =>
        msg.receivedAt.isAfter(oneMinuteAgo));

    if (recentDuplicate) {
      debugPrint("⏭️ Skipping duplicate SMS (found in database) from $sender in background");
      return;
    }

    final newMsg = Message()
      ..sender = sender
      ..body = body
      ..receivedAt = now
      ..processed = false
      ..retryCount = 0;

    await isar.writeTxn(() async {
      await isar?.messages.put(newMsg);
    });

    debugPrint("✅ Background message saved: $body");

    // Don't process immediately in background - let the app process when it resumes
    // This avoids concurrency issues with Isar in background

  } catch (e) {
    debugPrint('❌ Error in background message handler: $e');
  } finally {
    // Try to safely close Isar after background operation
    if (isar != null) {
      try {
        await IsarHelper.closeIsar();
      } catch (closeError) {
        debugPrint('❌ Error closing Isar in background: $closeError');
      }
    }
  }
}