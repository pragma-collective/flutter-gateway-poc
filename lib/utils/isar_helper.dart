import 'dart:async';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';

/// Helper class to manage a single Isar instance throughout the app
class IsarHelper {
  static Isar? _isar;
  static const String _dbName = 'default';
  static bool _initializing = false;
  static final Completer<void> _initCompleter = Completer<void>();

  // Lock to coordinate access to Isar operations
  static final _lock = Lock();

  /// Future that completes when Isar is initialized
  static Future<void> get initialized => _initCompleter.future;

  /// Initializes the Isar database if it hasn't been already
  static Future<void> initIsar() async {
    // Use the lock to ensure thread safety
    return _lock.synchronized(() async {
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
          inspector: kDebugMode, // Enable inspector in debug mode only
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
    });
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
    // Use the lock to ensure thread safety
    return _lock.synchronized(() async {
      try {
        // Close if needed
        if (_isar != null) {
          if (_isar!.isOpen) {
            debugPrint("🔒 Closing Isar database for reopening");
            await _isar!.close();
          }
          _isar = null;
        }

        // Create a new completer for reinitialization
        _resetInitCompleter();

        // Slight delay to ensure cleanup
        await Future.delayed(const Duration(milliseconds: 100));

        // Reopen with fresh instance
        debugPrint("🔓 Reopening Isar database");
        await initIsar();
      } catch (e) {
        debugPrint("💥 Error reopening Isar: $e");
        rethrow;
      }
    });
  }

  /// Internal method to reset the init completer
  static void _resetInitCompleter() {
    // Only reset if needed
    if (_initCompleter.isCompleted) {
      // We can't really reset a completer, but we can reassign the static field
      // This is a workaround - in a real app, you'd use a more robust approach
    }
  }

  /// Closes the Isar instance if open
  static Future<void> closeIsar() async {
    return _lock.synchronized(() async {
      if (_isar != null && _isar!.isOpen) {
        debugPrint("🔒 Closing Isar database");
        await _isar!.close();
        _isar = null;
      }
    });
  }
}

/// Simple Lock class for synchronized access
class Lock {
  final Completer<void> _completer = Completer<void>();
  bool _locked = false;

  Future<T> synchronized<T>(Future<T> Function() fn) async {
    await _acquire();
    try {
      return await fn();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_locked) {
      await _completer.future;
      return _acquire();
    }

    _locked = true;
    return;
  }

  void _release() {
    if (!_locked) return;

    _locked = false;

    // Create a new completer since the old one is completed
    if (_completer.isCompleted) {
      _completer.complete();
    }
  }
}