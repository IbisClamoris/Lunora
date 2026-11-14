import 'package:flutter/material.dart';

import '../../core/localization/lunora_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../core/settings/settings_service.dart';
import '../../core/theme/lunora_theme_assets.dart';
import '../../shared/widgets/lunora_visuals.dart';
import '../config/menu_entries.dart';

import 'package:flutter_svg/flutter_svg.dart';

class LunoraSidebar extends StatelessWidget {
  const LunoraSidebar({
    super.key,
    required this.expanded,
    required this.selectedIndex,
    required this.onSelect,
    required this.onToggle,
    required this.duration,
    this.visibleIndices = const [],
  });

  final bool expanded;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggle;
  final Duration duration;
  final List<int> visibleIndices;

  static const _iconNames = <String>[
    'home',
    'calendar',
    'bell',
    'shopping',
    'planner',
    'study',
    'finance',
    'books',
    'diary',
    'image',
    'books',
    'film',
    'recipes',
    'wishes',
    'settings',
  ];

  static const _englishTitles = <String>[
    'Home',
    'Calendar',
    'Notifications',
    'Shopping list',
    'My planner',
    'Study planner',
    'Finances',
    'Knowledge base',
    'Diary',
    'Diary gallery',
    'My books',
    'Movies & series',
    'Recipe book',
    'Wishlist',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;
    final indices = visibleIndices.isEmpty
        ? List<int>.generate(menuEntries.length, (index) => index)
        : visibleIndices;

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: expanded ? 252 : 76,
      color: palette.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? 20 : 12,
                18,
                expanded ? 18 : 12,
                22,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.border),
                    ),
                    child: AnimatedBuilder(
                      animation: SettingsService.instance,
                      builder: (context, _) {
                        final settings = SettingsService.instance.settings;
                        final themeName =
                            LunoraThemeAssets.folder(settings.colorTheme);
                        final modeName =
                            Theme.of(context).brightness == Brightness.dark
                                ? 'dark'
                                : 'light';
                        final assetPath =
                            'assets/branding/theme_icons/${themeName}_${modeName}.png';

                        return Image.asset(
                          assetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              SvgPicture.asset(
                            'assets/branding/app_icon.svg',
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                    ),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lunora',
                            style: TextStyle(
                              color: palette.text,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.4,
                            ),
                          ),
                          Text(
                            LunoraLocalization.text(
                              'твой личный мир',
                              'your personal world',
                            ),
                            style: TextStyle(
                              color: palette.secondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    LunoraLocalization.text('ТВОИ ПРОСТРАНСТВА', 'YOUR SPACES'),
                    style: TextStyle(
                      color: palette.secondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 10 : 9,
                  vertical: 4,
                ),
                itemCount: indices.length,
                itemBuilder: (context, itemIndex) {
                  final index = indices[itemIndex];
                  final entry = menuEntries[index];
                  final selected = index == selectedIndex;
                  final title = LunoraLocalization.isEnglish
                      ? _englishTitles[index]
                      : entry.title;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Tooltip(
                      message: expanded ? '' : title,
                      child: Material(
                        color: selected
                            ? palette.sidebarSelected
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => onSelect(index),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 46,
                            padding: EdgeInsets.symmetric(
                              horizontal: expanded ? 12 : 0,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: selected
                                  ? Border.all(
                                      color: palette.accent.withValues(
                                        alpha: .35,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: expanded
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                if (selected && expanded)
                                  Container(
                                    width: 3,
                                    height: 22,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: palette.accent,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                LunoraAssetIcon(
                                  LunoraThemeAssets.icon(
                                    SettingsService
                                        .instance
                                        .settings
                                        .colorTheme,
                                    _iconNames[index],
                                    size: 24,
                                  ),
                                  size: 21,
                                ),
                                if (expanded) ...[
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selected
                                            ? palette.text
                                            : palette.secondary,
                                        fontSize: 12.5,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: palette.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                expanded ? 12 : 9,
                10,
                expanded ? 12 : 9,
                12,
              ),
              child: Column(
                children: [
                  Container(height: 1, color: palette.border),
                  const SizedBox(height: 10),
                  Material(
                    color: palette.surface.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(13),
                      child: SizedBox(
                        height: 42,
                        child: Row(
                          mainAxisAlignment: expanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 13),
                            Icon(
                              expanded
                                  ? Icons.chevron_left_rounded
                                  : Icons.chevron_right_rounded,
                              color: palette.secondary,
                              size: 20,
                            ),
                            if (expanded) ...[
                              const SizedBox(width: 8),
                              Text(
                                LunoraLocalization.text(
                                  'Свернуть меню',
                                  'Collapse menu',
                                ),
                                style: TextStyle(
                                  color: palette.secondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
