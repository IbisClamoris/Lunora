import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_service.dart';
import '../../core/theme/lunora_theme_assets.dart';
import '../../core/theme/app_theme.dart';

/// Small wrapper for Lunora's hand-drawn SVG icon collection.
class LunoraAssetIcon extends StatelessWidget {
  const LunoraAssetIcon(
    this.assetPath, {
    this.size = 20,
    this.color,
    this.fit = BoxFit.contain,
    super.key,
  });

  final String assetPath;
  final double size;
  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? palette?.text : null);
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      fit: fit,
      colorFilter: effectiveColor == null
          ? null
          : ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      errorBuilder: (_, _, _) => Icon(
        Icons.image_not_supported_outlined,
        size: size,
        color: effectiveColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Theme-aware paper texture used by cards and surfaces across Lunora.
class LunoraPaperSurface extends StatelessWidget {
  const LunoraPaperSurface({
    required this.child,
    this.padding,
    this.borderRadius = 18,
    this.textureOpacity,
    this.borderColor,
    this.color,
    this.clipBehavior = Clip.antiAlias,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double? textureOpacity;
  final Color? borderColor;
  final Color? color;
  final Clip clipBehavior;

  static String textureFor(AppColorTheme theme) =>
      LunoraThemeAssets.texture(theme);

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.settings;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = color ?? Theme.of(context).colorScheme.surface;
    final opacity = textureOpacity ?? (dark ? 0.035 : 0.075);

    return ClipRRect(
      clipBehavior: clipBehavior,
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border.all(
            color: borderColor ?? Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: opacity,
                child: Image.asset(
                  textureFor(settings.colorTheme),
                  // Stretch one texture sheet across the surface instead of
                  // tiling it. Repeated bitmap edges were visible as seams
                  // on dark dashboard cards.
                  fit: BoxFit.cover,
                  color: dark ? const Color(0xFF77717B) : null,
                  colorBlendMode: dark ? BlendMode.softLight : null,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: dark ? 0.035 : 0.055,
                  child: SvgPicture.asset(
                    LunoraThemeAssets.frame(settings.colorTheme),
                    fit: BoxFit.fill,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            if (padding == null)
              child
            else
              Padding(padding: padding!, child: child),
          ],
        ),
      ),
    );
  }
}

/// Decorative botanical separator. The SVG is contained rather than stretched.
class LunoraBotanicalDivider extends StatelessWidget {
  const LunoraBotanicalDivider({
    this.variant = 2,
    this.height = 44,
    this.opacity = 0.88,
    this.horizontalPadding = 4,
    super.key,
  });

  final int variant;
  final double height;
  final double opacity;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.settings;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark && settings.colorTheme == AppColorTheme.midnight) {
      return Divider(
        height: height,
        thickness: 1,
        indent: horizontalPadding,
        endIndent: horizontalPadding,
        color: Theme.of(context).colorScheme.outlineVariant,
      );
    }
    final effectiveHeight =
        (variant == 1 ? height.clamp(36.0, 40.0) : height.clamp(48.0, 54.0))
            .toDouble();
    return SizedBox(
      height: effectiveHeight,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Opacity(
          opacity: opacity * (dark ? 0.72 : 1),
          child: SvgPicture.asset(
            LunoraThemeAssets.divider(
              settings.colorTheme,
              compact: variant == 1,
            ),
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

/// Decorative illustration selected automatically from the active theme.
class LunoraThemeArtwork extends StatelessWidget {
  const LunoraThemeArtwork({
    this.width = 180,
    this.height = 120,
    this.opacity = 0.72,
    this.alignment = Alignment.center,
    super.key,
  });

  final double width;
  final double height;
  final double opacity;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService.instance.settings.colorTheme;
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: SvgPicture.asset(
          LunoraThemeAssets.decoration(theme),
          width: width,
          height: height,
          fit: BoxFit.contain,
          alignment: alignment,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Thin theme-specific frame overlay for paper cards and editor panels.
class LunoraThemeFrame extends StatelessWidget {
  const LunoraThemeFrame({
    required this.child,
    this.dialog = false,
    this.padding = const EdgeInsets.all(12),
    this.opacity = 0.72,
    super.key,
  });

  final Widget child;
  final bool dialog;
  final EdgeInsetsGeometry padding;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService.instance.settings.colorTheme;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Padding(padding: padding, child: child),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: SvgPicture.asset(
                LunoraThemeAssets.frame(theme, dialog: dialog),
                fit: BoxFit.fill,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
