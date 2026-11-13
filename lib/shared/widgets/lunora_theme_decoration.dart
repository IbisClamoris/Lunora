import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_service.dart';
import '../../core/theme/lunora_theme_assets.dart';

/// Декоративные мотивы, зависящие от выбранной темы Lunora.
class LunoraThemeDecoration {
  LunoraThemeDecoration._();

  static List<IconData> motifsFor(AppColorTheme theme) => switch (theme) {
    AppColorTheme.botanical => [
      Icons.eco_outlined,
      Icons.spa_outlined,
      Icons.local_florist_outlined,
    ],
    AppColorTheme.lavender => [
      Icons.local_florist_outlined,
      Icons.auto_awesome_outlined,
      Icons.star_outline_rounded,
    ],
    AppColorTheme.roseGarden => [
      Icons.filter_vintage_outlined,
      Icons.local_florist_outlined,
      Icons.favorite_border_rounded,
    ],
    AppColorTheme.vintageLibrary => [
      Icons.menu_book_outlined,
      Icons.auto_stories_outlined,
      Icons.history_edu_outlined,
    ],
    AppColorTheme.moonlight => [
      Icons.nightlight_round,
      Icons.star_outline_rounded,
      Icons.brightness_3_outlined,
    ],
    AppColorTheme.midnight => [
      Icons.auto_awesome_outlined,
      Icons.stars_outlined,
      Icons.dark_mode_outlined,
    ],
  };

  static String? botanicalAssetFor(AppColorTheme theme) =>
      theme == AppColorTheme.vintageLibrary || theme == AppColorTheme.roseGarden
      ? LunoraThemeAssets.extra(theme)
      : LunoraThemeAssets.decoration(theme);
}

/// Универсальный декоративный разделитель.
///
/// Для каждой темы использует собственный набор символов.
class LunoraThemeDivider extends StatelessWidget {
  const LunoraThemeDivider({
    this.height = 30,
    this.opacity = 0.65,
    this.horizontalPadding = 4,
    super.key,
  });

  final double height;
  final double opacity;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService.instance.settings.colorTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = height <= 30;
    // Keep enough vertical breathing room for the complete SVG artwork.
    // Several motifs have fine strokes close to the viewBox edges.
    final effectiveHeight = compact
        ? (height < 36 ? 36.0 : height)
        : (height < 48 ? 48.0 : height);
    return SizedBox(
      height: effectiveHeight,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Opacity(
          opacity: opacity * (isDark ? 0.72 : 1),
          child: SvgPicture.asset(
            LunoraThemeAssets.divider(theme, compact: compact),
            fit: BoxFit.contain,
            alignment: Alignment.center,
            errorBuilder: (_, _, _) => Divider(
              height: height,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Небольшой декоративный мотив для карточек и заголовков.
class LunoraThemeMotif extends StatelessWidget {
  const LunoraThemeMotif({
    this.size = 24,
    this.opacity = 0.75,
    this.index = 0,
    super.key,
  });

  final double size;
  final double opacity;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService.instance.settings.colorTheme;
    final motifs = LunoraThemeDecoration.motifsFor(theme);
    final icon = motifs[index % motifs.length];

    return Opacity(
      opacity: opacity,
      child: Icon(
        icon,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
