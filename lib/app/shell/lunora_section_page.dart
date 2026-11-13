import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:lunora/app/config/menu_entries.dart';
import 'package:lunora/core/import_export/models/export_document.dart';
import 'package:lunora/core/theme/app_theme.dart';
import 'package:lunora/features/diary/pages/diary_page.dart';
import 'package:lunora/features/knowledge/pages/knowledge_page.dart';
import 'package:lunora/features/calendar/pages/calendar_page.dart';
import 'package:lunora/features/finance/pages/finance_page.dart';
import 'package:lunora/features/notifications/pages/notifications_page.dart';
import 'package:lunora/features/planner/pages/planner_page.dart';
import 'package:lunora/features/study/pages/study_page.dart';

import '../pages/data_history_page.dart';
import '../pages/export_page.dart';
import '../pages/import_preview_page.dart';

class LunoraSectionPage extends StatelessWidget {
  static const double _contentMaxWidth = 1100;
  static const double _compactBreakpoint = 600;

  final MenuEntry entry;
  final ValueChanged<int> onNavigate;
  final ExportDocument? exportDocument;
  final int financeInitialTabIndex;
  final bool plannerOpenNewNoteOnStart;

  const LunoraSectionPage({
    super.key,
    required this.entry,
    required this.onNavigate,
    this.exportDocument,
    this.financeInitialTabIndex = 0,
    this.plannerOpenNewNoteOnStart = false,
  });

  void _openImport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ImportPreviewPage(sourceModule: entry.title),
      ),
    );
  }

  void _openExport(BuildContext context) {
    final document = exportDocument;

    if (document == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ExportPage(document: document),
      ),
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const DataHistoryPage()),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    LunoraPalette palette, {
    required bool compact,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 42 : 48,
          height: compact ? 42 : 48,
          decoration: BoxDecoration(
            color: palette.sagePanel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(entry.icon, color: palette.text, size: compact ? 21 : 24),
        ),
        SizedBox(width: compact ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LunoraLocalization.text(entry.title),
                style: TextStyle(
                  color: palette.text,
                  fontSize: compact ? 21 : 25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                LunoraLocalization.text(entry.description),
                style: TextStyle(
                  color: palette.secondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreparationCard(
    BuildContext context,
    LunoraPalette palette, {
    required int index,
    required bool compact,
  }) {
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: palette.accent,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: 12,
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined, color: palette.accent, size: 27),
          const SizedBox(height: 16),
          Text(
            LunoraLocalization.text('Это пространство готовится'),
            style: TextStyle(
              color: palette.text,
              fontSize: compact ? 17 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LunoraLocalization.isEnglish
                ? 'A complete section for "${entry.title}" will appear here. We will add its features, data and tools in future updates.'
                : 'Здесь появится полноценный раздел «${entry.title}». Мы добавим его функции, данные и удобные инструменты на следующих этапах разработки.',
            style: TextStyle(
              color: palette.secondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openImport(context),
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  LunoraLocalization.text('Предпросмотр Excel-файла'),
                ),
                style: buttonStyle,
              ),
              if (exportDocument != null)
                OutlinedButton.icon(
                  onPressed: () => _openExport(context),
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(LunoraLocalization.text('Экспортировать данные')),
                  style: buttonStyle,
                ),
              OutlinedButton.icon(
                onPressed: () => _openHistory(context),
                icon: const Icon(Icons.history),
                label: Text(LunoraLocalization.text('История операций')),
                style: buttonStyle,
              ),
            ],
          ),
          if (index != 0) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => onNavigate(0),
              icon: const Icon(Icons.arrow_back, size: 17),
              label: Text(LunoraLocalization.text('Вернуться на главную')),
              style: TextButton.styleFrom(foregroundColor: palette.accent),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (entry.title == 'Календарь') {
      return const CalendarPage();
    }

    if (entry.title == 'Уведомления') {
      return const NotificationsPage();
    }

    if (entry.title == 'Мой планер') {
      return PlannerPage(openNewNoteOnStart: plannerOpenNewNoteOnStart);
    }

    if (entry.title == 'Учебный планер') {
      return const StudyPage();
    }

    if (entry.title == 'Мои финансы') {
      return FinancePage(initialTabIndex: financeInitialTabIndex);
    }

    if (entry.title == 'Моя база знаний') {
      return const KnowledgePage();
    }

    if (entry.title == 'Дневник') {
      return const DiaryPage();
    }

    final palette = Theme.of(context).extension<LunoraPalette>()!;
    final index = menuEntries.indexOf(entry);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;

        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, palette, compact: compact),
                  SizedBox(height: compact ? 20 : 28),
                  _buildPreparationCard(
                    context,
                    palette,
                    index: index,
                    compact: compact,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
