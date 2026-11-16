import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lunora/core/database/database_migrations.dart';

Future<Database> _openDatabase() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            setting_key TEXT NOT NULL UNIQUE,
            setting_value TEXT,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE favorites (
            id TEXT PRIMARY KEY, source_module TEXT NOT NULL,
            source_record_id TEXT NOT NULL, created_at TEXT NOT NULL,
            UNIQUE(source_module, source_record_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE import_history (
            id TEXT PRIMARY KEY, file_name TEXT NOT NULL, source_module TEXT,
            imported_at TEXT NOT NULL, imported_count INTEGER DEFAULT 0,
            status TEXT NOT NULL, details TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE export_history (
            id TEXT PRIMARY KEY, file_name TEXT NOT NULL, source_module TEXT,
            exported_at TEXT NOT NULL, status TEXT NOT NULL, details TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT,
            source_module TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )
        ''');
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database migration v26', () {
    late Database db;

    setUp(() async {
      db = await _openDatabase();
      await DatabaseMigrations.migrate(db, 1, 25);
    });

    tearDown(() async => db.close());

    test('adds collections, collection items and polymorphic record links', () async {
      await DatabaseMigrations.migrate(db, 25, 26);
      final tables = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      )).map((row) => row['name']).toSet();

      expect(tables, containsAll([
        'record_links', 'collections', 'collection_items', 'notes',
      ]));
    });

    test('preserves existing notes and adds optional record metadata', () async {
      await db.insert('notes', {
        'id': 'note-1',
        'title': 'Keep this note',
        'content': 'Existing content',
        'source_module': 'planner',
        'created_at': '2026-01-01',
        'updated_at': '2026-01-02',
      });

      await DatabaseMigrations.migrate(db, 25, 26);

      final note = (await db.query('notes')).single;
      expect(note['title'], 'Keep this note');
      expect(note['content'], 'Existing content');
      expect(note['source_record_id'], isNull);
      expect(note['tags'], '[]');
      expect(note['is_pinned'], 0);
    });

    test('enforces collection membership uniqueness and cascade deletion', () async {
      await DatabaseMigrations.migrate(db, 25, 26);
      await db.insert('collections', {
        'id': 'collection-1',
        'name': 'Favorites',
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      });
      final item = {
        'id': 'item-1',
        'collection_id': 'collection-1',
        'record_module': 'books',
        'record_id': 'book-1',
        'added_at': '2026-01-01',
      };
      await db.insert('collection_items', item);
      await expectLater(
        db.insert('collection_items', {...item, 'id': 'item-2'}),
        throwsA(isA<DatabaseException>()),
      );

      await db.delete('collections', where: 'id = ?', whereArgs: ['collection-1']);
      expect(await db.query('collection_items'), isEmpty);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    });

    test('prevents self-links and duplicate relation records', () async {
      await DatabaseMigrations.migrate(db, 25, 26);
      final link = {
        'id': 'link-1',
        'source_module': 'books',
        'source_record_id': 'book-1',
        'target_module': 'movies',
        'target_record_id': 'movie-1',
        'relation_type': 'adaptation',
        'created_at': '2026-01-01',
      };
      await db.insert('record_links', link);
      await expectLater(
        db.insert('record_links', {...link, 'id': 'link-2'}),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.insert('record_links', {
          ...link,
          'id': 'link-self',
          'target_module': 'books',
          'target_record_id': 'book-1',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('is safe to apply migration 26 more than once', () async {
      await DatabaseMigrations.migrate(db, 25, 26);
      await expectLater(DatabaseMigrations.migrate(db, 25, 26), completes);
    });
  });
}
