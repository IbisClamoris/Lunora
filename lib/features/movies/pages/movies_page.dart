import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/settings/settings_service.dart';
import '../../../core/theme/lunora_theme_assets.dart';

import '../../../shared/widgets/lunora_section_header.dart';

import '../models/movie_entry.dart';
import '../repositories/movie_repository.dart';
import 'movie_details_page.dart';
import 'movie_editor_page.dart';
import 'movie_web_search_page.dart';
import '../services/movie_metadata_service.dart';

class MoviesPage extends StatefulWidget {
  const MoviesPage({super.key});

  @override
  State<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends State<MoviesPage> {
  final MovieRepository _repository = MovieRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  late Future<List<MovieEntry>> _moviesFuture;

  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadMovies() {
    _moviesFuture = _repository.getAll();
  }

  Future<void> _refresh() async {
    setState(_loadMovies);
    await _moviesFuture;
  }

  Future<void> _openExternalSearch() async {
    final metadata = await Navigator.of(context).push<MovieMetadata>(
      MaterialPageRoute(builder: (_) => const MovieWebSearchPage()),
    );
    if (metadata != null && mounted) {
      await _openEditor(metadata: metadata);
    }
  }

  Future<void> _openEditor({MovieEntry? movie, MovieMetadata? metadata}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            MovieEditorPage(movie: movie, initialMetadata: metadata),
      ),
    );

    if (result == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _changeMovieStatus(MovieEntry movie, String status) async {
    if (movie.status == status) return;
    try {
      await _repository.updateStatus(movie.id, status);
      if (mounted) await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text('Не удалось изменить статус: $error'))),
      );
    }
  }

  Future<void> _openDetails(MovieEntry movie) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => MovieDetailsPage(movie: movie)),
    );

    if (result == true && mounted) {
      await _refresh();
    }
  }

  List<MovieEntry> _filterMovies(List<MovieEntry> movies) {
    var result = movies;

    switch (_selectedFilter) {
      case 'movies':
        result = result.where((movie) => movie.isMovie).toList();
        break;
      case 'series':
        result = result.where((movie) => movie.isSeries).toList();
        break;
      case 'watching':
        result = result.where((movie) => movie.status == 'watching').toList();
        break;
      case 'completed':
        result = result.where((movie) => movie.status == 'completed').toList();
        break;
      case 'planned':
        result = result.where((movie) => movie.status == 'planned').toList();
        break;
      case 'on_hold':
        result = result.where((movie) => movie.status == 'on_hold').toList();
        break;
      case 'dropped':
        result = result.where((movie) => movie.status == 'dropped').toList();
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();

      result = result.where((movie) {
        return movie.title.toLowerCase().contains(query) ||
            movie.originalTitle.toLowerCase().contains(query) ||
            movie.genres.any((genre) => genre.toLowerCase().contains(query)) ||
            movie.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    return result;
  }

  int _countByStatus(List<MovieEntry> movies, String status) {
    return movies.where((movie) => movie.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: FutureBuilder<List<MovieEntry>>(
        future: _moviesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }

          final movies = snapshot.data ?? [];
          final filteredMovies = _filterMovies(movies);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
                  sliver: SliverToBoxAdapter(child: _buildHeader(colors)),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  sliver: SliverToBoxAdapter(
                    child: _buildStatistics(movies, colors),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 28)),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  sliver: SliverToBoxAdapter(
                    child: _buildLibraryHeader(colors),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 12),
                  sliver: SliverToBoxAdapter(child: _buildSearch(colors)),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  sliver: SliverToBoxAdapter(child: _buildFilters(colors)),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                if (filteredMovies.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(colors, movies.isEmpty),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;

                        final columns = width >= 1100
                            ? 5
                            : width >= 850
                            ? 4
                            : width >= 600
                            ? 3
                            : width >= 380
                            ? 2
                            : 1;

                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 18,
                                mainAxisSpacing: 18,
                                childAspectRatio: 0.66,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final movie = filteredMovies[index];

                            return _buildMovieCard(movie, colors);
                          }, childCount: filteredMovies.length),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: Text(LunoraLocalization.text('Добавить')),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colors) {
    return LunoraSectionHeader(
      title: LunoraLocalization.text('Мир кино'),
      subtitle: LunoraLocalization.text(
        'Фильмы, сериалы и истории, к которым хочется возвращаться.',
      ),
      icon: Icons.movie_filter_rounded,
      actions: [
        OutlinedButton.icon(
          onPressed: _openExternalSearch,
          icon: const Icon(Icons.travel_explore_rounded, size: 18),
          label: Text(LunoraLocalization.text('Найти в интернете')),
        ),
      ],
    );
  }

  Widget _buildStatistics(List<MovieEntry> movies, ColorScheme colors) {
    final statistics = [
      _StatisticData(
        title: LunoraLocalization.text('Всего'),
        value: movies.length,
        icon: Icons.video_collection_outlined,
        color: colors.primary,
      ),
      _StatisticData(
        title: LunoraLocalization.text('Смотрю'),
        value: _countByStatus(movies, 'watching'),
        icon: Icons.play_circle_outline_rounded,
        color: const Color(0xFF789477),
      ),
      _StatisticData(
        title: LunoraLocalization.text('Просмотрено'),
        value: _countByStatus(movies, 'completed'),
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF8D9FC0),
      ),
      _StatisticData(
        title: LunoraLocalization.text('В планах'),
        value: _countByStatus(movies, 'planned'),
        icon: Icons.bookmark_border_rounded,
        color: const Color(0xFFAA8DBD),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: statistics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemBuilder: (context, index) {
            final item = statistics[index];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(item.icon, color: item.color, size: 25),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.value.toString(),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLibraryHeader(ColorScheme colors) {
    return Row(
      children: [
        Icon(Icons.local_movies_outlined, color: colors.primary, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            LunoraLocalization.text('Моя коллекция'),
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildSearch(ColorScheme colors) {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() => _searchQuery = value.trim());
      },
      decoration: InputDecoration(
        hintText: LunoraLocalization.text('Найти фильм, сериал или жанр...'),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: colors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildFilters(ColorScheme colors) {
    final filters = <(String, String)>[
      ('all', 'Всё'),
      ('movies', 'Фильмы'),
      ('series', 'Сериалы'),
      ('watching', 'Смотрю'),
      ('completed', 'Просмотрено'),
      ('planned', 'В планах'),
      ('on_hold', 'Отложено'),
      ('dropped', 'Брошено'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _selectedFilter == filter.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(LunoraLocalization.text(filter.$2)),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedFilter = filter.$1);
              },
              selectedColor: colors.primaryContainer,
              backgroundColor: colors.surfaceContainerLow,
              side: BorderSide(
                color: selected ? colors.primary : colors.outlineVariant,
              ),
              labelStyle: TextStyle(
                color: selected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMovieCard(MovieEntry movie, ColorScheme colors) {
    final statusColor = _statusColor(movie.status, colors);

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetails(movie),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPoster(movie, colors),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        movie.isSeries ? 'СЕРИАЛ' : 'ФИЛЬМ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  if (movie.rating != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFD5AD70),
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              movie.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (movie.genres.isNotEmpty)
                      Text(
                        movie.genres.take(2).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        PopupMenuButton<String>(
                          tooltip: LunoraLocalization.text('Быстро изменить статус'),
                          onSelected: (value) =>
                              _changeMovieStatus(movie, value),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'planned',
                              child: Text(LunoraLocalization.text('В планах')),
                            ),
                            PopupMenuItem(
                              value: 'watching',
                              child: Text(LunoraLocalization.text('Смотрю')),
                            ),
                            PopupMenuItem(
                              value: 'completed',
                              child: Text(LunoraLocalization.text('Просмотрено')),
                            ),
                            PopupMenuItem(
                              value: 'on_hold',
                              child: Text(LunoraLocalization.text('Отложено')),
                            ),
                            PopupMenuItem(
                              value: 'dropped',
                              child: Text(LunoraLocalization.text('Брошено')),
                            ),
                          ],
                          padding: EdgeInsets.zero,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _statusLabel(movie.status),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 15,
                                  color: statusColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (movie.releaseYear != null)
                          Text(
                            movie.releaseYear.toString(),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoster(MovieEntry movie, ColorScheme colors) {
    if (movie.posterPath != null && File(movie.posterPath!).existsSync()) {
      return Image.file(
        File(movie.posterPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _posterPlaceholder(colors),
      );
    }

    return _posterPlaceholder(colors);
  }

  Widget _posterPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: 54,
          color: colors.primary.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  Color _statusColor(String status, ColorScheme colors) {
    switch (status) {
      case 'watching':
        return colors.primary;
      case 'completed':
        return const Color(0xFF789477);
      case 'planned':
        return const Color(0xFFAA8DBD);
      case 'on_hold':
        return const Color(0xFFC69B72);
      case 'dropped':
        return const Color(0xFFC58F9B);
      default:
        return colors.secondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'watching':
        return 'Смотрю';
      case 'completed':
        return 'Просмотрено';
      case 'planned':
        return 'В планах';
      case 'on_hold':
        return 'Отложено';
      case 'dropped':
        return 'Брошено';
      default:
        return 'Неизвестно';
    }
  }

  Widget _buildEmptyState(ColorScheme colors, bool libraryIsEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              LunoraThemeAssets.emptyState(
                SettingsService.instance.settings.colorTheme,
                libraryIsEmpty ? 'movies' : 'search',
              ),
              width: 180,
              height: 135,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 18),
            Text(
              libraryIsEmpty
                  ? 'Твоя коллекция пока пуста'
                  : 'Ничего не найдено',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              libraryIsEmpty
                  ? 'Добавь первый фильм или сериал, чтобы начать собирать свою коллекцию.'
                  : 'Попробуй изменить поисковый запрос или выбранный фильтр.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
            ),
            if (libraryIsEmpty) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
                label: Text(LunoraLocalization.text('Добавить запись')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 52, color: colors.error),
            const SizedBox(height: 16),
            Text(
              LunoraLocalization.text('Не удалось загрузить коллекцию'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                setState(_loadMovies);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(LunoraLocalization.text('Повторить')),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticData {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _StatisticData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
