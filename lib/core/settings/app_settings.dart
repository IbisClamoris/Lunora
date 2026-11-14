enum AppThemeMode { light, dark, system }

enum AppLanguage { russian, english }

enum AppDensity { comfortable, compact, spacious }

enum AppColorTheme {
  botanical,
  lavender,
  roseGarden,
  vintageLibrary,
  midnight,
  moonlight,
}

class AppSettings {
  final AppThemeMode themeMode;
  final AppLanguage language;
  final AppDensity density;

  final AppColorTheme colorTheme;
  final String currency;
  final String dateFormat;
  final bool use24HourTime;
  final bool firstDayMonday;

  final bool notificationsEnabled;
  final bool soundEnabled;
  final int notificationVolume;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;

  final bool startWithWindows;
  final bool checkForUpdatesAutomatically;
  final bool minimizeToTray;

  final bool botanicalDecorations;
  final bool animationsEnabled;
  final Map<String, bool> sectionVisibility;

  const AppSettings({
    this.themeMode = AppThemeMode.light,
    this.language = AppLanguage.russian,
    this.density = AppDensity.comfortable,
    this.colorTheme = AppColorTheme.botanical,
    this.currency = 'RUB',
    this.dateFormat = 'dd.MM.yyyy',
    this.use24HourTime = true,
    this.firstDayMonday = true,
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.notificationVolume = 70,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '23:00',
    this.quietHoursEnd = '08:00',
    this.startWithWindows = false,
    this.checkForUpdatesAutomatically = true,
    this.minimizeToTray = true,
    this.botanicalDecorations = true,
    this.animationsEnabled = true,
    this.sectionVisibility = const {},
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AppLanguage? language,
    AppDensity? density,
    AppColorTheme? colorTheme,
    String? currency,
    String? dateFormat,
    bool? use24HourTime,
    bool? firstDayMonday,
    bool? notificationsEnabled,
    bool? soundEnabled,
    int? notificationVolume,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? startWithWindows,
    bool? checkForUpdatesAutomatically,
    bool? minimizeToTray,
    bool? botanicalDecorations,
    bool? animationsEnabled,
    Map<String, bool>? sectionVisibility,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      density: density ?? this.density,
      colorTheme: colorTheme ?? this.colorTheme,
      currency: currency ?? this.currency,
      dateFormat: dateFormat ?? this.dateFormat,
      use24HourTime: use24HourTime ?? this.use24HourTime,
      firstDayMonday: firstDayMonday ?? this.firstDayMonday,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      notificationVolume: notificationVolume ?? this.notificationVolume,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      startWithWindows: startWithWindows ?? this.startWithWindows,
      checkForUpdatesAutomatically: checkForUpdatesAutomatically ?? this.checkForUpdatesAutomatically,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      botanicalDecorations: botanicalDecorations ?? this.botanicalDecorations,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      sectionVisibility: sectionVisibility ?? this.sectionVisibility,
    );
  }

  bool isSectionEnabled(String key) => sectionVisibility[key] ?? true;

  AppSettings setSectionEnabled(String key, bool enabled) {
    return copyWith(sectionVisibility: {...sectionVisibility, key: enabled});
  }
}
