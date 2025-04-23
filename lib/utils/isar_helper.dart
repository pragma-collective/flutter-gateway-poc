import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';

class IsarHelper {
  static Isar? _isar;
  static const String _name = 'default';

  static Future<void> initIsar() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [MessageSchema],
      directory: dir.path,
      name: _name,
    );
  }

  static Isar getIsarInstance() {
    return _isar ??
        (throw Exception('[💥] Isar "$_name" not initialized — call initIsar() first.'));
  }

  /// ✅ Close and reopen Isar (used after background writes)
  static Future<void> safeReopenIsar() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.close();
    }

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [MessageSchema],
      directory: dir.path,
      name: _name,
    );
  }
}