import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import '../../../core/storage/storage_service.dart';

class RecipeSearchResult {
  final String title;
  final String url;
  final String? imageUrl;
  final String snippet;
  final String sourceName;

  const RecipeSearchResult({
    required this.title,
    required this.url,
    this.imageUrl,
    this.snippet = '',
    required this.sourceName,
  });
}

class ImportedRecipeIngredient {
  final String name;
  final double? quantity;
  final String unit;
  final String notes;

  const ImportedRecipeIngredient({
    required this.name,
    this.quantity,
    this.unit = '',
    this.notes = '',
  });
}

class RecipeImportData {
  final String title;
  final String description;
  final String instructions;
  final List<ImportedRecipeIngredient> ingredients;
  final int servings;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final String sourceUrl;
  final String sourceName;
  final String? coverPath;

  const RecipeImportData({
    required this.title,
    this.description = '',
    this.instructions = '',
    this.ingredients = const [],
    this.servings = 2,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    required this.sourceUrl,
    required this.sourceName,
    this.coverPath,
  });
}

class RecipeMetadataService {
  RecipeMetadataService._();
  static final instance = RecipeMetadataService._();

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36';

  Future<List<RecipeSearchResult>> search(String query) async {
    final clean = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return const [];

    // Используем WebView2, как в рабочем поиске книг Lunora.
    final results = await _searchWithWebView(clean);
    if (results.isNotEmpty) return results;

    return _searchWithWebView('рецепт $clean');
  }

  Future<List<RecipeSearchResult>> _searchWithWebView(String query) async {
    final controller = WebviewController();
    try {
      await controller.initialize();
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await controller.setDefaultContextMenusEnabled(true);

      final searchText = '"$query" рецепт пошагово';
      final uri = Uri.https('yandex.ru', '/search/', {'text': searchText});
      await controller.loadUrl(uri.toString());

      for (var attempt = 0; attempt < 20; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        try {
          final dynamic raw = await controller.executeScript('''
            (() => {
              const query = ${jsonEncode(query)};
              const normalize = value => String(value || '')
                .toLowerCase().replace(/ё/g, 'е')
                .replace(/[^\\p{L}\\p{N}]+/gu, ' ')
                .replace(/\\s+/g, ' ').trim();
              const clean = value => String(value || '')
                .replace(/[\\u00a0\\u200b]/g, ' ')
                .replace(/\\s+/g, ' ').trim();
              const tokens = normalize(query).split(' ').filter(x => x.length > 2);
              const collectionPattern = /подборк|топ\\s*\\d|лучши[ех]|сборник|меню на|что приготовить|\\d+ рецептов|рецепты на каждый/i;
              const cards = Array.from(document.querySelectorAll('li.serp-item, .serp-item, [data-cid], .Organic'));
              const seen = new Set();
              const out = [];
              for (const card of cards) {
                const heading = card.querySelector('h2, h3, [role="heading"]');
                const link = (heading && (heading.closest('a[href]') || heading.querySelector('a[href]'))) || card.querySelector('a[href]');
                if (!link) continue;
                const url = link.href || '';
                if (!/^https?:\\/\\//i.test(url)) continue;
                let parsed;
                try { parsed = new URL(url); } catch (_) { continue; }
                const host = parsed.hostname.toLowerCase().replace(/^www\\./, '');
                if (!host.includes('.') || /yandex\\.|google\\.|bing\\.|duckduckgo\\./i.test(host)) continue;
                if (seen.has(url)) continue;
                const title = clean(heading ? heading.innerText : link.innerText);
                if (title.length < 4 || title.length > 180 || collectionPattern.test(title)) continue;
                if (/\\/(collections?|selection|articles?| подборк|top)\\b/i.test(parsed.pathname)) continue;
                const text = clean(card.innerText || '');
                if (/реклама|войти|настройки|быстрый ответ/i.test(text)) continue;
                const normalizedTitle = normalize(title);
                const matched = tokens.filter(token => normalizedTitle.includes(token)).length;
                const required = tokens.length <= 1 ? 1 : Math.max(1, Math.ceil(tokens.length * 0.6));
                if (matched < required || !/рецепт|приготов|ингредиент|блюдо/i.test(title + ' ' + text)) continue;
                const image = card.querySelector('img');
                const imageUrl = image ? (image.currentSrc || image.src || null) : null;
                const snippet = text.replace(title, '').trim().slice(0, 600);
                const score = matched * 10 + (normalizedTitle.includes(normalize(query)) ? 20 : 0);
                seen.add(url);
                out.push({title, url, snippet, imageUrl, host, score});
              }
              out.sort((a, b) => b.score - a.score);
              return JSON.stringify(out.slice(0, 30));
            })()
          ''');
          final decoded = raw is String ? jsonDecode(raw) : raw;
          if (decoded is List) {
            final hits = <RecipeSearchResult>[];
            for (final item in decoded) {
              if (item is! Map) continue;
              final title = (item['title'] ?? '').toString().trim();
              final url = (item['url'] ?? '').toString().trim();
              final parsed = Uri.tryParse(url);
              if (title.isEmpty || parsed == null || !parsed.hasScheme) {
                continue;
              }
              hits.add(
                RecipeSearchResult(
                  title: _cleanText(title),
                  url: url,
                  snippet: _cleanText((item['snippet'] ?? '').toString()),
                  imageUrl: item['imageUrl']?.toString(),
                  sourceName: (item['host'] ?? parsed.host).toString(),
                ),
              );
            }
            if (hits.isNotEmpty) return hits;
          }
        } catch (error) {
          if (attempt == 19) {
            stderr.writeln('Recipe WebView extraction failed: $error');
          }
        }
      }
      return const [];
    } finally {
      await controller.dispose();
    }
  }

  Future<RecipeImportData> importRecipe(RecipeSearchResult result) async {
    final uri = Uri.parse(result.url);
    final document = await _getDocument(uri);
    final recipe = _findRecipeJsonLdInDocument(document);
    if (recipe == null) {
      final description =
          document
              .querySelector('meta[property="og:description"]')
              ?.attributes['content'] ??
          document
              .querySelector('meta[name="description"]')
              ?.attributes['content'] ??
          result.snippet;
      final title =
          document
              .querySelector('meta[property="og:title"]')
              ?.attributes['content'] ??
          document.querySelector('title')?.text ??
          result.title;
      final imageUrl = document
          .querySelector('meta[property="og:image"]')
          ?.attributes['content'];
      return RecipeImportData(
        title: _cleanText(title),
        description: _cleanText(description),
        sourceUrl: result.url,
        sourceName: result.sourceName,
        coverPath: await _downloadImage(
          imageUrl == null ? result.imageUrl : _absoluteUrl(uri, imageUrl),
        ),
      );
    }

    final ingredients = <ImportedRecipeIngredient>[];
    final rawIngredients = recipe['recipeIngredient'];
    if (rawIngredients is List) {
      for (final item in rawIngredients) {
        final parsed = _parseIngredient(item.toString());
        if (parsed.name.isNotEmpty) ingredients.add(parsed);
      }
    }

    final instructions = _extractInstructions(recipe['recipeInstructions']);
    final imageUrl =
        _extractImage(recipe['image']) ??
        document
            .querySelector('meta[property="og:image"]')
            ?.attributes['content'];
    final description =
        recipe['description']?.toString() ??
        document
            .querySelector('meta[property="og:description"]')
            ?.attributes['content'] ??
        '';

    return RecipeImportData(
      title: _cleanText(recipe['name']?.toString() ?? result.title),
      description: _cleanText(description),
      instructions: instructions,
      ingredients: ingredients,
      servings: _parseServings(recipe['recipeYield']),
      prepTimeMinutes: _parseDuration(recipe['prepTime']?.toString()),
      cookTimeMinutes: _parseDuration(recipe['cookTime']?.toString()),
      sourceUrl: result.url,
      sourceName: result.sourceName,
      coverPath: await _downloadImage(
        imageUrl == null ? null : _absoluteUrl(uri, imageUrl),
      ),
    );
  }

  Map<String, dynamic>? _findRecipeJsonLd(dynamic node) {
    if (node is List) {
      for (final item in node) {
        final found = _findRecipeJsonLd(item);
        if (found != null) return found;
      }
    } else if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      final type = map['@type'];
      if ((type == 'Recipe') || (type is List && type.contains('Recipe'))) {
        return map;
      }
      final graph = map['@graph'];
      if (graph != null) {
        final found = _findRecipeJsonLd(graph);
        if (found != null) return found;
      }
      for (final value in map.values) {
        if (value is Map || value is List) {
          final found = _findRecipeJsonLd(value);
          if (found != null) return found;
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _findRecipeJsonLdInDocument(dynamic document) {
    for (final script in document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      final raw = script.text.trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        final found = _findRecipeJsonLd(decoded);
        if (found != null) return found;
      } catch (_) {}
    }
    return null;
  }

  String _extractInstructions(dynamic value) {
    final parts = <String>[];
    void visit(dynamic item) {
      if (item is String) {
        if (item.trim().isNotEmpty) parts.add(item.trim());
      } else if (item is List) {
        for (final child in item) {
          visit(child);
        }
      } else if (item is Map) {
        final text = item['text'] ?? item['name'];
        if (text != null && text.toString().trim().isNotEmpty) {
          parts.add(text.toString().trim());
        } else if (item['itemListElement'] != null) {
          visit(item['itemListElement']);
        }
      }
    }

    visit(value);
    return parts
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n\n');
  }

  String? _extractImage(dynamic value) {
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return _extractImage(value.first);
    if (value is Map) {
      return value['url']?.toString() ?? value['contentUrl']?.toString();
    }
    return null;
  }

  ImportedRecipeIngredient _parseIngredient(String raw) {
    final text = _cleanText(raw);
    final match = RegExp(r'^([\d\s.,/½¼¾⅓⅔]+)\s*([^\d]+?)?\s+(.+)$')
        .firstMatch(text);
    if (match == null) return ImportedRecipeIngredient(name: text);
    final quantity = _parseQuantity(match.group(1) ?? '');
    final unit = (match.group(2) ?? '').trim();
    final name = (match.group(3) ?? '').trim();
    if (name.isEmpty) return ImportedRecipeIngredient(name: text);
    return ImportedRecipeIngredient(name: name, quantity: quantity, unit: unit);
  }

  double? _parseQuantity(String value) {
    final text = value.trim().replaceAll(',', '.');
    if (text.contains('/')) {
      final parts = text.split('/');
      if (parts.length == 2) {
        final a = double.tryParse(parts[0].trim());
        final b = double.tryParse(parts[1].trim());
        if (a != null && b != null && b != 0) return a / b;
      }
    }
    return double.tryParse(text);
  }

  int _parseServings(dynamic value) {
    final text = value is List ? value.join(' ') : value?.toString() ?? '';
    final match = RegExp(r'\d+').firstMatch(text);
    if (match == null) return 2;
    final parsed = int.tryParse(match.group(0)!) ?? 2;
    if (parsed < 1) return 1;
    if (parsed > 100) return 100;
    return parsed;
  }

  int? _parseDuration(String? value) {
    if (value == null) return null;
    final match = RegExp(r'P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?')
        .firstMatch(value);
    if (match == null) return null;
    final days = int.tryParse(match.group(1) ?? '0') ?? 0;
    final hours = int.tryParse(match.group(2) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(3) ?? '0') ?? 0;
    final total = days * 1440 + hours * 60 + minutes;
    return total > 0 ? total : null;
  }

  Future<String?> _downloadImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      final request = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.acceptHeader, 'image/*');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) return null;
      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
      if (bytes.isEmpty || bytes.length > 12 * 1024 * 1024) return null;
      final directory = await StorageService.instance.coversDirectory;
      final extension = p.extension(uri.path).toLowerCase();
      final safeExtension =
          ['.jpg', '.jpeg', '.png', '.webp'].contains(extension)
          ? extension
          : '.jpg';
      final file = File(
        p.join(
          directory.path,
          'recipe_${DateTime.now().microsecondsSinceEpoch}$safeExtension',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _getDocument(Uri uri) async {
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.headers.set(
      HttpHeaders.acceptHeader,
      'text/html,application/xhtml+xml',
    );
    request.headers.set(
      HttpHeaders.acceptLanguageHeader,
      'ru-RU,ru;q=0.9,en;q=0.7',
    );
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw HttpException('Сайт вернул HTTP ${response.statusCode}', uri: uri);
    }
    final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
    final body = utf8.decode(bytes, allowMalformed: true);
    return html_parser.parse(body);
  }

  String _absoluteUrl(Uri base, String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null) return value;
    return parsed.hasScheme ? value : base.resolveUri(parsed).toString();
  }

  String _cleanText(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').replaceAll('&nbsp;', ' ').trim();
}
