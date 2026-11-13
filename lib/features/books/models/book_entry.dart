import 'dart:convert';

class BookEntry {
  final String id;
  final String title;
  final String authors;
  final String description;
  final String? coverPath;
  final String genre;
  final List<String> tags;
  final String status;
  final double? rating;
  final String review;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? pageCount;
  final int currentPage;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String seriesName;
  final double? seriesNumber;
  final String bookFormat;
  final String sourceName;

  const BookEntry({
    required this.id,
    required this.title,
    this.authors = '',
    this.description = '',
    this.coverPath,
    this.genre = '',
    this.tags = const [],
    this.status = 'planned',
    this.rating,
    this.review = '',
    this.startedAt,
    this.finishedAt,
    this.pageCount,
    this.currentPage = 0,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.seriesName = '',
    this.seriesNumber,
    this.bookFormat = '',
    this.sourceName = '',
  });

  bool get isReading => status == 'reading';

  bool get isCompleted => status == 'completed';

  bool get isPlanned => status == 'planned';

  double get progress {
    if (pageCount == null || pageCount! <= 0) {
      return 0;
    }

    return (currentPage / pageCount!).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).round();

  factory BookEntry.fromMap(Map<String, dynamic> map) {
    return BookEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      authors: map['authors'] as String? ?? '',
      description: map['description'] as String? ?? '',
      coverPath: map['cover_path'] as String?,
      genre: map['genre'] as String? ?? '',
      tags: _decodeTags(map['tags']),
      status: map['status'] as String? ?? 'planned',
      rating: (map['rating'] as num?)?.toDouble(),
      review: map['review'] as String? ?? '',
      startedAt: _parseDate(map['started_at']),
      finishedAt: _parseDate(map['finished_at']),
      pageCount: (map['page_count'] as num?)?.toInt(),
      currentPage: (map['current_page'] as num?)?.toInt() ?? 0,
      isFavorite: (map['is_favorite'] as num?)?.toInt() == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      seriesName: map['series_name'] as String? ?? '',
      seriesNumber: (map['series_number'] as num?)?.toDouble(),
      bookFormat: map['book_format'] as String? ?? '',
      sourceName: map['source_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'authors': authors,
      'description': description,
      'cover_path': coverPath,
      'genre': genre,
      'tags': _encodeTags(tags),
      'status': status,
      'rating': rating,
      'review': review,
      'started_at': startedAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'page_count': pageCount,
      'current_page': currentPage,
      'is_favorite': isFavorite ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'series_name': seriesName,
      'series_number': seriesNumber,
      'book_format': bookFormat,
      'source_name': sourceName,
    };
  }

  BookEntry copyWith({
    String? title,
    String? authors,
    String? description,
    String? coverPath,
    bool clearCoverPath = false,
    String? genre,
    List<String>? tags,
    String? status,
    double? rating,
    bool clearRating = false,
    String? review,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    int? pageCount,
    bool clearPageCount = false,
    int? currentPage,
    bool? isFavorite,
    DateTime? updatedAt,
    String? seriesName,
    double? seriesNumber,
    bool clearSeriesNumber = false,
    String? bookFormat,
    String? sourceName,
  }) {
    return BookEntry(
      id: id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      description: description ?? this.description,
      coverPath: clearCoverPath ? null : coverPath ?? this.coverPath,
      genre: genre ?? this.genre,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      rating: clearRating ? null : rating ?? this.rating,
      review: review ?? this.review,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      finishedAt: clearFinishedAt ? null : finishedAt ?? this.finishedAt,
      pageCount: clearPageCount ? null : pageCount ?? this.pageCount,
      currentPage: currentPage ?? this.currentPage,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      seriesName: seriesName ?? this.seriesName,
      seriesNumber: clearSeriesNumber
          ? null
          : seriesNumber ?? this.seriesNumber,
      bookFormat: bookFormat ?? this.bookFormat,
      sourceName: sourceName ?? this.sourceName,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  static List<String> _decodeTags(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(value.toString());

      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {
      return [];
    }

    return [];
  }

  static String _encodeTags(List<String> tags) {
    return jsonEncode(tags);
  }
}
