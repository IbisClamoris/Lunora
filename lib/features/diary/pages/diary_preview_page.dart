import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/lunora_visuals.dart';
import '../models/diary_entry.dart';
import '../repositories/diary_repository.dart';
import 'diary_editor_page.dart';

class DiaryPreviewPage extends StatefulWidget {
  final DiaryEntry entry;

  const DiaryPreviewPage({super.key, required this.entry});

  @override
  State<DiaryPreviewPage> createState() => _DiaryPreviewPageState();
}

class _DiaryPreviewPageState extends State<DiaryPreviewPage> {
  static const String _contentPrefix = 'quill:v1:';

  late DiaryEntry _entry;
  QuillController? _quillController;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _initializeContent();
  }

  void _initializeContent() {
    final content = _entry.content;

    if (!content.startsWith(_contentPrefix)) {
      return;
    }

    try {
      final json =
          jsonDecode(content.substring(_contentPrefix.length)) as List<dynamic>;

      final document = Document.fromJson(json);

      _quillController = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (error) {
      debugPrint('Ошибка чтения записи дневника: $error');
    }
  }

  @override
  void dispose() {
    _quillController?.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  String _entryTypeLabel(String type) {
    return type == 'memory' ? 'Воспоминание' : 'Дневниковая запись';
  }

  Widget _metadataChip(String label, LunoraPalette palette, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: palette.secondary),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(color: palette.text, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _editEntry() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DiaryEditorPage(entry: _entry)),
    );

    if (result != true || !mounted) return;

    final updatedEntry = await DiaryRepository.instance.getById(_entry.id);

    if (!mounted || updatedEntry == null) return;

    setState(() {
      _entry = updatedEntry;
      _quillController?.dispose();
      _quillController = null;
      _initializeContent();
    });
  }

  Widget _buildEntryContent(LunoraPalette palette) {
    if (_entry.content.trim().isEmpty) {
      return Text(
        LunoraLocalization.text('В этой записи пока нет текста.'),
        style: TextStyle(color: palette.secondary, fontStyle: FontStyle.italic),
      );
    }

    if (_entry.content.startsWith(_contentPrefix)) {
      if (_quillController != null) {
        return QuillEditor.basic(
          controller: _quillController!,
          config: QuillEditorConfig(
            padding: EdgeInsets.zero,
            expands: false,
            embedBuilders: const [DiaryPreviewImageEmbedBuilder()],
          ),
        );
      }

      return Text(
        LunoraLocalization.text(
          'Не удалось отобразить содержимое этой записи.',
        ),
        style: TextStyle(color: palette.secondary),
      );
    }

    return SelectableText(
      _entry.content,
      style: TextStyle(color: palette.text, fontSize: 15, height: 1.7),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(LunoraLocalization.text('Запись дневника')),
        backgroundColor: palette.background,
        actions: [
          IconButton(
            tooltip: LunoraLocalization.text('Редактировать'),
            onPressed: _editEntry,
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Card(
                color: palette.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: palette.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _entry.title.isEmpty
                                  ? 'Без названия'
                                  : _entry.title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          if (_entry.isFavorite)
                            const Icon(
                              Icons.favorite,
                              color: Colors.pinkAccent,
                              size: 22,
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Text(
                        _formatDate(_entry.entryDate),
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metadataChip(
                            _entryTypeLabel(_entry.entryType),
                            palette,
                            icon: _entry.entryType == 'memory'
                                ? Icons.auto_awesome_outlined
                                : Icons.menu_book_outlined,
                          ),
                          if (_entry.category != 'Без категории')
                            _metadataChip(
                              _entry.category,
                              palette,
                              icon: Icons.folder_outlined,
                            ),
                          if (_entry.mood != null && _entry.mood!.isNotEmpty)
                            _metadataChip(
                              _entry.mood!,
                              palette,
                              icon: Icons.mood_outlined,
                            ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      const SizedBox(height: 8),
                      const LunoraBotanicalDivider(variant: 9, height: 30),
                      const SizedBox(height: 16),

                      _buildEntryContent(palette),

                      if (_entry.tags.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const LunoraBotanicalDivider(variant: 3, height: 28),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _entry.tags
                              .map(
                                (tag) => _metadataChip(
                                  '#$tag',
                                  palette,
                                  icon: Icons.tag,
                                ),
                              )
                              .toList(),
                        ),
                      ],

                      const SizedBox(height: 28),

                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _editEntry,
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(
                            LunoraLocalization.text('Редактировать запись'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DiaryPreviewImageEmbedBuilder extends EmbedBuilder {
  const DiaryPreviewImageEmbedBuilder();

  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final imagePath = embedContext.node.value.data.toString();
    final imageFile = File(imagePath);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 460),
          child: GestureDetector(
            onTap: () {
              if (!imageFile.existsSync()) return;

              showDialog<void>(
                context: context,
                barrierColor: Colors.black87,
                builder: (dialogContext) {
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(24),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4,
                          child: Image.file(
                            imageFile,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: LunoraLocalization.text('Закрыть'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFF4EBDD),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFB9A184), width: 1.3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 9,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF6),
                  border: Border.all(color: const Color(0xFFD8C6AA)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        color: const Color(0xFFF7F1E8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined),
                            SizedBox(width: 8),
                            Text(
                              LunoraLocalization.text('Фотография недоступна'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
