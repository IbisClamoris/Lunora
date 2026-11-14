import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:lunora/core/import_export/services/excel_service.dart';

import '../services/finance_excel_import_service.dart';

class FinanceExcelImportPage extends StatefulWidget {
  const FinanceExcelImportPage({super.key});

  @override
  State<FinanceExcelImportPage> createState() => _FinanceExcelImportPageState();
}

class _FinanceExcelImportPageState extends State<FinanceExcelImportPage> {
  bool _isImporting = false;
  String? _selectedFileName;

  Future<void> _selectAndImport() async {
    if (_isImporting) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xlsm'],
        dialogTitle: LunoraLocalization.text('Выберите финансовую книгу Excel'),
      );

      if (files.isEmpty) return;

      final selectedFile = files.first;
      final path = selectedFile.path;

      if (path == null || path.isEmpty) {
        throw Exception('Не удалось получить путь к файлу.');
      }

      if (!mounted) return;

      setState(() {
        _selectedFileName = selectedFile.name;
      });

      final document = await ExcelService.instance.readWorkbook(File(path));

      final budgetSheet = document.sheets.where((sheet) {
        final name = sheet.name.trim().toLowerCase().replaceAll('ё', 'е');

        return name == 'бюджет';
      }).firstOrNull;

      DateTime? budgetPeriod;

      if (budgetSheet != null && budgetSheet.rows.length > 1) {
        if (!mounted) return;

        budgetPeriod = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          helpText: LunoraLocalization.text('Выберите месяц бюджета'),
          cancelText: LunoraLocalization.text('Отмена'),
          confirmText: LunoraLocalization.text('Выбрать'),
        );

        if (budgetPeriod == null) return;

        budgetPeriod = DateTime(budgetPeriod.year, budgetPeriod.month);
      }

      if (!mounted) return;

      final result = await FinanceExcelImportService.instance.importWorkbook(
        document,
        budgetPeriod: budgetPeriod,
      );

      if (!mounted) return;

      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LunoraLocalization.text('Ошибка импорта: $error')),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    return Scaffold(
      appBar: AppBar(title: Text(LunoraLocalization.text('Импорт финансов'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.table_view_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  LunoraLocalization.text('Импорт из Excel'),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '${LunoraLocalization.text('Выберите финансовую книгу Excel. ')}Lunora обработает счета, операции, кредиты, бюджеты и накопления.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (_selectedFileName != null) ...[
                  Text(
                    LunoraLocalization.text('Выбран файл:'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedFileName!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isImporting ? null : _selectAndImport,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_open_rounded),
                    label: Text(
                      _isImporting
                          ? 'Импорт выполняется...'
                          : 'Выбрать Excel-файл',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  LunoraLocalization.text('Поддерживаются файлы .xlsx и .xlsm'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
