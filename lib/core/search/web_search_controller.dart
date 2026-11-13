import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

@immutable
class WebSearchHit {
  const WebSearchHit({
    required this.title,
    required this.url,
    this.author = '',
    this.description = '',
    this.imageUrl,
  });

  final String title;
  final String url;
  final String author;
  final String description;
  final String? imageUrl;
}

/// Searches public book pages through Yandex in WebView2.
/// Only organic search cards with a real heading and an external URL are used.
class WebSearchController {
  WebSearchController({WebviewController? controller})
    : controller = controller ?? WebviewController();

  final WebviewController controller;
  bool _initialized = false;
  bool _disposed = false;

  Future<void> initialize() async {
    if (_disposed) {
      throw StateError('WebSearchController уже закрыт.');
    }
    if (_initialized) return;

    await controller.initialize();
    await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await controller.setDefaultContextMenusEnabled(true);
    _initialized = true;
  }

  Future<List<WebSearchHit>> searchBooks(String query) async {
    final normalizedQuery = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedQuery.isEmpty) return const <WebSearchHit>[];

    await initialize();

    // Добавляем книжный контекст, но сохраняем исходную формулировку.
    final searchText = '"$normalizedQuery" книги произведения';
    final uri = Uri.https('yandex.ru', '/search/', <String, String>{
      'text': searchText,
    });
    await controller.loadUrl(uri.toString());

    for (var attempt = 0; attempt < 15; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      try {
        final dynamic raw = await controller.executeScript(r'''
          (() => {
            const clean = value => String(value || '')
              .replace(/[\u00a0\u200b]/g, ' ')
              .replace(/\s+/g, ' ')
              .trim();
            const genericPage = /полный список|лучшие книги|книги автора|новинки \d{4}|биография|порядок читать|как читать|гид по мирам|подборка книг|все книги|каталог книг|купить книги|интернет-магазин/i;
            const badText = /быстрый ответ|может заинтересовать|реклама|скачать браузер|яндекс браузер|войти|обратная связь|заказы|избранное|мнение:|обсуждение|форум|вопросы и ответы|нейросеть|алиса ai/i;
            const badHost = /(^|\.)(yandex\.|ya\.ru|wikipedia\.org|vk\.com|dzen\.ru|youtube\.com|t\.me|pikabu\.ru|otzovik\.com|irecommend\.ru)$/i;
            const trustedHost = /litres\.ru|chitai-gorod\.ru|book24\.ru|labirint\.ru|eksmo\.ru|ast\.ru|bookvoed\.ru|livelib\.ru|fantlab\.ru|mybook\.ru|books\.ru|ozon\.ru|wildberries\.ru/i;
            const bookWords = /книг|роман|трилоги|цикл|серия|автор|издательств|читать|бумажн|электронн|фэнтези|фантастик/i;
            const cards = Array.from(document.querySelectorAll('li.serp-item, .serp-item'));
            const seen = new Set();
            const out = [];

            for (const card of cards) {
              const cardClass = String(card.className || '').toLowerCase();
              const cardText = clean(card.innerText || '');
              if (/adv|advert|commercial|sponsored|реклам/.test(cardClass)) continue;
              if (!cardText || badText.test(cardText)) continue;

              const heading = card.querySelector('h2, h3, [role="heading"]');
              if (!heading) continue;
              const title = clean(heading.innerText || heading.textContent);
              if (title.length < 3 || title.length > 180 || badText.test(title)) continue;

              const link = heading.closest('a[href]') || heading.querySelector('a[href]') ||
                card.querySelector('a[href]');
              if (!link) continue;
              const url = link.href || '';
              if (!/^https?:\/\//i.test(url)) continue;
              let parsed;
              try { parsed = new URL(url); } catch (_) { continue; }
              const host = parsed.hostname.toLowerCase().replace(/^www\./, '');
              if (badHost.test(host) || /yandex\.(ru|com)/i.test(host)) continue;
              if (seen.has(url)) continue;

              const snippetNode = card.querySelector(
                '.text-container, .organic__content, .serp-item__text, [data-snippet], .text'
              );
              let description = clean(snippetNode ? snippetNode.innerText : cardText);
              description = description.replace(title, '').trim();
              description = description.replace(/^[^ ]+\.(ru|com|org|net)\s*/i, '').trim();
              if (description.length > 650) description = description.slice(0, 647) + '…';

              // Search cards should contain book context, not merely a passing mention.
              const trusted = trustedHost.test(host);
              if (!trusted && !bookWords.test(title + ' ' + description)) continue;

              const image = card.querySelector('img');
              const imageUrl = image ? (image.currentSrc || image.src || null) : null;
              const score = (trusted ? 5 : 0) +
                (bookWords.test(title) ? 3 : 0) +
                (bookWords.test(description) ? 1 : 0) +
                (title.length < 100 ? 1 : 0);

              seen.add(url);
              out.push({
                title,
                url,
                description,
                imageUrl,
                source: host,
                score
              });
            }

            out.sort((a, b) => b.score - a.score);
            return JSON.stringify(out.slice(0, 20));
          })()
        ''');

        final decoded = raw is String ? jsonDecode(raw) : raw;
        if (decoded is! List) continue;

        final hits = <WebSearchHit>[];
        for (final item in decoded) {
          if (item is! Map) continue;
          final title = (item['title'] ?? '').toString().trim();
          final url = (item['url'] ?? '').toString().trim();
          if (title.isEmpty || !url.startsWith('http')) continue;
          final parsed = _parseBookTitle(title, normalizedQuery);
          if (parsed.title.isEmpty || !_isBookTitle(parsed.title)) continue;
          hits.add(
            WebSearchHit(
              title: parsed.title,
              author: parsed.author,
              url: url,
              description: _cleanDescription(
                (item['description'] ?? '').toString(),
                parsed.title,
                parsed.author,
              ),
              imageUrl: item['imageUrl']?.toString(),
            ),
          );
        }
        if (hits.isNotEmpty) return hits;
      } catch (error, stackTrace) {
        debugPrint('Book search extraction attempt ${attempt + 1}: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return const <WebSearchHit>[];
  }

  ({String title, String author}) _parseBookTitle(String raw, String query) {
    var title = raw.trim();
    var author = '';

    // Сначала убираем хвосты магазинов и издательств из заголовка.
    title = title.replaceAll(RegExp(r'\s*[|]\s*.*$', caseSensitive: false), '');

    // Формат: Автор «Название книги».
    final quoted = RegExp(r'[«"]([^»"]{2,100})[»"]').firstMatch(title);
    if (quoted != null) {
      final prefix = title.substring(0, quoted.start).trim();
      title = quoted.group(1)!.trim();
      author = _cleanAuthor(prefix);
    } else {
      // Формат: Автор — Название или Название — Автор.
      final split = RegExp(r'\s+[—–]\s+').firstMatch(title);
      if (split != null) {
        final left = title.substring(0, split.start).trim();
        final right = title.substring(split.end).trim();
        final cleanLeft = _cleanAuthor(left);
        final cleanRight = _cleanAuthor(right);
        if (_looksLikeAuthorQuery(cleanLeft) && right.length >= 2) {
          author = cleanLeft;
          title = right;
        } else if (_looksLikeAuthorQuery(cleanRight) && left.length >= 2) {
          author = cleanRight;
          title = left;
        }
      }
    }

    title = title
        .replaceAll(RegExp(r'\s*[|»].*$'), '')
        .replaceAll(
          RegExp(
            r'\s+(?:купить|читать онлайн|скачать|издательство акт|литрес|лабиринт|читай-город).*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'^(?:книга|роман)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (author.isEmpty && _looksLikeAuthorQuery(query)) {
      author = _cleanAuthor(query);
    }
    return (title: title, author: author);
  }

  String _cleanAuthor(String value) {
    var author = value.trim();
    author = author.replaceAll(RegExp(r'[|•·].*$'), '');
    author = author.replaceAll(
      RegExp(
        r'\s+(?:издательство|литрес|литрес\.ру|читай-город|лабиринт|буквоед|book24|купить|читать онлайн|скачать).*$',
        caseSensitive: false,
      ),
      '',
    );
    author = author.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    author = author.replaceAll(RegExp(r'^[«"\s]+|[»"\s]+$'), '');
    return author;
  }

  bool _looksLikeAuthorQuery(String query) {
    return query.trim().split(RegExp(r'\s+')).length >= 2 &&
        !RegExp(
          r'книга|роман|трилогия|цикл|серия|том',
          caseSensitive: false,
        ).hasMatch(query);
  }

  bool _isBookTitle(String title) {
    return title.length >= 2 &&
        title.length <= 100 &&
        !RegExp(
          r'полный список|лучшие книги|книги автора|новинки|биография|порядок читать|как читать|гид по мирам|подборка|все книги|каталог|интернет-магазин|отзывы|рецензия|мнение:',
          caseSensitive: false,
        ).hasMatch(title);
  }

  String _cleanDescription(String value, String title, String author) {
    var text = value
        .replaceAll(RegExp(r'[\u00a0\u200b]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.isEmpty) return '';

    // Сниппеты с хлебными крошками и коммерческими призывами не являются
    // описанием произведения. Лучше оставить поле пустым, чем сохранить мусор.
    final commercialOrNavigation = RegExp(
      r'(^[›>]|издательство|скачать|читать онлайн|купить|интернет-магазин|доставка|отзывов на магазин|рейтинг|формат fb2|формат epub|pdf или читать|книга .* —)',
      caseSensitive: false,
    );
    if (commercialOrNavigation.hasMatch(text)) return '';

    for (final part in [title, author]) {
      if (part.isNotEmpty) {
        text = text.replaceAll(
          RegExp(RegExp.escape(part), caseSensitive: false),
          '',
        );
      }
    }

    text = text
        .replaceAll(RegExp(r'^[\s:|>›—–-]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.length < 55) return '';
    return text.length > 500 ? '${text.substring(0, 497)}…' : text;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_initialized) {
      await controller.dispose();
      _initialized = false;
    }
  }
}
