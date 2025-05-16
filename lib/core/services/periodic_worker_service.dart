import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cellfi_app/core/services/message_service.dart';
import 'package:cellfi_app/utils/isar_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PeriodicWorkerService handles processing of messages at regular intervals
class PeriodicWorkerService {
  static const String _lastProcessingKey = 'last_message_processing_time';
  static const Duration defaultInterval = Duration(minutes: 2);
  static const Duration minProcessingInterval = Duration(minutes: 1);

  static Timer? _periodicTimer;
  static bool _isInitialized = false;
  static bool _processingInProgress = false;
  static DateTime? _lastProcessingTime; // In-memory tracking to avoid excessive SharedPreferences access
  static final StreamController<WorkerStatus> _statusController =
  StreamController<WorkerStatus>.broadcast();

  // Mutex-like lock to prevent concurrent processing
  static Completer<void>? _processingLock;

  /// Stream of worker status updates
  static Stream<WorkerStatus> get statusStream => _statusController.stream;

  /// Is the worker currently processing messages
  static bool get isProcessing => _processingInProgress;

  /// Initialize the periodic worker
  static Future<void> initialize({Duration? interval}) async {
    if (_isInitialized) return;

    try {
      // Load the last processing time
      _lastProcessingTime = await _getLastProcessingTime();

      // Start the periodic timer
      _startPeriodicTimer(interval: interval ?? defaultInterval);

      _isInitialized = true;
      debugPrint('✅ Periodic worker initialized');
      _statusController.add(WorkerStatus.initialized);
    } catch (e) {
      debugPrint('❌ Failed to initialize periodic worker: $e');
      _statusController.add(WorkerStatus.error);
    }
  }

  /// Start the periodic timer
  static void _startPeriodicTimer({required Duration interval}) {
    _periodicTimer?.cancel();

    _periodicTimer = Timer.periodic(interval, (_) {
      // _checkAndProcessMessages();
    });

    debugPrint('✅ Periodic timer started with interval: ${interval.inMinutes} minutes');
  }

  /// Force a one-time immediate execution
  static Future<void> processMessagesNow({bool bypassTimeCheck = false}) async {
    // Check if we recently processed messages (to prevent duplicate calls)
    if (!bypassTimeCheck && _lastProcessingTime != null) {
      final now = DateTime.now();
      final diff = now.difference(_lastProcessingTime!);

      // If last processing was too recent, don't process again unless bypassed
      if (diff < minProcessingInterval) {
        debugPrint('⏳ Last processing was ${diff.inSeconds} seconds ago (minimum interval: ${minProcessingInterval.inSeconds}s), skipping');
        return;
      }
    }

    await _processMessages(force: bypassTimeCheck);
  }

  /// Check if it's time to process messages and process if needed
  static Future<void> _checkAndProcessMessages() async {
    if (_processingInProgress) {
      debugPrint('⏳ Processing already in progress, skipping');
      return;
    }

    final lastProcessing = _lastProcessingTime ?? await _getLastProcessingTime();
    final now = DateTime.now();

    // Change this to respect the configured interval instead of hardcoded 5 minutes
    // If last processing was less than the configured minimum interval ago, skip
    if (lastProcessing != null &&
        now.difference(lastProcessing).inMinutes < minProcessingInterval.inMinutes) {
      debugPrint('⏳ Last processing was less than minimum interval ago, skipping');
      return;
    }

    await _processMessages();
  }

  /// Process all unprocessed messages
  static Future<void> _processMessages({bool force = false}) async {
    // Check if processing is already in progress
    if (_processingInProgress && !force) {
      debugPrint('⏳ Processing already in progress, skipping');
      return;
    }

    // Check if we're locked
    if (_processingLock != null && !_processingLock!.isCompleted) {
      debugPrint('🔒 Processing is locked, waiting...');
      await _processingLock!.future;
    }

    // Create a new lock
    _processingLock = Completer<void>();

    _processingInProgress = true;
    _statusController.add(WorkerStatus.processing);

    try {
      debugPrint('🔄 Processing messages...');

      // Wait for Isar to be ready
      await IsarHelper.initialized;

      // Only get the Isar instance when we're ready to use it
      final isar = IsarHelper.getIsarInstance();

      // Create a new MessageService instance to avoid conflicts
      final messageService = MessageService();
      await messageService.processUnsentMessages(isar);

      // Clean up old failed messages
      await messageService.deleteFailedMessages(isar);

      // Update last processing time both in memory and storage
      final now = DateTime.now();
      _lastProcessingTime = now;
      await _setLastProcessingTime(now);

      debugPrint('✅ Message processing completed');
      _statusController.add(WorkerStatus.completed);
    } catch (e) {
      debugPrint('❌ Message processing failed: $e');
      _statusController.add(WorkerStatus.error);
    } finally {
      _processingInProgress = false;

      // Complete the processing lock
      if (_processingLock != null && !_processingLock!.isCompleted) {
        _processingLock!.complete();
      }
    }
  }

  /// Cancel the periodic timer
  static void cancel() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    debugPrint('✅ Periodic timer cancelled');
  }

  /// Clean up resources
  static void dispose() {
    cancel();
    // Don't close the _statusController here, as it may be used by listeners
    // that outlive this service. Instead, we'll mark it as inactive.
    _isInitialized = false;
  }

  /// Get the last processing time from shared preferences
  static Future<DateTime?> _getLastProcessingTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastProcessingKey);

      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('❌ Error getting last processing time: $e');
    }

    return null;
  }

  /// Set the last processing time in shared preferences
  static Future<void> _setLastProcessingTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastProcessingKey, time.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('❌ Error setting last processing time: $e');
    }
  }
}

/// Status of the worker service
enum WorkerStatus {
  initialized,
  processing,
  completed,
  error
}

/// Extension to add isCompleted to Completer
extension CompleterExtension<T> on Completer<T> {
  bool get isCompleted => this.isCompleted;
}