import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/movie_entry.dart';
import '../repositories/movie_repository.dart';
import 'movie_editor_page.dart';

class MovieDetailsPage extends StatefulWidget {
  final MovieEntry movie;

  const MovieDetailsPage({super.key, required this.movie});

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  late MovieEntry _movie;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);

    try {
      final updatedMovie = await MovieRepository.instance.getById(_movie.id);

      if (updatedMovie != null && mounted) {
        setState(() => _movie = updatedMovie);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Не удалось обновить запись: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editMovie() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => MovieEditorPage(movie: _movie)),
    );

    if (result == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _deleteMovie() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(LunoraLocalization.text('Удалить запись?')),
          content: Text(
            LunoraLocalization.text(
              '«${_movie.title}» будет удалён из твоей коллекции.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade400,
              ),
              child: Text(LunoraLocalization.text('Удалить')),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await MovieRepository.instance.delete(_movie.id);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _showMessage('Не удалось удалить запись: $e');
      }
    }
  }

  Future<void> _changeProgress() async {
    final seasonController = TextEditingController(
      text: _movie.currentSeason.toString(),
    );

    final episodeController = TextEditingController(
      text: _movie.currentEpisode.toString(),
    );

    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(LunoraLocalization.text('Прогресс просмотра')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: seasonController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: LunoraLocalization.text('Текущий сезон'),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: episodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: LunoraLocalization.text('Текущая серия'),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            FilledButton(
              onPressed: () {
                final season = int.tryParse(seasonController.text.trim());
                final episode = int.tryParse(episodeController.text.trim());

                if (season == null ||
                    episode == null ||
                    season < 0 ||
                    episode < 0) {
                  return;
                }

                if (_movie.seasonsCount != null &&
                    season > _movie.seasonsCount!) {
                  return;
                }

                if (_movie.episodesCount != null &&
                    episode > _movie.episodesCount!) {
                  return;
                }

                Navigator.pop(context, (season, episode));
              },
              child: Text(LunoraLocalization.text('Сохранить')),
            ),
          ],
        );
      },
    );

    seasonController.dispose();
    episodeController.dispose();

    if (result == null) return;

    try {
      final updatedMovie = _movie.copyWith(
        currentSeason: result.$1,
        currentEpisode: result.$2,
      );

      await MovieRepository.instance.update(updatedMovie);

      if (mounted) {
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Не удалось обновить прогресс: $e');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(LunoraLocalization.text(message))));
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

  Color _statusColor(ColorScheme colors) {
    switch (_movie.status) {
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Не указана';

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_movie.isSeries ? LunoraLocalization.text('О сериале') : LunoraLocalization.text('О фильме')),
        actions: [
          IconButton(
            tooltip: LunoraLocalization.text('Редактировать'),
            onPressed: _editMovie,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: LunoraLocalization.text('Удалить'),
            onPressed: _deleteMovie,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMovieHeader(colors),
                    const SizedBox(height: 30),

                    if (_movie.isSeries) ...[
                      _buildSeriesProgress(colors),
                      const SizedBox(height: 30),
                    ],

                    if (_movie.description.isNotEmpty) ...[
                      _sectionTitle(LunoraLocalization.text('Описание'), Icons.description_outlined),
                      const SizedBox(height: 12),
                      _textCard(colors, _movie.description),
                      const SizedBox(height: 26),
                    ],

                    _sectionTitle(LunoraLocalization.text('Информация'), Icons.info_outline_rounded),
                    const SizedBox(height: 12),
                    _buildInformation(colors),
                    const SizedBox(height: 26),

                    if (_movie.genres.isNotEmpty) ...[
                      _sectionTitle(LunoraLocalization.text('Жанры'), Icons.category_outlined),
                      const SizedBox(height: 12),
                      _buildChips(colors, _movie.genres),
                      const SizedBox(height: 26),
                    ],

                    if (_movie.tags.isNotEmpty) ...[
                      _sectionTitle(LunoraLocalization.text('Теги'), Icons.sell_outlined),
                      const SizedBox(height: 12),
                      _buildChips(colors, _movie.tags),
                      const SizedBox(height: 26),
                    ],

                    if (_movie.review.isNotEmpty) ...[
                      _sectionTitle(
                        'Мои впечатления',
                        Icons.rate_review_outlined,
                      ),
                      const SizedBox(height: 12),
                      _textCard(colors, _movie.review),
                      const SizedBox(height: 26),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(color: colors.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildMovieHeader(ColorScheme colors) {
    final statusColor = _statusColor(colors);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 480;

          final poster = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child:
                _movie.posterPath != null &&
                    File(_movie.posterPath!).existsSync()
                ? Image.file(
                    File(_movie.posterPath!),
                    width: 150,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return _posterPlaceholder(colors);
                    },
                  )
                : _posterPlaceholder(colors),
          );

          final information = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _movie.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_movie.originalTitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _movie.originalTitle,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
                if (_movie.releaseYear != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _movie.releaseYear.toString(),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _statusLabel(_movie.status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _movie.isSeries ? 'Сериал' : 'Фильм',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                if (_movie.rating != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFD5AD70),
                        size: 23,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_movie.rating!.toStringAsFixed(1)} / 10',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: poster),
                const SizedBox(height: 22),
                information,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [poster, const SizedBox(width: 24), information],
          );
        },
      ),
    );
  }

  Widget _posterPlaceholder(ColorScheme colors) {
    return Container(
      width: 150,
      height: 220,
      color: colors.surfaceContainerHighest,
      child: Icon(
        Icons.movie_outlined,
        size: 60,
        color: colors.primary.withValues(alpha: 0.55),
      ),
    );
  }

  Widget _buildSeriesProgress(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.live_tv_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LunoraLocalization.text('Прогресс просмотра'),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: _changeProgress,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(LunoraLocalization.text('Изменить')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            LunoraLocalization.text(
              'Сезон ${_movie.currentSeason}, серия ${_movie.currentEpisode}',
            ),
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          if (_movie.seasonsCount != null || _movie.episodesCount != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (_movie.seasonsCount != null)
                  '${_movie.seasonsCount} сезонов',
                if (_movie.episodesCount != null)
                  '${_movie.episodesCount} серий',
              ].join(' · '),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInformation(ColorScheme colors) {
    final items = <(String, String, IconData)>[
      (
        'Год выпуска',
        _movie.releaseYear?.toString() ?? 'Не указан',
        Icons.calendar_today_outlined,
      ),
      ('Тип', _movie.isSeries ? 'Сериал' : 'Фильм', Icons.movie_outlined),
      if (_movie.isMovie)
        (
          'Длительность',
          _movie.runtimeMinutes != null
              ? '${_movie.runtimeMinutes} минут'
              : 'Не указана',
          Icons.schedule_outlined,
        ),
      if (_movie.isSeries) ...[
        (
          'Количество сезонов',
          _movie.seasonsCount?.toString() ?? 'Не указано',
          Icons.video_library_outlined,
        ),
        (
          'Количество серий',
          _movie.episodesCount?.toString() ?? 'Не указано',
          Icons.playlist_play_rounded,
        ),
      ],
      (
        'Дата просмотра',
        _formatDate(_movie.watchedAt),
        Icons.event_available_outlined,
      ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Icon(items[i].$3, color: colors.primary),
              title: Text(
                items[i].$1,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              subtitle: Text(
                items[i].$2,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (i != items.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colors.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildChips(ColorScheme colors, List<String> values) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return Chip(
          label: Text(value),
          backgroundColor: colors.surfaceContainerLow,
          side: BorderSide(color: colors.outlineVariant),
          labelStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        );
      }).toList(),
    );
  }

  Widget _textCard(ColorScheme colors, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: SelectableText(
        text,
        style: TextStyle(color: colors.onSurface, height: 1.6, fontSize: 14),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21),
        const SizedBox(width: 9),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
