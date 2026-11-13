import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:window_manager/window_manager.dart';

import 'app/shell/lunora_home.dart';
import 'features/notifications/services/notification_scheduler.dart';
import 'features/notifications/services/system_notification_service.dart';
import 'core/settings/settings_service.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/platform/lunora_tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Убираем системный заголовок Windows.
  // Собственная панель Lunora остаётся частью интерфейса.
  if (Platform.isWindows) {
    final window = WindowManager.instance.getCurrent();

    if (window != null) {
      window.titleBarStyle = TitleBarStyle.hidden;
    }
  }

  await SettingsService.instance.load();

  await initializeDateFormatting('ru', null);
  await initializeDateFormatting('ru_RU', null);
  await initializeDateFormatting('en_US', null);

  try {
    await SystemNotificationService.instance.initialize();
    await NotificationScheduler.instance.start();
  } catch (error, stackTrace) {
    debugPrint('Ошибка инициализации уведомлений: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const LunoraApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await LunoraTrayService.instance.initialize();
  });
}

extension LunoraThemeContext on BuildContext {
  LunoraPalette get palette =>
      Theme.of(this).extension<LunoraPalette>()!;
}

class LunoraApp extends StatelessWidget {
  const LunoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService.instance,
      builder: (context, child) {
        final settings = SettingsService.instance.settings;

        Intl.defaultLocale =
            settings.language == AppLanguage.english
                ? 'en_US'
                : 'ru_RU';

        final lightTheme = AppTheme.light(
          colorTheme: settings.colorTheme,
          density: settings.density,
        );

        final darkTheme = AppTheme.dark(
          colorTheme: settings.colorTheme,
          density: settings.density,
        );

        return MaterialApp(
          title: 'Lunora',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ru', 'RU'),
            Locale('en', 'US'),
          ],
          locale: settings.language.name == 'english'
              ? const Locale('en', 'US')
              : const Locale('ru', 'RU'),
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: switch (settings.themeMode) {
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
            AppThemeMode.system => ThemeMode.system,
          },
          home: const LunoraHome(),
        );
      },
    );
  }
}