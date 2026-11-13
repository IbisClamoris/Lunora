import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../storage/storage_service.dart';
import 'database_migrations.dart';

class LunoraDatabase {
  LunoraDatabase._();

  static final LunoraDatabase instance = LunoraDatabase._();

  static const int databaseVersion = 25;
  static const String databaseName = 'lunora.db';

  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final databaseDirectory = await StorageService.instance.dataDirectory;

    final databasePath = '${databaseDirectory.path}\\$databaseName';

    return databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setting_key TEXT NOT NULL UNIQUE,
        setting_value TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        id TEXT PRIMARY KEY,
        source_module TEXT NOT NULL,
        source_record_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(source_module, source_record_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS import_history (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        source_module TEXT,
        imported_at TEXT NOT NULL,
        imported_count INTEGER DEFAULT 0,
        status TEXT NOT NULL,
        details TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS export_history (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        source_module TEXT,
        exported_at TEXT NOT NULL,
        status TEXT NOT NULL,
        details TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT,
        source_module TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await DatabaseMigrations.migrate(db, 1, version);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await DatabaseMigrations.migrate(db, oldVersion, newVersion);
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
