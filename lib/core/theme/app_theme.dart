import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

class LunoraPalette extends ThemeExtension<LunoraPalette> {
  final Color background, surface, sidebar, sidebarSelected, sagePanel;
  final Color lavender, rose, text, secondary, border, accent;
  final Color accentSoft, success, warning, danger;
  const LunoraPalette({
    required this.background,
    required this.surface,
    required this.sidebar,
    required this.sidebarSelected,
    required this.sagePanel,
    required this.lavender,
    required this.rose,
    required this.text,
    required this.secondary,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
  });
  @override
  LunoraPalette copyWith({
    Color? background,
    Color? surface,
    Color? sidebar,
    Color? sidebarSelected,
    Color? sagePanel,
    Color? lavender,
    Color? rose,
    Color? text,
    Color? secondary,
    Color? border,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? warning,
    Color? danger,
  }) => LunoraPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    sidebar: sidebar ?? this.sidebar,
    sidebarSelected: sidebarSelected ?? this.sidebarSelected,
    sagePanel: sagePanel ?? this.sagePanel,
    lavender: lavender ?? this.lavender,
    rose: rose ?? this.rose,
    text: text ?? this.text,
    secondary: secondary ?? this.secondary,
    border: border ?? this.border,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
  );
  @override
  LunoraPalette lerp(covariant LunoraPalette? o, double t) {
    if (o == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return LunoraPalette(
      background: l(background, o.background),
      surface: l(surface, o.surface),
      sidebar: l(sidebar, o.sidebar),
      sidebarSelected: l(sidebarSelected, o.sidebarSelected),
      sagePanel: l(sagePanel, o.sagePanel),
      lavender: l(lavender, o.lavender),
      rose: l(rose, o.rose),
      text: l(text, o.text),
      secondary: l(secondary, o.secondary),
      border: l(border, o.border),
      accent: l(accent, o.accent),
      accentSoft: l(accentSoft, o.accentSoft),
      success: l(success, o.success),
      warning: l(warning, o.warning),
      danger: l(danger, o.danger),
    );
  }
}

class AppTheme {
  AppTheme._();
  static VisualDensity _density(AppDensity d) => switch (d) {
    AppDensity.compact => const VisualDensity(horizontal: -1, vertical: -1),
    AppDensity.comfortable => VisualDensity.standard,
    AppDensity.spacious => const VisualDensity(horizontal: 1, vertical: 1),
  };
  // Every collection has its own identity. Each tuple: background, surface, sidebar, selected, panel, lavender, rose, text, secondary, border, accent.
  static const _light = <AppColorTheme, List<Color>>{
    AppColorTheme.botanical: [
      Color(0xFFF3F5EF),
      Color(0xFFFCFDF9),
      Color(0xFFE8EEE4),
      Color(0xFFD8E4D3),
      Color(0xFFE5EDE1),
      Color(0xFFEAE5F1),
      Color(0xFFF2E4E2),
      Color(0xFF26352D),
      Color(0xFF68766D),
      Color(0xFFD7E0D5),
      Color(0xFF66866C),
    ],
    AppColorTheme.lavender: [
      Color(0xFFF4F1F8),
      Color(0xFFFFFDFF),
      Color(0xFFEAE3F1),
      Color(0xFFDED2EB),
      Color(0xFFEDE6F4),
      Color(0xFFE5DDF2),
      Color(0xFFF1E3EB),
      Color(0xFF342B40),
      Color(0xFF766B83),
      Color(0xFFDED5E7),
      Color(0xFF8970A8),
    ],
    AppColorTheme.roseGarden: [
      Color(0xFFF8F1F0),
      Color(0xFFFFFCFB),
      Color(0xFFF0E1E0),
      Color(0xFFE8D0D0),
      Color(0xFFF3E5E2),
      Color(0xFFECE3EE),
      Color(0xFFF3DDDF),
      Color(0xFF3F2D32),
      Color(0xFF806D70),
      Color(0xFFE5D5D3),
      Color(0xFFAD737D),
    ],
    AppColorTheme.vintageLibrary: [
      Color(0xFFF2EBDD),
      Color(0xFFFFFBF1),
      Color(0xFFE7DCC7),
      Color(0xFFDCCBAE),
      Color(0xFFEDE2CC),
      Color(0xFFE9E0D6),
      Color(0xFFEEDDD0),
      Color(0xFF3D3528),
      Color(0xFF796E5C),
      Color(0xFFDED2BC),
      Color(0xFF947447),
    ],
    AppColorTheme.midnight: [
      Color(0xFFF0EDF5),
      Color(0xFFFCFAFF),
      Color(0xFFE3DCEB),
      Color(0xFFD5C9E2),
      Color(0xFFE9E1F0),
      Color(0xFFE2D8EF),
      Color(0xFFF0DFE9),
      Color(0xFF292333),
      Color(0xFF71677E),
      Color(0xFFD8CEE2),
      Color(0xFF8665A5),
    ],
    AppColorTheme.moonlight: [
      Color(0xFFEEF3F7),
      Color(0xFFFCFEFF),
      Color(0xFFDDE8F0),
      Color(0xFFCBDCE8),
      Color(0xFFE3EDF3),
      Color(0xFFE3E8F2),
      Color(0xFFE4EBF0),
      Color(0xFF273642),
      Color(0xFF687B89),
      Color(0xFFD5E0E8),
      Color(0xFF6489A4),
    ],
  };
  static const _dark = <AppColorTheme, List<Color>>{
    AppColorTheme.botanical: [
      Color(0xFF1C241F),
      Color(0xFF27312A),
      Color(0xFF222D25),
      Color(0xFF394B3D),
      Color(0xFF303E33),
      Color(0xFF40394A),
      Color(0xFF49383B),
      Color(0xFFF0F3EC),
      Color(0xFFB4C0B5),
      Color(0xFF435247),
      Color(0xFFA6C39F),
    ],
    AppColorTheme.lavender: [
      Color(0xFF211D29),
      Color(0xFF2D2737),
      Color(0xFF292333),
      Color(0xFF443751),
      Color(0xFF393044),
      Color(0xFF493A5B),
      Color(0xFF4B3747),
      Color(0xFFF3EDF8),
      Color(0xFFC1B5CD),
      Color(0xFF4B4056),
      Color(0xFFC1A6E0),
    ],
    AppColorTheme.roseGarden: [
      Color(0xFF2A2024),
      Color(0xFF382A30),
      Color(0xFF30242A),
      Color(0xFF50363F),
      Color(0xFF443239),
      Color(0xFF49394C),
      Color(0xFF583A43),
      Color(0xFFF7ECEE),
      Color(0xFFCAB5BA),
      Color(0xFF514047),
      Color(0xFFD29AA5),
    ],
    AppColorTheme.vintageLibrary: [
      Color(0xFF29251E),
      Color(0xFF373126),
      Color(0xFF302B22),
      Color(0xFF51442F),
      Color(0xFF423A2B),
      Color(0xFF494039),
      Color(0xFF4C3B30),
      Color(0xFFF5EBD8),
      Color(0xFFC6B99F),
      Color(0xFF514838),
      Color(0xFFD0B17A),
    ],
    AppColorTheme.midnight: [
      Color(0xFF1D1925),
      Color(0xFF292331),
      Color(0xFF241F2D),
      Color(0xFF43344F),
      Color(0xFF342B40),
      Color(0xFF4A3B5C),
      Color(0xFF513744),
      Color(0xFFF5EFF9),
      Color(0xFFC1B3CC),
      Color(0xFF4C4058),
      Color(0xFFC3A0E5),
    ],
    AppColorTheme.moonlight: [
      Color(0xFF1C252D),
      Color(0xFF26333D),
      Color(0xFF222E38),
      Color(0xFF394F60),
      Color(0xFF2F414E),
      Color(0xFF3B4054),
      Color(0xFF3C4B55),
      Color(0xFFF0F5F8),
      Color(0xFFB6C5CF),
      Color(0xFF40515C),
      Color(0xFFA2C6DE),
    ],
  };
  static ThemeData light({
    AppColorTheme colorTheme = AppColorTheme.botanical,
    AppDensity density = AppDensity.comfortable,
  }) => _build(_light[colorTheme]!, Brightness.light, density);
  static ThemeData dark({
    AppColorTheme colorTheme = AppColorTheme.botanical,
    AppDensity density = AppDensity.comfortable,
  }) => _build(_dark[colorTheme]!, Brightness.dark, density);
  static ThemeData _build(
    List<Color> c,
    Brightness brightness,
    AppDensity density,
  ) {
    final p = LunoraPalette(
      background: c[0],
      surface: c[1],
      sidebar: c[2],
      sidebarSelected: c[3],
      sagePanel: c[4],
      lavender: c[5],
      rose: c[6],
      text: c[7],
      secondary: c[8],
      border: c[9],
      accent: c[10],
      accentSoft: c[4],
      success: const Color(0xFF6F9B78),
      warning: const Color(0xFFC49350),
      danger: const Color(0xFFC8797C),
    );
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c[10],
      onPrimary: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF211B29),
      secondary: c[5],
      onSecondary: c[7],
      error: p.danger,
      onError: Colors.white,
      surface: c[1],
      onSurface: c[7],
      surfaceContainerLowest: c[1],
      surfaceContainerLow: c[0],
      surfaceContainer: c[2],
      surfaceContainerHigh: c[3],
      surfaceContainerHighest: c[4],
      outline: c[9],
      outlineVariant: c[9].withValues(alpha: .65),
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: c[7],
      onInverseSurface: c[1],
      inversePrimary: c[10],
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c[0],
      canvasColor: c[1],
      fontFamily: 'Segoe UI',
      visualDensity: _density(density),
      extensions: [p],
    );
    final radius = BorderRadius.circular(16);
    return base.copyWith(
      cardTheme: CardThemeData(
        color: c[1],
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: c[9]),
        ),
      ),
      dividerTheme: DividerThemeData(color: c[9], thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: c[1],
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: c[9]),
        ),
        titleTextStyle: TextStyle(
          color: c[7],
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: c[8], fontSize: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c[0],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: c[8]),
        labelStyle: TextStyle(color: c[8]),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: c[9]),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: c[9]),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: c[10], width: 1.6),
        ),
      ),
      textTheme: base.textTheme
          .apply(bodyColor: c[7], displayColor: c[7], fontFamily: 'Segoe UI')
          .copyWith(
            headlineSmall: TextStyle(
              color: c[7],
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
            titleLarge: TextStyle(
              color: c[7],
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            titleMedium: TextStyle(
              color: c[7],
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            bodyMedium: TextStyle(color: c[7], fontSize: 14, height: 1.45),
            bodySmall: TextStyle(color: c[8], fontSize: 12, height: 1.4),
          ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(42, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(c[10]),
          foregroundColor: WidgetStatePropertyAll(
            brightness == Brightness.light
                ? Colors.white
                : const Color(0xFF211B29),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(42, 44)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: c[9])),
          foregroundColor: WidgetStatePropertyAll(c[7]),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(c[10])),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c[10] : c[8],
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c[10].withValues(alpha: .25)
              : c[9],
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c[10] : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c[7],
        contentTextStyle: TextStyle(color: c[1]),
      ),
    );
  }
}
