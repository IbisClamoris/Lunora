import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/movie_entry.dart';

typedef MovieDatabaseProvider = Future<Database> Function();

class MovieRepository {
  MovieRepository._({MovieDatabaseProvider? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => LunoraDatabase.instance.database);

  static final MovieRepository instance = MovieRepository._();

  final MovieDatabaseProvider _databaseProvider;

  static const Uuid _uuid = Uuid();

  static const String _table = 'movie_entries';

  Future<Database> get _database => _databaseProvider();

  Future<List<MovieEntry>> getAll() async {
    final db = await _database;

    final result = await db.query(_table, orderBy: 'updated_at DESC');

    return result.map(MovieEntry.fromMap).toList();
  }

  Future<MovieEntry?> getById(String id) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return MovieEntry.fromMap(result.first);
  }

  Future<List<MovieEntry>> getByType(String mediaType) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'media_type = ?',
      whereArgs: [mediaType],
      orderBy: 'updated_at DESC',
    );

    return result.map(MovieEntry.fromMap).toList();
  }

  Future<List<MovieEntry>> getByStatus(String status) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'updated_at DESC',
    );

    return result.map(MovieEntry.fromMap).toList();
  }

  Future<List<MovieEntry>> getFavorites() async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'rating IS NOT NULL',
      orderBy: 'rating DESC, updated_at DESC',
    );

    return result.map(MovieEntry.fromMap).toList();
  }

  Future<List<MovieEntry>> getByGenre(String genre) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'genres LIKE ?',
      whereArgs: ['%${_escapeLike(genre)}%'],
      orderBy: 'title COLLATE NOCASE ASC',
    );

    return result.map(MovieEntry.fromMap).toList();
  }

  Future<List<MovieEntry>> search(String query) async {
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return getAll();
    }

    final db = await _database;
    final pattern = '%${_escapeLike(normalizedQuery)}%';

    final result = await db.query(
      _table,
      where: '''
        title LIKE ? ESCAPE '\\'
        OR original_title LIKE ? ESCAPE '\\'
        OR description LIKE ? ESCAPE '\\'
        OR review LIKE ? ESCAPE '\\'
        OR genres LIKE ? ESCAPE '\\'
        OR tags LIKE ? ESCAPE '\\'
      ''',
      whereArgs: [pattern, pattern, pattern, pattern, pattern, pattern],
      orderBy: 'title COLLATE NOCASE ASC',
    );

    return result.map(MovieEntry.fromMap).toList();
  }

  Future<String> create(MovieEntry movie) async {
    final db = await _database;

    final id = movie.id.trim().isEmpty ? _uuid.v4() : movie.id;

    final entry = MovieEntry(
      id: id,
      title: movie.title,
      originalTitle: movie.originalTitle,
      mediaType: movie.mediaType,
      description: movie.description,
      posterPath: movie.posterPath,
      backdropPath: movie.backdropPath,
      genres: movie.genres,
      tags: movie.tags,
      status: movie.status,
      rating: movie.rating,
      review: movie.review,
      releaseYear: movie.releaseYear,
      runtimeMinutes: movie.runtimeMinutes,
      seasonsCount: movie.seasonsCount,
      episodesCount: movie.episodesCount,
      currentSeason: movie.currentSeason,
      currentEpisode: movie.currentEpisode,
      watchedAt: movie.watchedAt,
      createdAt: movie.createdAt,
      updatedAt: DateTime.now(),
    );

    await db.insert(
      _table,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return id;
  }

  Future<void> update(MovieEntry movie) async {
    final db = await _database;

    await db.update(
      _table,
      movie.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [movie.id],
    );
  }

  Future<void> updateStatus(String id, String status) async {
    final db = await _database;
    final now = DateTime.now().toIso8601String();
    final values = <String, Object?>{'status': status, 'updated_at': now};
    if (status == 'completed') {
      values['watched_at'] = now;
    }
    await db.update(_table, values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    final db = await _database;

    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final db = await _database;

    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM $_table');

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<int> countByType(String mediaType) async {
    final db = await _database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $_table WHERE media_type = ?',
      [mediaType],
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<int> countByStatus(String status) async {
    final db = await _database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $_table WHERE status = ?',
      [status],
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  String _escapeLike(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }
}
