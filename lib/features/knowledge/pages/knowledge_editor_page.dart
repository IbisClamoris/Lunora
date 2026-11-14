import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';

import '../models/knowledge_entry.dart';
import '../repositories/knowledge_repository.dart';

class KnowledgeEditorPage extends StatefulWidget {
  final KnowledgeEntry? entry;

  const KnowledgeEditorPage({super.key, this.entry});

  @override
  State<KnowledgeEditorPage> createState() => _KnowledgeEditorPageState();
}

class _KnowledgeEditorPageState extends State<KnowledgeEditorPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _sourceUrlController = TextEditingController();

  final KnowledgeRepository _repository = KnowledgeRepository.instance;

  String _selectedCategory = LunoraLocalization.text('Другое', 'Other');
  bool _isSaving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();

    final entry = widget.entry;

    if (entry != null) {
      _titleController.text = entry.title;
      _contentController.text = entry.content;
      _selectedCategory = entry.category;
      _tagsController.text = entry.tags.join(', ');
      _sourceUrlController.text = entry.sourceUrl ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _sourceUrlController.dispose();
    super.dispose();
  }

  List<String> _parseTags() {
    return _tagsController.text
        .split(RegExp(r'[,;]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();
      final tags = _parseTags();
      final sourceUrl = _sourceUrlController.text.trim();

      if (_isEditing) {
        final updatedEntry = widget.entry!.copyWith(
          title: title,
          content: content,
          category: _selectedCategory,
          tags: tags,
          sourceUrl: sourceUrl.isEmpty ? null : sourceUrl,
        );

        await _repository.update(updatedEntry);
      } else {
        await _repository.create(
          title: title,
          content: content,
          category: _selectedCategory,
          tags: tags,
          sourceUrl: sourceUrl.isEmpty ? null : sourceUrl,
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

      setState(() => _isSaving = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  InputDecoration _decoration(String hint, {Widget? prefixIcon}) {
    final colors = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: colors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(15),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? LunoraLocalization.text('Редактирование записи') : LunoraLocalization.text('Новая запись')),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveEntry,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(LunoraLocalization.text('Сохранить')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionTitle(LunoraLocalization.text('Название')),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(
                    LunoraLocalization.text('Например, Основные формулы физики', 'For example, Basic physics formulas'),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return LunoraLocalization.text('Введите название записи', 'Enter an entry title');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 22),

                _buildSectionTitle(LunoraLocalization.text('Категория')),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: _decoration(
                    LunoraLocalization.text('Выберите категорию', 'Choose a category'),
                    prefixIcon: const Icon(Icons.folder_outlined),
                  ),
                  items: KnowledgeEntry.categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),

                const SizedBox(height: 22),

                _buildSectionTitle(LunoraLocalization.text('Содержимое')),
                TextFormField(
                  controller: _contentController,
                  minLines: 10,
                  maxLines: 25,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(
                    LunoraLocalization.text('Добавь текст, заметки, формулы или другую информацию...', 'Add text, notes, formulas, or other information...'),
                  ),
                  keyboardType: TextInputType.multiline,
                ),

                const SizedBox(height: 22),

                _buildSectionTitle(LunoraLocalization.text('Теги')),
                TextFormField(
                  controller: _tagsController,
                  decoration:
                      _decoration(
                        LunoraLocalization.text('Например: экзамен, важное, теория', 'For example: exam, important, theory'),
                        prefixIcon: const Icon(Icons.sell_outlined),
                      ).copyWith(
                        helperText: LunoraLocalization.text(
                          LunoraLocalization.text('Разделяй теги запятыми или точками с запятой', 'Separate tags with commas or semicolons'),
                        ),
                      ),
                ),

                const SizedBox(height: 22),

                _buildSectionTitle(LunoraLocalization.text('Источник')),
                TextFormField(
                  controller: _sourceUrlController,
                  keyboardType: TextInputType.url,
                  decoration: _decoration(
                    'https://example.com',
                    prefixIcon: const Icon(Icons.link),
                  ),
                  validator: (value) {
                    final url = value?.trim() ?? '';

                    if (url.isEmpty) return null;

                    final uri = Uri.tryParse(url);

                    if (uri == null ||
                        !uri.hasScheme ||
                        (uri.scheme != 'http' && uri.scheme != 'https') ||
                        uri.host.isEmpty) {
                      return 'Введите корректную ссылку с http:// или https://';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 30),

                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveEntry,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isEditing ? LunoraLocalization.text('Сохранить изменения', 'Save changes') : LunoraLocalization.text('Создать запись', 'Create entry'),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  LunoraLocalization.text(
                    LunoraLocalization.text('Запись будет сохранена в твоей библиотеке знаний.', 'The entry will be saved in your knowledge library.'),
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
