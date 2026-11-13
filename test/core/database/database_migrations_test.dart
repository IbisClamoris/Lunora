import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lunora/core/database/database_migrations.dart';
import 'package:lunora/features/notifications/models/notification_item.dart';
import 'package:lunora/features/recipes/models/recipe_ingredient.dart';

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

      // Verify the complete column contract used by current feature models.
      const modelColumns = <String, List<String>>{
        'movie_entries': [
          'id', 'title', 'original_title', 'media_type', 'description',
          'poster_path', 'backdrop_path', 'genres', 'tags', 'status',
          'rating', 'review', 'release_year', 'runtime_minutes',
          'seasons_count', 'episodes_count', 'current_season',
          'current_episode', 'watched_at', 'created_at', 'updated_at',
        ],
        'movie_episodes': [
          'id', 'movie_id', 'season_number', 'episode_number', 'title',
          'air_date', 'status', 'watched_at', 'rating', 'notes',
          'created_at', 'updated_at',
        ],
        'movie_watch_history': [
          'id', 'movie_id', 'watched_at', 'started_at', 'finished_at',
          'duration_minutes', 'rating', 'mood', 'impressions',
          'favorite_quote', 'notes', 'created_at', 'updated_at',
        ],
        'movie_genres': [
          'id', 'name', 'is_favorite', 'created_at', 'updated_at',
        ],
        'diary_entries': [
          'id', 'title', 'content', 'entry_date', 'created_at',
          'updated_at', 'mood', 'category', 'entry_type', 'is_favorite', 'tags',
        ],
        'planner_goals': [
          'id', 'title', 'month', 'year', 'is_completed', 'sort_order',
          'created_at', 'updated_at',
        ],
        'tasks': [
          'id', 'title', 'description', 'status', 'priority', 'due_date',
          'due_time_minutes', 'created_at', 'updated_at', 'completed_at',
        ],
        'wishlist_entries': [
          'id', 'title', 'description', 'image_path', 'category', 'tags',
          'price', 'currency', 'source_url', 'priority', 'desired_date',
          'is_purchased', 'is_favorite', 'purchased_at', 'notes',
          'sort_order', 'created_at', 'updated_at', 'legacy_status',
        ],
        'study_subjects': [
          'id', 'name', 'teacher', 'description', 'academic_year',
          'semester', 'sort_order', 'created_at', 'updated_at',
        ],
        'study_periods': [
          'id', 'title', 'period_type', 'academic_year', 'semester',
          'starts_at', 'ends_at', 'description', 'created_at', 'updated_at',
        ],
        'study_items': [
          'id', 'subject_id', 'period_id', 'title', 'description',
          'item_type', 'format', 'status', 'scheduled_at', 'due_at',
          'grade', 'notes', 'sort_order', 'created_at', 'updated_at',
        ],
        'knowledge_entries': [
          'id', 'title', 'content', 'category', 'tags', 'source_url',
          'sort_order', 'created_at', 'updated_at',
        ],
        'finance_accounts': [
          'id', 'name', 'account_type', 'currency', 'opening_balance_minor',
          'is_active', 'sort_order', 'notes', 'created_at', 'updated_at',
        ],
        'finance_categories': [
          'id', 'name', 'category_type', 'parent_id', 'is_active',
          'sort_order', 'created_at', 'updated_at',
        ],
        'finance_transactions': [
          'id', 'title', 'transaction_type', 'amount_minor', 'account_id',
          'destination_account_id', 'category_id', 'debt_id',
          'transaction_date', 'description', 'created_at', 'updated_at',
        ],
        'finance_debts': [
          'id', 'name', 'debt_type', 'creditor', 'initial_amount_minor',
          'current_balance_minor', 'interest_rate', 'monthly_payment_minor',
          'payment_day', 'next_payment_date', 'start_date', 'end_date',
          'status', 'notes', 'sort_order', 'created_at', 'updated_at',
        ],
        'finance_debt_payments': [
          'id', 'debt_id', 'transaction_id', 'amount_minor',
          'principal_minor', 'interest_minor', 'paid_at', 'notes', 'created_at',
        ],
        'finance_budgets': [
          'id', 'category_id', 'year', 'month', 'limit_minor',
          'created_at', 'updated_at',
        ],
        'finance_savings_goals': [
          'id', 'title', 'description', 'target_amount_minor',
          'saved_amount_minor', 'currency', 'target_date', 'status',
          'sort_order', 'created_at', 'updated_at',
        ],
      };
      for (final entry in modelColumns.entries) {
        expect(
          await columns(db, entry.key),
          containsAll(entry.value),
          reason: 'Schema mismatch for ${entry.key}',
        );
      }
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
        'priority': 'high', 'status': 'cancelled', 'is_favorite': 1,
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
      // A legacy plan entry can outlive its recipe because recipe_id is nullable
      // and uses ON DELETE SET NULL. v25 keeps this row in the legacy table.
      await db.insert('meal_plan_entries', {
        'id': 'meal-detached', 'recipe_id': null, 'date': '2026-01-04',
        'meal_type': 'Breakfast', 'servings': 1, 'note': 'Recipe was deleted',
        'created_at': '2026-01-01', 'updated_at': '2026-01-02',
      });
      await db.execute('ALTER TABLE meal_plan_entries ADD COLUMN notes TEXT');
      await db.execute('ALTER TABLE meal_plan_entries ADD COLUMN cooking_days INTEGER');
      await db.execute('ALTER TABLE meal_plan_entries ADD COLUMN duration_minutes INTEGER');
      await db.execute('ALTER TABLE meal_plan_entries ADD COLUMN status TEXT');
      await db.execute('ALTER TABLE meal_plan_entries ADD COLUMN sort_order INTEGER');
      await db.update(
        'meal_plan_entries',
        {
          'notes': 'Detailed meal notes',
          'cooking_days': 2,
          'duration_minutes': 45,
          'status': 'prepared',
          'sort_order': 4,
        },
        where: 'id = ?',
        whereArgs: ['meal-1'],
      );
      await db.insert('finance_savings_goals', {
        'id': 'goal-1', 'title': 'Trip', 'description': 'Emergency fund details',
        'target_amount': 50000, 'current_amount': 12000,
        'currency': 'EUR', 'target_date': '2026-12-01',
        'status': 'active', 'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      });

      await DatabaseMigrations.migrate(db, 24, 25);

      final shopping = (await db.query('shopping_items')).single;
      expect(shopping['list_id'], 'list-1');
      expect(shopping['title'], 'Tea');
      expect(shopping['quantity'], 2);
      expect(shopping['notes'], 'Green tea');
      expect(shopping['is_purchased'], 1);

      final wishlist = (await db.query('wishlist_entries')).single;
      expect(wishlist['title'], 'Book');
      expect(wishlist['source_url'], 'https://example.com/book');
      expect(wishlist['priority'], 'high');
      expect(wishlist['is_favorite'], 1);

      final notification = (await db.query('notifications')).single;
      expect(notification['message'], 'Read a chapter');
      expect(notification['read_at'], isNotNull);
      expect(notification['is_delivered'], 1);
      expect(
        NotificationItem.fromMap(notification).metadata['systemDeliveryStatus'],
        'delivered',
      );
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
      expect(meal['notes'], 'Detailed meal notes');
      expect(meal['cooking_days'], 2);
      expect(meal['duration_minutes'], 45);
      expect(meal['status'], 'prepared');
      expect(meal['sort_order'], 4);

      // Detached legacy entries are intentionally retained in the old table.
      // They cannot be represented by the current model, whose recipeId is required.
      final detachedLegacyMeals = await db.query(
        'meal_plan_entries',
        where: 'id = ?',
        whereArgs: ['meal-detached'],
      );
      expect(detachedLegacyMeals, hasLength(1));
      expect(detachedLegacyMeals.single['recipe_id'], isNull);
      expect(
        (await db.query('recipe_meal_plan_entries')).map((row) => row['id']),
        isNot(contains('meal-detached')),
      );

      final goal = (await db.query('finance_savings_goals')).single;
      expect(goal['target_amount_minor'], 5000000);
      expect(goal['saved_amount_minor'], 1200000);
      expect(goal['description'], 'Emergency fund details');
      expect(wishlist['legacy_status'], 'cancelled');
      expect(wishlist['is_purchased'], 0);
      final ingredient = (await db.query('recipe_ingredients')).single;
      expect(ingredient['quantity'], 3);
      expect(ingredient['notes'], 'Large');
      expect(RecipeIngredient.fromMap(ingredient).createdAt, isA<DateTime>());
      expect(RecipeIngredient.fromMap(ingredient).updatedAt, isA<DateTime>());
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

    test('upgrades legacy notifications with is_read but no updated_at', () async {
      db = await openTestDatabase();
      await DatabaseMigrations.migrate(db, 1, 19);
      await db.execute('''
        CREATE TABLE notifications (
          id TEXT PRIMARY KEY, title TEXT NOT NULL,
          body TEXT NOT NULL DEFAULT '', type TEXT NOT NULL DEFAULT '',
          is_read INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL
        )
      ''');
      await db.insert('notifications', {
        'id': 'notice-no-updated', 'title': 'Legacy reminder',
        'body': 'Still here', 'type': 'reminder', 'is_read': 1,
        'created_at': '2025-03-01T10:00:00.000',
      });

      await DatabaseMigrations.migrate(db, 19, 25);

      final notice = (await db.query('notifications')).single;
      expect(notice['message'], 'Still here');
      expect(notice['read_at'], '2025-03-01T10:00:00.000');
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

    test('upgrades every historical database version from 1 through 24', () async {
      for (var oldVersion = 1; oldVersion <= 24; oldVersion++) {
        db = await openTestDatabase();
        await DatabaseMigrations.migrate(db, 1, oldVersion);

        // Seed representative records in tables that exist at this version.
        final existingTables = await tableNames(db);
        if (existingTables.contains('recipe_entries')) {
          await db.insert('recipe_entries', {
            'id': 'recipe-v$oldVersion',
            'title': 'Legacy recipe v$oldVersion',
            'created_at': '2025-01-01',
            'updated_at': '2025-01-01',
          });
        }
        if (existingTables.contains('wishlist_items')) {
          await db.insert('wishlist_items', {
            'id': 'wish-v$oldVersion',
            'title': 'Legacy wish v$oldVersion',
            'created_at': '2025-01-01',
            'updated_at': '2025-01-01',
          });
        }
        if (existingTables.contains('shopping_items')) {
          await db.insert('shopping_lists', {
            'id': 'list-v$oldVersion', 'title': 'Legacy list',
            'created_at': '2025-01-01', 'updated_at': '2025-01-01',
          });
          await db.insert('shopping_items', {
            'id': 'shopping-v$oldVersion', 'list_id': 'list-v$oldVersion',
            'name': 'Legacy item', 'created_at': '2025-01-01',
            'updated_at': '2025-01-01',
          });
        }

        await DatabaseMigrations.migrate(db, oldVersion, 25);

        final upgradedTables = await tableNames(db);
        expect(upgradedTables, containsAll([
          'shopping_items', 'wishlist_entries', 'notifications',
          'study_subjects', 'study_items', 'finance_accounts',
          'knowledge_entries', 'recipe_meal_plan_entries',
        ]), reason: 'Upgrade from database version $oldVersion');

        if (existingTables.contains('recipe_entries')) {
          expect(
            (await db.query('recipe_entries')).single['title'],
            'Legacy recipe v$oldVersion',
            reason: 'Recipe row lost while upgrading from $oldVersion',
          );
        }
        if (existingTables.contains('shopping_items')) {
          expect(
            (await db.query('shopping_items')).single['title'],
            'Legacy item',
            reason: 'Shopping row lost while upgrading from $oldVersion',
          );
        }
        expect(
          await db.rawQuery('PRAGMA foreign_key_check'),
          isEmpty,
          reason: 'Foreign key violation after upgrading from $oldVersion',
        );
        await db.close();
      }
    });

    test('movie, diary and planner tables accept current model records', () async {
      db = await openTestDatabase();
      await DatabaseMigrations.migrate(db, 1, 25);
      const now = '2026-11-13T12:00:00.000';

      await db.insert('movie_entries', {
        'id': 'movie-1', 'title': 'The Example', 'original_title': '',
        'media_type': 'movie', 'description': '', 'genres': '[]',
        'tags': '[]', 'status': 'planned', 'review': '',
        'current_season': 0, 'current_episode': 0, 'is_favorite': 0,
        'sort_order': 0, 'created_at': now, 'updated_at': now,
      });
      await db.insert('movie_episodes', {
        'id': 'episode-1', 'movie_id': 'movie-1', 'season_number': 1,
        'episode_number': 1, 'title': 'Pilot', 'status': 'planned',
        'notes': '', 'created_at': now, 'updated_at': now,
      });
      await db.insert('movie_watch_history', {
        'id': 'watch-1', 'movie_id': 'movie-1', 'watched_at': now,
        'mood': '', 'impressions': '', 'favorite_quote': '', 'notes': '',
        'created_at': now, 'updated_at': now,
      });
      await db.insert('movie_genres', {
        'id': 'genre-1', 'name': 'Fantasy', 'is_favorite': 0,
        'created_at': now, 'updated_at': now,
      });
      await db.insert('diary_entries', {
        'id': 'diary-1', 'title': 'Today', 'content': 'Entry',
        'entry_date': '2026-11-13', 'created_at': now, 'updated_at': now,
        'category': 'Personal', 'entry_type': 'diary',
        'is_favorite': 0, 'tags': '[]',
      });
      await db.insert('planner_goals', {
        'id': 'goal-1', 'title': 'Read a book', 'month': 11, 'year': 2026,
        'is_completed': 0, 'sort_order': 0,
        'created_at': now, 'updated_at': now,
      });
      expect((await db.query('movie_entries')).single['title'], 'The Example');
      expect((await db.query('movie_episodes')).single['movie_id'], 'movie-1');
      expect((await db.query('movie_watch_history')).single['id'], 'watch-1');
      expect((await db.query('movie_genres')).single['name'], 'Fantasy');
      expect((await db.query('diary_entries')).single['entry_date'], '2026-11-13');
      expect((await db.query('planner_goals')).single['title'], 'Read a book');
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
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
