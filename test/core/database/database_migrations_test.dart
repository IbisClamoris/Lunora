import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lunora/core/database/database_migrations.dart';

Future<Database> openTestDatabase() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
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
  return db;
}

Future<Set<String>> tableNames(Database db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table'",
  );
  return rows.map((row) => row['name'] as String).toSet();
}

Future<Set<String>> columns(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info("$table")');
  return rows.map((row) => row['name'] as String).toSet();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Database migration v25', () {
    late Database db;

    tearDown(() async {
      await db.close();
    });

    test('creates all required tables on a clean installation', () async {
      db = await openTestDatabase();
      await DatabaseMigrations.migrate(db, 1, 25);

      final tables = await tableNames(db);
      for (final table in [
        'movie_entries',
        'recipe_entries',
        'wishlist_items',
        'wishlist_entries',
        'shopping_items',
        'notifications',
        'study_subjects',
        'study_periods',
        'study_items',
        'knowledge_entries',
        'finance_accounts',
        'finance_categories',
        'finance_transactions',
        'finance_debts',
        'finance_debt_payments',
        'finance_budgets',
        'finance_savings_goals',
        'recipe_meal_plan_entries',
        'diary_entries',
        'planner_goals',
      ]) {
        expect(tables, contains(table), reason: 'Missing table: $table');
      }

      expect(await columns(db, 'shopping_items'), containsAll([
        'title', 'quantity', 'notes', 'sort_order', 'purchased_at',
      ]));
      expect(await columns(db, 'notifications'), contains('read_at'));
      expect(await columns(db, 'recipe_entries'), containsAll([
        'cuisine', 'difficulty', 'is_cook_ahead',
      ]));
    });

    test('preserves legacy shopping, wishlist, notification and meal-plan rows', () async {
      db = await openTestDatabase();
      await DatabaseMigrations.migrate(db, 1, 24);

      await db.insert('shopping_lists', {
        'id': 'list-1', 'title': 'Test list',
        'created_at': '2026-01-01', 'updated_at': '2026-01-01',
      });
      await db.insert('shopping_items', {
        'id': 'shop-1', 'list_id': 'list-1', 'name': 'Tea',
        'amount': 2, 'unit': 'packs', 'category': 'Food',
        'is_purchased': 1, 'note': 'Green tea',
        'created_at': '2026-01-01', 'updated_at': '2026-01-02',
      });
      await db.insert('wishlist_items', {
        'id': 'wish-1', 'title': 'Book', 'description': 'A novel',
        'category': 'Books', 'price': 25, 'currency': 'EUR',
        'url': 'https://example.com/book', 'image_path': null,
        'priority': 'high', 'status': 'planned', 'is_favorite': 0,
        'created_at': '2026-01-01', 'updated_at': '2026-01-02',
      });
      await db.insert('notifications', {
        'id': 'notice-1', 'title': 'Reminder', 'body': 'Read a chapter',
        'type': 'reminder', 'scheduled_at': null, 'is_read': 1,
        'is_delivered': 1, 'related_id': null,
        'created_at': '2026-01-01', 'updated_at': '2026-01-02',
      });
      await db.insert('recipe_entries', {
        'id': 'recipe-1', 'title': 'Soup',
        'created_at': '2026-01-01', 'updated_at': '2026-01-01',
      });
      await db.insert('meal_plan_entries', {
        'id': 'meal-1', 'recipe_id': 'recipe-1', 'date': '2026-01-03',
        'meal_type': 'Lunch', 'servings': 3, 'note': 'Prepare ahead',
        'created_at': '2026-01-01', 'updated_at': '2026-01-01',
      });
      await db.insert('finance_savings_goals', {
        'id': 'goal-1', 'title': 'Trip', 'description': '',
        'target_amount': 50000, 'current_amount': 12000,
        'currency': 'EUR', 'target_date': '2026-12-01',
        'status': 'active', 'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      });

      await DatabaseMigrations.migrate(db, 24, 25);

      final shopping = (await db.query('shopping_items')).single;
      expect(shopping['title'], 'Tea');
      expect(shopping['quantity'], 2);
      expect(shopping['notes'], 'Green tea');
      expect(shopping['is_purchased'], 1);

      final wishlist = (await db.query('wishlist_entries')).single;
      expect(wishlist['title'], 'Book');
      expect(wishlist['source_url'], 'https://example.com/book');
      expect(wishlist['priority'], 'high');

      final notification = (await db.query('notifications')).single;
      expect(notification['message'], 'Read a chapter');
      expect(notification['read_at'], isNotNull);

      final meal = (await db.query('recipe_meal_plan_entries')).single;
      expect(meal['recipe_id'], 'recipe-1');
      expect(meal['plan_date'], '2026-01-03');
      expect(meal['notes'], 'Prepare ahead');

      final goal = (await db.query('finance_savings_goals')).single;
      expect(goal['target_amount_minor'], 50000);
      expect(goal['saved_amount_minor'], 12000);
    });

    test('is safe to run after the database is already at v25', () async {
      db = await openTestDatabase();
      await DatabaseMigrations.migrate(db, 1, 25);
      await expectLater(
        DatabaseMigrations.migrate(db, 25, 25),
        completes,
      );
    });
  });
}
