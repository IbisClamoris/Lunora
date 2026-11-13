import 'package:flutter/foundation.dart';

import '../database/database.dart';
import '../navigation/lunora_navigation.dart';
import 'global_search_result.dart';

class GlobalSearchService {
  GlobalSearchService._();

  static final GlobalSearchService instance = GlobalSearchService._();

  static const Map<String, LunoraSection> _sectionMap = {
    'tasks': LunoraSection.calendar,
    'notifications': LunoraSection.notifications,
    'shopping_lists': LunoraSection.shoppingList,
    'shopping_items': LunoraSection.shoppingList,
    'planner_goals': LunoraSection.planner,
    'study_subjects': LunoraSection.studyPlanner,
    'study_topics': LunoraSection.studyPlanner,
    'study_tasks': LunoraSection.studyPlanner,
    'study_notes': LunoraSection.studyPlanner,
    'finance_savings_goals': LunoraSection.finances,
    'knowledge_entries': LunoraSection.knowledgeBase,
    'diary_entries': LunoraSection.diary,
    'book_entries': LunoraSection.books,
    'movie_entries': LunoraSection.movies,
    'movie_episodes': LunoraSection.movies,
    'movie_watch_history': LunoraSection.movies,
    'movie_genres': LunoraSection.movies,
    'recipe_entries': LunoraSection.recipes,
    'recipe_ingredients': LunoraSection.recipes,
    'recipe_steps': LunoraSection.recipes,
    'meal_plan_entries': LunoraSection.recipes,
    'wishlist_items': LunoraSection.wishlist,
  };

  static const Set<String> _ignoredTables = {
    'settings',
    'favorites',
    'import_history',
    'export_history',
    'sqlite_sequence',
  };

  static const Set<String> _ignoredColumns = {
    'id',
    'created_at',
    'updated_at',
    'completed_at',
    'started_at',
    'finished_at',
    'watched_at',
    'scheduled_at',
    'due_date',
    'entry_date',
    'target_date',
    'air_date',
    'release_date',
    'finish_date',
    'cover_path',
    'poster_path',
    'backdrop_path',
    'image_path',
    'source_url',
    'url',
  };

  Future<List<GlobalSearchResult>> search(
    String query, {
    int limit = 100,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];

    final db = await LunoraDatabase.instance.database;
    final tables = await db.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
      ORDER BY name
    ''');

    final results = <GlobalSearchResult>[];

    for (final tableRow in tables) {
      final tableName = tableRow['name'] as String;
      if (_ignoredTables.contains(tableName) ||
          tableName.startsWith('sqlite_') ||
          tableName.endsWith('_new')) {
        continue;
      }

      final columns = await db.rawQuery('PRAGMA table_info("$tableName")');
      final searchableColumns = columns
          .where((column) {
            final name = column['name'] as String;
            final type = (column['type'] as String? ?? '').toUpperCase();
            return type.contains('TEXT') && !_ignoredColumns.contains(name);
          })
          .map((column) => column['name'] as String)
          .toList();

      if (searchableColumns.isEmpty) continue;

      final section = _sectionForTable(tableName);
      if (section == null && tableName != 'notes') continue;

      final conditions = searchableColumns
          .map(
            (column) =>
                "instr(lower(COALESCE(CAST(\"$column\" AS TEXT), '')), lower(?)) > 0",
          )
          .join(' OR ');

      try {
        final rows = await db.rawQuery(
          'SELECT * FROM "$tableName" WHERE ($conditions) LIMIT ?',
          [
            ...List<Object?>.filled(searchableColumns.length, normalizedQuery),
            limit,
          ],
        );

        for (final row in rows) {
          final id = row['id']?.toString();
          if (id == null || id.isEmpty) continue;

          final resolvedSection = tableName == 'notes'
              ? _sectionForNote(row['source_module']?.toString())
              : section;
          if (resolvedSection == null) continue;

          final title = _findTitle(row, tableName);
          if (title.isEmpty) continue;

          results.add(
            GlobalSearchResult(
              id: id,
              title: title,
              subtitle: _findSubtitle(row, title),
              tableName: tableName,
              section: resolvedSection,
            ),
          );

          if (results.length >= limit) return results;
        }
      } catch (error, stackTrace) {
        // Ошибка отдельной таблицы не прерывает поиск по остальным.
        debugPrint('Global search: table "$tableName" failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return results;
  }

  LunoraSection? _sectionForTable(String tableName) {
    final direct = _sectionMap[tableName];
    if (direct != null) return direct;

    if (tableName.startsWith('finance_')) return LunoraSection.finances;
    if (tableName.startsWith('study_')) return LunoraSection.studyPlanner;
    if (tableName.startsWith('planner_')) return LunoraSection.planner;
    if (tableName.startsWith('knowledge_')) return LunoraSection.knowledgeBase;
    if (tableName.startsWith('recipe_') || tableName.startsWith('meal_plan_')) {
      return LunoraSection.recipes;
    }
    if (tableName.startsWith('shopping_')) return LunoraSection.shoppingList;
    if (tableName.startsWith('movie_')) return LunoraSection.movies;

    return null;
  }

  LunoraSection? _sectionForNote(String? sourceModule) {
    switch (sourceModule) {
      case 'planner':
        return LunoraSection.planner;
      case 'study':
      case 'study_planner':
        return LunoraSection.studyPlanner;
      case 'recipe':
      case 'recipes':
        return LunoraSection.recipes;
      case 'knowledge':
        return LunoraSection.knowledgeBase;
      default:
        return null;
    }
  }

  String _findTitle(Map<String, Object?> row, String tableName) {
    const candidates = ['title', 'name', 'subject', 'question', 'content'];
    for (final key in candidates) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value.length > 120 ? '${value.substring(0, 117)}...' : value;
      }
    }
    return tableName;
  }

  String _findSubtitle(Map<String, Object?> row, String title) {
    const candidates = [
      'description',
      'content',
      'note',
      'review',
      'category',
      'tags',
    ];
    for (final key in candidates) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != title) {
        return value.length > 160 ? '${value.substring(0, 157)}...' : value;
      }
    }
    return '';
  }
}
