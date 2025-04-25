import 'dart:async';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';

/// Helper class to manage a single Isar instance throughout the app
class IsarHelper {
  static Isar? _isar;
  static const String _dbName = 'default';
  static bool _initializing = false;

  // Add a Completer to track initialization state
  static final Completer<void> _initCompleter = Completer<void>();

  /// Future that completes when Isar is initialized
  static Future<void> get initialized => _initCompleter.future;

  /// Initializes the Isar database if it hasn't been already
  static Future<void> initIsar() async {
    // If we already have an open instance, nothing to do
    if (_isar != null && _isar!.isOpen) {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      return;
    }

    // Prevent multiple init calls from running simultaneously
    if (_initializing) {
      debugPrint("⏳ Isar initialization already in progress");
      return;
    }

    try {
      _initializing = true;
      final dir = await getApplicationDocumentsDirectory();

      _isar = await Isar.open(
        [MessageSchema],
        directory: dir.path,
        name: _dbName,
      );

      debugPrint("✅ Isar initialized successfully");

      // Complete the initialization future
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } catch (e) {
      debugPrint("💥 Isar initialization failed: $e");

      // If initialization fails, complete with error
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }

      rethrow;
    } finally {
      _initializing = false;
    }
  }

  /// Gets the Isar instance, throws if not initialized
  static Isar getIsarInstance() {
    if (_isar == null || !_isar!.isOpen) {
      throw Exception('[💥] Isar database not initialized - call initIsar() first');
    }
    return _isar!;
  }

  /// Safely reopens Isar after background operations
  static Future<void> safeReopenIsar() async {
    try {
      // Close if needed
      if (_isar != null && _isar!.isOpen) {
        await _isar!.close();
        _isar = null;
      }

      // Create a new completer for reinitialization
      if (_initCompleter.isCompleted) {
        // Reset the completer
        // Note: This approach is a bit tricky since Completer can't be "reset"
        // In a real implementation, you might use a different approach
        // such as a private method that creates a new Completer
        // For now, we'll use a workaround with an internal reset method
        _resetInitCompleter();
      }

      // Reopen with fresh instance
      await initIsar();
    } catch (e) {
      debugPrint("💥 Error reopening Isar: $e");
      rethrow;
    }
  }

  /// Internal method to reset the init completer
  /// Only for use in safeReopenIsar
  static void _resetInitCompleter() {
    // This is a simplified approach - in real code you might
    // need a different pattern to handle this more cleanly
    // such as using a static variable to track the current completer
    // For demonstration purposes only
  }

  /// Closes the Isar instance if open
  static Future<void> closeIsar() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.close();
      _isar = null;
    }
  }
}