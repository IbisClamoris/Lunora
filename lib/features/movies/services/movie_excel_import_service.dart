import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/import_export/models/spreadsheet_document.dart';

class MovieExcelImportResult {
  final int movies;
  final int episodes;
  final int watchHistory;
  final int genres;

  final int existingMovies;
  final int existingEpisodes;
  final int existingHistory;
  final int existingGenres;

  final int skippedRows;

  const MovieExcelImportResult({
    required this.movies,
    required this.episodes,
    required this.watchHistory,
    required this.genres,
    required this.existingMovies,
    required this.existingEpisodes,
    required this.existingHistory,
    required this.existingGenres,
    required this.skippedRows,
  });

  int get totalImported => movies + episodes + watchHistory + genres;

  int get totalExisting =>
      existingMovies + existingEpisodes + existingHistory + existingGenres;
}

class MovieExcelImportService {
  MovieExcelImportService._();

  static final MovieExcelImportService instance = MovieExcelImportService._();

  static const Uuid _uuid = Uuid();

  Future<MovieExcelImportResult> importWorkbook(
    SpreadsheetDocument document,
  ) async {
    final sheets = <String, SpreadsheetSheetData>{
      for (final sheet in document.sheets) _normalize(sheet.name): sheet,
    };

    SpreadsheetSheetData? findSheet(List<String> names) {
      for (final name in names) {
        final sheet = sheets[_normalize(name)];
        if (sheet != null) return sheet;
      }
      return null;
    }

    // Поддерживаем старые названия с эмодзи и реальные названия листов книги.
    final collectionSheet = findSheet([
      '🎬 Коллекция',
      'Коллекция',
      'Коллекции',
    ]);
    final episodesSheet = findSheet([
      '📺 Сезоны и серии',
      'Сезоны и серии',
      'Серии',
    ]);
    final historySheet = findSheet([
      '📝 Дневник просмотра',
      'Дневник просмотра',
      'Дневник',
    ]);
    final genresSheet = findSheet(['🏷️ Жанры', 'Жанры']);

    if (collectionSheet == null ||
        episodesSheet == null ||
        historySheet == null ||
        genresSheet == null) {
      throw const FormatException(
        'В Excel-файле не найдены необходимые листы коллекции, '
        'серий, дневника просмотра и жанров.',
      );
    }

    final movieRows = _readRows(collectionSheet);
    final episodeRows = _readRows(episodesSheet);
    final historyRows = _readRows(historySheet);
    final genreRows = _readRows(genresSheet);

    final db = await LunoraDatabase.instance.database;

    var importedMovies = 0;
    var importedEpisodes = 0;
    var importedHistory = 0;
    var importedGenres = 0;

    var existingMovies = 0;
    var existingEpisodes = 0;
    var existingHistory = 0;
    var existingGenres = 0;

    var skippedRows = 0;

    final movieIds = <String, String>{};

    await db.transaction((txn) async {
      // ПРОИЗВЕДЕНИЯ

      for (final row in movieRows) {
        final title = _string(row, ['Название']);

        if (title.isEmpty) {
          skippedRows++;
          continue;
        }

        final year = _integer(row, ['Год']);

        final hasEpisodes = episodeRows.any(
          (episode) =>
              _normalize(_string(episode, ['Название'])) == _normalize(title),
        );

        final mediaType = _mediaType(
          _string(row, ['Тип']),
          hasEpisodes: hasEpisodes,
        );

        final existing = await txn.query(
          'movie_entries',
          columns: ['id'],
          where: '''
            LOWER(TRIM(title)) = ?
            AND COALESCE(release_year, 0) = ?
            AND media_type = ?
          ''',
          whereArgs: [_normalize(title), year ?? 0, mediaType],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          movieIds[_normalize(title)] = existing.first['id'] as String;
          existingMovies++;
          continue;
        }

        final now = DateTime.now().toIso8601String();
        final id = _uuid.v4();

        final completionDate = _date(_value(row, ['Дата завершения']));

        final genres = _splitList(_string(row, ['Жанры']));

        final progress = _parseProgress(_string(row, ['Прогресс']));

        final seriesRows = episodeRows.where(
          (episode) =>
              _normalize(_string(episode, ['Название'])) == _normalize(title),
        );

        final seasonNumbers = seriesRows
            .map((episode) => _integer(episode, ['Сезон']) ?? 1)
            .toSet();

        final episodeNumbers = seriesRows
            .map((episode) => _integer(episode, ['Номер серии']) ?? 0)
            .where((number) => number > 0)
            .toList();

        final seasonsCount = seasonNumbers.isEmpty
            ? null
            : seasonNumbers.reduce((a, b) => a > b ? a : b);

        final episodesCount = episodeNumbers.isEmpty
            ? null
            : episodeNumbers.reduce((a, b) => a > b ? a : b);

        await txn.insert('movie_entries', {
          'id': id,
          'title': title,
          'original_title': '',
          'media_type': mediaType,

          // В исходной книге описание находится в столбце «Заметки».
          'description': _cleanText(
            _string(row, ['Описание', 'Синопсис', 'Заметки']),
          ),

          'poster_path': null,
          'backdrop_path': null,
          'genres': jsonEncode(genres),
          'tags': jsonEncode(<String>[]),
          'status': _status(_string(row, ['Статус'])),
          'rating': _number(row, ['Оценка']),
          'review': '',
          'release_year': year,
          'runtime_minutes': null,
          'seasons_count': seasonsCount,
          'episodes_count': episodesCount,
          'current_season': progress.$1,
          'current_episode': progress.$2,
          'watched_at': completionDate,
          'is_favorite': _boolean(_value(row, ['Избранное'])) ? 1 : 0,
          'sort_order': importedMovies,
          'created_at': now,
          'updated_at': now,
        });

        movieIds[_normalize(title)] = id;
        importedMovies++;
      }

      // ЖАНРЫ

      for (final row in genreRows) {
        final name = _string(row, ['Жанр']);

        if (name.isEmpty) {
          skippedRows++;
          continue;
        }

        final existing = await txn.query(
          'movie_genres',
          columns: ['id'],
          where: 'LOWER(TRIM(name)) = ?',
          whereArgs: [_normalize(name)],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          existingGenres++;
          continue;
        }

        final now = DateTime.now().toIso8601String();

        await txn.insert('movie_genres', {
          'id': _uuid.v4(),
          'name': name,
          'is_favorite': _boolean(_value(row, ['Любимый'])) ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        });

        importedGenres++;
      }

      // СЕРИИ

      for (final row in episodeRows) {
        final title = _string(row, ['Название']);
        final movieId = movieIds[_normalize(title)];

        if (movieId == null || title.isEmpty) {
          skippedRows++;
          continue;
        }

        final seasonNumber = _integer(row, ['Сезон']) ?? 1;
        final episodeNumber = _integer(row, ['Номер серии']) ?? 1;

        final existing = await txn.query(
          'movie_episodes',
          columns: ['id'],
          where: '''
            movie_id = ?
            AND season_number = ?
            AND episode_number = ?
          ''',
          whereArgs: [movieId, seasonNumber, episodeNumber],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          existingEpisodes++;
          continue;
        }

        final now = DateTime.now().toIso8601String();

        await txn.insert('movie_episodes', {
          'id': _uuid.v4(),
          'movie_id': movieId,
          'season_number': seasonNumber,
          'episode_number': episodeNumber,
          'title': _string(row, ['Название серии']),
          'air_date': _date(_value(row, ['Дата выхода'])),
          'status': _episodeStatus(_string(row, ['Статус'])),
          'watched_at': _date(_value(row, ['Дата просмотра'])),
          'rating': _number(row, ['Оценка']),
          'notes': _cleanText(_string(row, ['Заметки'])),
          'created_at': now,
          'updated_at': now,
        });

        importedEpisodes++;
      }

      // ДНЕВНИК ПРОСМОТРА

      for (final row in historyRows) {
        final title = _string(row, ['Название']);
        final movieId = movieIds[_normalize(title)];

        final watchedAt = _date(_value(row, ['Дата просмотра']));

        if (movieId == null || watchedAt == null) {
          skippedRows++;
          continue;
        }

        final startedAt = _combineDateAndTime(
          watchedAt,
          _value(row, ['Время начала']),
        );

        final finishedAt = _combineDateAndTime(
          watchedAt,
          _value(row, ['Время окончания']),
        );

        final existing = await txn.query(
          'movie_watch_history',
          columns: ['id'],
          where: '''
            movie_id = ?
            AND watched_at = ?
            AND started_at IS ?
          ''',
          whereArgs: [movieId, watchedAt, startedAt],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          existingHistory++;
          continue;
        }

        final now = DateTime.now().toIso8601String();

        final viewingType = _string(row, ['Тип просмотра']);

        await txn.insert('movie_watch_history', {
          'id': _uuid.v4(),
          'movie_id': movieId,
          'watched_at': watchedAt,
          'started_at': startedAt,
          'finished_at': finishedAt,
          'duration_minutes': _integer(row, ['Длительность (мин)']),
          'rating': _number(row, ['Оценка']),
          'mood': _string(row, ['Настроение']),
          'impressions': _cleanText(_string(row, ['Впечатления'])),
          'favorite_quote': _cleanText(_string(row, ['Цитаты и заметки'])),
          'notes': viewingType.isEmpty ? '' : 'Тип просмотра: $viewingType',
          'created_at': now,
          'updated_at': now,
        });

        importedHistory++;
      }

      // ОБНОВЛЕНИЕ ПРОГРЕССА СЕРИАЛОВ

      for (final movieId in movieIds.values.toSet()) {
        final counts = await txn.rawQuery(
          '''
          SELECT
            COUNT(*) AS total,
            SUM(
              CASE WHEN status = 'watched'
              THEN 1 ELSE 0 END
            ) AS watched
          FROM movie_episodes
          WHERE movie_id = ?
          ''',
          [movieId],
        );

        final total = _toInt(counts.first['total']) ?? 0;

        final watchingRows = await txn.rawQuery(
          '''
          SELECT season_number, episode_number
          FROM movie_episodes
          WHERE movie_id = ?
            AND status = 'watching'
          ORDER BY season_number DESC, episode_number DESC
          LIMIT 1
          ''',
          [movieId],
        );

        final watchedRows = await txn.rawQuery(
          '''
          SELECT season_number, episode_number
          FROM movie_episodes
          WHERE movie_id = ?
            AND status = 'watched'
          ORDER BY season_number DESC, episode_number DESC
          LIMIT 1
          ''',
          [movieId],
        );

        final progressRow = watchingRows.isNotEmpty
            ? watchingRows.first
            : watchedRows.isNotEmpty
            ? watchedRows.first
            : null;

        final currentSeason = progressRow == null
            ? 0
            : _toInt(progressRow['season_number']) ?? 0;

        final currentEpisode = progressRow == null
            ? 0
            : _toInt(progressRow['episode_number']) ?? 0;

        final seasonCount = await txn.rawQuery(
          '''
          SELECT COUNT(DISTINCT season_number) AS total
          FROM movie_episodes
          WHERE movie_id = ?
          ''',
          [movieId],
        );

        await txn.update(
          'movie_entries',
          {
            'episodes_count': total > 0 ? total : null,
            'seasons_count': _toInt(seasonCount.first['total']) ?? 0,
            'current_season': currentSeason,
            'current_episode': currentEpisode,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [movieId],
        );
      }
    });

    return MovieExcelImportResult(
      movies: importedMovies,
      episodes: importedEpisodes,
      watchHistory: importedHistory,
      genres: importedGenres,
      existingMovies: existingMovies,
      existingEpisodes: existingEpisodes,
      existingHistory: existingHistory,
      existingGenres: existingGenres,
      skippedRows: skippedRows,
    );
  }

  // ЧТЕНИЕ СТРОК

  static List<Map<String, Object?>> _readRows(SpreadsheetSheetData sheet) {
    if (sheet.rows.isEmpty) return [];

    final headers = sheet.rows.first
        .map((value) => _normalize(value?.toString() ?? ''))
        .toList();

    final result = <Map<String, Object?>>[];

    for (final row in sheet.rows.skip(1)) {
      final values = <String, Object?>{};

      for (var i = 0; i < headers.length; i++) {
        if (headers[i].isEmpty) continue;
        values[headers[i]] = i < row.length ? row[i] : null;
      }

      if (values.values.every(
        (value) => value == null || value.toString().trim().isEmpty,
      )) {
        continue;
      }

      result.add(values);
    }

    return result;
  }

  static Object? _value(Map<String, Object?> row, List<String> names) {
    for (final name in names) {
      final key = _normalize(name);
      if (row.containsKey(key)) return row[key];
    }

    return null;
  }

  static String _string(Map<String, Object?> row, List<String> names) {
    return _value(row, names)?.toString().trim() ?? '';
  }

  // ПРЕОБРАЗОВАНИЕ ЗНАЧЕНИЙ

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _mediaType(String value, {required bool hasEpisodes}) {
    final type = _normalize(value);

    if (type.contains('сериал') || type.contains('аниме') && hasEpisodes) {
      return 'series';
    }

    return 'movie';
  }

  static String _status(String value) {
    return switch (_normalize(value)) {
      'смотрю' => 'watching',
      'просмотрено' => 'completed',
      'на паузе' => 'on_hold',
      'брошено' => 'dropped',
      _ => 'planned',
    };
  }

  static String _episodeStatus(String value) {
    return switch (_normalize(value)) {
      'просмотрено' => 'watched',
      'смотрю' => 'watching',
      _ => 'planned',
    };
  }

  static List<String> _splitList(String value) {
    if (value.trim().isEmpty) return [];

    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static bool _boolean(Object? value) {
    final text = _normalize(value?.toString() ?? '');

    return text == 'да' || text == 'true' || text == '1' || text == 'yes';
  }

  static int? _integer(Map<String, Object?> row, List<String> names) {
    final value = _value(row, names);
    if (value == null) return null;

    if (value is num) return value.round();

    return int.tryParse(value.toString().replaceAll(',', '.'));
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  static double? _number(Map<String, Object?> row, List<String> names) {
    final value = _value(row, names);
    if (value == null) return null;

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  static (int, int) _parseProgress(String value) {
    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(value);

    if (match == null) return (0, 0);

    return (1, int.tryParse(match.group(1)!) ?? 0);
  }

  static String? _date(Object? value) {
    if (value == null) return null;

    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day).toIso8601String();
    }

    if (value is num) {
      final date = DateTime(
        1899,
        12,
        30,
      ).add(Duration(milliseconds: (value * 86400000).round()));

      return DateTime(date.year, date.month, date.day).toIso8601String();
    }

    final parsed = DateTime.tryParse(value.toString());

    return parsed?.toIso8601String();
  }

  static String? _combineDateAndTime(String date, Object? time) {
    if (time == null) return null;

    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) return null;

    if (time is DateTime) {
      return DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        time.hour,
        time.minute,
        time.second,
      ).toIso8601String();
    }

    if (time is Duration) {
      return DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      ).add(time).toIso8601String();
    }

    if (time is num) {
      final duration = Duration(milliseconds: (time * 86400000).round());

      return DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      ).add(duration).toIso8601String();
    }

    final text = time.toString().trim();

    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(text);

    if (match == null) return null;

    return DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3) ?? '0'),
    ).toIso8601String();
  }

  static String _cleanText(String value) {
    return value.replaceAll('_x000D_', '').replaceAll('\r\n', '\n').trim();
  }
}
