import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../settings/app_settings.dart';
import '../settings/settings_service.dart';

/// Owns Lunora's system-tray icon and its native context menu.
///
/// The tray is currently enabled on Windows only. The service uses the native
/// tray_manager API (0.7+) and window_manager's per-window close requests.
class LunoraTrayService {
  LunoraTrayService._();

  static final LunoraTrayService instance = LunoraTrayService._();

  TrayIcon? _trayIcon;
  Window? _window;
  bool _allowExit = false;
  bool _initialized = false;
  int? _trayListenerId;
  int? _windowListenerId;

  Future<void> initialize() async {
    if (_initialized || kIsWeb || !Platform.isWindows) return;

    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    _window = window;

    final trayIcon = TrayIcon.create();
    if (trayIcon == null) {
      debugPrint('Lunora: не удалось создать значок системного трея.');
      return;
    }

    _trayIcon = trayIcon;
    trayIcon.icon = ImageAsset.fromAsset('assets/branding/tray_icon.png');
    trayIcon.setTooltip('Lunora');
    _trayListenerId = trayIcon.addListener(_onTrayEvent);

    _createContextMenu();

    _windowListenerId = window.addListener(_onWindowEvent);
    _initialized = true;
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
    if (event is TrayIconDoubleClickedEvent) {
      restoreWindow();
    }
  }

  void _onWindowEvent(WindowEvent event) {
    if (event is WindowCloseRequestedEvent) {
      final shouldHide =
          !_allowExit && SettingsService.instance.settings.minimizeToTray;
      if (shouldHide) {
        event.request.cancel();
        _window?.hide();
      }
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
    final windowListenerId = _windowListenerId;
    if (windowListenerId != null) {
      _window?.removeListener(windowListenerId);
    }
    final trayListenerId = _trayListenerId;
    if (trayListenerId != null) {
      _trayIcon?.removeListener(trayListenerId);
    }
    _trayIcon?.dispose();
    _trayIcon = null;
    _trayListenerId = null;
    _windowListenerId = null;
    _initialized = false;
  }
}
