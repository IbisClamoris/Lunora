import 'dart:convert';

class MovieEntry {
  final String id;
  final String title;
  final String originalTitle;
  final String mediaType;
  final String description;
  final String? posterPath;
  final String? backdropPath;
  final List<String> genres;
  final List<String> tags;
  final String status;
  final double? rating;
  final String review;
  final int? releaseYear;
  final int? runtimeMinutes;
  final int? seasonsCount;
  final int? episodesCount;
  final int currentSeason;
  final int currentEpisode;
  final DateTime? watchedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MovieEntry({
    required this.id,
    required this.title,
    this.originalTitle = '',
    this.mediaType = 'movie',
    this.description = '',
    this.posterPath,
    this.backdropPath,
    this.genres = const [],
    this.tags = const [],
    this.status = 'planned',
    this.rating,
    this.review = '',
    this.releaseYear,
    this.runtimeMinutes,
    this.seasonsCount,
    this.episodesCount,
    this.currentSeason = 0,
    this.currentEpisode = 0,
    this.watchedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isMovie => mediaType == 'movie';

  bool get isSeries => mediaType == 'series';

  bool get isWatching => status == 'watching';

  bool get isCompleted => status == 'completed';

  bool get isPlanned => status == 'planned';

  bool get isOnHold => status == 'on_hold';

  bool get isDropped => status == 'dropped';

  double get progress {
    if (!isSeries ||
        seasonsCount == null ||
        seasonsCount! <= 0 ||
        episodesCount == null ||
        episodesCount! <= 0) {
      return 0;
    }

    final totalEpisodes = episodesCount! * seasonsCount!;
    final watchedEpisodes =
        ((currentSeason - 1) * episodesCount! + currentEpisode).clamp(
          0,
          totalEpisodes,
        );

    return watchedEpisodes / totalEpisodes;
  }

  int get progressPercent => (progress * 100).round();

  factory MovieEntry.fromMap(Map<String, dynamic> map) {
    return MovieEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      originalTitle: map['original_title'] as String? ?? '',
      mediaType: map['media_type'] as String? ?? 'movie',
      description: map['description'] as String? ?? '',
      posterPath: map['poster_path'] as String?,
      backdropPath: map['backdrop_path'] as String?,
      genres: _decodeList(map['genres']),
      tags: _decodeList(map['tags']),
      status: map['status'] as String? ?? 'planned',
      rating: (map['rating'] as num?)?.toDouble(),
      review: map['review'] as String? ?? '',
      releaseYear: (map['release_year'] as num?)?.toInt(),
      runtimeMinutes: (map['runtime_minutes'] as num?)?.toInt(),
      seasonsCount: (map['seasons_count'] as num?)?.toInt(),
      episodesCount: (map['episodes_count'] as num?)?.toInt(),
      currentSeason: (map['current_season'] as num?)?.toInt() ?? 0,
      currentEpisode: (map['current_episode'] as num?)?.toInt() ?? 0,
      watchedAt: _parseDate(map['watched_at']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'original_title': originalTitle,
      'media_type': mediaType,
      'description': description,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'genres': _encodeList(genres),
      'tags': _encodeList(tags),
      'status': status,
      'rating': rating,
      'review': review,
      'release_year': releaseYear,
      'runtime_minutes': runtimeMinutes,
      'seasons_count': seasonsCount,
      'episodes_count': episodesCount,
      'current_season': currentSeason,
      'current_episode': currentEpisode,
      'watched_at': watchedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MovieEntry copyWith({
    String? title,
    String? originalTitle,
    String? mediaType,
    String? description,
    String? posterPath,
    bool clearPosterPath = false,
    String? backdropPath,
    bool clearBackdropPath = false,
    List<String>? genres,
    List<String>? tags,
    String? status,
    double? rating,
    bool clearRating = false,
    String? review,
    int? releaseYear,
    bool clearReleaseYear = false,
    int? runtimeMinutes,
    bool clearRuntimeMinutes = false,
    int? seasonsCount,
    bool clearSeasonsCount = false,
    int? episodesCount,
    bool clearEpisodesCount = false,
    int? currentSeason,
    int? currentEpisode,
    DateTime? watchedAt,
    bool clearWatchedAt = false,
    DateTime? updatedAt,
  }) {
    return MovieEntry(
      id: id,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      mediaType: mediaType ?? this.mediaType,
      description: description ?? this.description,
      posterPath: clearPosterPath ? null : posterPath ?? this.posterPath,
      backdropPath: clearBackdropPath
          ? null
          : backdropPath ?? this.backdropPath,
      genres: genres ?? this.genres,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      rating: clearRating ? null : rating ?? this.rating,
      review: review ?? this.review,
      releaseYear: clearReleaseYear ? null : releaseYear ?? this.releaseYear,
      runtimeMinutes: clearRuntimeMinutes
          ? null
          : runtimeMinutes ?? this.runtimeMinutes,
      seasonsCount: clearSeasonsCount
          ? null
          : seasonsCount ?? this.seasonsCount,
      episodesCount: clearEpisodesCount
          ? null
          : episodesCount ?? this.episodesCount,
      currentSeason: currentSeason ?? this.currentSeason,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      watchedAt: clearWatchedAt ? null : watchedAt ?? this.watchedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  static List<String> _decodeList(dynamic value) {
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

  static String _encodeList(List<String> values) {
    return jsonEncode(values);
  }
}
