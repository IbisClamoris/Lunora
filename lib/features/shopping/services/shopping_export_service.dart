import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/theme/app_theme.dart';
import '../models/shopping_item.dart';

enum ShoppingExportFilter { all, toBuy, purchased }

class ShoppingExportService {
  ShoppingExportService._();

  static final ShoppingExportService instance = ShoppingExportService._();

  Future<Directory> _getExportDirectory() async {
    final appData = await getApplicationSupportDirectory();

    final directory = Directory(p.join(appData.path, 'Lunora', 'Exports'));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  List<ShoppingItem> _filterItems(
    List<ShoppingItem> items,
    ShoppingExportFilter filter,
  ) {
    switch (filter) {
      case ShoppingExportFilter.all:
        return List<ShoppingItem>.from(items);

      case ShoppingExportFilter.toBuy:
        return items.where((item) => !item.isPurchased).toList();

      case ShoppingExportFilter.purchased:
        return items.where((item) => item.isPurchased).toList();
    }
  }

  String _filterTitle(ShoppingExportFilter filter) {
    switch (filter) {
      case ShoppingExportFilter.all:
        return 'Весь список покупок';

      case ShoppingExportFilter.toBuy:
        return 'Список покупок';

      case ShoppingExportFilter.purchased:
        return 'Купленные товары';
    }
  }

  String _formatQuantity(ShoppingItem item) {
    final quantity = item.quantity;

    if (quantity == null) return '';

    final formatted = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString().replaceAll('.', ',');

    final unit = item.unit?.trim();

    if (unit == null || unit.isEmpty) {
      return formatted;
    }

    return '$formatted $unit';
  }

  String _fileName(String extension) {
    final date = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());

    return 'lunora_shopping_$date.$extension';
  }

  Future<pw.Font> _loadPdfFont(String fileName) async {
    final windowsDirectory = Platform.environment['WINDIR'] ?? r'C:\Windows';

    final fontFile = File(p.join(windowsDirectory, 'Fonts', fileName));

    if (!await fontFile.exists()) {
      throw Exception('Не найден системный шрифт Windows: ${fontFile.path}');
    }

    final bytes = await fontFile.readAsBytes();

    return pw.Font.ttf(ByteData.sublistView(bytes));
  }

  Future<File> exportPdf({
    required List<ShoppingItem> items,
    required ShoppingExportFilter filter,
    required LunoraPalette palette,
  }) async {
    final filteredItems = _filterItems(items, filter);
    final document = pw.Document();

    final regularFont = await _loadPdfFont('segoeui.ttf');
    final boldFont = await _loadPdfFont('segoeuib.ttf');

    final purchasedCount = filteredItems
        .where((item) => item.isPurchased)
        .length;

    final pendingCount = filteredItems.length - purchasedCount;

    final surface = PdfColor.fromInt(palette.surface.toARGB32());

    final textColor = PdfColor.fromInt(palette.text.toARGB32());

    final secondaryColor = PdfColor.fromInt(palette.secondary.toARGB32());

    final accentColor = PdfColor.fromInt(palette.accent.toARGB32());

    final borderColor = PdfColor.fromInt(palette.border.toARGB32());

    final sageColor = PdfColor.fromInt(palette.sagePanel.toARGB32());

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Container(
              padding: const pw.EdgeInsets.all(22),
              decoration: pw.BoxDecoration(
                color: sageColor,
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LUNORA',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 11,
                      color: secondaryColor,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    _filterTitle(filter),
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 23,
                      color: textColor,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()),
                    style: pw.TextStyle(fontSize: 10, color: secondaryColor),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              children: [
                _pdfStat(
                  'Всего',
                  filteredItems.length.toString(),
                  surface,
                  textColor,
                  borderColor,
                ),
                pw.SizedBox(width: 8),
                _pdfStat(
                  'К покупке',
                  pendingCount.toString(),
                  surface,
                  textColor,
                  borderColor,
                ),
                pw.SizedBox(width: 8),
                _pdfStat(
                  'Куплено',
                  purchasedCount.toString(),
                  surface,
                  textColor,
                  borderColor,
                ),
              ],
            ),
            pw.SizedBox(height: 22),
          ];

          if (filteredItems.isEmpty) {
            widgets.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  color: surface,
                  border: pw.Border.all(color: borderColor),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  LunoraLocalization.text('В этом разделе пока нет товаров.'),
                  style: pw.TextStyle(fontSize: 12, color: secondaryColor),
                ),
              ),
            );
          } else {
            final categories = <String, List<ShoppingItem>>{};

            for (final item in filteredItems) {
              final category = item.category?.trim().isNotEmpty == true
                  ? item.category!.trim()
                  : 'Без категории';

              categories.putIfAbsent(category, () => []).add(item);
            }

            for (final entry in categories.entries) {
              widgets.add(
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: pw.BoxDecoration(
                    color: sageColor,
                    borderRadius: pw.BorderRadius.circular(7),
                  ),
                  child: pw.Text(
                    entry.key,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 11,
                      color: textColor,
                    ),
                  ),
                ),
              );

              widgets.add(pw.SizedBox(height: 6));

              for (final item in entry.value) {
                widgets.add(
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 7),
                    padding: const pw.EdgeInsets.all(11),
                    decoration: pw.BoxDecoration(
                      color: surface,
                      border: pw.Border.all(color: borderColor),
                      borderRadius: pw.BorderRadius.circular(7),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 13,
                          height: 13,
                          margin: const pw.EdgeInsets.only(right: 10, top: 2),
                          decoration: pw.BoxDecoration(
                            color: item.isPurchased ? accentColor : surface,
                            border: pw.Border.all(
                              color: item.isPurchased
                                  ? accentColor
                                  : secondaryColor,
                            ),
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.title,
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 10,
                                  color: textColor,
                                  decoration: item.isPurchased
                                      ? pw.TextDecoration.lineThrough
                                      : pw.TextDecoration.none,
                                ),
                              ),
                              if (_formatQuantity(item).isNotEmpty)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 3),
                                  child: pw.Text(
                                    _formatQuantity(item),
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      color: secondaryColor,
                                    ),
                                  ),
                                ),
                              if (item.notes?.trim().isNotEmpty == true)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(top: 4),
                                  child: pw.Text(
                                    item.notes!.trim(),
                                    style: pw.TextStyle(
                                      fontSize: 8,
                                      color: secondaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (item.isPurchased)
                          pw.Text(
                            LunoraLocalization.text('Куплено'),
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: accentColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

              widgets.add(pw.SizedBox(height: 10));
            }
          }

          return widgets;
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Lunora · Your personal world',
                  style: pw.TextStyle(fontSize: 8, color: secondaryColor),
                ),
                pw.Text(
                  '${context.pageNumber} / ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: secondaryColor),
                ),
              ],
            ),
          );
        },
      ),
    );

    final directory = await _getExportDirectory();

    final file = File(p.join(directory.path, _fileName('pdf')));

    await file.writeAsBytes(await document.save());

    return file;
  }

  pw.Widget _pdfStat(
    String label,
    String value,
    PdfColor surface,
    PdfColor text,
    PdfColor border,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: surface,
          border: pw.Border.all(color: border),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: text,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(label, style: pw.TextStyle(fontSize: 8, color: text)),
          ],
        ),
      ),
    );
  }

  Future<File> exportPng({
    required List<ShoppingItem> items,
    required ShoppingExportFilter filter,
    required LunoraPalette palette,
    required bool isDark,
  }) async {
    final filteredItems = _filterItems(items, filter);

    const width = 1200.0;
    const horizontalPadding = 64.0;
    const headerHeight = 270.0;
    const categoryHeight = 66.0;
    const itemHeight = 94.0;
    const footerHeight = 90.0;

    final categories = <String, List<ShoppingItem>>{};

    for (final item in filteredItems) {
      final category = item.category?.trim().isNotEmpty == true
          ? item.category!.trim()
          : 'Без категории';

      categories.putIfAbsent(category, () => []).add(item);
    }

    var contentHeight = headerHeight + footerHeight + 40.0;

    for (final entry in categories.entries) {
      contentHeight += categoryHeight;
      contentHeight += entry.value.length * itemHeight;
      contentHeight += 20;
    }

    if (filteredItems.isEmpty) {
      contentHeight += 130;
    }

    final height = contentHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final backgroundPaint = Paint()..color = palette.background;

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), backgroundPaint);

    final textColor = palette.text;
    final secondaryColor = palette.secondary;

    void drawText(
      String text,
      double x,
      double y, {
      double fontSize = 24,
      Color? color,
      FontWeight weight = FontWeight.normal,
    }) {
      final builder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                fontSize: fontSize,
                fontWeight: weight,
                maxLines: 3,
              ),
            )
            ..pushStyle(
              ui.TextStyle(
                color: color ?? textColor,
                fontSize: fontSize,
                fontWeight: weight,
              ),
            )
            ..addText(text);

      final paragraph = builder.build();

      paragraph.layout(
        ui.ParagraphConstraints(width: width - x - horizontalPadding),
      );

      canvas.drawParagraph(paragraph, Offset(x, y));
    }

    void drawRoundedRect(
      Rect rect,
      Color color, {
      double radius = 18,
      Color? borderColor,
    }) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );

      if (borderColor != null) {
        final borderPaint = Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
          borderPaint,
        );
      }
    }

    drawRoundedRect(
      Rect.fromLTWH(horizontalPadding, 40, width - horizontalPadding * 2, 205),
      palette.sagePanel,
      radius: 28,
    );

    drawText(
      'L U N O R A',
      horizontalPadding + 32,
      68,
      fontSize: 19,
      color: secondaryColor,
      weight: FontWeight.w600,
    );

    drawText(
      _filterTitle(filter),
      horizontalPadding + 32,
      112,
      fontSize: 39,
      weight: FontWeight.bold,
    );

    drawText(
      DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()),
      horizontalPadding + 32,
      174,
      fontSize: 19,
      color: secondaryColor,
    );

    final purchasedCount = filteredItems
        .where((item) => item.isPurchased)
        .length;

    final pendingCount = filteredItems.length - purchasedCount;

    drawText(
      '${LunoraLocalization.text('Всего: ${filteredItems.length}     ')}К покупке: $pendingCount     Куплено: $purchasedCount',
      horizontalPadding + 32,
      210,
      fontSize: 17,
      color: secondaryColor,
    );

    var y = 280.0;

    if (filteredItems.isEmpty) {
      drawRoundedRect(
        Rect.fromLTWH(horizontalPadding, y, width - horizontalPadding * 2, 110),
        palette.surface,
        borderColor: palette.border,
      );

      drawText(
        LunoraLocalization.text('В этом разделе пока нет товаров.'),
        horizontalPadding + 28,
        y + 40,
        fontSize: 23,
        color: secondaryColor,
      );

      y += 130;
    }

    for (final entry in categories.entries) {
      drawRoundedRect(
        Rect.fromLTWH(horizontalPadding, y, width - horizontalPadding * 2, 54),
        palette.sagePanel,
        radius: 12,
      );

      drawText(
        entry.key,
        horizontalPadding + 22,
        y + 14,
        fontSize: 22,
        weight: FontWeight.w600,
      );

      y += categoryHeight;

      for (final item in entry.value) {
        drawRoundedRect(
          Rect.fromLTWH(
            horizontalPadding,
            y,
            width - horizontalPadding * 2,
            78,
          ),
          palette.surface,
          radius: 12,
          borderColor: palette.border,
        );

        final checkboxRect = Rect.fromLTWH(
          horizontalPadding + 22,
          y + 25,
          25,
          25,
        );

        drawRoundedRect(
          checkboxRect,
          item.isPurchased ? palette.accent : palette.surface,
          radius: 6,
          borderColor: palette.accent,
        );

        drawText(
          item.title,
          horizontalPadding + 68,
          y + 12,
          fontSize: 21,
          weight: FontWeight.w600,
        );

        final details = [
          if (_formatQuantity(item).isNotEmpty) _formatQuantity(item),
          if (item.notes?.trim().isNotEmpty == true) item.notes!.trim(),
        ].join(' · ');

        if (details.isNotEmpty) {
          drawText(
            details,
            horizontalPadding + 68,
            y + 43,
            fontSize: 15,
            color: secondaryColor,
          );
        }

        if (item.isPurchased) {
          drawText(
            LunoraLocalization.text('Куплено'),
            width - horizontalPadding - 140,
            y + 27,
            fontSize: 15,
            color: palette.accent,
          );
        }

        y += itemHeight;
      }

      y += 20;
    }

    drawText(
      'Lunora · Your personal world',
      horizontalPadding,
      height - 55,
      fontSize: 16,
      color: secondaryColor,
    );

    final picture = recorder.endRecording();

    final uiImage = await picture.toImage(width.toInt(), height.toInt());

    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Не удалось создать PNG-изображение.');
    }

    final bytes = byteData.buffer.asUint8List();

    final decoded = img.decodePng(bytes);

    if (decoded == null) {
      throw Exception('Не удалось обработать PNG-изображение.');
    }

    final encoded = img.encodePng(decoded);

    final directory = await _getExportDirectory();

    final file = File(p.join(directory.path, _fileName('png')));

    await file.writeAsBytes(encoded);

    picture.dispose();
    uiImage.dispose();

    return file;
  }
}
