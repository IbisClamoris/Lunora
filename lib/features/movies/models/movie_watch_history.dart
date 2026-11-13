class MovieWatchHistory {
  final String id;
  final String movieId;
  final DateTime watchedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? durationMinutes;
  final double? rating;
  final String mood;
  final String impressions;
  final String favoriteQuote;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MovieWatchHistory({
    required this.id,
    required this.movieId,
    required this.watchedAt,
    this.startedAt,
    this.finishedAt,
    this.durationMinutes,
    this.rating,
    this.mood = '',
    this.impressions = '',
    this.favoriteQuote = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory MovieWatchHistory.fromMap(Map<String, dynamic> map) {
    return MovieWatchHistory(
      id: map['id'] as String,
      movieId: map['movie_id'] as String,
      watchedAt: DateTime.parse(map['watched_at'] as String),
      startedAt: _parseDate(map['started_at']),
      finishedAt: _parseDate(map['finished_at']),
      durationMinutes: (map['duration_minutes'] as num?)?.toInt(),
      rating: (map['rating'] as num?)?.toDouble(),
      mood: map['mood'] as String? ?? '',
      impressions: map['impressions'] as String? ?? '',
      favoriteQuote: map['favorite_quote'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'movie_id': movieId,
      'watched_at': watchedAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'duration_minutes': durationMinutes,
      'rating': rating,
      'mood': mood,
      'impressions': impressions,
      'favorite_quote': favoriteQuote,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MovieWatchHistory copyWith({
    String? movieId,
    DateTime? watchedAt,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    int? durationMinutes,
    bool clearDuration = false,
    double? rating,
    bool clearRating = false,
    String? mood,
    String? impressions,
    String? favoriteQuote,
    String? notes,
    DateTime? updatedAt,
  }) {
    return MovieWatchHistory(
      id: id,
      movieId: movieId ?? this.movieId,
      watchedAt: watchedAt ?? this.watchedAt,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      finishedAt: clearFinishedAt ? null : finishedAt ?? this.finishedAt,
      durationMinutes: clearDuration
          ? null
          : durationMinutes ?? this.durationMinutes,
      rating: clearRating ? null : rating ?? this.rating,
      mood: mood ?? this.mood,
      impressions: impressions ?? this.impressions,
      favoriteQuote: favoriteQuote ?? this.favoriteQuote,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
