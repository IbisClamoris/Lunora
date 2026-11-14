import 'dart:io';

import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/lunora_section_header.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/settings/settings_service.dart';
import '../../core/platform/windows_autostart_service.dart';
import 'backup_management_page.dart';
import '../../core/platform/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _service = SettingsService.instance;

  AppSettings get _settings => _service.settings;

  bool _loading = true;
  bool _saving = false;

  double? _volumePreview;

  static const double _contentMaxWidth = 950;
  static const double _compactBreakpoint = 560;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await _service.load();
      _volumePreview = _settings.notificationVolume.toDouble();
      if (_settings.checkForUpdatesAutomatically && Platform.isWindows) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates(silent: true));
      }
    } catch (error) {
      if (mounted) {
        _showMessage(LunoraLocalization.text('Не удалось загрузить настройки: $error', 'Could not load settings: $error'));
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _update(AppSettings settings) async {
    setState(() {
      _saving = true;
    });

    try {
      await _service.update(settings);
    } catch (error) {
      if (mounted) {
        _showMessage(LunoraLocalization.text('Не удалось сохранить настройки: $error', 'Could not save settings: $error'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _volumePreview = _settings.notificationVolume.toDouble();
          _saving = false;
        });
      }
    }
  }

  Future<void> _setWindowsAutostart(bool enabled) async {
    if (!Platform.isWindows) {
      _showMessage(
        _settings.language == AppLanguage.english
            ? 'Windows startup is available only on Windows.'
            : LunoraLocalization.text('Автозапуск доступен только в Windows.', 'Startup is only available on Windows.'),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await WindowsAutostartService.instance.setEnabled(enabled);
      await _service.update(_settings.copyWith(startWithWindows: enabled));
      if (mounted) {
        _showMessage(
          enabled
              ? (_settings.language == AppLanguage.english
                    ? 'Lunora will start with Windows.'
                    : LunoraLocalization.text('Lunora будет запускаться вместе с Windows.', 'Lunora will start with Windows.'))
              : (_settings.language == AppLanguage.english
                    ? 'Lunora was removed from Windows startup.'
                    : LunoraLocalization.text('Lunora удалена из автозагрузки Windows.', 'Lunora has been removed from Windows startup.')),
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          _settings.language == AppLanguage.english
              ? 'Could not change Windows startup: $error'
              : LunoraLocalization.text('Не удалось изменить автозапуск Windows: $error', 'Could not change Windows startup settings: $error'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _checkForUpdates({bool silent = false}) async {
    try {
      final update = await UpdateService.instance.checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        if (!silent) {
          _showMessage(_settings.language == AppLanguage.english
              ? 'You are using the latest version.'
              : LunoraLocalization.text('Установлена последняя версия Lunora.', 'The latest version of Lunora is installed.'));
        }
        return;
      }

      final english = _settings.language == AppLanguage.english;
      final install = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(english ? 'Lunora update available' : LunoraLocalization.text('Доступно обновление Lunora')),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(english
                    ? 'Version ${update.version} is ready. Your data will be backed up before installation.'
                    : LunoraLocalization.text('Доступна версия ${update.version}. Перед установкой будет создана резервная копия данных.', 'Version ${update.version} is available. A data backup will be created before installation.')),
                if (update.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(english ? 'Release notes' : LunoraLocalization.text('Что нового'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(update.notes),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(english ? 'Later' : LunoraLocalization.text('Позже')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(english ? 'Install update' : LunoraLocalization.text('Установить')),
            ),
          ],
        ),
      );
      if (install != true || !mounted) return;
      _showMessage(english
          ? 'Downloading and verifying the update…'
          : LunoraLocalization.text('Загружаю обновление и проверяю контрольную сумму…', 'Downloading update and verifying checksum…'));
      await UpdateService.instance.downloadVerifyBackupAndInstall(update);
    } catch (error) {
      if (mounted) {
        _showMessage(_settings.language == AppLanguage.english
            ? 'Update failed: $error'
            : LunoraLocalization.text('Не удалось обновить Lunora: $error', 'Could not update Lunora: $error'));
      }
    }
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LunoraLocalization.text('Сбросить настройки?')),
        content: Text(
          LunoraLocalization.text(
            LunoraLocalization.text('Все настройки Lunora вернутся к значениям по умолчанию.', 'All Lunora settings will be restored to their defaults.'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LunoraLocalization.text('Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(LunoraLocalization.text('Сбросить')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (Platform.isWindows && _settings.startWithWindows) {
          await WindowsAutostartService.instance.setEnabled(false);
        }
        await _service.reset();

        if (mounted) {
          setState(() {
            _volumePreview = _settings.notificationVolume.toDouble();
          });
          _showMessage(LunoraLocalization.text('Настройки сброшены', 'Settings reset'));
        }
      } catch (error) {
        if (mounted) {
          _showMessage(LunoraLocalization.text('Не удалось сбросить настройки: $error', 'Could not reset settings: $error'));
        }
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(LunoraLocalization.text(message))));
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;

        final palette = Theme.of(context).extension<LunoraPalette>();
        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: palette?.surface ?? Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: (palette?.border ?? Theme.of(context).dividerColor)
                  .withValues(alpha: .85),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .035),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _settingRow({
    required String title,
    String? description,
    required Widget control,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;

        final titleContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (description != null) ...[
              const SizedBox(height: 3),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );

        if (compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleContent,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: control),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: titleContent),
              const SizedBox(width: 16),
              control,
            ],
          ),
        );
      },
    );
  }

  Widget _switch({required bool value, required ValueChanged<bool> onChanged}) {
    return Switch(value: value, onChanged: _saving ? null : onChanged);
  }

  Widget _themePicker() {
    const themeData = <AppColorTheme, (String, List<Color>)>{
      AppColorTheme.botanical: (
        LunoraLocalization.text('Ботаника', 'Botanical'),
        [
          Color(0xFFF3F5EF),
          Color(0xFFE8EEE4),
          Color(0xFF9DB39A),
          Color(0xFF66866C),
        ],
      ),
      AppColorTheme.lavender: (
        LunoraLocalization.text('Лаванда', 'Lavender'),
        [
          Color(0xFFF4F1F8),
          Color(0xFFEAE3F1),
          Color(0xFFB9A4D0),
          Color(0xFF8970A8),
        ],
      ),
      AppColorTheme.roseGarden: (
        LunoraLocalization.text('Розовый сад', 'Rose Garden'),
        [
          Color(0xFFF8F1F0),
          Color(0xFFF0E1E0),
          Color(0xFFD8A8AD),
          Color(0xFFAD737D),
        ],
      ),
      AppColorTheme.vintageLibrary: (
        LunoraLocalization.text('Винтажная библиотека', 'Vintage Library'),
        [
          Color(0xFFF2EBDD),
          Color(0xFFE7DCC7),
          Color(0xFFBBA47D),
          Color(0xFF947447),
        ],
      ),
      AppColorTheme.midnight: (
        LunoraLocalization.text('Полночь', 'Midnight'),
        [
          Color(0xFFF0EDF5),
          Color(0xFFE3DCEB),
          Color(0xFFB9A1D1),
          Color(0xFF8665A5),
        ],
      ),
      AppColorTheme.moonlight: (
        LunoraLocalization.text('Лунный свет', 'Moonlight'),
        [
          Color(0xFFEEF3F7),
          Color(0xFFDDE8F0),
          Color(0xFFA5C0D2),
          Color(0xFF6489A4),
        ],
      ),
    };
    final palette = Theme.of(context).extension<LunoraPalette>()!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 620 ? 108.0 : 116.0;
        return Wrap(
          spacing: 9,
          runSpacing: 9,
          children: AppColorTheme.values.map((theme) {
            final data = themeData[theme]!;
            final selected = _settings.colorTheme == theme;
            return SizedBox(
              width: cardWidth,
              child: Material(
                color: selected ? palette.sidebarSelected : palette.background,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: _saving
                      ? null
                      : () => _update(_settings.copyWith(colorTheme: theme)),
                  borderRadius: BorderRadius.circular(15),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: selected ? palette.accent : palette.border,
                        width: selected ? 1.7 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: data.$2
                              .map(
                                (color) => Expanded(
                                  child: Container(
                                    height: 19,
                                    margin: const EdgeInsets.only(right: 3),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: palette.border.withValues(
                                          alpha: .5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          LunoraLocalization.text(data.$1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selected
                              ? LunoraLocalization.text('Выбрано', 'Selected')
                              : LunoraLocalization.text('Выбрать', 'Select'),
                          style: TextStyle(
                            color: selected
                                ? palette.accent
                                : palette.secondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: items,
        onChanged: _saving ? null : onChanged,
      ),
    );
  }

  Widget _timeButton(String currentValue, ValueChanged<String> onSelected) {
    return OutlinedButton(
      onPressed: _saving
          ? null
          : () async {
              final parts = currentValue.split(':');

              final initialTime = TimeOfDay(
                hour: int.tryParse(parts[0]) ?? 23,
                minute: int.tryParse(parts[1]) ?? 0,
              );

              final selected = await showTimePicker(
                context: context,
                initialTime: initialTime,
              );

              if (selected != null) {
                final value =
                    '${selected.hour.toString().padLeft(2, '0')}:'
                    '${selected.minute.toString().padLeft(2, '0')}';

                onSelected(value);
              }
            },
      child: Text(currentValue),
    );
  }

  Future<void> _openBackupManagement() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BackupManagementPage()));
  }

  Widget _buildSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LunoraSectionHeader(
          title: _settings.language == AppLanguage.english
              ? 'Settings'
              : LunoraLocalization.text('Настройки', 'Settings'),
          subtitle: _settings.language == AppLanguage.english
              ? 'Make Lunora feel like your own space'
              : LunoraLocalization.text('Настрой Lunora под себя', 'Make Lunora your own'),
          icon: Icons.tune_rounded,
        ),
        const SizedBox(height: 24),

        // Внешний вид
        _section(
          title: _settings.language == AppLanguage.english
              ? 'Appearance'
              : LunoraLocalization.text('Внешний вид', 'Appearance'),
          icon: Icons.palette_outlined,
          children: [
            _settingRow(
              title: _settings.language == AppLanguage.english
                  ? 'App appearance'
                  : LunoraLocalization.text('Режим оформления', 'Theme mode'),
              description: _settings.language == AppLanguage.english
                  ? 'Choose light, dark or follow your Windows settings.'
                  : LunoraLocalization.text('Выбери светлое, тёмное оформление или режим Windows.', 'Choose a light or dark theme, or follow Windows settings.'),
              control: _dropdown<AppThemeMode>(
                value: _settings.themeMode,
                items: [
                  DropdownMenuItem(
                    value: AppThemeMode.light,
                    child: Text(LunoraLocalization.text('Светлая', 'Light')),
                  ),
                  DropdownMenuItem(
                    value: AppThemeMode.dark,
                    child: Text(LunoraLocalization.text('Тёмная', 'Dark')),
                  ),
                  DropdownMenuItem(
                    value: AppThemeMode.system,
                    child: Text(
                      LunoraLocalization.text('Как в Windows', 'System'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _update(_settings.copyWith(themeMode: value));
                  }
                },
              ),
            ),
            const Divider(),
            _themePicker(),
            const Divider(),
            _settingRow(
              title: _settings.language == AppLanguage.english
                  ? 'Interface density'
                  : LunoraLocalization.text('Плотность интерфейса', 'Interface density'),
              control: _dropdown<AppDensity>(
                value: _settings.density,
                items: [
                  DropdownMenuItem(
                    value: AppDensity.compact,
                    child: Text(
                      _settings.language == AppLanguage.english
                          ? 'Compact'
                          : LunoraLocalization.text('Компактная', 'Compact'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: AppDensity.comfortable,
                    child: Text(
                      _settings.language == AppLanguage.english
                          ? 'Comfortable'
                          : LunoraLocalization.text('Обычная', 'Comfortable'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: AppDensity.spacious,
                    child: Text(
                      _settings.language == AppLanguage.english
                          ? 'Spacious'
                          : LunoraLocalization.text('Просторная', 'Spacious'),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _update(_settings.copyWith(density: value));
                  }
                },
              ),
            ),
            const Divider(),
            _settingRow(
              title: _settings.language == AppLanguage.english
                  ? 'Theme decorations'
                  : LunoraLocalization.text('Декоративные элементы', 'Decorative elements'),
              description: _settings.language == AppLanguage.english
                  ? 'Themed decorative artwork across the app'
                  : LunoraLocalization.text('Декоративные элементы интерфейса', 'Interface decorations'),
              control: _switch(
                value: _settings.botanicalDecorations,
                onChanged: (value) =>
                    _update(_settings.copyWith(botanicalDecorations: value)),
              ),
            ),
            _settingRow(
              title: _settings.language == AppLanguage.english
                  ? 'Animations'
                  : LunoraLocalization.text('Анимации', 'Animations'),
              description: _settings.language == AppLanguage.english
                  ? 'Smooth transitions and effects'
                  : LunoraLocalization.text('Плавные переходы и эффекты', 'Smooth transitions and effects'),
              control: _switch(
                value: _settings.animationsEnabled,
                onChanged: (value) =>
                    _update(_settings.copyWith(animationsEnabled: value)),
              ),
            ),
          ],
        ),

        _section(
          title: _settings.language == AppLanguage.english
              ? 'Your spaces'
              : LunoraLocalization.text('Твои разделы', 'Your sections'),
          icon: Icons.dashboard_customize_outlined,
          children: [
            Text(
              _settings.language == AppLanguage.english
                  ? 'Hide sections you do not use. You can turn them back on at any time.'
                  : LunoraLocalization.text('Отключай ненужные разделы. Их можно включить обратно в любой момент.', 'Disable sections you do not need. You can turn them back on at any time.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            for (final item in <(String, String, String)>[
              ('calendar', 'Календарь', 'Calendar'),
              ('notifications', LunoraLocalization.text('Уведомления', 'Notifications'), 'Notifications'),
              ('shoppingList', 'Список покупок', 'Shopping list'),
              ('planner', 'Мой планер', 'My planner'),
              ('studyPlanner', 'Учебный планер', 'Study planner'),
              ('finances', 'Мои финансы', 'Finances'),
              ('knowledgeBase', 'Моя база знаний', 'Knowledge base'),
              ('diary', 'Дневник', 'Diary'),
              ('diaryGallery', 'Галерея дневника', 'Diary gallery'),
              ('books', 'Мой книжный мир', 'My books'),
              ('movies', 'Мир кино и сериалов', 'Movies & series'),
              ('recipes', 'Моя книга рецептов', 'Recipe book'),
              ('wishlist', 'Вишлист', 'Wishlist'),
            ])
              _settingRow(
                title: _settings.language == AppLanguage.english
                    ? item.$3
                    : item.$2,
                control: _switch(
                  value: _settings.isSectionEnabled(item.$1),
                  onChanged: (value) =>
                      _update(_settings.setSectionEnabled(item.$1, value)),
                ),
              ),
          ],
        ),

        // Региональные настройки
        _section(
          title: _settings.language == AppLanguage.english
              ? 'Language & region'
              : LunoraLocalization.text('Региональные настройки', 'Regional settings'),
          icon: Icons.language,
          children: [
            _settingRow(
              title: _settings.language == AppLanguage.english
                  ? 'Interface language'
                  : LunoraLocalization.text('Язык интерфейса', 'Interface language'),
              control: _dropdown<AppLanguage>(
                value: _settings.language,
                items: [
                  DropdownMenuItem(
                    value: AppLanguage.russian,
                    child: Text(LunoraLocalization.text('Русский')),
                  ),
                  DropdownMenuItem(
                    value: AppLanguage.english,
                    child: Text('English'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _update(_settings.copyWith(language: value));
                  }
                },
              ),
            ),
            _settingRow(
              title: _settings.language == AppLanguage.english
                  ? 'Currency'
                  : LunoraLocalization.text('Валюта', 'Currency'),
              control: _dropdown<String>(
                value: _settings.currency,
                items: const [
                  DropdownMenuItem(value: 'RUB', child: Text('₽ RUB')),
                  DropdownMenuItem(value: 'EUR', child: Text('€ EUR')),
                  DropdownMenuItem(value: 'USD', child: Text('\$ USD')),
                  DropdownMenuItem(value: 'GBP', child: Text('£ GBP')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _update(_settings.copyWith(currency: value));
                  }
                },
              ),
            ),
            _settingRow(
              title: _settings.language == AppLanguage.english
                  ? 'Date format'
                  : LunoraLocalization.text('Формат даты', 'Date format'),
              control: _dropdown<String>(
                value: _settings.dateFormat,
                items: const [
                  DropdownMenuItem(
                    value: 'dd.MM.yyyy',
                    child: Text('05.11.2026'),
                  ),
                  DropdownMenuItem(
                    value: 'MM/dd/yyyy',
                    child: Text('11/05/2026'),
                  ),
                  DropdownMenuItem(
                    value: 'yyyy-MM-dd',
                    child: Text('2026-11-05'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _update(_settings.copyWith(dateFormat: value));
                  }
                },
              ),
            ),
            const Divider(),
            _settingRow(
              title: LunoraLocalization.text('24-часовой формат времени'),
              control: _switch(
                value: _settings.use24HourTime,
                onChanged: (value) =>
                    _update(_settings.copyWith(use24HourTime: value)),
              ),
            ),
            _settingRow(
              title: LunoraLocalization.text('Начинать неделю с понедельника'),
              control: _switch(
                value: _settings.firstDayMonday,
                onChanged: (value) =>
                    _update(_settings.copyWith(firstDayMonday: value)),
              ),
            ),
          ],
        ),

        // Уведомления
        _section(
          title: _settings.language == AppLanguage.english
              ? 'Notifications'
              : LunoraLocalization.text('Уведомления', 'Notifications'),
          icon: Icons.notifications_outlined,
          children: [
            _settingRow(
              title: LunoraLocalization.text('Уведомления'),
              control: _switch(
                value: _settings.notificationsEnabled,
                onChanged: (value) =>
                    _update(_settings.copyWith(notificationsEnabled: value)),
              ),
            ),
            _settingRow(
              title: LunoraLocalization.text('Звуки уведомлений'),
              control: _switch(
                value: _settings.soundEnabled,
                onChanged: (value) =>
                    _update(_settings.copyWith(soundEnabled: value)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${LunoraLocalization.text('Громкость: ')}${(_volumePreview ?? _settings.notificationVolume.toDouble()).round()}%',
            ),
            Slider(
              value: (_volumePreview ?? _settings.notificationVolume.toDouble())
                  .clamp(0.0, 100.0),
              min: 0,
              max: 100,
              divisions: 20,
              label:
                  '${(_volumePreview ?? _settings.notificationVolume.toDouble()).round()}%',
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        _volumePreview = value;
                      });
                    },
              onChangeEnd: (value) {
                _update(_settings.copyWith(notificationVolume: value.round()));
              },
            ),
            const Divider(),
            _settingRow(
              title: LunoraLocalization.text('Тихие часы'),
              control: _switch(
                value: _settings.quietHoursEnabled,
                onChanged: (value) =>
                    _update(_settings.copyWith(quietHoursEnabled: value)),
              ),
            ),
            if (_settings.quietHoursEnabled) ...[
              _settingRow(
                title: LunoraLocalization.text('Начало'),
                control: _timeButton(
                  _settings.quietHoursStart,
                  (value) =>
                      _update(_settings.copyWith(quietHoursStart: value)),
                ),
              ),
              _settingRow(
                title: LunoraLocalization.text('Окончание'),
                control: _timeButton(
                  _settings.quietHoursEnd,
                  (value) => _update(_settings.copyWith(quietHoursEnd: value)),
                ),
              ),
            ],
          ],
        ),

        // Запуск и поведение
        _section(
          title: _settings.language == AppLanguage.english
              ? 'Startup & behaviour'
              : LunoraLocalization.text('Запуск и поведение', 'Startup and behaviour'),
          icon: Icons.desktop_windows_outlined,
          children: [
            _settingRow(
              title: LunoraLocalization.text('Запускать вместе с Windows'),
              control: _switch(
                value: _settings.startWithWindows,
                onChanged: _setWindowsAutostart,
              ),
            ),
            _settingRow(
              title: LunoraLocalization.text('Сворачивать в системный трей'),
              control: _switch(
                value: _settings.minimizeToTray,
                onChanged: (value) =>
                    _update(_settings.copyWith(minimizeToTray: value)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              LunoraLocalization.text(
                LunoraLocalization.text('Управление окном и выход доступны через значок Lunora в области уведомлений Windows.', 'Window controls and exit are available from the Lunora icon in the Windows notification area.'),
                'Window controls and exit are available from the Lunora icon in the Windows notification area.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),

        _section(
          title: _settings.language == AppLanguage.english
              ? 'Updates'
              : LunoraLocalization.text('Обновления', 'Updates'),
          icon: Icons.system_update_alt_rounded,
          children: [
            _settingRow(
              title: _settings.language == AppLanguage.english
                  ? 'Check for updates when opening Settings'
                  : LunoraLocalization.text('Проверять обновления при открытии настроек', 'Check for updates when opening settings'),
              description: _settings.language == AppLanguage.english
                  ? 'Updates are never installed without your confirmation.'
                  : LunoraLocalization.text('Обновления никогда не устанавливаются без подтверждения.', 'Updates are never installed without confirmation.'),
              control: _switch(
                value: _settings.checkForUpdatesAutomatically,
                onChanged: (value) => _update(
                  _settings.copyWith(checkForUpdatesAutomatically: value),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _checkForUpdates(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_settings.language == AppLanguage.english
                    ? 'Check now'
                    : 'Проверить сейчас'),
              ),
            ),
          ],
        ),

        // Данные и резервные копии
        _section(
          title: _settings.language == AppLanguage.english
              ? 'Data & backups'
              : LunoraLocalization.text('Данные и резервные копии', 'Data and backups'),
          icon: Icons.storage_outlined,
          children: [
            Text(
              LunoraLocalization.text(
                LunoraLocalization.text('Управление резервными копиями базы данных Lunora.', 'Manage Lunora database backups.'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _openBackupManagement,
                icon: const Icon(Icons.backup_outlined),
                label: Text(
                  _settings.language == AppLanguage.english
                      ? 'Manage backups'
                      : LunoraLocalization.text('Управление резервными копиями', 'Manage backups'),
                ),
              ),
            ),
          ],
        ),

        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _resetSettings,
            icon: const Icon(Icons.restart_alt),
            label: Text(
              _settings.language == AppLanguage.english
                  ? 'Reset settings'
                  : LunoraLocalization.text('Сбросить настройки', 'Reset settings'),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _compactBreakpoint;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 28,
                  vertical: compact ? 18 : 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth,
                    ),
                    child: _buildSettingsContent(),
                  ),
                ),
              ),
              if (_saving)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          );
        },
      ),
    );
  }
}
