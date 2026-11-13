class MovieEpisode {
  final String id;
  final String movieId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final DateTime? airDate;
  final String status;
  final DateTime? watchedAt;
  final double? rating;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MovieEpisode({
    required this.id,
    required this.movieId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.title = '',
    this.airDate,
    this.status = 'planned',
    this.watchedAt,
    this.rating,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isWatched => status == 'watched';

  bool get isPlanned => status == 'planned';

  factory MovieEpisode.fromMap(Map<String, dynamic> map) {
    return MovieEpisode(
      id: map['id'] as String,
      movieId: map['movie_id'] as String,
      seasonNumber: (map['season_number'] as num).toInt(),
      episodeNumber: (map['episode_number'] as num).toInt(),
      title: map['title'] as String? ?? '',
      airDate: _parseDate(map['air_date']),
      status: map['status'] as String? ?? 'planned',
      watchedAt: _parseDate(map['watched_at']),
      rating: (map['rating'] as num?)?.toDouble(),
      notes: map['notes'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'movie_id': movieId,
      'season_number': seasonNumber,
      'episode_number': episodeNumber,
      'title': title,
      'air_date': airDate?.toIso8601String(),
      'status': status,
      'watched_at': watchedAt?.toIso8601String(),
      'rating': rating,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MovieEpisode copyWith({
    String? movieId,
    int? seasonNumber,
    int? episodeNumber,
    String? title,
    DateTime? airDate,
    bool clearAirDate = false,
    String? status,
    DateTime? watchedAt,
    bool clearWatchedAt = false,
    double? rating,
    bool clearRating = false,
    String? notes,
    DateTime? updatedAt,
  }) {
    return MovieEpisode(
      id: id,
      movieId: movieId ?? this.movieId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      airDate: clearAirDate ? null : airDate ?? this.airDate,
      status: status ?? this.status,
      watchedAt: clearWatchedAt ? null : watchedAt ?? this.watchedAt,
      rating: clearRating ? null : rating ?? this.rating,
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
