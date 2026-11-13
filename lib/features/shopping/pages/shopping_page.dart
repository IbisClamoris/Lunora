import 'package:lunora/core/settings/settings_service.dart';
import 'package:lunora/core/theme/lunora_theme_assets.dart';
import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:lunora/core/theme/lunora_dialog.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lunora/shared/widgets/lunora_section_header.dart';

import '../../../core/theme/app_theme.dart';
import '../../wishlist/repositories/wishlist_repository.dart';
import '../models/shopping_item.dart';
import '../repositories/shopping_repository.dart';
import '../services/shopping_export_service.dart';
import 'shopping_editor_page.dart';

enum _ShoppingExportFormat { pdf, png }

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});
  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  final ShoppingRepository _repository = ShoppingRepository.instance;
  final WishlistRepository _wishlistRepository = WishlistRepository();
  final TextEditingController _searchController = TextEditingController();
  List<ShoppingItem> _items = [];
  List<String> _categories = [];
  bool _isLoading = true;
  bool _isExporting = false;
  bool _showPurchased = false;
  String? _selectedCategory;
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final items = await _repository.getAll(
        isPurchased: _showPurchased,
        category: _selectedCategory,
        searchQuery: _searchController.text,
      );
      final categories = await _repository.getCategories();
      if (!mounted) return;
      setState(() {
        _items = items;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось загрузить список: $e'),
          ),
        ),
      );
    }
  }

  Future<void> _openEditor({ShoppingItem? item}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ShoppingEditorPage(item: item)),
    );
    if (!mounted) return;
    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _togglePurchased(ShoppingItem item) async {
    try {
      final newStatus = !item.isPurchased;
      await _repository.setPurchased(item.id, isPurchased: newStatus);
      if (item.sourceModule == 'wishlist' &&
          item.sourceRecordId != null &&
          item.sourceRecordId!.isNotEmpty) {
        await _wishlistRepository.setPurchased(
          item.sourceRecordId!,
          isPurchased: newStatus,
        );
      }
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось изменить статус: $e'),
          ),
        ),
      );
    }
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    final confirmed = await showLunoraDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LunoraLocalization.text('Удалить товар?')),
        content: Text(
          LunoraLocalization.text('«${item.title}» будет удалён из списка.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LunoraLocalization.text('Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(LunoraLocalization.text('Удалить')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await _repository.delete(item.id);
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось удалить товар: $e'),
          ),
        ),
      );
    }
  }

  Future<void> _clearPurchased() async {
    final confirmed = await showLunoraDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LunoraLocalization.text('Очистить купленное?')),
        content: Text(
          LunoraLocalization.text(
            'Все товары из раздела «Куплено» будут удалены.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LunoraLocalization.text('Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(LunoraLocalization.text('Очистить')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await _repository.deletePurchased();
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось очистить список: $e'),
          ),
        ),
      );
    }
  }

  Future<void> _showExportDialog() async {
    if (_isExporting) return;
    var selectedFormat = _ShoppingExportFormat.pdf;
    var selectedFilter = ShoppingExportFilter.all;
    final options =
        await showLunoraDialog<
          ({_ShoppingExportFormat format, ShoppingExportFilter filter})
        >(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text(LunoraLocalization.text('Экспорт списка')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(LunoraLocalization.text('Формат файла')),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<_ShoppingExportFormat>(
                        initialValue: selectedFormat,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: _ShoppingExportFormat.pdf,
                            child: Text(
                              LunoraLocalization.text('PDF-документ'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: _ShoppingExportFormat.png,
                            child: Text(
                              LunoraLocalization.text('PNG-изображение'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedFormat = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(LunoraLocalization.text('Что экспортировать')),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<ShoppingExportFilter>(
                        initialValue: selectedFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: ShoppingExportFilter.all,
                            child: Text(LunoraLocalization.text('Весь список')),
                          ),
                          DropdownMenuItem(
                            value: ShoppingExportFilter.toBuy,
                            child: Text(
                              LunoraLocalization.text('Только к покупке'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: ShoppingExportFilter.purchased,
                            child: Text(
                              LunoraLocalization.text('Только купленное'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedFilter = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        LunoraLocalization.text(
                          'Файл будет сохранён в папку Lunora/Exports.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(LunoraLocalization.text('Отмена')),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext, (
                          format: selectedFormat,
                          filter: selectedFilter,
                        ));
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: Text(LunoraLocalization.text('Экспортировать')),
                    ),
                  ],
                );
              },
            );
          },
        );
    if (!mounted || options == null) return;
    await _exportItems(format: options.format, filter: options.filter);
  }

  Future<void> _exportItems({
    required _ShoppingExportFormat format,
    required ShoppingExportFilter filter,
  }) async {
    final theme = Theme.of(context);
    final palette = theme.extension<LunoraPalette>();
    final isDark = theme.brightness == Brightness.dark;
    if (palette == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось определить цветовую тему.'),
          ),
        ),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      final allItems = await _repository.getAll();
      if (!mounted) return;
      final service = ShoppingExportService.instance;
      final file = switch (format) {
        _ShoppingExportFormat.pdf => await service.exportPdf(
          items: allItems,
          filter: filter,
          palette: palette,
        ),
        _ShoppingExportFormat.png => await service.exportPng(
          items: allItems,
          filter: filter,
          palette: palette,
          isDark: isDark,
        ),
      };
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Файл успешно сохранён:\n${file.path}'),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось экспортировать список: $e'),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        // Непрозрачная подложка перекрывает глобальный декор оболочки.
        // Поэтому на странице остаётся только собственная, контролируемая композиция.
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: IgnorePointer(
              child: Opacity(
                opacity: isDark ? 0.035 : 0.065,
                child: Image.asset(
                  LunoraThemeAssets.texture(
                    SettingsService.instance.settings.colorTheme,
                  ),
                  fit: BoxFit.none,
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),
          ),
        ),
        // Небольшой акцент сверху слева и основная композиция снизу справа.
        // Оба элемента находятся за контентом и не обрезаются краями окна.
        Positioned(
          top: 18,
          left: 18,
          child: IgnorePointer(
            child: Opacity(
              opacity: isDark ? 0.045 : 0.075,
              child: SvgPicture.asset(
                LunoraThemeAssets.decoration(
                  SettingsService.instance.settings.colorTheme,
                ),
                width: 92,
                height: 118,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          right: 22,
          child: IgnorePointer(
            child: Opacity(
              opacity: isDark ? 0.055 : 0.095,
              child: SvgPicture.asset(
                LunoraThemeAssets.extra(
                  SettingsService.instance.settings.colorTheme,
                ),
                width: 164,
                height: 218,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth < 1248
                ? constraints.maxWidth
                : 1200.0;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(palette),
                      const SizedBox(height: 18),
                      _buildStatistics(palette),
                      const SizedBox(height: 18),
                      _buildSearchAndFilters(palette),
                      const SizedBox(height: 14),
                      _buildTabs(),
                      const SizedBox(height: 14),
                      Expanded(child: _buildItemsList(palette)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader(LunoraPalette? palette) {
    return LunoraSectionHeader(
      title: LunoraLocalization.text('Список покупок'),
      subtitle: LunoraLocalization.text('Маленькие запасы большого уюта'),
      icon: Icons.shopping_basket_outlined,
      actions: [
        IconButton.filledTonal(
          tooltip: LunoraLocalization.text('Экспортировать список'),
          onPressed: _isExporting ? null : _showExportDialog,
          icon: _isExporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined),
        ),
        if (_showPurchased)
          IconButton(
            tooltip: LunoraLocalization.text('Очистить купленное'),
            onPressed: _items.isEmpty ? null : _clearPurchased,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        FilledButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add),
          label: Text(LunoraLocalization.text('Добавить')),
        ),
      ],
    );
  }

  Widget _buildStatistics(LunoraPalette? palette) {
    return FutureBuilder<List<int>>(
      future: Future.wait([
        _repository.getCount(isPurchased: false),
        _repository.getCount(isPurchased: true),
      ]),
      builder: (context, snapshot) {
        final remaining = snapshot.data?[0] ?? 0;
        final purchased = snapshot.data?[1] ?? 0;
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 260,
              child: _statCard(
                title: LunoraLocalization.text('К покупке'),
                value: remaining.toString(),
                icon: Icons.shopping_basket_outlined,
                color: palette?.sagePanel ?? Colors.green.shade50,
              ),
            ),
            SizedBox(
              width: 260,
              child: _statCard(
                title: LunoraLocalization.text('Куплено'),
                value: purchased.toString(),
                icon: Icons.check_circle_outline,
                color: palette?.lavender ?? Colors.purple.shade50,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              Theme.of(context)
                  .extension<LunoraPalette>()
                  ?.border
                  .withValues(alpha: 0.55) ??
              Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(LunoraPalette? palette) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: LunoraLocalization.text('Найти товар...'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _loadData();
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<String?>(
          tooltip: LunoraLocalization.text('Фильтр по категории'),
          initialValue: _selectedCategory,
          onSelected: (value) {
            setState(() => _selectedCategory = value);
            _loadData();
          },
          itemBuilder: (context) => [
            PopupMenuItem<String?>(
              value: null,
              child: Text(LunoraLocalization.text('Все категории')),
            ),
            ..._categories.map(
              (category) => PopupMenuItem<String?>(
                value: category,
                child: Text(category),
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: palette?.secondary ?? Colors.grey.shade400,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.filter_list),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    final selectedColor = Theme.of(context).colorScheme.primary;
    return Container(
      width: 480,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              title: LunoraLocalization.text('К покупке'),
              selected: !_showPurchased,
              selectedColor: selectedColor,
              onTap: () {
                if (!_showPurchased) return;
                setState(() {
                  _showPurchased = false;
                  _selectedCategory = null;
                });
                _loadData();
              },
            ),
          ),
          Expanded(
            child: _tabButton(
              title: LunoraLocalization.text('Куплено'),
              selected: _showPurchased,
              selectedColor: selectedColor,
              onTap: () {
                if (_showPurchased) return;
                setState(() {
                  _showPurchased = true;
                  _selectedCategory = null;
                });
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required bool selected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: selected
                ? Border.all(color: selectedColor.withValues(alpha: 0.42))
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsList(LunoraPalette? palette) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                LunoraThemeAssets.emptyState(
                  SettingsService.instance.settings.colorTheme,
                  'shopping',
                ),
                width: 210,
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Text(
                _showPurchased
                    ? 'Пока ничего не куплено'
                    : 'Корзина пока пуста',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _showPurchased ? 'Купленные товары появятся здесь' : 'Добавь нужное вручную или перенеси ингредиенты из рецепта',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette?.secondary ?? Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildItemCard(item, palette);
      },
    );
  }

  Widget _buildItemCard(ShoppingItem item, LunoraPalette? palette) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEditor(item: item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: (palette?.surface ?? Theme.of(context).colorScheme.surface)
                .withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (palette?.border ?? Colors.grey).withValues(alpha: 0.65),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: item.isPurchased,
                onChanged: (_) => _togglePurchased(item),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: item.isPurchased
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isPurchased ? palette?.secondary : null,
                      ),
                    ),
                    if (item.quantity != null || item.unit != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (item.quantity != null)
                            _formatQuantity(item.quantity!),
                          if (item.unit != null && item.unit!.isNotEmpty)
                            item.unit!,
                        ].join(' '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (item.category != null &&
                        item.category!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.category!,
                        style: TextStyle(
                          fontSize: 12,
                          color: palette?.secondary ?? Colors.grey,
                        ),
                      ),
                    ],
                    if (_visibleNotes(item) case final notes?) ...[
                      const SizedBox(height: 4),
                      Text(notes, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: LunoraLocalization.text('Удалить'),
                onPressed: () => _deleteItem(item),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _visibleNotes(ShoppingItem item) {
    final notes = item.notes?.trim();
    if (notes == null || notes.isEmpty) return null;
    // Some older recipe integrations stored their internal ingredient key
    // in the notes column. Keep that metadata in the database, but never
    // expose it as a note in the shopping list UI.
    final normalized = notes.toLowerCase();
    if (normalized.startsWith('recipe_ingredient_id:') ||
        normalized.startsWith('recipe_ingredient_id=')) {
      return null;
    }
    return notes;
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}
