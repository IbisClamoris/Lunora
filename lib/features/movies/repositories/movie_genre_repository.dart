import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/movie_genre.dart';

typedef MovieGenreDatabaseProvider = Future<Database> Function();

class MovieGenreRepository {
  MovieGenreRepository._({MovieGenreDatabaseProvider? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => LunoraDatabase.instance.database);

  static final MovieGenreRepository instance = MovieGenreRepository._();

  final MovieGenreDatabaseProvider _databaseProvider;

  static const Uuid _uuid = Uuid();
  static const String _table = 'movie_genres';

  Future<Database> get _database => _databaseProvider();

  Future<List<MovieGenre>> getAll() async {
    final db = await _database;

    final result = await db.query(_table, orderBy: 'name COLLATE NOCASE ASC');

    return result.map(MovieGenre.fromMap).toList();
  }

  Future<MovieGenre?> getById(String id) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return MovieGenre.fromMap(result.first);
  }

  Future<MovieGenre?> getByName(String name) async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name.trim()],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return MovieGenre.fromMap(result.first);
  }

  Future<List<MovieGenre>> getFavorites() async {
    final db = await _database;

    final result = await db.query(
      _table,
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return result.map(MovieGenre.fromMap).toList();
  }

  Future<String> create(MovieGenre genre) async {
    final db = await _database;

    final id = genre.id.trim().isEmpty ? _uuid.v4() : genre.id;

    final entry = MovieGenre(
      id: id,
      name: genre.name.trim(),
      isFavorite: genre.isFavorite,
      createdAt: genre.createdAt,
      updatedAt: DateTime.now(),
    );

    await db.insert(
      _table,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return id;
  }

  Future<void> update(MovieGenre genre) async {
    final db = await _database;

    await db.update(
      _table,
      genre
          .copyWith(name: genre.name.trim(), updatedAt: DateTime.now())
          .toMap(),
      where: 'id = ?',
      whereArgs: [genre.id],
    );
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
}
