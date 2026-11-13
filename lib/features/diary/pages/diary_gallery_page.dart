import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/diary_entry.dart';
import '../repositories/diary_repository.dart';
import '../../../shared/widgets/lunora_section_header.dart';
import '../../../shared/widgets/lunora_visuals.dart';
import 'diary_preview_page.dart';

class DiaryGalleryPage extends StatefulWidget {
  const DiaryGalleryPage({super.key});

  @override
  State<DiaryGalleryPage> createState() => _DiaryGalleryPageState();
}

class _DiaryGalleryPageState extends State<DiaryGalleryPage> {
  static const String _contentPrefix = 'quill:v1:';

  bool _isLoading = true;
  List<_DiaryPhoto> _photos = [];

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final entries = await DiaryRepository.instance.getAll();
      final photos = <_DiaryPhoto>[];

      for (final entry in entries) {
        final paths = _extractImagePaths(entry.content);

        for (final path in paths) {
          final file = File(path);

          if (await file.exists()) {
            photos.add(_DiaryPhoto(entry: entry, path: path));
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Ошибка загрузки галереи: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _photos = [];
        _isLoading = false;
      });
    }
  }

  List<String> _extractImagePaths(String content) {
    if (!content.startsWith(_contentPrefix)) {
      return [];
    }

    try {
      final json = content.substring(_contentPrefix.length);
      final operations = jsonDecode(json);

      if (operations is! List) return [];

      final paths = <String>[];

      for (final operation in operations) {
        if (operation is! Map) continue;

        final insert = operation['insert'];

        if (insert is! Map) continue;

        final imagePath = insert['image'];

        if (imagePath is String && imagePath.isNotEmpty) {
          paths.add(imagePath);
        }
      }

      return paths;
    } catch (error) {
      debugPrint('Ошибка чтения изображений записи: $error');
      return [];
    }
  }

  Future<void> _openPhoto(_DiaryPhoto photo) async {
    final file = File(photo.path);

    if (!await file.exists()) {
      await _loadPhotos();
      return;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: Colors.white,
                    );
                  },
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: LunoraLocalization.text('Закрыть'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEntry(_DiaryPhoto photo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DiaryPreviewPage(entry: photo.entry)),
    );

    await _loadPhotos();
  }

  Future<void> _deletePhoto(_DiaryPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(LunoraLocalization.text('Удалить фотографию?')),
          content: Text(
            LunoraLocalization.text(
              'Фотография будет удалена из записи и из хранилища Lunora. Это действие нельзя отменить.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(LunoraLocalization.text('Удалить')),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final repository = DiaryRepository.instance;
      final currentEntry = await repository.getById(photo.entry.id);

      if (currentEntry == null) {
        await _loadPhotos();
        return;
      }

      final updatedContent = _removeImageFromContent(
        currentEntry.content,
        photo.path,
      );

      if (updatedContent == currentEntry.content) {
        await _loadPhotos();
        return;
      }

      await repository.update(currentEntry.copyWith(content: updatedContent));

      final allEntries = await repository.getAll();

      final stillUsed = allEntries.any(
        (entry) => _extractImagePaths(entry.content).contains(photo.path),
      );

      if (!stillUsed) {
        final file = File(photo.path);

        if (await file.exists()) {
          await file.delete();
        }
      }

      if (!mounted) return;

      await _loadPhotos();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text('Фотография удалена'))),
      );
    } catch (error, stackTrace) {
      debugPrint('Ошибка удаления фотографии: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось удалить фотографию'),
          ),
        ),
      );
    }
  }

  String _removeImageFromContent(String content, String imagePath) {
    if (!content.startsWith(_contentPrefix)) {
      return content;
    }

    try {
      final json = content.substring(_contentPrefix.length);
      final decoded = jsonDecode(json);

      if (decoded is! List) return content;

      final filtered = decoded.where((operation) {
        if (operation is! Map) return true;

        final insert = operation['insert'];

        if (insert is! Map) return true;

        return insert['image'] != imagePath;
      }).toList();

      return _contentPrefix + jsonEncode(filtered);
    } catch (error) {
      debugPrint('Ошибка изменения содержимого записи: $error');
      return content;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LunoraSectionHeader(
            title: LunoraLocalization.text('Галерея дневника'),
            subtitle: LunoraLocalization.text(
              'Фотографии, иллюстрации и памятные моменты.',
            ),
            icon: Icons.photo_library_outlined,
            actions: [
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loadPhotos,
                icon: const Icon(Icons.refresh),
                label: Text(LunoraLocalization.text('Обновить')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const LunoraBotanicalDivider(variant: 7, height: 34),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.photo_outlined, size: 18, color: palette.accent),
                const SizedBox(width: 8),
                Text(
                  LunoraLocalization.text('${_photos.length} фотографий'),
                  style: TextStyle(color: palette.secondary),
                ),
              ],
            ),
          ),
          Expanded(child: _buildGallery()),
        ],
      ),
    );
  }

  Widget _buildGallery() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              LunoraLocalization.text('Здесь пока нет фотографий'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              LunoraLocalization.text(
                'Добавляй фотографии в записи дневника,\nи они появятся здесь',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPhotos,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          final crossAxisCount = width >= 1100
              ? 5
              : width >= 800
              ? 4
              : width >= 520
              ? 3
              : 2;

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.78,
            ),
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              return _buildPhotoCard(_photos[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildPhotoCard(_DiaryPhoto photo) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;
    final title = photo.entry.title.trim().isEmpty
        ? 'Без названия'
        : photo.entry.title;

    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(color: palette.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => _openPhoto(photo),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F1E7),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: const Color(0xFFB99A72),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFD8C5A7),
                            width: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(photo.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 40,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 7,
                      top: 7,
                      child: Icon(
                        Icons.eco_outlined,
                        size: 17,
                        color: Color(0xFF8D9B7D),
                      ),
                    ),
                    const Positioned(
                      right: 7,
                      bottom: 7,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 15,
                        color: Color(0xFFB78F88),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: () => _deletePhoto(photo),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                          tooltip: LunoraLocalization.text(
                            'Удалить фотографию',
                          ),
                          iconSize: 18,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(photo.entry.entryDate),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.secondary),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openEntry(photo),
                    icon: Icon(
                      Icons.menu_book_outlined,
                      color: palette.accent,
                      size: 19,
                    ),
                    tooltip: LunoraLocalization.text('Открыть запись'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaryPhoto {
  final DiaryEntry entry;
  final String path;

  const _DiaryPhoto({required this.entry, required this.path});
}
