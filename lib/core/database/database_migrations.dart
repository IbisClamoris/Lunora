import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseMigrations {
  DatabaseMigrations._();

  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 1:
          await _migration1(db);
          break;
        case 2:
          await _migration2(db);
          break;
        case 3:
          await _migration3(db);
          break;
        case 4:
          await _migration4(db);
          break;
        case 5:
          await _migration5(db);
          break;
        case 6:
          await _migration6(db);
          break;
        case 7:
          await _migration7(db);
          break;
        case 8:
          await _migration8(db);
          break;
        case 9:
          await _migration9(db);
          break;
        case 10:
          await _migration10(db);
          break;
        case 11:
          await _migration11(db);
          break;
        case 12:
          await _migration12(db);
          break;
        case 13:
          await _migration13(db);
          break;
        case 14:
          await _migration14(db);
          break;
        case 15:
          await _migration15(db);
          break;
        case 16:
          await _migration16(db);
          break;
        case 17:
          await _migration17(db);
          break;
        case 18:
          await _migration18(db);
          break;
        case 19:
          await _migration19(db);
          break;
        case 20:
          await _migration20(db);
          break;
        case 21:
          await _migration21(db);
          break;
        case 22:
          await _migration22(db);
          break;
        case 23:
          await _migration23(db);
          break;
        case 24:
          await _migration24(db);
          break;
        case 25:
          await _migration25(db);
          break;
      }
    }
  }

  // Первоначальная структура создаётся в database.dart.

  static Future<void> _migration1(Database db) async {}

  static Future<void> _migration2(Database db) async {}

  static Future<void> _migration3(Database db) async {}

  static Future<void> _migration4(Database db) async {}

  static Future<void> _migration5(Database db) async {}

  static Future<void> _migration6(Database db) async {}

  static Future<void> _migration7(Database db) async {}

  static Future<void> _migration8(Database db) async {}

  static Future<void> _migration9(Database db) async {}

  static Future<void> _migration10(Database db) async {}

  static Future<void> _migration11(Database db) async {}

  static Future<void> _migration12(Database db) async {}

  // ============================================================
  // MIGRATION 13
  // ============================================================

  static Future<void> _migration13(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_entries (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        original_title TEXT,
        description TEXT,
        poster_path TEXT,
        backdrop_path TEXT,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        genres TEXT,
        tags TEXT,
        release_date TEXT,
        finish_date TEXT,
        rating REAL,
        review TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        total_seasons INTEGER,
        total_episodes INTEGER,
        watched_seasons INTEGER,
        watched_episodes INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_title
      ON movie_entries(title)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_type
      ON movie_entries(type)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_status
      ON movie_entries(status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_favorite
      ON movie_entries(is_favorite)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_updated
      ON movie_entries(updated_at)
    ''');
  }

  // ============================================================
  // MIGRATION 14
  // ============================================================

  static Future<void> _migration14(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_entries (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        instructions TEXT,
        cover_path TEXT,
        category TEXT,
        tags TEXT,
        servings INTEGER,
        prep_time_minutes INTEGER,
        cook_time_minutes INTEGER,
        rating REAL,
        review TEXT,
        source_url TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recipe_entries_title
      ON recipe_entries(title)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recipe_entries_category
      ON recipe_entries(category)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recipe_entries_favorite
      ON recipe_entries(is_favorite)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_ingredients (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        name TEXT NOT NULL,
        amount REAL,
        unit TEXT,
        note TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (recipe_id)
          REFERENCES recipe_entries(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe
      ON recipe_ingredients(recipe_id)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_steps (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        description TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (recipe_id)
          REFERENCES recipe_entries(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recipe_steps_recipe
      ON recipe_steps(recipe_id)
    ''');
  }

  // ============================================================
  // MIGRATION 15
  // ============================================================

  static Future<void> _migration15(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wishlist_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        price REAL,
        currency TEXT NOT NULL DEFAULT '',
        url TEXT NOT NULL DEFAULT '',
        image_path TEXT,
        priority TEXT NOT NULL DEFAULT 'medium',
        status TEXT NOT NULL DEFAULT 'planned',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_wishlist_items_status
      ON wishlist_items(status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_wishlist_items_category
      ON wishlist_items(category)
    ''');
  }

  // ============================================================
  // MIGRATION 16
  // ============================================================

  static Future<void> _migration16(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_lists (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_items (
        id TEXT PRIMARY KEY,
        list_id TEXT,
        name TEXT NOT NULL,
        amount REAL,
        unit TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        is_purchased INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (list_id)
          REFERENCES shopping_lists(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_shopping_items_list
      ON shopping_items(list_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_shopping_items_purchased
      ON shopping_items(is_purchased)
    ''');
  }

  // ============================================================
  // MIGRATION 17
  // ============================================================

  static Future<void> _migration17(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS finance_savings_goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        target_amount INTEGER NOT NULL DEFAULT 0,
        current_amount INTEGER NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT '',
        target_date TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_finance_savings_goals_status
      ON finance_savings_goals(status)
    ''');
  }

  // ============================================================
  // MIGRATION 18
  // ============================================================

  static Future<void> _migration18(Database db) async {
    final recipeColumns = await db.rawQuery(
      'PRAGMA table_info(recipe_entries)',
    );

    final existingRecipeColumns = recipeColumns
        .map((row) => row['name'] as String)
        .toSet();

    if (!existingRecipeColumns.contains('source_url')) {
      await db.execute("ALTER TABLE recipe_entries ADD COLUMN source_url TEXT");
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_plan_entries (
        id TEXT PRIMARY KEY,
        recipe_id TEXT,
        date TEXT NOT NULL,
        meal_type TEXT NOT NULL DEFAULT '',
        servings INTEGER NOT NULL DEFAULT 1,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (recipe_id)
          REFERENCES recipe_entries(id)
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_meal_plan_entries_date
      ON meal_plan_entries(date)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_meal_plan_entries_recipe
      ON meal_plan_entries(recipe_id)
    ''');
  }

  // ============================================================
  // MIGRATION 19
  // ============================================================

  static Future<void> _migration19(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(recipe_entries)');

    final existingColumns = columns.map((row) => row['name'] as String).toSet();

    if (!existingColumns.contains('source_name')) {
      await db.execute(
        "ALTER TABLE recipe_entries ADD COLUMN source_name TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  // ============================================================
  // MIGRATION 20
  // ============================================================

  static Future<void> _migration20(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT '',
        scheduled_at TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        is_delivered INTEGER NOT NULL DEFAULT 0,
        related_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Existing notification tables may predate scheduled_at or is_read.
    // CREATE TABLE IF NOT EXISTS does not add missing columns, so only create
    // indexes for columns that are actually present in the legacy schema.
    final notificationColumns = await _tableColumns(db, 'notifications');
    if (notificationColumns.contains('scheduled_at')) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_notifications_scheduled
        ON notifications(scheduled_at)
      ''');
    }

    if (notificationColumns.contains('is_read')) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_notifications_read
        ON notifications(is_read)
      ''');
    }
  }

  // ============================================================
  // MIGRATION 21
  // ============================================================

  static Future<void> _migration21(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS book_entries (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        original_title TEXT NOT NULL DEFAULT '',
        author TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        cover_path TEXT,
        status TEXT NOT NULL DEFAULT 'planned',
        rating REAL,
        review TEXT NOT NULL DEFAULT '',
        release_year INTEGER,
        page_count INTEGER,
        current_page INTEGER NOT NULL DEFAULT 0,
        started_at TEXT,
        finished_at TEXT,
        genres TEXT NOT NULL DEFAULT '[]',
        tags TEXT NOT NULL DEFAULT '[]',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        series_name TEXT NOT NULL DEFAULT '',
        series_number INTEGER,
        book_format TEXT NOT NULL DEFAULT '',
        source_name TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_book_entries_title
      ON book_entries(title)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_book_entries_author
      ON book_entries(author)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_book_entries_status
      ON book_entries(status)
    ''');
  }

  // ============================================================
  // MIGRATION 22
  // Приведение movie_entries к структуре MovieEntry.
  // Старые поля сохраняются отдельно.
  // ============================================================

  static Future<void> _migration22(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(movie_entries)');

    if (tableInfo.isEmpty) {
      await _createMovieEntriesTable(db);
      return;
    }

    final columns = tableInfo.map((row) => row['name'] as String).toSet();

    String sourceColumn(String name, {String fallback = 'NULL'}) {
      return columns.contains(name) ? name : fallback;
    }

    await db.execute('''
      CREATE TABLE movie_entries_new (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        original_title TEXT NOT NULL DEFAULT '',
        media_type TEXT NOT NULL DEFAULT 'movie',
        description TEXT NOT NULL DEFAULT '',
        poster_path TEXT,
        backdrop_path TEXT,
        genres TEXT NOT NULL DEFAULT '[]',
        tags TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'planned',
        rating REAL,
        review TEXT NOT NULL DEFAULT '',
        release_year INTEGER,
        runtime_minutes INTEGER,
        seasons_count INTEGER,
        episodes_count INTEGER,
        current_season INTEGER NOT NULL DEFAULT 0,
        current_episode INTEGER NOT NULL DEFAULT 0,
        watched_at TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        type TEXT,
        release_date TEXT,
        finish_date TEXT,
        total_seasons INTEGER,
        total_episodes INTEGER,
        watched_seasons INTEGER,
        watched_episodes INTEGER
      )
    ''');

    await db.execute('''
      INSERT INTO movie_entries_new (
        id,
        title,
        original_title,
        media_type,
        description,
        poster_path,
        backdrop_path,
        genres,
        tags,
        status,
        rating,
        review,
        release_year,
        runtime_minutes,
        seasons_count,
        episodes_count,
        current_season,
        current_episode,
        watched_at,
        is_favorite,
        sort_order,
        created_at,
        updated_at,
        type,
        release_date,
        finish_date,
        total_seasons,
        total_episodes,
        watched_seasons,
        watched_episodes
      )
      SELECT
        ${sourceColumn('id')},
        ${sourceColumn('title', fallback: "''")},
        ${sourceColumn('original_title', fallback: "''")},
        COALESCE(${sourceColumn('media_type', fallback: sourceColumn('type', fallback: "'movie'"))}, 'movie'),
        COALESCE(${sourceColumn('description', fallback: "''")}, ''),
        ${sourceColumn('poster_path')},
        ${sourceColumn('backdrop_path')},
        COALESCE(${sourceColumn('genres', fallback: "'[]'")}, '[]'),
        COALESCE(${sourceColumn('tags', fallback: "'[]'")}, '[]'),
        COALESCE(${sourceColumn('status', fallback: "'planned'")}, 'planned'),
        ${sourceColumn('rating')},
        COALESCE(${sourceColumn('review', fallback: "''")}, ''),
        ${sourceColumn('release_year')},
        ${sourceColumn('runtime_minutes')},
        COALESCE(${sourceColumn('seasons_count', fallback: sourceColumn('total_seasons'))}, ${sourceColumn('total_seasons')}),
        COALESCE(${sourceColumn('episodes_count', fallback: sourceColumn('total_episodes'))}, ${sourceColumn('total_episodes')}),
        COALESCE(${sourceColumn('current_season', fallback: sourceColumn('watched_seasons', fallback: '0'))}, 0),
        COALESCE(${sourceColumn('current_episode', fallback: sourceColumn('watched_episodes', fallback: '0'))}, 0),
        ${sourceColumn('watched_at')},
        COALESCE(${sourceColumn('is_favorite', fallback: '0')}, 0),
        COALESCE(${sourceColumn('sort_order', fallback: '0')}, 0),
        COALESCE(${sourceColumn('created_at', fallback: "datetime('now')")}, datetime('now')),
        COALESCE(${sourceColumn('updated_at', fallback: "datetime('now')")}, datetime('now')),
        ${sourceColumn('type')},
        ${sourceColumn('release_date')},
        ${sourceColumn('finish_date')},
        ${sourceColumn('total_seasons')},
        ${sourceColumn('total_episodes')},
        ${sourceColumn('watched_seasons')},
        ${sourceColumn('watched_episodes')}
      FROM movie_entries
    ''');

    await db.execute('DROP TABLE movie_entries');

    await db.execute('ALTER TABLE movie_entries_new RENAME TO movie_entries');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_title
      ON movie_entries(title)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_type
      ON movie_entries(media_type)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_status
      ON movie_entries(status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_favorite
      ON movie_entries(is_favorite)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_updated
      ON movie_entries(updated_at)
    ''');
  }

  // ============================================================
  // MIGRATION 23
  // Серии, история просмотра и жанры.
  // ============================================================

  static Future<void> _migration23(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_episodes (
        id TEXT PRIMARY KEY,
        movie_id TEXT NOT NULL,
        season_number INTEGER NOT NULL DEFAULT 1,
        episode_number INTEGER NOT NULL DEFAULT 1,
        title TEXT NOT NULL DEFAULT '',
        air_date TEXT,
        status TEXT NOT NULL DEFAULT 'planned',
        watched_at TEXT,
        rating REAL,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (movie_id)
          REFERENCES movie_entries(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_episodes_movie
      ON movie_episodes(movie_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_episodes_season
      ON movie_episodes(movie_id, season_number, episode_number)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_episodes_status
      ON movie_episodes(movie_id, status)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_watch_history (
        id TEXT PRIMARY KEY,
        movie_id TEXT NOT NULL,
        watched_at TEXT NOT NULL,
        started_at TEXT,
        finished_at TEXT,
        duration_minutes INTEGER,
        rating REAL,
        mood TEXT NOT NULL DEFAULT '',
        impressions TEXT NOT NULL DEFAULT '',
        favorite_quote TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (movie_id)
          REFERENCES movie_entries(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_watch_history_movie
      ON movie_watch_history(movie_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_watch_history_watched
      ON movie_watch_history(watched_at)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_genres (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_movie_genres_name
      ON movie_genres(name COLLATE NOCASE)
    ''');
  }

  // ============================================================
  // Создание актуальной таблицы фильмов.
  // ============================================================

  static Future<void> _createMovieEntriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_entries (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        original_title TEXT NOT NULL DEFAULT '',
        media_type TEXT NOT NULL DEFAULT 'movie',
        description TEXT NOT NULL DEFAULT '',
        poster_path TEXT,
        backdrop_path TEXT,
        genres TEXT NOT NULL DEFAULT '[]',
        tags TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'planned',
        rating REAL,
        review TEXT NOT NULL DEFAULT '',
        release_year INTEGER,
        runtime_minutes INTEGER,
        seasons_count INTEGER,
        episodes_count INTEGER,
        current_season INTEGER NOT NULL DEFAULT 0,
        current_episode INTEGER NOT NULL DEFAULT 0,
        watched_at TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        type TEXT,
        release_date TEXT,
        finish_date TEXT,
        total_seasons INTEGER,
        total_episodes INTEGER,
        watched_seasons INTEGER,
        watched_episodes INTEGER
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_title
      ON movie_entries(title)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_type
      ON movie_entries(media_type)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_status
      ON movie_entries(status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_favorite
      ON movie_entries(is_favorite)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movie_entries_updated
      ON movie_entries(updated_at)
    ''');
  }
  // ============================================================
  // MIGRATION 24
  // Дневник, цели планера и общие задачи.
  // ============================================================

  static Future<void> _migration24(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS diary_entries (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        entry_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        mood TEXT,
        category TEXT NOT NULL DEFAULT 'Без категории',
        entry_type TEXT NOT NULL DEFAULT 'diary',
        is_favorite INTEGER NOT NULL DEFAULT 0,
        tags TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_diary_entries_date
      ON diary_entries(entry_date DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_diary_entries_favorite
      ON diary_entries(is_favorite)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_diary_entries_category
      ON diary_entries(category)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS planner_goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_planner_goals_period
      ON planner_goals(year, month, sort_order)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'planned',
        priority TEXT NOT NULL DEFAULT 'normal',
        due_date TEXT,
        due_time_minutes INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_due
      ON tasks(due_date, due_time_minutes)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tasks_status
      ON tasks(status)
    ''');
  }

  // Migration 25 restores tables required by current feature repositories.
  static Future<Set<String>> _tableColumns(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info("$table")');
    return rows.map((row) => row['name'] as String).toSet();
  }

  static Future<void> _ensureColumn(
    Database db, String table, String column, String definition,
  ) async {
    if (!(await _tableColumns(db, table)).contains(column)) {
      await db.execute('ALTER TABLE "$table" ADD COLUMN "$column" $definition');
    }
  }

  static Future<void> _migration25(Database db) async {
    // Legacy shopping_items had a required "name" column. Rebuild it to
    // match ShoppingItem and preserve rows/values from the old schema.
    final shopping = await _tableColumns(db, 'shopping_items');
    if (shopping.isNotEmpty) {
      final titleExpr = shopping.contains('title') ? 'title' : 'name';
      final quantityExpr = shopping.contains('quantity') ? 'quantity' :
          (shopping.contains('amount') ? 'amount' : 'NULL');
      final notesExpr = shopping.contains('notes') ? 'notes' :
          (shopping.contains('note') ? 'note' : 'NULL');
      final unitExpr = shopping.contains('unit') ? 'unit' : 'NULL';
      final categoryExpr = shopping.contains('category') ? 'category' : 'NULL';
      final purchasedExpr = shopping.contains('is_purchased') ? 'is_purchased' : '0';
      final createdExpr = shopping.contains('created_at') ? 'created_at' : "datetime('now')";
      final updatedExpr = shopping.contains('updated_at') ? 'updated_at' : "datetime('now')";
      final idExpr = shopping.contains('id') ? 'id' : "lower(hex(randomblob(16)))";
      final listIdExpr = shopping.contains('list_id') ? 'list_id' : 'NULL';
      final purchasedAtExpr = shopping.contains('purchased_at') ? 'purchased_at' : 'NULL';
      final sourceModuleExpr = shopping.contains('source_module') ? 'source_module' : 'NULL';
      final sourceIdExpr = shopping.contains('source_record_id') ? 'source_record_id' : 'NULL';
      final sortExpr = shopping.contains('sort_order') ? 'sort_order' : '0';
      await db.execute('''
        CREATE TABLE shopping_items_v25 (
          id TEXT PRIMARY KEY, list_id TEXT, title TEXT NOT NULL, category TEXT,
          quantity REAL, unit TEXT, notes TEXT,
          is_purchased INTEGER NOT NULL DEFAULT 0, purchased_at TEXT,
          source_module TEXT, source_record_id TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
          FOREIGN KEY(list_id) REFERENCES shopping_lists(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        INSERT OR REPLACE INTO shopping_items_v25
        SELECT $idExpr, $listIdExpr, COALESCE($titleExpr, ''), $categoryExpr,
          $quantityExpr, $unitExpr, $notesExpr, $purchasedExpr,
          $purchasedAtExpr, $sourceModuleExpr, $sourceIdExpr, $sortExpr,
          $createdExpr, $updatedExpr FROM shopping_items
      ''');
      await db.execute('DROP TABLE shopping_items');
      await db.execute('ALTER TABLE shopping_items_v25 RENAME TO shopping_items');
    } else {
      await db.execute('''
        CREATE TABLE shopping_items (
          id TEXT PRIMARY KEY, list_id TEXT, title TEXT NOT NULL, category TEXT,
          quantity REAL, unit TEXT, notes TEXT,
          is_purchased INTEGER NOT NULL DEFAULT 0, purchased_at TEXT,
          source_module TEXT, source_record_id TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
          FOREIGN KEY(list_id) REFERENCES shopping_lists(id) ON DELETE CASCADE
        )
      ''');
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shopping_items_order ON shopping_items(is_purchased,sort_order,created_at)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS wishlist_entries (
        id TEXT PRIMARY KEY, title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '', image_path TEXT,
        category TEXT NOT NULL DEFAULT 'Без категории',
        tags TEXT NOT NULL DEFAULT '[]', price REAL,
        currency TEXT NOT NULL DEFAULT '', source_url TEXT,
        priority TEXT NOT NULL DEFAULT 'normal', desired_date TEXT,
        legacy_status TEXT NOT NULL DEFAULT '',
        is_purchased INTEGER NOT NULL DEFAULT 0, is_favorite INTEGER NOT NULL DEFAULT 0,
        purchased_at TEXT, notes TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    final oldWishlist = await _tableColumns(db, 'wishlist_items');
    if (oldWishlist.isNotEmpty) {
      final sourceUrl = oldWishlist.contains('source_url') ? 'source_url' :
          (oldWishlist.contains('url') ? 'url' : 'NULL');
      final image = oldWishlist.contains('image_path') ? 'image_path' : 'NULL';
      final tags = oldWishlist.contains('tags') ? 'tags' : "'[]'";
      final purchased = oldWishlist.contains('is_purchased')
          ? 'is_purchased'
          : (oldWishlist.contains('status')
              ? "CASE WHEN status IN ('purchased','bought','completed') THEN 1 ELSE 0 END"
              : '0');
      final legacyStatus = oldWishlist.contains('status') ? 'COALESCE(status,\'\')' : "''";
      final purchasedAt = oldWishlist.contains('purchased_at') ? 'purchased_at' : 'NULL';
      final favorite = oldWishlist.contains('is_favorite') ? 'is_favorite' : '0';
      final notes = oldWishlist.contains('notes') ? 'notes' : "''";
      final sortOrder = oldWishlist.contains('sort_order') ? 'sort_order' : '0';
      await db.execute('''
        INSERT OR IGNORE INTO wishlist_entries
        (id,title,description,image_path,category,tags,price,currency,source_url,
         priority,legacy_status,is_purchased,is_favorite,purchased_at,notes,sort_order,created_at,updated_at)
        SELECT id,title,COALESCE(description,''),$image,
         COALESCE(category,'Без категории'),COALESCE($tags,'[]'),price,
         COALESCE(currency,''),$sourceUrl,COALESCE(priority,'normal'),
         $legacyStatus,$purchased,$favorite,$purchasedAt,COALESCE($notes,''),$sortOrder,
         created_at,updated_at FROM wishlist_items
      ''');
    }

    // Rebuild notifications because the v20 table has a NOT NULL
    // updated_at column that the current NotificationItem model no longer writes.
    final legacyNotificationColumns = await _tableColumns(db, 'notifications');
    if (legacyNotificationColumns.isNotEmpty) {
      String notificationExpr(String current, {String? legacy, String fallback = 'NULL'}) {
        if (legacyNotificationColumns.contains(current)) return current;
        if (legacy != null && legacyNotificationColumns.contains(legacy)) return legacy;
        return fallback;
      }
      final notificationTitle = notificationExpr('title', fallback: "''");
      final notificationCreated = notificationExpr('created_at', fallback: "datetime('now')");
      final notificationType = notificationExpr('type', fallback: "'info'");
      final notificationMessage = notificationExpr('message', legacy: 'body', fallback: "''");
      final notificationReadAt = notificationExpr('read_at');
      final notificationScheduled = notificationExpr('scheduled_at');
      final notificationCategory = notificationExpr('category', fallback: "'other'");
      final notificationEventType = notificationExpr('event_type', fallback: "'unknown'");
      final notificationEventKey = notificationExpr('event_key');
      final notificationSourceModule = notificationExpr('source_module');
      final notificationSourceId = notificationExpr('source_record_id', legacy: 'related_id');
      final notificationMetadata = notificationExpr('metadata', fallback: "'{}'");
      final notificationId = notificationExpr('id', fallback: "lower(hex(randomblob(16)))");
      var readAtExpression = notificationReadAt;
      if (legacyNotificationColumns.contains('is_read')) {
        // Some intermediate/hand-migrated legacy databases have is_read but
        // no updated_at. Only reference columns that actually exist.
        final readTimestamp = legacyNotificationColumns.contains('updated_at')
            ? 'updated_at'
            : notificationCreated;
        final legacyReadAt =
            "CASE WHEN is_read=1 THEN COALESCE($readTimestamp,$notificationCreated) END";
        readAtExpression = notificationReadAt == 'NULL'
            ? legacyReadAt
            : "COALESCE($notificationReadAt,$legacyReadAt)";
      }
      await db.execute('''
        CREATE TABLE notifications_v25 (
          id TEXT PRIMARY KEY,
          category TEXT NOT NULL DEFAULT 'other',
          type TEXT NOT NULL DEFAULT 'info',
          event_type TEXT NOT NULL DEFAULT 'unknown',
          event_key TEXT,
          title TEXT NOT NULL DEFAULT '',
          message TEXT NOT NULL DEFAULT '',
          source_module TEXT,
          source_record_id TEXT,
          created_at TEXT NOT NULL DEFAULT '',
          scheduled_at TEXT,
          read_at TEXT,
          metadata TEXT NOT NULL DEFAULT '{}'
        )
      ''');
      await db.execute('''
        INSERT INTO notifications_v25
        (id,category,type,event_type,event_key,title,message,source_module,
         source_record_id,created_at,scheduled_at,read_at,metadata)
        SELECT $notificationId,$notificationCategory,$notificationType,
          $notificationEventType,$notificationEventKey,$notificationTitle,
          $notificationMessage,$notificationSourceModule,$notificationSourceId,
          COALESCE($notificationCreated,''),$notificationScheduled,
          $readAtExpression,$notificationMetadata
        FROM notifications
      ''');
      await db.execute('DROP TABLE notifications');
      await db.execute('ALTER TABLE notifications_v25 RENAME TO notifications');
    } else {
      await db.execute('''
        CREATE TABLE notifications (
          id TEXT PRIMARY KEY, category TEXT NOT NULL DEFAULT 'other',
          type TEXT NOT NULL DEFAULT 'info', event_type TEXT NOT NULL DEFAULT 'unknown',
          event_key TEXT, title TEXT NOT NULL DEFAULT '', message TEXT NOT NULL DEFAULT '',
          source_module TEXT, source_record_id TEXT, created_at TEXT NOT NULL DEFAULT '',
          scheduled_at TEXT, read_at TEXT, metadata TEXT NOT NULL DEFAULT '{}'
        )
      ''');
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_read_at ON notifications(read_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_event_key ON notifications(event_key)');

    // book_entries v21 used author/genres; the current BookEntry model
    // writes authors/genre. Add current columns and preserve legacy values.
    await _ensureColumn(db, 'book_entries', 'authors', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(db, 'book_entries', 'genre', "TEXT NOT NULL DEFAULT ''");
    final bookColumns = await _tableColumns(db, 'book_entries');
    if (bookColumns.contains('author')) {
      await db.execute("UPDATE book_entries SET authors=CASE WHEN authors='' THEN COALESCE(author,'') ELSE authors END");
    }
    if (bookColumns.contains('genres')) {
      await db.execute("UPDATE book_entries SET genre=CASE WHEN genre='' THEN COALESCE(genres,'') ELSE genre END");
    }

    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_read_at ON notifications(read_at)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_subjects (
        id TEXT PRIMARY KEY, name TEXT NOT NULL,
        teacher TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '',
        academic_year TEXT NOT NULL DEFAULT '', semester INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_periods (
        id TEXT PRIMARY KEY, title TEXT NOT NULL,
        period_type TEXT NOT NULL DEFAULT 'other', academic_year TEXT NOT NULL DEFAULT '',
        semester INTEGER NOT NULL DEFAULT 1, starts_at TEXT, ends_at TEXT,
        description TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_items (
        id TEXT PRIMARY KEY, subject_id TEXT, period_id TEXT, title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '', item_type TEXT NOT NULL DEFAULT 'other',
        format TEXT NOT NULL DEFAULT 'none', status TEXT NOT NULL DEFAULT 'planned',
        scheduled_at TEXT, due_at TEXT, grade TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES study_subjects(id) ON DELETE SET NULL,
        FOREIGN KEY(period_id) REFERENCES study_periods(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_study_items_schedule ON study_items(scheduled_at,due_at,sort_order)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_entries (
        id TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'Другое', tags TEXT NOT NULL DEFAULT '[]',
        source_url TEXT, sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_knowledge_entries_order ON knowledge_entries(sort_order,updated_at)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS finance_accounts (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, account_type TEXT NOT NULL DEFAULT 'other',
        currency TEXT NOT NULL DEFAULT 'RUB', opening_balance_minor INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1, sort_order INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS finance_categories (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, category_type TEXT NOT NULL DEFAULT 'expense',
        parent_id TEXT, is_active INTEGER NOT NULL DEFAULT 1, sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        FOREIGN KEY(parent_id) REFERENCES finance_categories(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS finance_transactions (
        id TEXT PRIMARY KEY, title TEXT NOT NULL, transaction_type TEXT NOT NULL DEFAULT 'expense',
        amount_minor INTEGER NOT NULL DEFAULT 0, account_id TEXT NOT NULL,
        destination_account_id TEXT, category_id TEXT, debt_id TEXT,
        transaction_date TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        FOREIGN KEY(account_id) REFERENCES finance_accounts(id) ON DELETE CASCADE,
        FOREIGN KEY(destination_account_id) REFERENCES finance_accounts(id) ON DELETE SET NULL,
        FOREIGN KEY(category_id) REFERENCES finance_categories(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS finance_debts (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, debt_type TEXT NOT NULL DEFAULT 'loan',
        creditor TEXT NOT NULL DEFAULT '', initial_amount_minor INTEGER NOT NULL DEFAULT 0,
        current_balance_minor INTEGER NOT NULL DEFAULT 0, interest_rate REAL NOT NULL DEFAULT 0,
        monthly_payment_minor INTEGER NOT NULL DEFAULT 0, payment_day INTEGER,
        next_payment_date TEXT, start_date TEXT, end_date TEXT,
        status TEXT NOT NULL DEFAULT 'active', notes TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS finance_debt_payments (
        id TEXT PRIMARY KEY, debt_id TEXT NOT NULL, transaction_id TEXT NOT NULL,
        amount_minor INTEGER NOT NULL DEFAULT 0, principal_minor INTEGER NOT NULL DEFAULT 0,
        interest_minor INTEGER NOT NULL DEFAULT 0, paid_at TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL,
        FOREIGN KEY(debt_id) REFERENCES finance_debts(id) ON DELETE CASCADE,
        FOREIGN KEY(transaction_id) REFERENCES finance_transactions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS finance_budgets (
        id TEXT PRIMARY KEY, category_id TEXT NOT NULL, year INTEGER NOT NULL,
        month INTEGER NOT NULL, limit_minor INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        FOREIGN KEY(category_id) REFERENCES finance_categories(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS finance_savings_goals (
        id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
        target_amount_minor INTEGER NOT NULL DEFAULT 0,
        saved_amount_minor INTEGER NOT NULL DEFAULT 0, currency TEXT NOT NULL DEFAULT 'RUB',
        target_date TEXT, status TEXT NOT NULL DEFAULT 'active',
        sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    // Version 17 stored savings goal amounts in major currency units.
    // Current finance models store minor units (Excel import multiplies by 100).
    // Convert legacy values exactly once when the v25 fields are still zero.
    await _ensureColumn(db, 'finance_savings_goals', 'description', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(db, 'finance_savings_goals', 'target_amount_minor', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'finance_savings_goals', 'saved_amount_minor', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(db, 'finance_savings_goals', 'currency', "TEXT NOT NULL DEFAULT 'RUB'");
    await _ensureColumn(db, 'finance_savings_goals', 'target_date', 'TEXT');
    await _ensureColumn(db, 'finance_savings_goals', 'status', "TEXT NOT NULL DEFAULT 'active'");
    await _ensureColumn(db, 'finance_savings_goals', 'sort_order', 'INTEGER NOT NULL DEFAULT 0');
    final savingsColumns = await _tableColumns(db, 'finance_savings_goals');
    if (savingsColumns.contains('target_amount')) {
      await db.execute('UPDATE finance_savings_goals SET target_amount_minor=CASE WHEN target_amount_minor=0 THEN target_amount * 100 ELSE target_amount_minor END');
    }
    if (savingsColumns.contains('current_amount')) {
      await db.execute('UPDATE finance_savings_goals SET saved_amount_minor=CASE WHEN saved_amount_minor=0 THEN current_amount * 100 ELSE saved_amount_minor END');
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_finance_transactions_date ON finance_transactions(transaction_date DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_finance_transactions_account ON finance_transactions(account_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_finance_budgets_period ON finance_budgets(year,month,category_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_finance_debt_payments_debt ON finance_debt_payments(debt_id,paid_at DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_meal_plan_entries (
        id TEXT PRIMARY KEY, recipe_id TEXT NOT NULL, plan_date TEXT NOT NULL,
        meal_type TEXT NOT NULL DEFAULT 'Ужин', servings INTEGER NOT NULL DEFAULT 2,
        cooking_days INTEGER NOT NULL DEFAULT 1, duration_minutes INTEGER,
        status TEXT NOT NULL DEFAULT 'Запланировано', notes TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        FOREIGN KEY(recipe_id) REFERENCES recipe_entries(id) ON DELETE CASCADE
      )
    ''');
    final oldMealPlan = await _tableColumns(db, 'meal_plan_entries');
    if (oldMealPlan.isNotEmpty) {
      final dateColumn = oldMealPlan.contains('plan_date') ? 'plan_date' : 'date';
      await db.execute('''
        INSERT OR IGNORE INTO recipe_meal_plan_entries
        (id,recipe_id,plan_date,meal_type,servings,notes,created_at,updated_at)
        SELECT id,recipe_id,$dateColumn,COALESCE(meal_type,'Ужин'),
          COALESCE(servings,2),COALESCE(note,''),created_at,updated_at
        FROM meal_plan_entries WHERE recipe_id IS NOT NULL
      ''');
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_recipe_meal_plan_date ON recipe_meal_plan_entries(plan_date,sort_order)');
    await _ensureColumn(db, 'recipe_entries', 'cuisine', 'TEXT');
    await _ensureColumn(db, 'recipe_entries', 'difficulty', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(db, 'recipe_entries', 'is_cook_ahead', 'INTEGER NOT NULL DEFAULT 0');
    // Recipe ingredients were originally stored as amount/note; current
    // RecipeIngredient writes quantity/notes. Keep legacy columns and copy.
    await _ensureColumn(db, 'recipe_ingredients', 'quantity', 'REAL');
    await _ensureColumn(db, 'recipe_ingredients', 'notes', "TEXT NOT NULL DEFAULT ''");
    // Current RecipeIngredient.toMap also writes timestamps, absent in v14.
    await _ensureColumn(db, 'recipe_ingredients', 'created_at', "TEXT NOT NULL DEFAULT ''");
    await _ensureColumn(db, 'recipe_ingredients', 'updated_at', "TEXT NOT NULL DEFAULT ''");
    final ingredientColumns = await _tableColumns(db, 'recipe_ingredients');
    if (ingredientColumns.contains('amount')) {
      await db.execute('UPDATE recipe_ingredients SET quantity=COALESCE(quantity,amount)');
    }
    if (ingredientColumns.contains('note')) {
      await db.execute("UPDATE recipe_ingredients SET notes=CASE WHEN notes='' THEN COALESCE(note,'') ELSE notes END");
    }
  }

}
