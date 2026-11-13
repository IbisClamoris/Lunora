import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/settings/settings_service.dart';
import '../../core/theme/lunora_theme_assets.dart';

class LunoraThemeBackdrop extends StatelessWidget {
  const LunoraThemeBackdrop({
    required this.child,
    this.opacity = .13,
    this.enabled = true,
    super.key,
  });
  final Widget child;
  final double opacity;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.settings;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).scaffoldBackgroundColor;
    return ColoredBox(
      color: color,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: dark ? .035 : .065,
                  child: Image.asset(
                    LunoraThemeAssets.texture(settings.colorTheme),
                    fit: BoxFit.none,
                    repeat: ImageRepeat.repeat,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          Positioned.fill(child: child),
          if (enabled)
            Positioned(
              right: -42,
              bottom: -34,
              child: IgnorePointer(
                child: Opacity(
                  opacity: dark ? opacity * .72 : opacity,
                  child: SizedBox(
                    width: 330,
                    height: 270,
                    child: SvgPicture.asset(
                      LunoraThemeAssets.decoration(settings.colorTheme),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
