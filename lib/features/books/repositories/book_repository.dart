import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/book_entry.dart';

typedef BookDatabaseProvider = Future<Database> Function();

class BookRepository {
  BookRepository._({BookDatabaseProvider? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => LunoraDatabase.instance.database);

  static final BookRepository instance = BookRepository._();

  final BookDatabaseProvider _databaseProvider;

  static const Uuid _uuid = Uuid();

  Future<Database> get _database => _databaseProvider();

  // Получить все книги.
  Future<List<BookEntry>> getAll() async {
    final db = await _database;

    final result = await db.query('book_entries', orderBy: 'updated_at DESC');

    return result.map(BookEntry.fromMap).toList();
  }

  // Получить книгу по ID.
  Future<BookEntry?> getById(String id) async {
    final db = await _database;

    final result = await db.query(
      'book_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return BookEntry.fromMap(result.first);
  }

  // Получить книги по статусу.
  Future<List<BookEntry>> getByStatus(String status) async {
    final db = await _database;

    final result = await db.query(
      'book_entries',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'updated_at DESC',
    );

    return result.map(BookEntry.fromMap).toList();
  }

  // Получить избранные книги.
  Future<List<BookEntry>> getFavorites() async {
    final db = await _database;

    final result = await db.query(
      'book_entries',
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );

    return result.map(BookEntry.fromMap).toList();
  }

  // Получить книги по жанру.
  Future<List<BookEntry>> getByGenre(String genre) async {
    final db = await _database;

    final result = await db.query(
      'book_entries',
      where: 'genre = ?',
      whereArgs: [genre],
      orderBy: 'updated_at DESC',
    );

    return result.map(BookEntry.fromMap).toList();
  }

  // Получить книги по серии.
  Future<List<BookEntry>> getBySeries(String seriesName) async {
    final db = await _database;

    final result = await db.query(
      'book_entries',
      where: 'series_name = ?',
      whereArgs: [seriesName],
      orderBy: 'series_number ASC',
    );

    return result.map(BookEntry.fromMap).toList();
  }

  // Поиск книг.
  Future<List<BookEntry>> search(String query) async {
    final db = await _database;

    final searchQuery = '%${query.trim()}%';

    final result = await db.query(
      'book_entries',
      where: '''
        title LIKE ?
        OR authors LIKE ?
        OR description LIKE ?
        OR genre LIKE ?
        OR tags LIKE ?
        OR series_name LIKE ?
        OR book_format LIKE ?
        OR source_name LIKE ?
      ''',
      whereArgs: [
        searchQuery,
        searchQuery,
        searchQuery,
        searchQuery,
        searchQuery,
        searchQuery,
        searchQuery,
        searchQuery,
      ],
      orderBy: 'updated_at DESC',
    );

    return result.map(BookEntry.fromMap).toList();
  }

  // Создать книгу.
  Future<String> create(BookEntry entry) async {
    final db = await _database;

    final now = DateTime.now();
    final id = entry.id.isEmpty ? _uuid.v4() : entry.id;

    final newEntry = BookEntry(
      id: id,
      title: entry.title,
      authors: entry.authors,
      description: entry.description,
      coverPath: entry.coverPath,
      genre: entry.genre,
      tags: entry.tags,
      status: entry.status,
      rating: entry.rating,
      review: entry.review,
      startedAt: entry.startedAt,
      finishedAt: entry.finishedAt,
      pageCount: entry.pageCount,
      currentPage: entry.currentPage,
      isFavorite: entry.isFavorite,
      createdAt: now,
      updatedAt: now,
      seriesName: entry.seriesName,
      seriesNumber: entry.seriesNumber,
      bookFormat: entry.bookFormat,
      sourceName: entry.sourceName,
    );

    await db.insert(
      'book_entries',
      newEntry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return id;
  }

  // Обновить книгу.
  Future<void> update(BookEntry entry) async {
    final db = await _database;

    final updatedEntry = entry.copyWith(updatedAt: DateTime.now());

    await db.update(
      'book_entries',
      updatedEntry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  // Переключить избранное.
  Future<void> toggleFavorite(String id) async {
    final db = await _database;

    final result = await db.query(
      'book_entries',
      columns: ['is_favorite'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return;
    }

    final currentValue = result.first['is_favorite'] as int? ?? 0;
    final newValue = currentValue == 1 ? 0 : 1;

    await db.update(
      'book_entries',
      {'is_favorite': newValue, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Обновить прогресс чтения.
  Future<void> updateProgress(String id, int currentPage) async {
    final db = await _database;

    await db.update(
      'book_entries',
      {
        'current_page': currentPage,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Изменить статус книги.
  Future<void> updateStatus(String id, String status) async {
    final db = await _database;

    final now = DateTime.now().toIso8601String();

    final values = <String, Object?>{'status': status, 'updated_at': now};

    if (status == 'reading') {
      values['started_at'] = now;
      values['finished_at'] = null;
    } else if (status == 'completed') {
      values['finished_at'] = now;
    }

    await db.update('book_entries', values, where: 'id = ?', whereArgs: [id]);
  }

  // Удалить книгу.
  Future<void> delete(String id) async {
    final db = await _database;

    await db.delete('book_entries', where: 'id = ?', whereArgs: [id]);
  }

  // Получить общее количество книг.
  Future<int> count() async {
    final db = await _database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM book_entries',
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  // Получить количество книг по статусу.
  Future<int> countByStatus(String status) async {
    final db = await _database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM book_entries WHERE status = ?',
      [status],
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }
}
