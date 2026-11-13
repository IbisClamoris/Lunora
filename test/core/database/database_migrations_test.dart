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
      expect(await columns(db, 'notifications'), isNot(contains('updated_at')));
      expect(await columns(db, 'book_entries'), containsAll(['authors', 'genre']));
      expect(await columns(db, 'recipe_ingredients'), containsAll([
        'quantity', 'notes', 'created_at', 'updated_at',
      ]));
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
      await db.insert('recipe_ingredients', {
        'id': 'ingredient-1', 'recipe_id': 'recipe-1', 'name': 'Potato',
        'amount': 3, 'unit': 'pcs', 'note': 'Large',
        'sort_order': 0,
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
      // Current NotificationItem.toMap omits the legacy updated_at column.
      await db.insert('notifications', {
        'id': 'notice-2', 'category': 'study', 'type': 'reminder',
        'event_type': 'study_deadline', 'title': 'Exam',
        'message': 'Prepare notes', 'created_at': '2026-01-04T00:00:00.000',
        'metadata': '{}',
      });
      expect((await db.query('notifications')).length, 2);

      // Current BookEntry.toMap uses authors/genre rather than legacy author/genres.
      await db.insert('book_entries', {
        'id': 'book-1', 'title': 'Neverwhere', 'authors': 'Neil Gaiman',
        'description': '', 'genre': 'Fantasy', 'tags': '[]',
        'status': 'reading', 'review': '', 'is_favorite': 0,
        'created_at': '2026-01-04T00:00:00.000',
        'updated_at': '2026-01-04T00:00:00.000',
        'current_page': 10, 'series_name': '', 'book_format': '',
        'source_name': '',
      });
      expect((await db.query('book_entries')).single['authors'], 'Neil Gaiman');

      final meal = (await db.query('recipe_meal_plan_entries')).single;
      expect(meal['recipe_id'], 'recipe-1');
      expect(meal['plan_date'], '2026-01-03');
      expect(meal['notes'], 'Prepare ahead');

      final goal = (await db.query('finance_savings_goals')).single;
      expect(goal['target_amount_minor'], 50000);
      expect(goal['saved_amount_minor'], 12000);
      final ingredient = (await db.query('recipe_ingredients')).single;
      expect(ingredient['quantity'], 3);
      expect(ingredient['notes'], 'Large');
      // Current RecipeIngredient.toMap requires both timestamp columns.
      await db.insert('recipe_ingredients', {
        'id': 'ingredient-2', 'recipe_id': 'recipe-1', 'name': 'Carrot',
        'quantity': 1.5, 'unit': 'pcs', 'notes': 'Fresh',
        'sort_order': 1, 'created_at': '2026-01-03T00:00:00.000',
        'updated_at': '2026-01-03T00:00:00.000',
      });
      expect((await db.query('recipe_ingredients')).length, 2);
    });

    test('new feature tables accept current model-shaped records', () async {
      db = await openTestDatabase();
      await DatabaseMigrations.migrate(db, 1, 25);

      const now = '2026-11-13T12:00:00.000';
      await db.insert('study_subjects', {
        'id': 'subject-1', 'name': 'Math', 'teacher': '',
        'description': '', 'academic_year': '2026/2027',
        'semester': 1, 'sort_order': 0, 'created_at': now, 'updated_at': now,
      });
      await db.insert('study_periods', {
        'id': 'period-1', 'title': 'Autumn', 'period_type': 'semester',
        'academic_year': '2026/2027', 'semester': 1, 'starts_at': null,
        'ends_at': null, 'description': '', 'created_at': now, 'updated_at': now,
      });
      await db.insert('study_items', {
        'id': 'study-1', 'subject_id': 'subject-1', 'period_id': 'period-1',
        'title': 'Exam', 'description': '', 'item_type': 'exam',
        'format': 'offline', 'status': 'planned', 'scheduled_at': null,
        'due_at': null, 'grade': '', 'notes': '', 'sort_order': 0,
        'created_at': now, 'updated_at': now,
      });
      await db.insert('knowledge_entries', {
        'id': 'knowledge-1', 'title': 'Formula', 'content': 'E=mc²',
        'category': 'Конспекты', 'tags': '[]', 'source_url': null,
        'sort_order': 0, 'created_at': now, 'updated_at': now,
      });
      await db.insert('finance_accounts', {
        'id': 'account-1', 'name': 'Cash', 'account_type': 'cash',
        'currency': 'EUR', 'opening_balance_minor': 10000,
        'is_active': 1, 'sort_order': 0, 'notes': '',
        'created_at': now, 'updated_at': now,
      });
      await db.insert('finance_categories', {
        'id': 'category-1', 'name': 'Food', 'category_type': 'expense',
        'parent_id': null, 'is_active': 1, 'sort_order': 0,
        'created_at': now, 'updated_at': now,
      });
      await db.insert('finance_transactions', {
        'id': 'transaction-1', 'title': 'Groceries',
        'transaction_type': 'expense', 'amount_minor': 2500,
        'account_id': 'account-1', 'destination_account_id': null,
        'category_id': 'category-1', 'debt_id': null,
        'transaction_date': now, 'description': '',
        'created_at': now, 'updated_at': now,
      });
      await db.insert('finance_debts', {
        'id': 'debt-1', 'name': 'Loan', 'debt_type': 'loan',
        'creditor': '', 'initial_amount_minor': 100000,
        'current_balance_minor': 90000, 'interest_rate': 0,
        'monthly_payment_minor': 5000, 'payment_day': null,
        'next_payment_date': null, 'start_date': null, 'end_date': null,
        'status': 'active', 'notes': '', 'sort_order': 0,
        'created_at': now, 'updated_at': now,
      });
      await db.insert('finance_debt_payments', {
        'id': 'payment-1', 'debt_id': 'debt-1',
        'transaction_id': 'transaction-1', 'amount_minor': 5000,
        'principal_minor': 5000, 'interest_minor': 0,
        'paid_at': now, 'notes': '', 'created_at': now,
      });
      await db.insert('finance_budgets', {
        'id': 'budget-1', 'category_id': 'category-1',
        'year': 2026, 'month': 11, 'limit_minor': 30000,
        'created_at': now, 'updated_at': now,
      });
      await db.insert('finance_savings_goals', {
        'id': 'saving-1', 'title': 'Travel', 'target_amount_minor': 50000,
        'saved_amount_minor': 12000, 'currency': 'EUR', 'target_date': null,
        'status': 'active', 'sort_order': 0,
        'created_at': now, 'updated_at': now,
      });
      await db.insert('recipe_entries', {
        'id': 'recipe-2', 'title': 'Pasta',
        'created_at': now, 'updated_at': now,
      });
      await db.insert('recipe_meal_plan_entries', {
        'id': 'meal-2', 'recipe_id': 'recipe-2', 'plan_date': '2026-11-14',
        'meal_type': 'Обед', 'servings': 2, 'cooking_days': 1,
        'duration_minutes': null, 'status': 'Запланировано', 'notes': '',
        'sort_order': 0, 'created_at': now, 'updated_at': now,
      });

      expect((await db.query('study_items')).single['title'], 'Exam');
      expect((await db.query('knowledge_entries')).single['content'], 'E=mc²');
      expect((await db.query('finance_transactions')).single['amount_minor'], 2500);
      expect((await db.query('finance_debt_payments')).single['principal_minor'], 5000);
      expect((await db.query('recipe_meal_plan_entries')).single['plan_date'], '2026-11-14');
    });

    test('can reapply v25 without losing migrated rows', () async {
      db = await openTestDatabase();
      await DatabaseMigrations.migrate(db, 1, 24);

      await db.insert('notifications', {
        'id': 'legacy-notice', 'title': 'Legacy', 'body': 'Keep me',
        'type': 'reminder', 'is_read': 1, 'created_at': '2025-01-01',
        'updated_at': '2025-01-02',
      });
      await db.insert('book_entries', {
        'id': 'legacy-book', 'title': 'Old book', 'author': 'Old author',
        'genres': 'Fantasy', 'created_at': '2025-01-01',
        'updated_at': '2025-01-02',
      });
      await db.insert('wishlist_items', {
        'id': 'legacy-wish', 'title': 'Old wish',
        'created_at': '2025-01-01', 'updated_at': '2025-01-02',
      });

      await DatabaseMigrations.migrate(db, 24, 25);
      await DatabaseMigrations.migrate(db, 24, 25);

      expect((await db.query('notifications')).length, 1);
      expect((await db.query('notifications')).single['message'], 'Keep me');
      expect((await db.query('notifications')).single['read_at'], isNotNull);
      expect((await db.query('book_entries')).single['authors'], 'Old author');
      expect((await db.query('book_entries')).single['genre'], 'Fantasy');
      expect((await db.query('wishlist_entries')).length, 1);

      final foreignKeyViolations = await db.rawQuery('PRAGMA foreign_key_check');
      expect(foreignKeyViolations, isEmpty);
    });

    test('upgrades a version 20 database with existing notifications', () async {
      db = await openTestDatabase();
      await DatabaseMigrations.migrate(db, 1, 20);
      await db.insert('notifications', {
        'id': 'notice-v20', 'title': 'Reminder', 'body': 'Old body',
        'type': 'reminder', 'is_read': 1, 'is_delivered': 1,
        'created_at': '2025-03-01', 'updated_at': '2025-03-02',
      });

      await DatabaseMigrations.migrate(db, 20, 25);

      final notice = (await db.query('notifications')).single;
      expect(notice['message'], 'Old body');
      expect(notice['read_at'], isNotNull);
      expect(await columns(db, 'notifications'), isNot(contains('updated_at')));
    });

    test('upgrades a version 21 database with existing book metadata', () async {
      db = await openTestDatabase();
      await DatabaseMigrations.migrate(db, 1, 21);
      await db.insert('book_entries', {
        'id': 'book-v21', 'title': 'Legacy book', 'author': 'A. Writer',
        'genres': 'Mystery', 'created_at': '2025-03-01',
        'updated_at': '2025-03-02',
      });

      await DatabaseMigrations.migrate(db, 21, 25);

      final book = (await db.query('book_entries')).single;
      expect(book['authors'], 'A. Writer');
      expect(book['genre'], 'Mystery');
    });

    test('is safe to open a database already at v25 without rerunning migrations', () async {
      db = await openTestDatabase();
      await DatabaseMigrations.migrate(db, 1, 25);
      await expectLater(
        DatabaseMigrations.migrate(db, 25, 25),
        completes,
      );
    });
  });
}
