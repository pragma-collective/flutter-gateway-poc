import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';

/// Helper class to manage a single Isar instance throughout the app
class IsarHelper {
  static Isar? _isar;
  static const String _dbName = 'default';
  static bool _initializing = false;

  /// Initializes the Isar database if it hasn't been already
  static Future<void> initIsar() async {
    // If we already have an open instance, nothing to do
    if (_isar != null && _isar!.isOpen) {
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
    } catch (e) {
      debugPrint("💥 Isar initialization failed: $e");
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

      // Reopen with fresh instance
      await initIsar();
    } catch (e) {
      debugPrint("💥 Error reopening Isar: $e");
      rethrow;
    }
  }

  /// Closes the Isar instance if open
  static Future<void> closeIsar() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.close();
      _isar = null;
    }
  }
}