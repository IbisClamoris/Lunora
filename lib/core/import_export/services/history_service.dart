import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../database/database.dart';
import '../models/history_entry.dart';

class HistoryService {
  HistoryService._();

  static final HistoryService instance = HistoryService._();

  Future<List<HistoryEntry>> getImportHistory() async {
    final Database db = await LunoraDatabase.instance.database;

    final rows = await db.query('import_history', orderBy: 'imported_at DESC');

    return rows
        .map(
          (row) => HistoryEntry.fromImportMap(Map<String, Object?>.from(row)),
        )
        .toList();
  }

  Future<List<HistoryEntry>> getExportHistory() async {
    final Database db = await LunoraDatabase.instance.database;

    final rows = await db.query('export_history', orderBy: 'exported_at DESC');

    return rows
        .map(
          (row) => HistoryEntry.fromExportMap(Map<String, Object?>.from(row)),
        )
        .toList();
  }

  Future<int> getTotalImportCount() async {
    final Database db = await LunoraDatabase.instance.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM import_history',
    );

    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> getTotalExportCount() async {
    final Database db = await LunoraDatabase.instance.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM export_history',
    );

    return (result.first['total'] as int?) ?? 0;
  }
}
