import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/import_export/models/import_result.dart';
import '../../core/import_export/models/spreadsheet_document.dart';
import '../../core/import_export/services/excel_service.dart';
import '../../core/import_export/services/import_service.dart';

class ImportPreviewPage extends StatefulWidget {
  final List<String> targetFields;
  final List<String> requiredFields;
  final String sourceModule;
  final ImportTransactionHandler? importer;

  const ImportPreviewPage({
    super.key,
    this.targetFields = const [],
    this.requiredFields = const [],
    this.sourceModule = 'general',
    this.importer,
  });

  @override
  State<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends State<ImportPreviewPage> {
  static const double _contentMaxWidth = 1100;
  static const double _compactBreakpoint = 600;

  SpreadsheetDocument? _document;
  int _selectedSheetIndex = 0;

  final Map<int, String> _columnMappings = {};

  bool _isLoading = false;
  bool _isImporting = false;
  String? _errorMessage;

  SpreadsheetSheetData? get _selectedSheet {
    final document = _document;

    if (document == null ||
        document.sheets.isEmpty ||
        _selectedSheetIndex >= document.sheets.length) {
      return null;
    }

    return document.sheets[_selectedSheetIndex];
  }

  bool get _canImport {
    final sheet = _selectedSheet;

    if (sheet == null ||
        widget.importer == null ||
        widget.targetFields.isEmpty ||
        _isLoading ||
        _isImporting) {
      return false;
    }

    if (_getValidationErrors(sheet).isNotEmpty) {
      return false;
    }

    if (_columnMappings.isEmpty) {
      return false;
    }

    final mappedFields = _columnMappings.values.toSet();

    return widget.requiredFields.every(mappedFields.contains);
  }

  Future<void> _pickExcelFile() async {
    if (_isLoading || _isImporting) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xlsm'],
      );

      if (result.isEmpty) return;

      final path = result.first.path;

      if (path == null || path.isEmpty) {
        _showMessage('Не удалось получить путь к файлу.');
        return;
      }

      await _loadExcelFile(File(path));
    } catch (error) {
      if (!mounted) return;
      _showMessage('Ошибка выбора файла: $error');
    }
  }

  Future<void> _loadExcelFile(File file) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _document = null;
      _columnMappings.clear();
    });

    try {
      final document = await ExcelService.instance.readWorkbook(file);

      if (!mounted) return;

      setState(() {
        _document = document;
        _selectedSheetIndex = 0;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _document = null;
        _columnMappings.clear();
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _selectSheet(int? index) {
    if (index == null) return;

    setState(() {
      _selectedSheetIndex = index;
      _columnMappings.clear();
    });
  }

  void _updateMapping(int columnIndex, String? field) {
    setState(() {
      if (field == null || field.isEmpty) {
        _columnMappings.remove(columnIndex);
      } else {
        _columnMappings[columnIndex] = field;
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(LunoraLocalization.text(message))));
  }

  List<String> _getValidationErrors(SpreadsheetSheetData sheet) {
    final errors = <String>[];

    if (sheet.rows.isEmpty) {
      errors.add('Лист не содержит данных.');
      return errors;
    }

    if (sheet.rows.length < 2) {
      errors.add('В листе отсутствуют строки с данными.');
    }

    final headers = sheet.headers;

    if (headers.isEmpty) {
      errors.add('Не удалось определить заголовки колонок.');
      return errors;
    }

    for (var index = 0; index < headers.length; index++) {
      if (headers[index].trim().isEmpty) {
        errors.add('Не заполнен заголовок колонки ${index + 1}.');
      }
    }

    final normalizedHeaders = <String>{};

    for (final header in headers) {
      final normalized = header.trim().toLowerCase();

      if (normalized.isEmpty) continue;

      if (!normalizedHeaders.add(normalized)) {
        errors.add('Обнаружен повторяющийся заголовок "$header".');
      }
    }

    return errors;
  }

  int _countDataRows(SpreadsheetSheetData sheet) {
    if (sheet.rows.length <= 1) return 0;

    return sheet.rows.skip(1).where((row) {
      return row.any(
        (cell) => cell != null && cell.toString().trim().isNotEmpty,
      );
    }).length;
  }

  int _countEmptyRows(SpreadsheetSheetData sheet) {
    if (sheet.rows.length <= 1) return 0;

    return sheet.rows.skip(1).where((row) {
      return row.every(
        (cell) => cell == null || cell.toString().trim().isEmpty,
      );
    }).length;
  }

  int _countDuplicateRows(SpreadsheetSheetData sheet) {
    if (sheet.rows.length <= 2) return 0;

    final seen = <String>{};
    var duplicates = 0;

    for (final row in sheet.rows.skip(1)) {
      final isEmpty = row.every(
        (cell) => cell == null || cell.toString().trim().isEmpty,
      );

      if (isEmpty) continue;

      final key = row
          .map((cell) => cell?.toString().trim() ?? '')
          .join('\u001f');

      if (!seen.add(key)) {
        duplicates++;
      }
    }

    return duplicates;
  }

  List<String> _availableFields(int currentColumn) {
    final usedFields = _columnMappings.entries
        .where((entry) => entry.key != currentColumn)
        .map((entry) => entry.value)
        .toSet();

    return widget.targetFields
        .where((field) => !usedFields.contains(field))
        .toList();
  }

  Future<void> _confirmImport() async {
    if (!_canImport) return;

    final sheet = _selectedSheet;
    final document = _document;

    if (sheet == null || document == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(LunoraLocalization.text('Подтвердить импорт')),
          content: Text(
            '${LunoraLocalization.text('Будет передано ${_countDataRows(sheet)} строк ')}в раздел "${widget.sourceModule}".\n\nПустые строки будут пропущены. При ошибке транзакция будет отменена.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(LunoraLocalization.text('Импортировать')),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isImporting = true);

    ImportResult result;

    try {
      result = await ImportService.instance.importSheet(
        fileName: document.sourceFileName,
        sourceModule: widget.sourceModule,
        sheet: sheet,
        columnMapping: Map<int, String>.from(_columnMappings),
        requiredFields: widget.requiredFields,
        importer: widget.importer!,
      );
    } catch (error) {
      result = ImportResult.failure(
        message: 'Не удалось выполнить импорт.',
        errors: [error.toString()],
      );
    }

    if (!mounted) return;

    setState(() => _isImporting = false);

    await _showImportResult(result);
  }

  Future<void> _showImportResult(ImportResult result) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            result.success ? Icons.check_circle_outline : Icons.error_outline,
            color: result.success
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
            size: 34,
          ),
          title: Text(
            result.success ? 'Импорт завершён' : 'Импорт не выполнен',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(LunoraLocalization.text(result.message)),
              const SizedBox(height: 12),
              Text(
                LunoraLocalization.text(
                  'Импортировано записей: ${result.importedCount}',
                ),
              ),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  LunoraLocalization.text('Подробности:'),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                ...result.errors.map(
                  (error) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(LunoraLocalization.text(error)),
                  ),
                ),
              ],
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

  Widget _buildFilePicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.upload_file_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              LunoraLocalization.text('Выбери Excel-файл'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              LunoraLocalization.text('Поддерживаются файлы XLSX и XLSM'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isLoading || _isImporting ? null : _pickExcelFile,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(LunoraLocalization.text('Выбрать файл')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(LunoraLocalization.text('Читаем Excel-файл...')),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return _errorMessage == null
        ? const SizedBox.shrink()
        : Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  Widget _buildDocumentInfo() {
    final document = _document;

    if (document == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    document.sourceFileName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _infoItem('Листов', document.sheetCount.toString()),
                _infoItem('Всего строк', document.totalRowCount.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildSheetSelector() {
    final document = _document;

    if (document == null || document.sheets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<int>(
          initialValue: _selectedSheetIndex,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: LunoraLocalization.text('Лист Excel'),
            prefixIcon: Icon(Icons.table_chart_outlined),
            border: OutlineInputBorder(),
          ),
          items: List.generate(document.sheets.length, (index) {
            return DropdownMenuItem<int>(
              value: index,
              child: Text(
                document.sheets[index].name,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          onChanged: _selectSheet,
        ),
      ),
    );
  }

  Widget _buildValidation() {
    final sheet = _selectedSheet;

    if (sheet == null) return const SizedBox.shrink();

    final errors = _getValidationErrors(sheet);
    final emptyRows = _countEmptyRows(sheet);
    final duplicateRows = _countDuplicateRows(sheet);
    final dataRows = _countDataRows(sheet);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LunoraLocalization.text('Проверка данных'),
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (errors.isEmpty)
              Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      LunoraLocalization.text(
                        'Ошибок в заголовках не найдено.',
                      ),
                    ),
                  ),
                ],
              )
            else
              ...errors.map(
                (error) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_outlined,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(LunoraLocalization.text(error))),
                    ],
                  ),
                ),
              ),
            const Divider(height: 24),
            _validationInfo('Строк с данными', dataRows),
            const SizedBox(height: 8),
            _validationInfo('Пустых строк, будет пропущено', emptyRows),
            const SizedBox(height: 8),
            _validationInfo('Повторяющихся строк', duplicateRows),
          ],
        ),
      ),
    );
  }

  Widget _validationInfo(String label, int count) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildColumnMapping() {
    final sheet = _selectedSheet;

    if (sheet == null || sheet.headers.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.targetFields.isEmpty) {
      return _buildInformationCard(
        icon: Icons.info_outline,
        title: LunoraLocalization.text('Сопоставление пока недоступно'),
        description:
            'Для этого раздела ещё не настроены поля данных. '
            'Сейчас можно проверить структуру файла и просмотреть его содержимое.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LunoraLocalization.text('Сопоставление колонок'),
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              LunoraLocalization.text(
                'Укажи, каким полям Lunora соответствуют колонки файла.',
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(sheet.headers.length, (index) {
              final header = sheet.headers[index];
              final currentField = _columnMappings[index];
              final availableFields = _availableFields(index);

              final dropdownFields = <String>{
                ?currentField,
                ...availableFields,
              }.toList();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      header.isEmpty ? 'Колонка ${index + 1}' : header,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: currentField ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text(
                            LunoraLocalization.text('Не сопоставлено'),
                          ),
                        ),
                        ...dropdownFields.map(
                          (field) => DropdownMenuItem<String>(
                            value: field,
                            child: Text(field, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (value) => _updateMapping(index, value),
                    ),
                  ],
                ),
              );
            }),
            if (widget.requiredFields.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                LunoraLocalization.text(
                  'Обязательные поля: ${widget.requiredFields.join(', ')}',
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInformationCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPreview() {
    final sheet = _selectedSheet;

    if (sheet == null || sheet.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final columnCount = sheet.columnCount;

    if (columnCount == 0) return const SizedBox.shrink();

    final headers = sheet.headers;
    final dataRows = sheet.rows.length > 1
        ? sheet.rows.skip(1).take(100).toList()
        : <List<Object?>>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LunoraLocalization.text('Предварительный просмотр'),
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              LunoraLocalization.text(
                'Показаны первые ${dataRows.length} строк данных.',
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: List.generate(columnCount, (index) {
                  final header = index < headers.length ? headers[index] : '';

                  return DataColumn(
                    label: Text(
                      header.isEmpty ? 'Колонка ${index + 1}' : header,
                    ),
                  );
                }),
                rows: dataRows.map((row) {
                  return DataRow(
                    cells: List.generate(columnCount, (index) {
                      final value = index < row.length ? row[index] : null;

                      return DataCell(Text(value?.toString() ?? ''));
                    }),
                  );
                }).toList(),
              ),
            ),
            if (sheet.rows.length - 1 > 100)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  LunoraLocalization.text(
                    'Остальные строки не показаны в предпросмотре.',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportAction() {
    if (_selectedSheet == null) return const SizedBox.shrink();

    if (widget.importer == null) {
      return _buildInformationCard(
        icon: Icons.lock_outline,
        title: LunoraLocalization.text('Запись пока не подключена'),
        description:
            'Сначала нужно создать модель данных и безопасный обработчик '
            'импорта для этого раздела. Просмотр файла не изменяет базу данных.',
      );
    }

    final sheet = _selectedSheet!;
    final missingFields = widget.requiredFields
        .where((field) => !_columnMappings.values.contains(field))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LunoraLocalization.text('Готовность к импорту'),
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              LunoraLocalization.text(
                'Строк для передачи: ${_countDataRows(sheet)}',
              ),
            ),
            if (missingFields.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${LunoraLocalization.text('Не сопоставлены обязательные поля: ')}${missingFields.join(', ')}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canImport ? _confirmImport : null,
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_done_outlined),
                label: Text(
                  _isImporting ? 'Выполняется импорт...' : 'Импортировать',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LunoraLocalization.text('Импорт данных'))),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _compactBreakpoint;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 24,
              vertical: compact ? 14 : 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilePicker(),
                    if (_isLoading) ...[
                      const SizedBox(height: 16),
                      _buildLoading(),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildError(),
                    ],
                    if (_document != null) ...[
                      const SizedBox(height: 16),
                      _buildDocumentInfo(),
                      const SizedBox(height: 12),
                      _buildSheetSelector(),
                      const SizedBox(height: 12),
                      _buildValidation(),
                      const SizedBox(height: 12),
                      _buildColumnMapping(),
                      const SizedBox(height: 12),
                      _buildDataPreview(),
                      const SizedBox(height: 12),
                      _buildImportAction(),
                    ],
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
