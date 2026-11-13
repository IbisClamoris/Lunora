import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/movie_episode.dart';

typedef MovieEpisodeDatabaseProvider = Future<Database> Function();

class MovieEpisodeRepository {
  MovieEpisodeRepository._({MovieEpisodeDatabaseProvider? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => LunoraDatabase.instance.database);

  static final MovieEpisodeRepository instance = MovieEpisodeRepository._();

  final MovieEpisodeDatabaseProvider _databaseProvider;

  static const Uuid _uuid = Uuid();

  static const String _table = 'movie_episodes';

  Future<Database> get _database => _databaseProvider();

  Future<List<MovieEpisode>> getAll() async {
    final db = await _database;

    final result = await db.query(
      _table,
      orderBy: 'season_number ASC, episode_number ASC',
    );

    return result.map(MovieEpisode.fromMap).toList();
  }

  Future<MovieEpisode?> getById(String id) async {
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

    return MovieEpisode.fromMap(result.first);
  }

  Future<List<MovieEpisode>> getByMovie(String movieId) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'movie_id = ?',
      whereArgs: [movieId],
      orderBy: 'season_number ASC, episode_number ASC',
    );

    return result.map(MovieEpisode.fromMap).toList();
  }

  Future<List<MovieEpisode>> getBySeason(
    String movieId,
    int seasonNumber,
  ) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'movie_id = ? AND season_number = ?',
      whereArgs: [movieId, seasonNumber],
      orderBy: 'episode_number ASC',
    );

    return result.map(MovieEpisode.fromMap).toList();
  }

  Future<List<MovieEpisode>> getWatched(String movieId) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'movie_id = ? AND status = ?',
      whereArgs: [movieId, 'watched'],
      orderBy: 'season_number ASC, episode_number ASC',
    );

    return result.map(MovieEpisode.fromMap).toList();
  }

  Future<List<MovieEpisode>> getPlanned(String movieId) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'movie_id = ? AND status = ?',
      whereArgs: [movieId, 'planned'],
      orderBy: 'season_number ASC, episode_number ASC',
    );

    return result.map(MovieEpisode.fromMap).toList();
  }

  Future<String> create(MovieEpisode episode) async {
    final db = await _database;

    final id = episode.id.trim().isEmpty ? _uuid.v4() : episode.id;

    final entry = MovieEpisode(
      id: id,
      movieId: episode.movieId,
      seasonNumber: episode.seasonNumber,
      episodeNumber: episode.episodeNumber,
      title: episode.title,
      airDate: episode.airDate,
      status: episode.status,
      watchedAt: episode.watchedAt,
      rating: episode.rating,
      notes: episode.notes,
      createdAt: episode.createdAt,
      updatedAt: DateTime.now(),
    );

    await db.insert(
      _table,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return id;
  }

  Future<void> update(MovieEpisode episode) async {
    final db = await _database;

    await db.update(
      _table,
      episode.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [episode.id],
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

  Future<int> countByMovie(String movieId) async {
    final db = await _database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $_table WHERE movie_id = ?',
      [movieId],
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<int> countWatched(String movieId) async {
    final db = await _database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $_table '
      'WHERE movie_id = ? AND status = ?',
      [movieId, 'watched'],
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<int> countBySeason(String movieId, int seasonNumber) async {
    final db = await _database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $_table '
      'WHERE movie_id = ? AND season_number = ?',
      [movieId, seasonNumber],
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }
}
