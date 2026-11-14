import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/storage_service.dart';
import '../models/movie_entry.dart';
import '../repositories/movie_repository.dart';
import '../services/movie_metadata_service.dart';

class MovieEditorPage extends StatefulWidget {
  final MovieEntry? movie;
  final MovieMetadata? initialMetadata;

  const MovieEditorPage({super.key, this.movie, this.initialMetadata});

  @override
  State<MovieEditorPage> createState() => _MovieEditorPageState();
}

class _MovieEditorPageState extends State<MovieEditorPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _originalTitleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _genresController;
  late final TextEditingController _tagsController;
  late final TextEditingController _yearController;
  late final TextEditingController _runtimeController;
  late final TextEditingController _seasonsController;
  late final TextEditingController _episodesController;
  late final TextEditingController _currentSeasonController;
  late final TextEditingController _currentEpisodeController;
  late final TextEditingController _reviewController;

  late String _mediaType;
  late String _status;

  String? _posterPath;
  String? _backdropPath;
  double? _rating;
  DateTime? _watchedAt;

  bool _isSaving = false;

  bool get _isEditing => widget.movie != null;
  bool get _isSeries => _mediaType == 'series';

  @override
  void initState() {
    super.initState();

    final movie = widget.movie;
    final metadata = widget.initialMetadata;

    _titleController = TextEditingController(
      text: movie?.title ?? metadata?.title ?? '',
    );
    _originalTitleController = TextEditingController(
      text: movie?.originalTitle ?? metadata?.originalTitle ?? '',
    );
    _descriptionController = TextEditingController(
      text: movie?.description ?? metadata?.description ?? '',
    );
    _genresController = TextEditingController(
      text: movie?.genres.join(', ') ?? metadata?.genres.join(', ') ?? '',
    );
    _tagsController = TextEditingController(text: movie?.tags.join(', ') ?? '');
    _yearController = TextEditingController(
      text:
          movie?.releaseYear?.toString() ??
          metadata?.releaseYear?.toString() ??
          '',
    );
    _runtimeController = TextEditingController(
      text:
          movie?.runtimeMinutes?.toString() ??
          metadata?.runtimeMinutes?.toString() ??
          '',
    );
    _seasonsController = TextEditingController(
      text:
          movie?.seasonsCount?.toString() ??
          metadata?.seasonsCount?.toString() ??
          '',
    );
    _episodesController = TextEditingController(
      text:
          movie?.episodesCount?.toString() ??
          metadata?.episodesCount?.toString() ??
          '',
    );
    _currentSeasonController = TextEditingController(
      text: movie?.currentSeason.toString() ?? '0',
    );
    _currentEpisodeController = TextEditingController(
      text: movie?.currentEpisode.toString() ?? '0',
    );
    _reviewController = TextEditingController(text: movie?.review ?? '');

    _mediaType = movie?.mediaType ?? metadata?.mediaType ?? 'movie';
    _status = movie?.status ?? 'planned';
    _posterPath = movie?.posterPath;
    _backdropPath = movie?.backdropPath;
    _rating = movie?.rating;
    _watchedAt = movie?.watchedAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _originalTitleController.dispose();
    _descriptionController.dispose();
    _genresController.dispose();
    _tagsController.dispose();
    _yearController.dispose();
    _runtimeController.dispose();
    _seasonsController.dispose();
    _episodesController.dispose();
    _currentSeasonController.dispose();
    _currentEpisodeController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isBackdrop}) async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);

      if (file == null || file.path == null) {
        return;
      }

      setState(() {
        if (isBackdrop) {
          _backdropPath = file.path;
        } else {
          _posterPath = file.path;
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось выбрать изображение: $e'),
          ),
        ),
      );
    }
  }

  Future<String?> _downloadMetadataImage(String? url, String prefix) async {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.userAgentHeader, 'Lunora/1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final bytes = await response.fold<List<int>>(
        <int>[],
        (a, b) => a..addAll(b),
      );
      if (bytes.isEmpty) return null;
      final directory = await StorageService.instance.coversDirectory;
      final extension = p.extension(uri.path).toLowerCase();
      final safeExtension =
          ['.jpg', '.jpeg', '.png', '.webp'].contains(extension)
          ? extension
          : '.jpg';
      final file = File(
        p.join(
          directory.path,
          '${prefix}_${DateTime.now().microsecondsSinceEpoch}$safeExtension',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> _prepareImagePath(String? sourcePath) async {
    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }

    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw Exception('Файл изображения не найден: $sourcePath');
    }

    final directory = await StorageService.instance.coversDirectory;

    final normalizedSource = p.normalize(p.absolute(sourceFile.path));

    final normalizedDirectory = p.normalize(p.absolute(directory.path));

    if (p.isWithin(normalizedDirectory, normalizedSource)) {
      return sourceFile.path;
    }

    final extension = p.extension(sourcePath);
    final prefix = _posterPath == sourcePath
        ? 'movie_poster'
        : 'movie_backdrop';

    final fileName =
        '${prefix}_${DateTime.now().microsecondsSinceEpoch}$extension';

    final destinationPath = p.join(directory.path, fileName);

    final copiedFile = await sourceFile.copy(destinationPath);

    return copiedFile.path;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _watchedAt ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 10),
    );

    if (selected != null) {
      setState(() => _watchedAt = selected);
    }
  }

  List<String> _parseList(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final year = int.tryParse(_yearController.text.trim());
    final runtime = int.tryParse(_runtimeController.text.trim());
    final seasons = int.tryParse(_seasonsController.text.trim());
    final episodes = int.tryParse(_episodesController.text.trim());
    final currentSeason =
        int.tryParse(_currentSeasonController.text.trim()) ?? 0;
    final currentEpisode =
        int.tryParse(_currentEpisodeController.text.trim()) ?? 0;

    if (_isSeries) {
      if (currentSeason < 0 || currentEpisode < 0) {
        _showMessage('Прогресс не может быть отрицательным.');
        return;
      }

      if (seasons != null && currentSeason > seasons) {
        _showMessage(
          LunoraLocalization.text('Текущий сезон не может превышать общее количество сезонов.', 'The current season cannot exceed the total number of seasons.'),
        );
        return;
      }

      if (episodes != null && currentEpisode > episodes) {
        _showMessage(
          LunoraLocalization.text('Текущая серия не может превышать общее количество серий.', 'The current episode cannot exceed the total number of episodes.'),
        );
        return;
      }
    }

    if (year != null && (year < 1888 || year > DateTime.now().year + 10)) {
      _showMessage('Проверь год выпуска.');
      return;
    }

    if (runtime != null && runtime < 0) {
      _showMessage('Длительность не может быть отрицательной.');
      return;
    }

    if (seasons != null && seasons < 0 || episodes != null && episodes < 0) {
      _showMessage('Количество сезонов и серий не может быть отрицательным.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final oldMovie = widget.movie;

      final importedPoster =
          _posterPath ??
          await _downloadMetadataImage(
            widget.initialMetadata?.posterUrl,
            'movie_poster',
          );
      final importedBackdrop =
          _backdropPath ??
          await _downloadMetadataImage(
            widget.initialMetadata?.backdropUrl,
            'movie_backdrop',
          );
      final posterPath = await _prepareImagePath(importedPoster);
      final backdropPath = await _prepareImagePath(importedBackdrop);

      final movie = MovieEntry(
        id: oldMovie?.id ?? '',
        title: _titleController.text.trim(),
        originalTitle: _originalTitleController.text.trim(),
        mediaType: _mediaType,
        description: _descriptionController.text.trim(),
        posterPath: posterPath,
        backdropPath: backdropPath,
        genres: _parseList(_genresController.text),
        tags: _parseList(_tagsController.text),
        status: _status,
        rating: _rating,
        review: _reviewController.text.trim(),
        releaseYear: year,
        runtimeMinutes: _isSeries ? null : runtime,
        seasonsCount: _isSeries ? seasons : null,
        episodesCount: _isSeries ? episodes : null,
        currentSeason: _isSeries ? currentSeason : 0,
        currentEpisode: _isSeries ? currentEpisode : 0,
        watchedAt: _watchedAt,
        createdAt: oldMovie?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditing) {
        await MovieRepository.instance.update(movie);
      } else {
        await MovieRepository.instance.create(movie);
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось сохранить запись: $e'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(LunoraLocalization.text(message))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? LunoraLocalization.text('Редактирование записи') : LunoraLocalization.text('Новая запись')),
        actions: [
          IconButton(
            tooltip: LunoraLocalization.text('Сохранить'),
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPoster(),
                  const SizedBox(height: 28),

                  _sectionTitle(LunoraLocalization.text('Тип записи')),
                  const SizedBox(height: 14),

                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'movie',
                        label: Text(LunoraLocalization.text('Фильм')),
                        icon: Icon(Icons.movie_outlined),
                      ),
                      ButtonSegment(
                        value: 'series',
                        label: Text(LunoraLocalization.text('Сериал')),
                        icon: Icon(Icons.live_tv_outlined),
                      ),
                    ],
                    selected: {_mediaType},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _mediaType = selection.first;
                      });
                    },
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle(LunoraLocalization.text('Основная информация')),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _titleController,
                    label: LunoraLocalization.text('Название'),
                    required: true,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _originalTitleController,
                    label: LunoraLocalization.text('Оригинальное название'),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _yearController,
                    label: LunoraLocalization.text('Год выпуска'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _genresController,
                    label: LunoraLocalization.text('Жанры'),
                    hint: LunoraLocalization.text('Фэнтези, драма, приключения', 'Fantasy, drama, adventure'),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _descriptionController,
                    label: LunoraLocalization.text('Описание'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _tagsController,
                    label: LunoraLocalization.text('Теги'),
                    hint: LunoraLocalization.text('Любимое, пересмотреть, классика', 'Favourite, rewatch, classics'),
                  ),

                  const SizedBox(height: 28),
                  _sectionTitle(
                    _isSeries ? LunoraLocalization.text('Просмотр сериала', 'Watching a series') : LunoraLocalization.text('Просмотр фильма', 'Watching a movie'),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Статус'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'planned',
                        child: Text(LunoraLocalization.text('В планах')),
                      ),
                      DropdownMenuItem(
                        value: 'watching',
                        child: Text(LunoraLocalization.text('Смотрю')),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text(LunoraLocalization.text('Просмотрено')),
                      ),
                      DropdownMenuItem(
                        value: 'on_hold',
                        child: Text(LunoraLocalization.text('Отложено')),
                      ),
                      DropdownMenuItem(
                        value: 'dropped',
                        child: Text(LunoraLocalization.text('Брошено')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
                  ),

                  const SizedBox(height: 14),

                  if (_isSeries) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _seasonsController,
                            label: LunoraLocalization.text('Всего сезонов'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildTextField(
                            controller: _episodesController,
                            label: LunoraLocalization.text('Всего серий'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _currentSeasonController,
                            label: LunoraLocalization.text('Текущий сезон'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildTextField(
                            controller: _currentEpisodeController,
                            label: LunoraLocalization.text('Текущая серия'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    _buildTextField(
                      controller: _runtimeController,
                      label: LunoraLocalization.text('Длительность (минуты)'),
                      keyboardType: TextInputType.number,
                    ),

                  const SizedBox(height: 16),

                  _buildDateTile(),

                  const SizedBox(height: 28),
                  _sectionTitle(LunoraLocalization.text('Оценка и впечатления')),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<double?>(
                    initialValue: _rating,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Оценка'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<double?>(
                        value: null,
                        child: Text(LunoraLocalization.text('Без оценки')),
                      ),
                      ...List.generate(10, (index) {
                        final rating = (index + 1).toDouble();

                        return DropdownMenuItem<double?>(
                          value: rating,
                          child: Text('$rating / 10'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _rating = value);
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    controller: _reviewController,
                    label: LunoraLocalization.text('Мой отзыв'),
                    maxLines: 5,
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _isEditing ? LunoraLocalization.text('Сохранить изменения', 'Save changes') : LunoraLocalization.text('Добавить запись', 'Add entry'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoster() {
    return Center(
      child: Column(
        children: [
          _imagePreview(
            path: _posterPath,
            width: 150,
            height: 220,
            icon: Icons.movie_outlined,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _pickImage(isBackdrop: false),
            icon: const Icon(Icons.image_outlined),
            label: Text(LunoraLocalization.text('Выбрать постер')),
          ),
          if (_posterPath != null)
            TextButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => setState(() => _posterPath = null),
              icon: const Icon(Icons.delete_outline),
              label: Text(LunoraLocalization.text('Убрать постер')),
            ),
          const SizedBox(height: 18),
          _imagePreview(
            path: _backdropPath,
            width: 300,
            height: 110,
            icon: Icons.panorama_outlined,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _pickImage(isBackdrop: true),
            icon: const Icon(Icons.panorama_outlined),
            label: Text(LunoraLocalization.text('Выбрать фон')),
          ),
          if (_backdropPath != null)
            TextButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => setState(() => _backdropPath = null),
              icon: const Icon(Icons.delete_outline),
              label: Text(LunoraLocalization.text('Убрать фон')),
            ),
        ],
      ),
    );
  }

  Widget _imagePreview({
    required String? path,
    required double width,
    required double height,
    required IconData icon,
  }) {
    final exists = path != null && path.isNotEmpty && File(path).existsSync();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: exists
          ? Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _imagePlaceholder(icon),
            )
          : _imagePlaceholder(icon),
    );
  }

  Widget _imagePlaceholder(IconData icon) {
    return Center(
      child: Icon(
        icon,
        size: 54,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return LunoraLocalization.text('Заполни это поле', 'Fill in this field');
              }

              return null;
            }
          : null,
    );
  }

  Widget _buildDateTile() {
    final formattedDate = _watchedAt == null
        ? LunoraLocalization.text('Не указана', 'Not specified')
        : '${_watchedAt!.day.toString().padLeft(2, '0')}.'
              '${_watchedAt!.month.toString().padLeft(2, '0')}.'
              '${_watchedAt!.year}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(LunoraLocalization.text('Дата просмотра')),
      subtitle: Text(formattedDate),
      leading: const Icon(Icons.calendar_today_outlined),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: LunoraLocalization.text('Выбрать дату'),
            onPressed: _pickDate,
            icon: const Icon(Icons.edit_calendar_outlined),
          ),
          if (_watchedAt != null)
            IconButton(
              tooltip: LunoraLocalization.text('Очистить дату'),
              onPressed: () {
                setState(() => _watchedAt = null);
              },
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}
