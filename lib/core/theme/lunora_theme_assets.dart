import '../settings/app_settings.dart';

/// Единный реестр полного набора визуальных ресурсов шести тем Lunora.
/// Имена и пути соответствуют оригинальному пакету lunora-all-themes.
abstract final class LunoraThemeAssets {
  static String folder(AppColorTheme theme) => switch (theme) {
    AppColorTheme.botanical => 'botanical',
    AppColorTheme.lavender => 'lavender',
    AppColorTheme.roseGarden => 'rose_garden',
    AppColorTheme.vintageLibrary => 'vintage_library',
    AppColorTheme.moonlight => 'moonlight',
    AppColorTheme.midnight => 'midnight',
  };

  static String path(AppColorTheme theme, String category, String filename) =>
      'assets/themes/${folder(theme)}/$category/$filename';

  static String icon(AppColorTheme theme, String filename, {int size = 24}) =>
      path(theme, 'icons/$size', '${filename.replaceAll('.svg', '')}.svg');

  static String texture(AppColorTheme theme) =>
      path(theme, 'textures', switch (theme) {
        AppColorTheme.botanical => 'belaya-hlopkovaya-bumaga.png',
        AppColorTheme.lavender => 'svetlaya-lavandovaya-bumaga.png',
        AppColorTheme.roseGarden => 'rozovataya-bumaga.png',
        AppColorTheme.vintageLibrary => 'starinnaya-bumaga-s-voloknami.png',
        AppColorTheme.moonlight => 'lunno-kremovaya-bumaga.png',
        AppColorTheme.midnight => 'temno-sinyaya-bumaga.png',
      });

  static String divider(AppColorTheme theme, {bool compact = false}) => path(
    theme,
    'dividers',
    compact
        ? 'korotkiy-dlya-kartochek.svg'
        : switch (theme) {
            AppColorTheme.botanical => 's-vetochkami.svg',
            AppColorTheme.lavender => 's-malenkimi-cvetami.svg',
            AppColorTheme.roseGarden => 's-butonami-i-listyami.svg',
            AppColorTheme.vintageLibrary => 's-perom.svg',
            AppColorTheme.moonlight => 'lunnye-fazy.svg',
            AppColorTheme.midnight => 'temnye-cvety-i-listya.svg',
          },
  );

  static String decoration(AppColorTheme theme) =>
      path(theme, 'decor', switch (theme) {
        AppColorTheme.botanical => 'gerbarnaya-kompoziciya.svg',
        AppColorTheme.lavender => 'buket-lavandy.svg',
        AppColorTheme.roseGarden => 'venok.svg',
        AppColorTheme.vintageLibrary => 'bibliotechnaya-kompoziciya.svg',
        AppColorTheme.moonlight => 'sozvezdie.svg',
        AppColorTheme.midnight => 'alhimicheskiy-ornament.svg',
      });

  static String frame(AppColorTheme theme, {bool dialog = false}) => path(
    theme,
    'frames',
    dialog ? 'dialogovoe-okno.svg' : 'prostaya-kartochka.svg',
  );

  static String extra(AppColorTheme theme) =>
      path(theme, 'extras', switch (theme) {
        AppColorTheme.botanical => 'pechat-gerbariya.svg',
        AppColorTheme.lavender => 'cvetochnaya-pechat.svg',
        AppColorTheme.roseGarden => 'rozetka.svg',
        AppColorTheme.vintageLibrary => 'surguchnaya-pechat.svg',
        AppColorTheme.moonlight => 'nebesnaya-pechat.svg',
        AppColorTheme.midnight => 'misticheskaya-pechat.svg',
      });

  static String emptyState(AppColorTheme theme, String key) =>
      path(theme, 'empty-states', switch (key) {
        'tasks' => 'poka-net-zadach.svg',
        'calendar' => 'kalendar-poka-pust.svg',
        'notifications' => 'net-uvedomleniy.svg',
        'shopping' => 'spisok-pokupok-pust.svg',
        'planner' => 'net-zapisey-v-planere.svg',
        'diary' => 'dnevnik-esche-ne-zapolnen.svg',
        'books' => 'net-knig.svg',
        'movies' => 'net-filmov-i-serialov.svg',
        'recipes' => 'net-receptov.svg',
        'wishlist' => 'net-zhelaniy.svg',
        'study' => 'net-uchebnyh-materialov.svg',
        'finance' => 'net-finansovyh-zapisey.svg',
        'search' => 'poisk-nichego-ne-nashel.svg',
        'attachments' => 'otsutstvuyut-vlozheniya.svg',
        'exported' => 'dannye-uspeshno-eksportirovany.svg',
        'export' => 'net-dannyh-dlya-eksporta.svg',
        'import' => 'import-zavershen.svg',
        'error' => 'oshibka-zagruzki.svg',
        'offline' => 'net-podklyucheniya.svg',
        _ => 'poka-net-zadach.svg',
      });
}
