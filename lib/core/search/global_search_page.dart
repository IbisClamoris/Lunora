import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/lunora_navigation.dart';
import '../theme/app_theme.dart';
import 'global_search_result.dart';
import 'global_search_service.dart';

class GlobalSearchPage extends StatefulWidget {
  final String query;
  final ValueChanged<LunoraSection> onOpenSection;

  const GlobalSearchPage({
    super.key,
    required this.query,
    required this.onOpenSection,
  });

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  List<GlobalSearchResult> _results = [];

  bool _loading = false;
  String? _error;

  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(covariant GlobalSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.query != widget.query) {
      _debounce?.cancel();

      _debounce = Timer(const Duration(milliseconds: 250), _search);
    }
  }

  Future<void> _search() async {
    final query = widget.query.trim();
    final requestId = ++_requestId;

    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _loading = false;
          _error = null;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await GlobalSearchService.instance.search(query);

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String _sectionName(LunoraSection section) {
    switch (section) {
      case LunoraSection.home:
        return 'Главная';
      case LunoraSection.calendar:
        return 'Календарь';
      case LunoraSection.notifications:
        return 'Уведомления';
      case LunoraSection.shoppingList:
        return 'Список покупок';
      case LunoraSection.planner:
        return 'Мой планер';
      case LunoraSection.studyPlanner:
        return 'Учебный планер';
      case LunoraSection.finances:
        return 'Мои финансы';
      case LunoraSection.knowledgeBase:
        return 'База знаний';
      case LunoraSection.diary:
        return 'Дневник';
      case LunoraSection.diaryGallery:
        return 'Галерея дневника';
      case LunoraSection.books:
        return 'Книжный мир';
      case LunoraSection.movies:
        return 'Мир кино и сериалов';
      case LunoraSection.recipes:
        return 'Книга рецептов';
      case LunoraSection.wishlist:
        return 'Вишлист';
      case LunoraSection.settings:
        return 'Настройки';
    }
  }

  IconData _sectionIcon(LunoraSection section) {
    switch (section) {
      case LunoraSection.calendar:
        return Icons.calendar_month_outlined;
      case LunoraSection.notifications:
        return Icons.notifications_none;
      case LunoraSection.shoppingList:
        return Icons.shopping_basket_outlined;
      case LunoraSection.planner:
        return Icons.event_note_outlined;
      case LunoraSection.studyPlanner:
        return Icons.school_outlined;
      case LunoraSection.finances:
        return Icons.account_balance_wallet_outlined;
      case LunoraSection.knowledgeBase:
        return Icons.auto_stories_outlined;
      case LunoraSection.diary:
        return Icons.edit_note_outlined;
      case LunoraSection.books:
        return Icons.menu_book_outlined;
      case LunoraSection.movies:
        return Icons.movie_outlined;
      case LunoraSection.recipes:
        return Icons.restaurant_menu_outlined;
      case LunoraSection.wishlist:
        return Icons.auto_awesome_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  Map<LunoraSection, List<GlobalSearchResult>> get _groupedResults {
    final grouped = <LunoraSection, List<GlobalSearchResult>>{};

    for (final result in _results) {
      grouped.putIfAbsent(result.section, () => []).add(result);
    }

    return grouped;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LunoraLocalization.text('Результаты поиска'),
                style: TextStyle(
                  color: palette.text,
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                LunoraLocalization.text('По запросу «${widget.query}»'),
                style: TextStyle(color: palette.secondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                _buildMessage(
                  palette,
                  'Не удалось выполнить поиск.',
                  Icons.error_outline,
                )
              else if (_results.isEmpty)
                _buildMessage(palette, 'Ничего не найдено.', Icons.search_off)
              else
                ..._groupedResults.entries.map(
                  (entry) => _buildSection(palette, entry.key, entry.value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    LunoraPalette palette,
    LunoraSection section,
    List<GlobalSearchResult> results,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onOpenSection(section),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      _sectionIcon(section),
                      color: palette.accent,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _sectionName(section),
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${results.length}',
                      style: TextStyle(color: palette.secondary, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: palette.secondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ...results.map(
            (result) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                title: Text(
                  result.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: result.subtitle.isEmpty
                    ? null
                    : Text(
                        result.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 11,
                        ),
                      ),
                trailing: Icon(Icons.chevron_right, color: palette.secondary),
                onTap: () => widget.onOpenSection(section),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(LunoraPalette palette, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(icon, size: 42, color: palette.secondary),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: palette.secondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
