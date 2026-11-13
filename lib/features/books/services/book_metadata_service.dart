import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/storage_service.dart';

class BookMetadata {
  const BookMetadata({
    required this.title,
    required this.author,
    required this.description,
    required this.genre,
    required this.pageCount,
    required this.coverPath,
    required this.sourceName,
    this.seriesName = '',
    this.seriesNumber,
  });

  final String title;
  final String author;
  final String description;
  final String genre;
  final int? pageCount;
  final String? coverPath;
  final String sourceName;
  final String seriesName;
  final double? seriesNumber;
}

/// Получает библиографические данные из открытых каталогов.
/// Сначала проверяется Google Books, затем Open Library.
class BookMetadataService {
  BookMetadataService._();

  static final BookMetadataService instance = BookMetadataService._();

  static const Duration _requestTimeout = Duration(seconds: 12);

  Future<BookMetadata?> lookup({
    required String title,
    required String author,
  }) async {
    final cleanTitle = title.trim();
    final cleanAuthor = author.trim();
    if (cleanTitle.isEmpty) return null;

    final client = HttpClient()
      ..connectionTimeout = _requestTimeout
      ..idleTimeout = _requestTimeout;

    try {
      final google = await _lookupGoogleBooks(
        client,
        title: cleanTitle,
        author: cleanAuthor,
      );
      if (google != null && _hasUsefulData(google)) return google;

      final openLibrary = await _lookupOpenLibrary(
        client,
        title: cleanTitle,
        author: cleanAuthor,
      );
      if (openLibrary != null && _hasUsefulData(openLibrary)) {
        return openLibrary;
      }

      return google ?? openLibrary;
    } catch (error, stackTrace) {
      debugPrint('Book metadata lookup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    } finally {
      client.close(force: true);
    }
  }

  bool _hasUsefulData(BookMetadata data) {
    return data.coverPath != null ||
        data.description.isNotEmpty ||
        data.genre.isNotEmpty ||
        data.pageCount != null;
  }

  Future<BookMetadata?> _lookupGoogleBooks(
    HttpClient client, {
    required String title,
    required String author,
  }) async {
    final queries = <String>[
      if (author.isNotEmpty) 'intitle:"$title" inauthor:"$author"',
      '"$title" ${author.isNotEmpty ? author : ''}'.trim(),
      title,
    ];

    Map<String, dynamic>? best;
    var bestScore = 0;

    for (final query in queries) {
      final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', {
        'q': query,
        'maxResults': '10',
        'printType': 'books',
        'langRestrict': 'ru',
      });

      final response = await _getJson(client, uri);
      final items = response?['items'];
      if (items is! List) continue;

      for (final raw in items) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final volume = item['volumeInfo'];
        if (volume is! Map) continue;
        final info = Map<String, dynamic>.from(volume);
        final score = _scoreCandidate(
          candidateTitle: (info['title'] ?? '').toString(),
          candidateAuthors: info['authors'] is List
              ? (info['authors'] as List).join(' ')
              : '',
          title: title,
          author: author,
        );
        if (score > bestScore) {
          bestScore = score;
          best = info;
        }
      }

      // An exact title + author match is strong enough; no need to query more.
      if (bestScore >= 18) break;
    }

    if (best == null || bestScore < 8) return null;

    final authors = best['authors'];
    final authorName = authors is List && authors.isNotEmpty
        ? authors.join(', ')
        : author;

    final imageLinks = best['imageLinks'];
    String? imageUrl;
    if (imageLinks is Map) {
      imageUrl =
          (imageLinks['thumbnail'] ??
                  imageLinks['smallThumbnail'] ??
                  imageLinks['small'] ??
                  imageLinks['medium'])
              ?.toString();
    }

    final coverPath = imageUrl == null || imageUrl.isEmpty
        ? null
        : await _downloadCover(
            client,
            _secureImageUri(imageUrl),
            'google_books',
          );

    final seriesInfo = best['seriesInfo'];
    var seriesName = '';
    double? seriesNumber;
    if (seriesInfo is Map) {
      seriesName = _clean(
        (seriesInfo['series'] ??
                seriesInfo['seriesName'] ??
                seriesInfo['title'] ??
                '')
            .toString(),
      );
      seriesNumber = double.tryParse(
        (seriesInfo['bookDisplayNumber'] ?? seriesInfo['volumeNumber'] ?? '')
            .toString()
            .replaceAll(',', '.'),
      );
    }

    final categories = best['categories'];
    final genre = categories is List
        ? categories
              .map((value) => _clean(value.toString()))
              .where((value) => value.isNotEmpty)
              .take(5)
              .join(', ')
        : '';

    return BookMetadata(
      title: _clean((best['title'] ?? title).toString()),
      author: author.isNotEmpty ? author : _clean(authorName),
      description: _clean((best['description'] ?? '').toString()),
      genre: genre,
      pageCount: (best['pageCount'] as num?)?.toInt(),
      coverPath: coverPath,
      sourceName: 'Google Books',
      seriesName: seriesName,
      seriesNumber: seriesNumber,
    );
  }

  Future<BookMetadata?> _lookupOpenLibrary(
    HttpClient client, {
    required String title,
    required String author,
  }) async {
    final titleAliases = _titleAliases(title);
    final authorAliases = _authorAliases(author);
    final queries = <String>{
      for (final t in titleAliases)
        for (final a in authorAliases)
          if (a.isNotEmpty) '$t $a',
      ...titleAliases,
    };

    Map<String, dynamic>? best;
    var bestScore = 0;

    for (final query in queries) {
      final uri = Uri.https('openlibrary.org', '/search.json', {
        'q': query,
        'limit': '10',
        'fields': 'key,title,author_name,cover_i,first_publish_year,edition_key,subject,number_of_pages_median,series',
      });

      final response = await _getJson(client, uri);
      final docs = response?['docs'];
      if (docs is! List) continue;

      for (final raw in docs) {
        if (raw is! Map) continue;
        final doc = Map<String, dynamic>.from(raw);
        final authors = doc['author_name'] is List
            ? (doc['author_name'] as List).join(' ')
            : '';
        final score = _scoreCandidate(
          candidateTitle: (doc['title'] ?? '').toString(),
          candidateAuthors: authors,
          title: title,
          author: author,
        );
        if (score > bestScore) {
          bestScore = score;
          best = doc;
        }
      }
      if (bestScore >= 18) break;
    }

    if (best == null || bestScore < 8) return null;

    final resultTitle = _clean((best['title'] ?? title).toString());
    final authors = best['author_name'];
    final resultAuthor = authors is List && authors.isNotEmpty
        ? authors.join(', ')
        : author;

    final workKey = (best['key'] ?? '').toString();
    final work = workKey.startsWith('/works/')
        ? await _getJson(client, Uri.https('openlibrary.org', '$workKey.json'))
        : null;

    var description = '';
    final rawDescription = work?['description'];
    if (rawDescription is String) {
      description = _clean(rawDescription);
    } else if (rawDescription is Map) {
      description = _clean((rawDescription['value'] ?? '').toString());
    }

    final rawSeries = best['series'];
    final seriesName = rawSeries is List
        ? rawSeries
              .map((value) => _clean(value.toString()))
              .where((value) => value.isNotEmpty)
              .join(', ')
        : rawSeries is String
        ? _clean(rawSeries)
        : '';

    final subjects = best['subject'];
    final genre = subjects is List
        ? subjects
              .take(5)
              .map((value) => _clean(value.toString()))
              .where((value) => value.isNotEmpty)
              .join(', ')
        : '';

    int? pageCount = (best['number_of_pages_median'] as num?)?.toInt();
    final editions = best['edition_key'];
    if (editions is List) {
      for (final editionId in editions.take(3)) {
        final edition = await _getJson(
          client,
          Uri.https('openlibrary.org', '/books/${editionId.toString()}.json'),
        );
        pageCount ??= (edition?['number_of_pages'] as num?)?.toInt();
        if (pageCount != null) break;
      }
    }

    String? coverPath;
    final coverId = best['cover_i'];
    if (coverId is num) {
      coverPath = await _downloadCover(
        client,
        Uri.https('covers.openlibrary.org', '/b/id/${coverId.toInt()}-L.jpg'),
        'open_library',
      );
    }

    return BookMetadata(
      title: resultTitle,
      author: author.isNotEmpty ? author : _clean(resultAuthor),
      description: description,
      genre: genre,
      pageCount: pageCount,
      coverPath: coverPath,
      sourceName: 'Open Library',
      seriesName: seriesName,
    );
  }

  int _scoreCandidate({
    required String candidateTitle,
    required String candidateAuthors,
    required String title,
    required String author,
  }) {
    final candidate = _normalize(candidateTitle);
    final wantedTitle = _normalize(title);
    final candidateAuthor = _normalize(candidateAuthors);
    final wantedAuthors = _authorAliases(author).map(_normalize).toSet();

    if (candidate.isEmpty || wantedTitle.isEmpty) return 0;

    var score = 0;
    if (candidate == wantedTitle) {
      score += 14;
    } else if (candidate.contains(wantedTitle) ||
        wantedTitle.contains(candidate)) {
      score += 7;
    } else {
      final wantedWords = wantedTitle.split(' ').where((e) => e.length > 2);
      final matched = wantedWords.where(candidate.split(' ').contains).length;
      if (wantedWords.isNotEmpty) {
        score += (matched / wantedWords.length * 8).round();
      }
    }

    if (wantedAuthors.isNotEmpty && candidateAuthor.isNotEmpty) {
      if (wantedAuthors.any(
        (value) =>
            value.isNotEmpty &&
            (candidateAuthor.contains(value) ||
                value.contains(candidateAuthor)),
      )) {
        score += 10;
      } else if (_authorNameOverlap(candidateAuthor, wantedAuthors)) {
        score += 5;
      }
    }
    return score;
  }

  bool _authorNameOverlap(String candidate, Set<String> aliases) {
    final candidateWords = candidate
        .split(' ')
        .where((word) => word.length > 2)
        .toSet();
    for (final alias in aliases) {
      final aliasWords = alias
          .split(' ')
          .where((word) => word.length > 2)
          .toSet();
      if (aliasWords.isNotEmpty &&
          aliasWords.intersection(candidateWords).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  List<String> _titleAliases(String title) {
    final normalized = _normalize(title);
    final aliases = <String>[title];

    // Известные варианты названия на английском помогают найти запись,
    // если каталог содержит оригинальное, а не русское издание.
    const known = <String, String>{'тень и кость': 'Shadow and Bone'};
    final translated = known[normalized];
    if (translated != null) aliases.add(translated);
    return aliases;
  }

  List<String> _authorAliases(String author) {
    if (author.trim().isEmpty) return const [];
    final aliases = <String>[author];
    final normalized = _normalize(author);
    const known = <String, String>{'ли бардуго': 'Leigh Bardugo'};
    final translated = known[normalized];
    if (translated != null) aliases.add(translated);
    return aliases;
  }

  Uri _secureImageUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      throw const FormatException('Некорректный адрес обложки.');
    }
    return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
  }

  Future<Map<String, dynamic>?> _getJson(HttpClient client, Uri uri) async {
    try {
      final request = await client.getUrl(uri).timeout(_requestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Lunora Desktop/1.0 (public book metadata lookup)',
      );
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(_requestTimeout);
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (error) {
      debugPrint('Book catalogue request failed ($uri): $error');
      return null;
    }
  }

  Future<String?> _downloadCover(
    HttpClient client,
    Uri uri,
    String prefix,
  ) async {
    try {
      final request = await client.getUrl(uri).timeout(_requestTimeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'Lunora Desktop/1.0');
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode != HttpStatus.ok) return null;
      final bytes = await response
          .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk))
          .timeout(_requestTimeout);
      if (bytes.length < 500) return null;

      final directory = await StorageService.instance.coversDirectory;
      final file = File(
        p.join(
          directory.path,
          '${prefix}_${DateTime.now().microsecondsSinceEpoch}.jpg',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (error) {
      debugPrint('Book cover download failed ($uri): $error');
      return null;
    }
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _clean(String value) => value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'[\u00a0\u200b]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
