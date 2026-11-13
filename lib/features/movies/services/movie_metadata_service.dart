import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MovieMetadata {
  const MovieMetadata({
    required this.title,
    required this.originalTitle,
    required this.description,
    required this.genres,
    required this.mediaType,
    this.releaseYear,
    this.runtimeMinutes,
    this.seasonsCount,
    this.episodesCount,
    this.posterUrl,
    this.backdropUrl,
    this.sourceUrl,
    this.sourceName = 'TVmaze',
  });

  final String title;
  final String originalTitle;
  final String description;
  final List<String> genres;
  final String mediaType;
  final int? releaseYear;
  final int? runtimeMinutes;
  final int? seasonsCount;
  final int? episodesCount;
  final String? posterUrl;
  final String? backdropUrl;
  final String? sourceUrl;
  final String sourceName;
}

class MovieMetadataService {
  MovieMetadataService._();
  static final MovieMetadataService instance = MovieMetadataService._();

  static const _timeout = Duration(seconds: 15);

  Future<List<MovieMetadata>> searchSeries(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];

    final results = <MovieMetadata>[];
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      // TVmaze covers general television series.
      try {
        final uri = Uri.https('api.tvmaze.com', '/search/shows', {'q': value});
        final data = await _getJson(client, uri);
        if (data is List) {
          results.addAll(
            data.whereType<Map>().map((item) {
              final show = item['show'];
              if (show is! Map) return null;
              return _mapShow(Map<String, dynamic>.from(show));
            }).whereType<MovieMetadata>(),
          );
        }
      } catch (_) {}

      // AniList adds anime, including Japanese and English titles.
      try {
        results.addAll(await _searchAniList(client, value));
      } catch (_) {}

      // Wikidata provides an open, key-free catalogue for feature films.
      try {
        results.addAll(await _searchWikidataFilms(client, value));
      } catch (_) {}

      final unique = <String, MovieMetadata>{};
      for (final item in results) {
        final key =
            '${item.mediaType}|${item.title.toLowerCase()}|${item.releaseYear ?? ''}';
        unique.putIfAbsent(key, () => item);
      }
      return unique.values.take(40).toList();
    } finally {
      client.close(force: true);
    }
  }

  Future<List<MovieMetadata>> _searchAniList(
    HttpClient client,
    String query,
  ) async {
    const graphQl = r'''
query ($search: String) {
  Page(perPage: 20) {
    media(search: $search, type: ANIME, sort: SEARCH_MATCH) {
      id
      title { romaji english native }
      description(asHtml: false)
      genres
      format
      episodes
      duration
      seasonYear
      coverImage { extraLarge large }
      bannerImage
      siteUrl
    }
  }
}
''';

    final uri = Uri.https('graphql.anilist.co', '/');
    final request = await client.postUrl(uri).timeout(_timeout);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'Lunora/1.0');
    request.write(
      jsonEncode({
        'query': graphQl,
        'variables': {'search': query},
      }),
    );

    final response = await request.close().timeout(_timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'AniList вернул HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final data = decoded['data'];
    final page = data is Map ? data['Page'] : null;
    final media = page is Map ? page['media'] : null;
    if (media is! List) return const [];

    return media
        .whereType<Map>()
        .map((item) {
          final titleData = item['title'];
          final titles = titleData is Map ? titleData : const {};
          final title =
              (titles['english'] ?? titles['romaji'] ?? titles['native'] ?? '')
                  .toString();
          if (title.isEmpty) return null;
          final coverData = item['coverImage'];
          final cover = coverData is Map ? coverData : const {};
          final format = (item['format'] ?? '').toString();
          final year = item['seasonYear'];
          final banner = item['bannerImage']?.toString();
          return MovieMetadata(
            title: title,
            originalTitle: (titles['native'] ?? titles['romaji'] ?? title)
                .toString(),
            description: _stripHtml((item['description'] ?? '').toString()),
            genres: item['genres'] is List
                ? (item['genres'] as List)
                      .map((genre) => genre.toString())
                      .toList()
                : const [],
            mediaType: format == 'MOVIE' ? 'movie' : 'series',
            releaseYear: year is num ? year.toInt() : int.tryParse('$year'),
            runtimeMinutes: item['duration'] is num
                ? (item['duration'] as num).toInt()
                : null,
            episodesCount: item['episodes'] is num
                ? (item['episodes'] as num).toInt()
                : null,
            posterUrl: (cover['extraLarge'] ?? cover['large'])?.toString(),
            backdropUrl: banner == null || banner.isEmpty ? null : banner,
            sourceUrl: item['siteUrl']?.toString(),
            sourceName: 'AniList',
          );
        })
        .whereType<MovieMetadata>()
        .toList();
  }

  Future<List<MovieMetadata>> searchByPerson(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final uri = Uri.https('api.tvmaze.com', '/search/people', {'q': value});
      final data = await _getJson(client, uri);
      if (data is! List) return const [];
      final results = <MovieMetadata>[];
      for (final item in data.whereType<Map>().take(5)) {
        final person = item['person'];
        if (person is! Map) continue;
        final id = person['id'];
        if (id is! num) continue;
        final creditsUri = Uri.https(
          'api.tvmaze.com',
          '/people/${id.toInt()}/castcredits',
          {'embed': 'show'},
        );
        final credits = await _getJson(client, creditsUri);
        if (credits is! List) continue;
        for (final credit in credits.whereType<Map>()) {
          final embedded = credit['_embedded'];
          final show = embedded is Map ? embedded['show'] : null;
          if (show is Map) {
            results.add(_mapShow(Map<String, dynamic>.from(show)));
          }
        }
      }
      final unique = <String, MovieMetadata>{};
      for (final item in results) {
        unique[item.sourceUrl ?? item.title] = item;
      }
      return unique.values.take(30).toList();
    } finally {
      client.close(force: true);
    }
  }

  Future<List<MovieMetadata>> _searchWikidataFilms(
    HttpClient client,
    String query,
  ) async {
    Future<List<dynamic>> search(String language) async {
      final uri = Uri.https('www.wikidata.org', '/w/api.php', {
        'action': 'wbsearchentities',
        'search': query,
        'language': language,
        'uselang': language,
        'type': 'item',
        'limit': '20',
        'format': 'json',
      });
      final data = await _getJson(client, uri);
      final searchData = data is Map ? data['search'] : null;
      return searchData is List ? searchData : const [];
    }

    var matches = await search('ru');
    if (matches.isEmpty) matches = await search('en');
    final ids = matches
        .whereType<Map>()
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => RegExp(r'^Q\d+$').hasMatch(id))
        .take(20)
        .toList();
    if (ids.isEmpty) return const [];

    final entityUri = Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbgetentities',
      'ids': ids.join('|'),
      'props': 'labels|descriptions|claims',
      'languages': 'ru|en',
      'format': 'json',
    });
    final entityData = await _getJson(client, entityUri);
    final entities = entityData is Map ? entityData['entities'] : null;
    if (entities is! Map) return const [];

    final results = <MovieMetadata>[];
    for (final raw in entities.values) {
      if (raw is! Map) continue;
      final entity = Map<String, dynamic>.from(raw);
      final claims = entity['claims'];
      if (claims is! Map) continue;
      final instanceIds = _claimEntityIds(claims['P31']);
      // Q11424 = film. Anime films and animated films are included when
      // Wikidata classifies them as films.
      if (!instanceIds.contains('Q11424')) continue;

      final labels = entity['labels'] is Map
          ? entity['labels'] as Map
          : const {};
      final descriptions = entity['descriptions'] is Map
          ? entity['descriptions'] as Map
          : const {};
      final ruLabel = labels['ru'] is Map
          ? labels['ru']['value']?.toString()
          : null;
      final enLabel = labels['en'] is Map
          ? labels['en']['value']?.toString()
          : null;
      final title = (ruLabel?.isNotEmpty == true ? ruLabel : enLabel) ?? '';
      if (title.isEmpty) continue;
      final description =
          (descriptions['ru'] is Map
              ? descriptions['ru']['value']?.toString()
              : null) ??
          (descriptions['en'] is Map
              ? descriptions['en']['value']?.toString()
              : null) ??
          '';
      final year = _claimYear(claims['P577']);
      final runtime = _claimNumber(claims['P2047']);
      final imageName = _claimString(claims['P18']);
      final poster = imageName == null
          ? null
          : 'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(imageName)}';
      final genreIds = _claimEntityIds(claims['P136']);
      final genres = await _wikidataLabels(client, genreIds.take(8).toList());
      final id = entity['id']?.toString();
      results.add(
        MovieMetadata(
          title: title,
          originalTitle: enLabel ?? title,
          description: description,
          genres: genres,
          mediaType: 'movie',
          releaseYear: year,
          runtimeMinutes: runtime?.round(),
          posterUrl: poster,
          sourceUrl: id == null ? null : 'https://www.wikidata.org/wiki/$id',
          sourceName: 'Wikidata',
        ),
      );
    }
    return results;
  }

  Future<List<String>> _wikidataLabels(
    HttpClient client,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final uri = Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbgetentities',
      'ids': ids.join('|'),
      'props': 'labels',
      'languages': 'ru|en',
      'format': 'json',
    });
    final data = await _getJson(client, uri);
    final entities = data is Map ? data['entities'] : null;
    if (entities is! Map) return const [];
    return entities.values
        .whereType<Map>()
        .map((entity) {
          final labels = entity['labels'];
          if (labels is! Map) return '';
          final ru = labels['ru'];
          final en = labels['en'];
          return (ru is Map ? ru['value'] : null)?.toString() ??
              (en is Map ? en['value'] : null)?.toString() ??
              '';
        })
        .where((label) => label.isNotEmpty)
        .toList();
  }

  List<String> _claimEntityIds(dynamic rawClaims) {
    if (rawClaims is! List) return const [];
    return rawClaims
        .map((claim) {
          if (claim is! Map) return '';
          final mainsnak = claim['mainsnak'];
          final datavalue = mainsnak is Map ? mainsnak['datavalue'] : null;
          final value = datavalue is Map ? datavalue['value'] : null;
          return value is Map ? value['id']?.toString() ?? '' : '';
        })
        .where((id) => id.isNotEmpty)
        .toList();
  }

  String? _claimString(dynamic rawClaims) {
    if (rawClaims is! List || rawClaims.isEmpty) return null;
    final claim = rawClaims.first;
    final mainsnak = claim is Map ? claim['mainsnak'] : null;
    final datavalue = mainsnak is Map ? mainsnak['datavalue'] : null;
    final value = datavalue is Map ? datavalue['value'] : null;
    return value?.toString();
  }

  double? _claimNumber(dynamic rawClaims) {
    if (rawClaims is! List || rawClaims.isEmpty) return null;
    final claim = rawClaims.first;
    final mainsnak = claim is Map ? claim['mainsnak'] : null;
    final datavalue = mainsnak is Map ? mainsnak['datavalue'] : null;
    final value = datavalue is Map ? datavalue['value'] : null;
    if (value is Map) {
      return double.tryParse(
        value['amount']?.toString().replaceFirst('+', '') ?? '',
      );
    }
    return null;
  }

  int? _claimYear(dynamic rawClaims) {
    if (rawClaims is! List || rawClaims.isEmpty) return null;
    final claim = rawClaims.first;
    final mainsnak = claim is Map ? claim['mainsnak'] : null;
    final datavalue = mainsnak is Map ? mainsnak['datavalue'] : null;
    final value = datavalue is Map ? datavalue['value'] : null;
    final time = value is Map ? value['time']?.toString() : null;
    return time != null && time.length >= 5
        ? int.tryParse(time.substring(1, 5))
        : null;
  }

  Future<dynamic> _getJson(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri).timeout(_timeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Lunora/1.0 (desktop app)',
    );
    final response = await request.close().timeout(_timeout);
    if (response.statusCode == HttpStatus.notFound) return null;
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'TVmaze вернул HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    return decoded;
  }

  MovieMetadata _mapShow(Map<String, dynamic> show) {
    final premiered = (show['premiered'] ?? '').toString();
    final image = show['image'];
    final imageMap = image is Map ? image : const {};
    final summary = _stripHtml((show['summary'] ?? '').toString());
    final name = (show['name'] ?? '').toString();
    final official = (show['url'] ?? '').toString();
    return MovieMetadata(
      title: name,
      originalTitle: name,
      description: summary,
      genres: (show['genres'] is List)
          ? (show['genres'] as List).map((e) => e.toString()).toList()
          : const [],
      mediaType: 'series',
      releaseYear: premiered.length >= 4
          ? int.tryParse(premiered.substring(0, 4))
          : null,
      runtimeMinutes: (show['averageRuntime'] ?? show['runtime']) is num
          ? ((show['averageRuntime'] ?? show['runtime']) as num).toInt()
          : null,
      posterUrl:
          imageMap['original']?.toString() ?? imageMap['medium']?.toString(),
      sourceUrl: official.isEmpty ? null : official,
    );
  }

  String _stripHtml(String value) => value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}
