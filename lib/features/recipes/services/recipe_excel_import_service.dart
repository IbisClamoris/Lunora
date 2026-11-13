import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/import_export/models/spreadsheet_document.dart';
import '../models/recipe_entry.dart';
import '../models/recipe_ingredient.dart';

class RecipeExcelImportResult {
  final int recipesAdded;
  final int recipesUpdated;
  final int ingredientsImported;
  final int favoritesImported;
  final int mealPlanImported;

  const RecipeExcelImportResult({
    required this.recipesAdded,
    required this.recipesUpdated,
    required this.ingredientsImported,
    required this.favoritesImported,
    required this.mealPlanImported,
  });

  int get totalRecipes => recipesAdded + recipesUpdated;

  String get message {
    return 'Добавлено рецептов: $recipesAdded\n'
        'Обновлено рецептов: $recipesUpdated\n'
        'Импортировано ингредиентов: $ingredientsImported\n'
        'Избранное: $favoritesImported\n'
        'Записей плана питания: $mealPlanImported';
  }
}

class RecipeExcelImportService {
  RecipeExcelImportService._();

  static final RecipeExcelImportService instance = RecipeExcelImportService._();

  static const Uuid _uuid = Uuid();

  Future<RecipeExcelImportResult> importWorkbook(
    SpreadsheetDocument document,
  ) async {
    final recipeSheet = _findSheet(document, 'рецепты');

    if (recipeSheet == null) {
      throw Exception('В книге не найден лист «Рецепты».');
    }

    final recipeRows = recipeSheet.rows;

    if (recipeRows.length < 2) {
      throw Exception('На листе «Рецепты» нет записей.');
    }

    final recipeHeaders = _buildHeaders(recipeRows.first);
    final now = DateTime.now();

    var recipesAdded = 0;
    var recipesUpdated = 0;
    var ingredientsImported = 0;
    var favoritesImported = 0;
    var mealPlanImported = 0;

    final db = await LunoraDatabase.instance.database;

    await db.transaction((txn) async {
      final externalToInternal = <String, String>{};
      final titleToInternal = <String, String>{};

      final favoriteIds = _readFavorites(document);

      for (var index = 1; index < recipeRows.length; index++) {
        final row = recipeRows[index];

        final title = _string(
          _value(row, recipeHeaders, ['Название', 'Наименование']),
        );

        if (title.isEmpty) continue;

        final externalId = _string(
          _value(row, recipeHeaders, ['ID', 'ID рецепта']),
        );

        final stableId =
            'excel_recipe_${_safeId(externalId.isEmpty ? title : externalId)}';

        final oldRows = await txn.query(
          'recipe_entries',
          where: 'id = ?',
          whereArgs: [stableId],
          limit: 1,
        );

        DateTime oldCreatedAt = now;

        if (oldRows.isNotEmpty) {
          final value = oldRows.first['created_at'];

          if (value is String) {
            oldCreatedAt = DateTime.tryParse(value) ?? now;
          }
        }

        final favoriteCell = _value(row, recipeHeaders, [
          'Избранное',
          'В избранном',
        ]);

        final isFavorite =
            _toBool(favoriteCell) ||
            favoriteIds.contains(_normalize(externalId)) ||
            favoriteIds.contains(_normalize(title));

        final minutes = _toInt(
          _value(row, recipeHeaders, ['Время, мин', 'Время']),
        );

        final recipe = RecipeEntry(
          id: stableId,
          title: title,
          description: _string(_value(row, recipeHeaders, ['Описание'])),
          instructions: _string(
            _value(row, recipeHeaders, [
              'Приготовление',
              'Инструкция',
              'Инструкции',
            ]),
          ),
          category: _fallback(
            _string(_value(row, recipeHeaders, ['Категория'])),
            'Без категории',
          ),
          cuisine: _string(_value(row, recipeHeaders, ['Кухня мира', 'Кухня'])),
          difficulty: _string(_value(row, recipeHeaders, ['Сложность'])),
          servings:
              _toInt(
                _value(row, recipeHeaders, ['Порции', 'Количество порций']),
              ) ??
              2,
          cookTimeMinutes: minutes,
          prepTimeMinutes: null,
          rating: _toDouble(_value(row, recipeHeaders, ['Оценка', 'Рейтинг'])),
          review: '',
          sourceUrl: _extractUrl(
            _value(row, recipeHeaders, [
              'Ссылка',
              'URL',
              'Источник URL',
              'Ссылка на источник',
            ]),
          ),
          isFavorite: isFavorite,
          isCookAhead: _toBool(
            _value(row, recipeHeaders, [
              'На несколько дней',
              'Готовить заранее',
            ]),
          ),
          sortOrder: index,
          createdAt: oldCreatedAt,
          updatedAt: now,
        );

        if (oldRows.isEmpty) {
          await txn.insert('recipe_entries', recipe.toMap());

          recipesAdded++;
        } else {
          await txn.update(
            'recipe_entries',
            recipe.toMap(),
            where: 'id = ?',
            whereArgs: [stableId],
          );

          recipesUpdated++;
        }

        if (externalId.isNotEmpty) {
          externalToInternal[_normalize(externalId)] = stableId;
        }

        titleToInternal[_normalize(title)] = stableId;

        if (isFavorite) {
          favoritesImported++;
        }

        // Обновляем ингредиенты только импортируемого рецепта.
        await txn.delete(
          'recipe_ingredients',
          where: 'recipe_id = ?',
          whereArgs: [stableId],
        );

        final rawIngredients = _string(
          _value(row, recipeHeaders, ['Основные ингредиенты', 'Ингредиенты']),
        );

        final ingredients = _parseIngredients(rawIngredients, stableId, now);

        for (final ingredient in ingredients) {
          await txn.insert('recipe_ingredients', ingredient.toMap());
        }

        ingredientsImported += ingredients.length;
      }

      // Импорт плана питания.
      final mealSheet = _findSheet(document, 'план питания');

      if (mealSheet != null && mealSheet.rows.length > 1) {
        final rows = mealSheet.rows;
        final headers = _buildHeaders(rows.first);

        // Удаляем только записи, созданные этим импортёром.
        // Пользовательские записи остаются нетронутыми.
        await txn.delete(
          'recipe_meal_plan_entries',
          where: "id GLOB 'excel_plan_*'",
        );

        for (var index = 1; index < rows.length; index++) {
          final row = rows[index];

          final externalRecipeId = _string(
            _value(row, headers, ['ID рецепта', 'ID']),
          );

          final recipeTitle = _string(
            _value(row, headers, ['Название блюда', 'Название']),
          );

          final recipeId =
              externalToInternal[_normalize(externalRecipeId)] ??
              titleToInternal[_normalize(recipeTitle)];

          if (recipeId == null) continue;

          final date = _parseDate(_value(row, headers, ['Дата']));

          if (date == null) continue;

          final entry = {
            'id': 'excel_plan_$index',
            'recipe_id': recipeId,
            'plan_date': _dateKey(date),
            'meal_type': _fallback(
              _string(_value(row, headers, ['Приём пищи', 'Тип приёма пищи'])),
              'Ужин',
            ),
            'servings': _toInt(_value(row, headers, ['Порции'])) ?? 2,
            'cooking_days':
                _toInt(
                  _value(row, headers, ['Готовим на дней', 'Дней готовки']),
                ) ??
                1,
            'duration_minutes': _toInt(
              _value(row, headers, ['Время, мин', 'Время']),
            ),
            'status': _fallback(
              _string(_value(row, headers, ['Статус'])),
              'Запланировано',
            ),
            'notes': _string(_value(row, headers, ['Примечание', 'Заметки'])),
            'sort_order': index,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          };

          await txn.insert('recipe_meal_plan_entries', entry);

          mealPlanImported++;
        }
      }
    });

    return RecipeExcelImportResult(
      recipesAdded: recipesAdded,
      recipesUpdated: recipesUpdated,
      ingredientsImported: ingredientsImported,
      favoritesImported: favoritesImported,
      mealPlanImported: mealPlanImported,
    );
  }

  dynamic _findSheet(SpreadsheetDocument document, String keyword) {
    for (final sheet in document.sheets) {
      if (_normalize(sheet.name).contains(_normalize(keyword))) {
        return sheet;
      }
    }

    return null;
  }

  Map<String, int> _buildHeaders(List<Object?> row) {
    final result = <String, int>{};

    for (var index = 0; index < row.length; index++) {
      final name = _normalize(_string(row[index]));

      if (name.isNotEmpty) {
        result[name] = index;
      }
    }

    return result;
  }

  Object? _value(
    List<Object?> row,
    Map<String, int> headers,
    List<String> names,
  ) {
    for (final name in names) {
      final index = headers[_normalize(name)];

      if (index != null && index < row.length) {
        return row[index];
      }
    }

    return null;
  }

  String _string(Object? value) {
    if (value == null) return '';

    return value.toString().trim();
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _fallback(String value, String fallback) {
    return value.isEmpty ? fallback : value;
  }

  String _safeId(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');

    return normalized.isEmpty ? _uuid.v4() : normalized;
  }

  String? _extractUrl(Object? value) {
    final text = _string(value);

    if (text.isEmpty) return null;

    final match = RegExp(
      r'https?://\S+',
      caseSensitive: false,
    ).firstMatch(text);

    return match?.group(0);
  }

  bool _toBool(Object? value) {
    if (value == null) return false;

    if (value is bool) return value;

    if (value is num) return value != 0;

    final text = _normalize(value.toString());

    return ['да', 'true', '1', 'yes', 'избранное', 'готовить'].contains(text);
  }

  int? _toInt(Object? value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is num) return value.toInt();

    final text = value.toString().trim().replaceAll(',', '.');

    return int.tryParse(text) ?? double.tryParse(text)?.toInt();
  }

  double? _toDouble(Object? value) {
    if (value == null) return null;

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString().trim().replaceAll(',', '.'));
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;

    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }

    if (value is num) {
      return DateTime(1899, 12, 30).add(Duration(days: value.floor()));
    }

    final text = value.toString().trim();

    final iso = DateTime.tryParse(text);

    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }

    final match = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$')
        .firstMatch(text);

    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);

      final date = DateTime(year, month, day);

      if (date.year == year && date.month == month && date.day == day) {
        return date;
      }
    }

    return null;
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Set<String> _readFavorites(SpreadsheetDocument document) {
    final result = <String>{};

    final sheet = _findSheet(document, 'избранное');

    if (sheet == null || sheet.rows.length < 2) {
      return result;
    }

    final headers = _buildHeaders(sheet.rows.first);

    for (var index = 1; index < sheet.rows.length; index++) {
      final row = sheet.rows[index];

      final id = _string(_value(row, headers, ['ID', 'ID рецепта']));

      final title = _string(
        _value(row, headers, ['Название', 'Название рецепта']),
      );

      if (id.isNotEmpty) {
        result.add(_normalize(id));
      }

      if (title.isNotEmpty) {
        result.add(_normalize(title));
      }
    }

    return result;
  }

  List<RecipeIngredient> _parseIngredients(
    String raw,
    String recipeId,
    DateTime now,
  ) {
    if (raw.trim().isEmpty) return [];

    final parts = raw
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    final result = <RecipeIngredient>[];

    for (var index = 0; index < parts.length; index++) {
      final part = parts[index];

      var name = part;
      double? quantity;
      var unit = '';

      final separated = RegExp(r'^(.+?)\s*[—–:-]\s*(\d+(?:[.,]\d+)?)\s*(.*)$')
          .firstMatch(part);

      final trailing = RegExp(r'^(.+?)\s+(\d+(?:[.,]\d+)?)\s*([^\d].*)?$')
          .firstMatch(part);

      final match = separated ?? trailing;

      if (match != null) {
        final parsedName = match.group(1)?.trim() ?? '';

        final parsedQuantity = double.tryParse(
          (match.group(2) ?? '').replaceAll(',', '.'),
        );

        if (parsedName.isNotEmpty && parsedQuantity != null) {
          name = parsedName;
          quantity = parsedQuantity;
          unit = match.group(3)?.trim() ?? '';
        }
      }

      result.add(
        RecipeIngredient(
          id: _uuid.v4(),
          recipeId: recipeId,
          name: name,
          quantity: quantity,
          unit: unit,
          sortOrder: index,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return result;
  }
}
