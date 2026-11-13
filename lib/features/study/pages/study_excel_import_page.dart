import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:lunora/core/import_export/services/excel_service.dart';
import 'package:lunora/features/study/services/study_excel_import_service.dart';

class StudyExcelImportPage extends StatefulWidget {
  const StudyExcelImportPage({super.key});

  @override
  State<StudyExcelImportPage> createState() => _StudyExcelImportPageState();
}

class _StudyExcelImportPageState extends State<StudyExcelImportPage> {
  bool _isImporting = false;
  String? _error;

  Future<void> _pickAndImport() async {
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

      if (file == null) return;

      final path = file.path;

      if (path == null || path.isEmpty) {
        throw Exception('Не удалось получить путь к файлу.');
      }

      final document = await ExcelService.instance.readWorkbook(File(path));

      final importResult = await StudyExcelImportService.instance
          .importWorkbook(document);

      if (!mounted) return;

      Navigator.of(context).pop(importResult);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Не удалось импортировать файл:\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(LunoraLocalization.text('Импорт учебного плана')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  LunoraLocalization.text('Импорт учебных данных'),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '${LunoraLocalization.text('Выбери Excel-файл с учебными предметами, ')}периодами и событиями.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(LunoraLocalization.text('Поддерживаемые листы:')),
                      SizedBox(height: 10),
                      Text(LunoraLocalization.text('• Предметы')),
                      Text(LunoraLocalization.text('• Учебные периоды')),
                      Text(LunoraLocalization.text('• События и задания')),
                      SizedBox(height: 12),
                      Text(
                        LunoraLocalization.text(
                          'Форматы файлов: .xlsx и .xlsm',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isImporting ? null : _pickAndImport,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_open_outlined),
                    label: Text(
                      _isImporting ? 'Импортируем...' : 'Выбрать Excel-файл',
                    ),
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
