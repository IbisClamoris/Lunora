import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/movie_watch_history.dart';

typedef MovieWatchHistoryDatabaseProvider = Future<Database> Function();

class MovieWatchHistoryRepository {
  MovieWatchHistoryRepository._({
    MovieWatchHistoryDatabaseProvider? databaseProvider,
  }) : _databaseProvider =
           databaseProvider ?? (() => LunoraDatabase.instance.database);

  static final MovieWatchHistoryRepository instance =
      MovieWatchHistoryRepository._();

  final MovieWatchHistoryDatabaseProvider _databaseProvider;

  static const Uuid _uuid = Uuid();
  static const String _table = 'movie_watch_history';

  Future<Database> get _database => _databaseProvider();

  Future<List<MovieWatchHistory>> getAll() async {
    final db = await _database;

    final result = await db.query(_table, orderBy: 'watched_at DESC');

    return result.map(MovieWatchHistory.fromMap).toList();
  }

  Future<MovieWatchHistory?> getById(String id) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return MovieWatchHistory.fromMap(result.first);
  }

  Future<List<MovieWatchHistory>> getByMovie(String movieId) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'movie_id = ?',
      whereArgs: [movieId],
      orderBy: 'watched_at DESC',
    );

    return result.map(MovieWatchHistory.fromMap).toList();
  }

  Future<List<MovieWatchHistory>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'watched_at >= ? AND watched_at <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'watched_at DESC',
    );

    return result.map(MovieWatchHistory.fromMap).toList();
  }

  Future<String> create(MovieWatchHistory history) async {
    final db = await _database;

    final id = history.id.trim().isEmpty ? _uuid.v4() : history.id;

    final entry = MovieWatchHistory(
      id: id,
      movieId: history.movieId,
      watchedAt: history.watchedAt,
      startedAt: history.startedAt,
      finishedAt: history.finishedAt,
      durationMinutes: history.durationMinutes,
      rating: history.rating,
      mood: history.mood,
      impressions: history.impressions,
      favoriteQuote: history.favoriteQuote,
      notes: history.notes,
      createdAt: history.createdAt,
      updatedAt: DateTime.now(),
    );

    await db.insert(
      _table,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return id;
  }

  Future<void> update(MovieWatchHistory history) async {
    final db = await _database;

    await db.update(
      _table,
      history.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [history.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _database;

    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByMovie(String movieId) async {
    final db = await _database;

    await db.delete(_table, where: 'movie_id = ?', whereArgs: [movieId]);
  }

  Future<int> count() async {
    final db = await _database;

    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM $_table');

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<int> countByMovie(String movieId) async {
    final db = await _database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $_table WHERE movie_id = ?',
      [movieId],
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }
}
