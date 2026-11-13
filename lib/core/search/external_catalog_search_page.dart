import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalSearchSource {
  final String name;
  final String domain;
  const ExternalSearchSource(this.name, this.domain);
}

class ExternalCatalogSearchPage extends StatefulWidget {
  final String title;
  final String description;
  final String hint;
  final IconData icon;
  final List<ExternalSearchSource> sources;

  const ExternalCatalogSearchPage({
    super.key,
    required this.title,
    required this.description,
    required this.hint,
    required this.icon,
    required this.sources,
  });

  @override
  State<ExternalCatalogSearchPage> createState() =>
      _ExternalCatalogSearchPageState();
}

class _ExternalCatalogSearchPageState extends State<ExternalCatalogSearchPage> {
  final _controller = TextEditingController();
  String? _opening;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(ExternalSearchSource source) async {
    final query = _controller.text.trim();
    if (query.isEmpty || _opening != null) return;
    setState(() => _opening = source.name);
    try {
      final uri = Uri.https('yandex.ru', '/search/', {
        'text': 'site:${source.domain} $query',
      });
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LunoraLocalization.text('Не удалось открыть браузер.'),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LunoraLocalization.text('Не удалось открыть поиск: $error'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  Future<void> _openGeneralSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final uri = Uri.https('yandex.ru', '/search/', {'text': query});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(widget.icon, size: 54, color: colors.primary),
              const SizedBox(height: 14),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _openGeneralSearch(),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: LunoraLocalization.text('Очистить'),
                    onPressed: () => setState(_controller.clear),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _controller.text.trim().isEmpty
                    ? null
                    : _openGeneralSearch,
                icon: const Icon(Icons.travel_explore_rounded),
                label: Text(LunoraLocalization.text('Искать в Яндексе')),
              ),
              const SizedBox(height: 24),
              Text(
                LunoraLocalization.text('Искать на конкретном сайте'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              ...widget.sources.map(
                (source) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed:
                        _controller.text.trim().isEmpty || _opening != null
                        ? null
                        : () => _open(source),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _opening == source.name
                            ? 'Открываем ${source.name}…'
                            : source.name,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                LunoraLocalization.text(
                  'Поиск открывается в браузере. Lunora не загружает и не разбирает HTML сайтов: это избавляет от проблем с защитой и постоянно меняющейся разметкой. Найденный материал можно добавить в свою коллекцию обычным способом.',
                ),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
