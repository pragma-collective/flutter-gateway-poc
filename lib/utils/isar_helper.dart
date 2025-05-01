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
        debugPrint("🔄 Starting Isar initialization");

        final dir = await getApplicationDocumentsDirectory();
        debugPrint("📁 Documents directory: ${dir.path}");

        // Ensure the directory exists
        final dbDir = Directory('${dir.path}/isar');
        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
          debugPrint("📁 Created Isar directory: ${dbDir.path}");
        }

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

        // Try to close any existing instance
        if (_isar != null) {
          try {
            await _isar!.close();
            _isar = null;
          } catch (closeError) {
            debugPrint("💥 Error closing Isar after failed initialization: $closeError");
          }
        }

        // If initialization fails, complete with error
        if (!_initCompleter.isCompleted) {
          _initCompleter.completeError(e);
        } else {
          // If the completer is already completed, create a new one
          _resetInitCompleter();
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
      final error = Exception('[💥] Isar database not initialized - call initIsar() first');
      debugPrint(error.toString());
      throw error;
    }
    return _isar!;
  }

  /// Safely reopens Isar after background operations
  static Future<void> safeReopenIsar() async {
    // Use the lock to ensure thread safety
    return _lock.synchronized(() async {
      try {
        debugPrint("🔄 Starting Isar safe reopen process");

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

        debugPrint("✅ Isar database reopened successfully");
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
      // We can't really reset a completer, but we can deal with this situation better
      debugPrint("🔄 Resetting Isar initialization state");
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

  /// Check if Isar is open and ready
  static bool isIsarReady() {
    return _isar != null && _isar!.isOpen;
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
    _completer.complete();
  }
}