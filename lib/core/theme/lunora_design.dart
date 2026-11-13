import 'package:flutter/material.dart';

/// Отступы Lunora.
abstract final class LunoraSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 28;
  static const double page = 28;
  static const double pageCompact = 16;
}

/// Скругления.
abstract final class LunoraRadius {
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double xxl = 28;
  static const double pill = 999;
}

/// Размеры интерактивных элементов.
abstract final class LunoraControlSize {
  static const double compact = 34;
  static const double standard = 40;
  static const double large = 46;
  static const double input = 44;
  static const double sidebarExpanded = 248;
  static const double sidebarCollapsed = 76;
  static const double topBar = 68;
}

/// Анимации.
abstract final class LunoraMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration gentle = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 450);

  static const Curve curve = Curves.easeInOutCubic;
  static const Curve enterCurve = Curves.easeOutCubic;
}

/// Глубина поверхностей.
abstract final class LunoraElevation {
  static const double none = 0;
  static const double subtle = 1;
  static const double floating = 3;
  static const double dialog = 10;
}

/// Параметры бумажных поверхностей.
abstract final class LunoraPaperStyle {
  static const double cardTextureOpacity = .38;
  static const double panelTextureOpacity = .25;
  static const double darkTextureOpacity = .10;
  static const double borderOpacity = .85;
}

/// Общие настройки контекста.
extension LunoraDesignContext on BuildContext {
  ThemeData get lunoraTheme => Theme.of(this);

  ColorScheme get lunoraColors => Theme.of(this).colorScheme;

  TextTheme get lunoraText => Theme.of(this).textTheme;

  LunoraPaletteTokens get lunoraPalette => LunoraPaletteTokens(
    background: Theme.of(this).scaffoldBackgroundColor,
    surface: Theme.of(this).colorScheme.surface,
    primary: Theme.of(this).colorScheme.primary,
    onPrimary: Theme.of(this).colorScheme.onPrimary,
    text: Theme.of(this).colorScheme.onSurface,
    border: Theme.of(this).colorScheme.outline,
  );
}

/// Основные семантические цвета.
@immutable
class LunoraPaletteTokens {
  const LunoraPaletteTokens({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.text,
    required this.border,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color text;
  final Color border;
}
