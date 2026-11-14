import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/import_export/models/export_document.dart';
import '../../core/import_export/services/excel_service.dart';
import '../../core/import_export/services/export_preparation_service.dart';

class ExportPage extends StatefulWidget {
  final ExportDocument document;

  const ExportPage({super.key, required this.document});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  static const double _contentMaxWidth = 1100;
  static const double _wideLayoutBreakpoint = 850;

  late final TextEditingController _fileNameController;
  late List<bool> _selectedSheets;

  bool _isExporting = false;

  int get _selectedSheetCount {
    return _selectedSheets.where((selected) => selected).length;
  }

  int get _selectedRowCount {
    var total = 0;

    for (var index = 0; index < _selectedSheets.length; index++) {
      if (_selectedSheets[index]) {
        total += widget.document.sheets[index].data.rowCount;
      }
    }

    return total;
  }

  bool get _canExport {
    return !_isExporting &&
        _selectedSheetCount > 0 &&
        _fileNameController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    _fileNameController = TextEditingController(text: widget.document.fileName);

    _selectedSheets = widget.document.sheets
        .map((sheet) => sheet.isSelected)
        .toList();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  void _toggleSheet(int index, bool? value) {
    if (value == null || _isExporting) return;

    setState(() {
      _selectedSheets[index] = value;
    });
  }

  void _selectAllSheets(bool selected) {
    if (_isExporting) return;

    setState(() {
      _selectedSheets = List<bool>.filled(
        widget.document.sheets.length,
        selected,
      );
    });
  }

  String _normalizedFileName() {
    var name = _fileNameController.text.trim();

    name = name.replaceFirst(
      RegExp(r'\.(xlsx|xlsm)$', caseSensitive: false),
      '',
    );

    return '$name.xlsx';
  }

  ExportDocument _createExportDocument() {
    final updatedSheets = <ExportSheetOption>[];

    for (var index = 0; index < widget.document.sheets.length; index++) {
      final original = widget.document.sheets[index];

      updatedSheets.add(original.copyWith(isSelected: _selectedSheets[index]));
    }

    return widget.document.copyWith(
      fileName: _normalizedFileName(),
      sheets: updatedSheets,
    );
  }

  Future<void> _export() async {
    if (!_canExport) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final exportDocument = _createExportDocument();

      ExportPreparationService.instance.validate(exportDocument);

      final exportedFile = await ExcelService.instance.exportWorkbook(
        fileName: exportDocument.fileName,
        sheets: exportDocument.selectedSheets,
        sourceModule: exportDocument.sourceModule,
      );

      if (!mounted) return;

      await _showSaveLocationDialog(exportedFile);
    } catch (error) {
      if (!mounted) return;

      _showMessage('Не удалось выполнить экспорт: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _showSaveLocationDialog(File exportedFile) async {
    try {
      final bytes = await exportedFile.readAsBytes();

      if (!mounted) return;

      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Сохранить Excel-файл',
        fileName: exportedFile.uri.pathSegments.last,
        bytes: bytes,
      );

      if (!mounted) return;

      if (savedUri == null) {
        _showMessage(
          'Экспорт завершён. Внутренняя копия сохранена в папке Lunora.',
        );
        return;
      }

      await _showExportSuccess(exportedFile);
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Внутренняя копия создана, но не удалось сохранить файл '
        'в выбранное место: $error',
      );
    }
  }

  Future<void> _showExportSuccess(File exportedFile) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
          title: Text(LunoraLocalization.text('Экспорт завершён')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(LunoraLocalization.text('Excel-файл успешно сохранён.')),
              const SizedBox(height: 16),
              _resultInfo('Листов', _selectedSheetCount.toString()),
              const SizedBox(height: 8),
              _resultInfo('Строк', _selectedRowCount.toString()),
              const SizedBox(height: 16),
              Text(
                LunoraLocalization.text('Внутренняя копия Lunora:'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                exportedFile.path,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(LunoraLocalization.text('Закрыть')),
            ),
          ],
        );
      },
    );
  }

  Widget _resultInfo(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(LunoraLocalization.text(message))));
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.file_download_outlined,
                  size: 34,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LunoraLocalization.text('Экспорт данных'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.document.sourceModule,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                const Icon(Icons.table_chart_outlined),
                const SizedBox(width: 10),
                Expanded(child: Text(LunoraLocalization.text('Формат файла'))),
                Text(
                  'Excel (.xlsx)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileNameCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LunoraLocalization.text('Название файла'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fileNameController,
              enabled: !_isExporting,
              decoration: InputDecoration(
                labelText: LunoraLocalization.text('Имя файла'),
                hintText: LunoraLocalization.text('Мои данные'),
                prefixIcon: Icon(Icons.description_outlined),
                suffixText: '.xlsx',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            Text(
              LunoraLocalization.text('Файл будет сохранён в формате XLSX.'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetsCard() {
    final sheets = widget.document.sheets;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    LunoraLocalization.text('Содержимое экспорта'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  LunoraLocalization.text(
                    '$_selectedSheetCount из ${sheets.length}',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                TextButton(
                  onPressed: _isExporting ? null : () => _selectAllSheets(true),
                  child: Text(LunoraLocalization.text('Выбрать всё')),
                ),
                TextButton(
                  onPressed: _isExporting
                      ? null
                      : () => _selectAllSheets(false),
                  child: Text(LunoraLocalization.text('Снять выбор')),
                ),
              ],
            ),
            const Divider(),
            ...List.generate(sheets.length, (index) {
              final sheet = sheets[index];

              return CheckboxListTile(
                value: _selectedSheets[index],
                onChanged: _isExporting
                    ? null
                    : (value) => _toggleSheet(index, value),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  sheet.data.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${LunoraLocalization.text('${sheet.data.rowCount} строк · ')}${sheet.data.columnCount} колонок',
                ),
                secondary: Icon(
                  Icons.table_chart_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LunoraLocalization.text('Итог экспорта'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _summaryRow(
              Icons.table_chart_outlined,
              'Выбрано листов',
              _selectedSheetCount.toString(),
            ),
            const SizedBox(height: 12),
            _summaryRow(
              Icons.format_list_numbered,
              'Строк для экспорта',
              _selectedRowCount.toString(),
            ),
            const SizedBox(height: 12),
            _summaryRow(Icons.insert_drive_file_outlined, 'Формат', 'XLSX'),
            if (_selectedSheetCount == 0) ...[
              const SizedBox(height: 16),
              Text(
                LunoraLocalization.text(
                  'Выбери хотя бы один лист для экспорта.',
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _canExport ? _export : null,
        icon: _isExporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.file_download_outlined),
        label: Text(_isExporting ? LunoraLocalization.text('Подготовка файла...') : LunoraLocalization.text('Экспортировать')),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildContent(bool isWide) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: _buildSheetsCard()),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFileNameCard(),
                const SizedBox(height: 12),
                _buildSummaryCard(),
                const SizedBox(height: 16),
                _buildExportButton(),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFileNameCard(),
        const SizedBox(height: 12),
        _buildSheetsCard(),
        const SizedBox(height: 12),
        _buildSummaryCard(),
        const SizedBox(height: 16),
        _buildExportButton(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LunoraLocalization.text('Экспорт данных'))),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
          final horizontalPadding = constraints.maxWidth < 600 ? 12.0 : 20.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildContent(isWide),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
