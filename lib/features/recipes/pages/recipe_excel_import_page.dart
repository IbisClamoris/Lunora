import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/lunora_localization.dart';

import '../../../core/import_export/services/excel_service.dart';
import '../services/recipe_excel_import_service.dart';

class RecipeExcelImportPage extends StatefulWidget {
  const RecipeExcelImportPage({super.key});

  @override
  State<RecipeExcelImportPage> createState() => _RecipeExcelImportPageState();
}

class _RecipeExcelImportPageState extends State<RecipeExcelImportPage> {
  bool _isImporting = false;
  String? _fileName;
  String? _error;

  Future<void> _selectAndImport() async {
    if (_isImporting) return;

    setState(() {
      _isImporting = true;
      _error = null;
    });

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xlsm'],
      );

      if (!mounted) return;

      if (file == null) {
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final path = file.path;

      if (path == null || path.isEmpty) {
        throw Exception('Не удалось получить путь к файлу.');
      }

      setState(() {
        _fileName = file.name;
      });

      final document = await ExcelService.instance.readWorkbook(File(path));

      final result = await RecipeExcelImportService.instance.importWorkbook(
        document,
      );

      if (!mounted) return;

      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LunoraLocalization.text('Импорт рецептов', 'Import recipes'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  LunoraLocalization.text('Импорт книги рецептов'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  '${LunoraLocalization.text('Выбери Excel-файл книги рецептов. ')}Lunora импортирует рецепты, ингредиенты, избранное и план питания.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                if (_fileName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _fileName!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_isImporting) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    LunoraLocalization.text('Импортируем данные...'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],

                FilledButton.icon(
                  onPressed: _isImporting ? null : _selectAndImport,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_upload_outlined),
                  label: Text(
                    _isImporting ? 'Импортирование...' : 'Выбрать Excel-файл',
                  ),
                ),

                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed: _isImporting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(LunoraLocalization.text('Отмена', 'Cancel')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
