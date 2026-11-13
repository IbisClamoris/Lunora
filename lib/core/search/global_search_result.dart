import '../navigation/lunora_navigation.dart';

class GlobalSearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String tableName;
  final LunoraSection section;

  const GlobalSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tableName,
    required this.section,
  });
}
