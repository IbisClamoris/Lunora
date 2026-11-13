import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/diary_entry.dart';
import '../repositories/diary_repository.dart';
import '../../../shared/widgets/lunora_visuals.dart';

class DiaryEditorPage extends StatefulWidget {
  final DiaryEntry? entry;

  const DiaryEditorPage({super.key, this.entry});

  @override
  State<DiaryEditorPage> createState() => _DiaryEditorPageState();
}

class _DiaryEditorPageState extends State<DiaryEditorPage> {
  final _repository = DiaryRepository.instance;
  final _formKey = GlobalKey<FormState>();

  static const String _contentPrefix = 'quill:v1:';

  late final TextEditingController _titleController;
  late final TextEditingController _tagController;
  late final QuillController _quillController;

  late DateTime _entryDate;

  String? _mood;
  String _category = 'Без категории';
  String _entryType = 'diary';
  bool _isFavorite = false;
  bool _isSaving = false;
  bool _isAddingImage = false;

  final List<String> _tags = [];

  bool get _isEditing => widget.entry != null;

  static const List<String> _moods = [
    'Радость',
    'Спокойствие',
    'Вдохновение',
    'Благодарность',
    'Усталость',
    'Грусть',
    'Тревога',
    'Злость',
    'Ностальгия',
    'Смешанные чувства',
  ];

  static const List<String> _categories = [
    'Без категории',
    'Семья',
    'Дом',
    'Друзья',
    'Работа',
    'Учёба',
    'Путешествия',
    'Достижения',
    'Впечатления',
    'Мысли',
    'Другое',
  ];

  @override
  void initState() {
    super.initState();

    final entry = widget.entry;

    _titleController = TextEditingController(text: entry?.title ?? '');

    _tagController = TextEditingController();

    _quillController = _createQuillController(entry?.content ?? '');

    _entryDate = entry?.entryDate ?? DateTime.now();

    final savedMood = entry?.mood?.trim();
    _mood = savedMood == null || savedMood.isEmpty ? null : savedMood;

    _category = entry?.category ?? 'Без категории';
    _entryType = entry?.entryType ?? 'diary';
    _isFavorite = entry?.isFavorite ?? false;

    if (entry != null) {
      _tags.addAll(entry.tags);
    }
  }

  QuillController _createQuillController(String content) {
    Document document;

    if (content.startsWith(_contentPrefix)) {
      try {
        final decoded = jsonDecode(content.substring(_contentPrefix.length));

        if (decoded is! List || decoded.isEmpty) {
          throw const FormatException('Некорректный Delta');
        }

        document = Document.fromJson(decoded);
      } catch (_) {
        document = _createPlainTextDocument(content);
      }
    } else {
      document = _createPlainTextDocument(content);
    }

    return QuillController(
      document: document,
      selection: TextSelection.collapsed(offset: document.length - 1),
    );
  }

  Document _createPlainTextDocument(String content) {
    return Document.fromJson([
      {'insert': content.endsWith('\n') ? content : '$content\n'},
    ]);
  }

  String _getFormattedContent() {
    final delta = _quillController.document.toDelta().toJson();

    return '$_contentPrefix${jsonEncode(delta)}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Дата записи',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (selected != null && mounted) {
      setState(() {
        _entryDate = selected;
      });
    }
  }

  Future<void> _insertImage() async {
    if (_isAddingImage) return;

    setState(() {
      _isAddingImage = true;
    });

    try {
      final pickedFile = await FilePicker.pickFile(type: FileType.image);

      if (pickedFile == null) return;

      final sourcePath = pickedFile.path;

      if (sourcePath == null || sourcePath.isEmpty) {
        throw Exception('Не удалось получить путь к изображению.');
      }

      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        throw Exception('Выбранный файл не найден.');
      }

      final attachmentsDirectory =
          await StorageService.instance.attachmentsDirectory;

      final extension = p.extension(sourcePath).toLowerCase();
      final safeExtension = extension.isEmpty ? '.png' : extension;

      final fileName =
          'diary_${DateTime.now().microsecondsSinceEpoch}$safeExtension';

      final destinationPath = p.join(attachmentsDirectory.path, fileName);

      final copiedFile = await sourceFile.copy(destinationPath);

      if (!mounted) return;

      final document = _quillController.document;
      final selection = _quillController.selection;

      final index = selection.baseOffset.clamp(0, document.length - 1);

      document.insert(index, BlockEmbed.image(copiedFile.path));

      _quillController.updateSelection(
        TextSelection.collapsed(offset: index + 1),
        ChangeSource.local,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось добавить фотографию: $e'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingImage = false;
        });
      }
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();

    if (tag.isEmpty) return;

    if (_tags.any((existing) => existing.toLowerCase() == tag.toLowerCase())) {
      _tagController.clear();
      return;
    }

    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    _addTag();

    setState(() {
      _isSaving = true;
    });

    try {
      final content = _getFormattedContent();

      if (_isEditing) {
        final updatedEntry = widget.entry!.copyWith(
          title: _titleController.text.trim(),
          content: content,
          entryDate: _entryDate,
          updatedAt: DateTime.now(),
          mood: _mood,
          clearMood: _mood == null,
          category: _category,
          entryType: _entryType,
          isFavorite: _isFavorite,
          tags: [..._tags],
        );

        await _repository.update(updatedEntry);
      } else {
        await _repository.create(
          title: _titleController.text.trim(),
          content: content,
          entryDate: _entryDate,
          mood: _mood,
          category: _category,
          entryType: _entryType,
          isFavorite: _isFavorite,
          tags: [..._tags],
        );
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
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTextEditor(LunoraPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: palette.sagePanel.withValues(alpha: 0.72),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: QuillSimpleToolbar(
                    controller: _quillController,
                    config: const QuillSimpleToolbarConfig(
                      multiRowsDisplay: true,
                      showFontFamily: false,
                      showFontSize: false,
                      showSmallButton: false,
                      showInlineCode: false,
                      showBackgroundColorButton: true,
                      showBoldButton: true,
                      showItalicButton: true,
                      showUnderLineButton: true,
                      showStrikeThrough: true,
                      showColorButton: true,
                      showClearFormat: true,
                      showAlignmentButtons: true,
                      showHeaderStyle: true,
                      showListNumbers: true,
                      showListBullets: true,
                      showListCheck: true,
                      showCodeBlock: false,
                      showQuote: true,
                      showIndent: true,
                      showLink: true,
                      showUndo: true,
                      showRedo: true,
                      showSearchButton: false,
                      showSubscript: false,
                      showSuperscript: false,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: IconButton(
                    onPressed: _isAddingImage ? null : _insertImage,
                    tooltip: LunoraLocalization.text('Вставить фотографию'),
                    icon: _isAddingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image_outlined),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),
          SizedBox(
            height: 380,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: QuillEditor.basic(
                controller: _quillController,
                config: QuillEditorConfig(
                  placeholder: 'Запиши свои мысли, события и впечатления...',
                  padding: EdgeInsets.zero,
                  embedBuilders: const [DiaryImageEmbedBuilder()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    final categories = [
      ..._categories,
      if (!_categories.contains(_category)) _category,
    ];

    final moods = <String>[
      ..._moods,
      if (_mood != null && _mood!.isNotEmpty && !_moods.contains(_mood)) _mood!,
    ];

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактирование записи' : 'Новая запись'),
        backgroundColor: palette.background,
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(LunoraLocalization.text('Сохранить')),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: LunoraPaperSurface(
              color: palette.surface,
              borderRadius: 22,
              textureOpacity: 0.12,
              padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: palette.sagePanel,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: palette.accent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEditing ? 'МОИ ВОСПОМИНАНИЯ' : 'МОЙ ДНЕВНИК',
                                style: TextStyle(
                                  color: palette.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isEditing
                                    ? 'Редактирование записи'
                                    : 'Новая запись',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: palette.text,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const LunoraBotanicalDivider(variant: 4, height: 32),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(_formatDate(_entryDate)),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        side: BorderSide(color: palette.border),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Тип записи'),
                    DropdownButtonFormField<String>(
                      initialValue: _entryType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'diary',
                          child: Text(
                            LunoraLocalization.text('📖 Дневниковая запись'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'memory',
                          child: Text(
                            LunoraLocalization.text('✨ Воспоминание'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _entryType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('Настроение'),
                    DropdownButtonFormField<String>(
                      initialValue: _mood ?? '',
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: LunoraLocalization.text('Выбери настроение'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(LunoraLocalization.text('Не выбрано')),
                        ),
                        ...moods.map(
                          (mood) =>
                              DropdownMenuItem(value: mood, child: Text(mood)),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _mood = value == null || value.isEmpty ? null : value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('Категория'),
                    DropdownButtonFormField<String>(
                      initialValue: categories.contains(_category)
                          ? _category
                          : 'Без категории',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _category = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(LunoraLocalization.text('Любимый момент')),
                      subtitle: Text(
                        LunoraLocalization.text('Добавить запись в избранное'),
                      ),
                      secondary: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite
                            ? Colors.pinkAccent
                            : palette.secondary,
                      ),
                      value: _isFavorite,
                      onChanged: (value) {
                        setState(() {
                          _isFavorite = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Теги'),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: LunoraLocalization.text(
                                'Например: лето, семья, поездка',
                              ),
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _addTag,
                          icon: const Icon(Icons.add),
                          tooltip: LunoraLocalization.text('Добавить тег'),
                        ),
                      ],
                    ),
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags
                            .map(
                              (tag) => InputChip(
                                label: Text(tag),
                                onDeleted: () => _removeTag(tag),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _sectionTitle('Заголовок'),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: LunoraLocalization.text(
                          'О чём сегодняшний день?',
                        ),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 120,
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Запись'),
                    _buildTextEditor(palette),
                    const SizedBox(height: 12),
                    const LunoraBotanicalDivider(variant: 7, height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DiaryImageEmbedBuilder extends EmbedBuilder {
  const DiaryImageEmbedBuilder();

  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final imagePath = embedContext.node.value.data.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined),
                  SizedBox(width: 8),
                  Text(
                    LunoraLocalization.text('Не удалось загрузить фотографию'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
