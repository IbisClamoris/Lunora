import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../settings/app_settings.dart';
import '../settings/settings_service.dart';

/// Owns Lunora's system-tray icon, native window icon and context menu.
class LunoraTrayService with WidgetsBindingObserver {
  LunoraTrayService._();

  static final LunoraTrayService instance = LunoraTrayService._();

  TrayIcon? _trayIcon;
  Window? _window;
  bool _allowExit = false;
  bool _initialized = false;
  int? _trayListenerId;
  int? _windowListenerId;
  String? _lastIconKey;

  Future<void> initialize() async {
    if (_initialized || kIsWeb || !Platform.isWindows) return;

    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    _window = window;

    SettingsService.instance.addListener(_refreshThemeIcons);
    WidgetsBinding.instance.addObserver(this);

    final trayIcon = TrayIcon.create();
    if (trayIcon == null) {
      debugPrint('Lunora: не удалось создать значок системного трея.');
      await _refreshThemeIcons();
      return;
    }

    _trayIcon = trayIcon;
    _trayListenerId = trayIcon.addListener(_onTrayEvent);
    _createContextMenu();

    _windowListenerId = window.addListener(_onWindowEvent);
    _initialized = true;
    await _refreshThemeIcons();
  }

  @override
  void didChangePlatformBrightness() {
    if (SettingsService.instance.settings.themeMode == AppThemeMode.system) {
      _refreshThemeIcons();
    }
  }

  String _themeAssetName(AppSettings settings) {
    final theme = switch (settings.colorTheme) {
      AppColorTheme.botanical => 'botanical',
      AppColorTheme.lavender => 'lavender',
      AppColorTheme.roseGarden => 'rose_garden',
      AppColorTheme.vintageLibrary => 'vintage_library',
      AppColorTheme.midnight => 'midnight',
      AppColorTheme.moonlight => 'moonlight',
    };
    final isDark = switch (settings.themeMode) {
      AppThemeMode.dark => true,
      AppThemeMode.light => false,
      AppThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    return '${theme}_${isDark ? 'dark' : 'light'}';
  }

  Future<void> _refreshThemeIcons() async {
    if (!Platform.isWindows) return;
    final key = _themeAssetName(SettingsService.instance.settings);
    if (_lastIconKey == key) return;

    final assetBase = 'assets/branding/theme_icons/$key';
    try {
      final executableDirectory = File(Platform.resolvedExecutable).parent.path;
      final icoPath = p.join(
        executableDirectory,
        'data',
        'flutter_assets',
        '$assetBase.ico',
      );
      if (await File(icoPath).exists()) {
        await Application.instance.setIcon(icoPath);
      } else {
        debugPrint('Lunora: theme icon not found: $icoPath');
      }

      final trayIcon = _trayIcon;
      if (trayIcon != null) {
        trayIcon.icon = ImageAsset.fromAsset('$assetBase.png');
      }
      _lastIconKey = key;
    } catch (error, stackTrace) {
      debugPrint('Lunora: не удалось обновить тематическую иконку: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _createContextMenu() {
    final settings = SettingsService.instance.settings;
    final isEnglish = settings.language == AppLanguage.english;
    final menu = Menu.create();
    if (menu == null) return;

    final openItem = MenuItem.createWithLabelAndType(
      isEnglish ? 'Open Lunora' : 'Открыть Lunora',
      MenuItemType.normal,
    );
    final minimizeItem = MenuItem.createWithLabelAndType(
      isEnglish ? 'Minimize to tray' : 'Свернуть в трей',
      MenuItemType.normal,
    );
    final exitItem = MenuItem.createWithLabelAndType(
      isEnglish ? 'Exit' : 'Выход',
      MenuItemType.normal,
    );

    if (openItem == null || minimizeItem == null || exitItem == null) return;

    openItem.addListener((event) {
      if (event is MenuItemClickedEvent) restoreWindow();
    });
    minimizeItem.addListener((event) {
      if (event is MenuItemClickedEvent) minimizeToTray();
    });
    exitItem.addListener((event) {
      if (event is MenuItemClickedEvent) exitApplication();
    });

    menu.addItem(openItem);
    menu.addSeparator();
    menu.addItem(minimizeItem);
    menu.addSeparator();
    menu.addItem(exitItem);

    _trayIcon?.setContextMenu(menu);
    _trayIcon?.setContextMenuTrigger(ContextMenuTrigger.rightClicked);
    _trayIcon?.setVisible(true);
  }

  void _onTrayEvent(TrayIconEvent event) {
    if (event is TrayIconDoubleClickedEvent) restoreWindow();
  }

  void _onWindowEvent(WindowEvent event) {
    final shouldHide =
        !_allowExit && SettingsService.instance.settings.minimizeToTray;
    if (event is WindowCloseRequestedEvent && shouldHide) {
      event.request.cancel();
      _window?.hide();
    }
  }

  void minimizeToTray() {
    _window?.hide();
  }

  void minimizeWindow() {
    if (SettingsService.instance.settings.minimizeToTray) {
      minimizeToTray();
    } else {
      _window?.minimize();
    }
  }

  void restoreWindow() {
    final window = _window;
    if (window == null) return;
    window.show();
    window.restore();
    window.focus();
  }

  void exitApplication() {
    final window = _window;
    if (window == null) return;
    _allowExit = true;
    window.close();
  }

  Future<void> dispose() async {
    SettingsService.instance.removeListener(_refreshThemeIcons);
    WidgetsBinding.instance.removeObserver(this);
    final windowListenerId = _windowListenerId;
    if (windowListenerId != null) _window?.removeListener(windowListenerId);
    final trayListenerId = _trayListenerId;
    if (trayListenerId != null) _trayIcon?.removeListener(trayListenerId);
    _trayIcon?.dispose();
    _trayIcon = null;
    _trayListenerId = null;
    _windowListenerId = null;
    _lastIconKey = null;
    _initialized = false;
  }
}
