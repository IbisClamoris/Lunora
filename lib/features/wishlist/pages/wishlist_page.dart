import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../shared/widgets/lunora_section_header.dart';

import '../../../core/theme/app_theme.dart';
import '../models/wishlist_entry.dart';
import '../repositories/wishlist_repository.dart';
import 'wishlist_details_page.dart';
import 'wishlist_editor_page.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final WishlistRepository _repository = WishlistRepository();
  final TextEditingController _searchController = TextEditingController();

  List<WishlistEntry> _entries = [];
  List<String> _categories = [];

  bool _isLoading = true;
  bool _showPurchased = false;

  String _searchQuery = '';
  String _selectedCategory = 'Все категории';
  String _selectedPriority = 'Все приоритеты';

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
    try {
      final entries = await _repository.getAll();
      final categories = await _repository.getCategories();

      if (!mounted) return;

      setState(() {
        _entries = entries;
        _categories = categories;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Ошибка загрузки Вишлиста: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditor() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const WishlistEditorPage()));

    if (result == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _openDetails(WishlistEntry entry) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WishlistDetailsPage(entry: entry)),
    );

    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _togglePurchased(WishlistEntry entry) async {
    try {
      await _repository.setPurchased(entry.id, isPurchased: !entry.isPurchased);
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text('Не удалось изменить статус покупки: $error'))),
      );
    }
  }

  List<WishlistEntry> get _filteredEntries {
    return _entries.where((entry) {
      if (entry.isPurchased != _showPurchased) return false;

      if (_selectedCategory != 'Все категории' &&
          entry.category != _selectedCategory) {
        return false;
      }

      if (_selectedPriority != 'Все приоритеты' &&
          entry.priority != _selectedPriority) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();

        final matchesTitle = entry.title.toLowerCase().contains(query);
        final matchesDescription = entry.description.toLowerCase().contains(
          query,
        );
        final matchesTags = entry.tags.any(
          (tag) => tag.toLowerCase().contains(query),
        );

        if (!matchesTitle && !matchesDescription && !matchesTags) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  int get _totalCount => _entries.length;

  int get _purchasedCount =>
      _entries.where((entry) => entry.isPurchased).length;

  double get _totalPrice {
    return _entries
        .where((entry) => !entry.isPurchased)
        .fold<double>(0, (sum, entry) => sum + (entry.price ?? 0));
  }

  Color _priorityColor(String priority, LunoraPalette palette) {
    switch (priority) {
      case 'high':
        return const Color(0xFFCB8585);
      case 'low':
        return const Color(0xFF91A99A);
      default:
        return palette.accent;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return LunoraLocalization.text('Высокий', 'High');
      case 'low':
        return LunoraLocalization.text('Низкий', 'Low');
      default:
        return LunoraLocalization.text('Обычный', 'Normal');
    }
  }

  String _formatPrice(WishlistEntry entry) {
    if (entry.price == null) return 'Цена не указана';

    final price = entry.price!.toStringAsFixed(2);
    final formattedPrice = price.endsWith('.00')
        ? price.substring(0, price.length - 3)
        : price;

    return entry.currency.isEmpty
        ? formattedPrice
        : '$formattedPrice ${entry.currency}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(palette),
          const SizedBox(height: 22),
          _buildStatistics(palette),
          const SizedBox(height: 22),
          _buildControls(palette),
          const SizedBox(height: 18),
          Expanded(child: _buildContent(palette)),
        ],
      ),
    );
  }

  Widget _buildHeader(LunoraPalette palette) {
    return LunoraSectionHeader(
      title: LunoraLocalization.text('Мой вишлист'),
      subtitle: LunoraLocalization.text(
        LunoraLocalization.text('Всё, что хочется сохранить и однажды приобрести.', 'Everything you want to save and eventually buy.'),
      ),
      icon: Icons.auto_awesome_rounded,
      actions: [
        FilledButton.icon(
          onPressed: _openEditor,
          icon: const Icon(Icons.add),
          label: Text(LunoraLocalization.text('Добавить желание')),
        ),
      ],
    );
  }

  Widget _buildStatistics(LunoraPalette palette) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final cardWidth = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - 36) / 3;

        return Wrap(
          spacing: 18,
          runSpacing: 12,
          children: [
            _statCard(
              LunoraLocalization.text('Всего желаний', 'Total wishes'),
              _totalCount.toString(),
              Icons.auto_awesome_outlined,
              palette,
              cardWidth,
            ),
            _statCard(
              LunoraLocalization.text('Уже приобретено', 'Already purchased'),
              _purchasedCount.toString(),
              Icons.shopping_bag_outlined,
              palette,
              cardWidth,
            ),
            _statCard(
              LunoraLocalization.text('Планируемая сумма', 'Planned amount'),
              _totalPrice.toStringAsFixed(2),
              Icons.account_balance_wallet_outlined,
              palette,
              cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    LunoraPalette palette,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.text.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.accent, size: 23),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: palette.secondary),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(LunoraPalette palette) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 250,
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
              });
            },
            decoration: InputDecoration(
              hintText: LunoraLocalization.text('Поиск желаний...'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: palette.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        _buildDropdown(
          value: _selectedCategory,
          items: [
            'Все категории',
            ..._categories.where((item) => item != 'Все категории'),
          ],
          onChanged: (value) {
            setState(() {
              _selectedCategory = value;
            });
          },
          palette: palette,
        ),
        _buildDropdown(
          value: _selectedPriority,
          items: const ['Все приоритеты', 'high', 'normal', 'low'],
          labels: const {
            'Все приоритеты': LunoraLocalization.text('Все приоритеты', 'All priorities'),
            'high': LunoraLocalization.text('Высокий приоритет', 'High priority'),
            'normal': LunoraLocalization.text('Обычный приоритет', 'Normal priority'),
            'low': LunoraLocalization.text('Низкий приоритет', 'Low priority'),
          },
          onChanged: (value) {
            setState(() {
              _selectedPriority = value;
            });
          },
          palette: palette,
        ),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(LunoraLocalization.text('Желания')),
              icon: Icon(Icons.favorite_border),
            ),
            ButtonSegment(
              value: true,
              label: Text(LunoraLocalization.text('Куплено')),
              icon: Icon(Icons.check_circle_outline),
            ),
          ],
          selected: {_showPurchased},
          onSelectionChanged: (selection) {
            setState(() {
              _showPurchased = selection.first;
            });
          },
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(palette.text),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    Map<String, String>? labels,
    required ValueChanged<String> onChanged,
    required LunoraPalette palette,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: palette.surface,
          style: TextStyle(color: palette.text, fontSize: 12),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(labels?[item] ?? item),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ),
    );
  }

  Widget _buildContent(LunoraPalette palette) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: palette.accent));
    }

    final entries = _filteredEntries;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showPurchased
                  ? Icons.shopping_bag_outlined
                  : Icons.auto_awesome_outlined,
              size: 55,
              color: palette.secondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 15),
            Text(
              _showPurchased
                  ? LunoraLocalization.text('Пока ничего не приобретено', 'Nothing purchased yet')
                  : LunoraLocalization.text('Здесь пока пусто', 'Nothing here yet'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              LunoraLocalization.text('Добавленные желания появятся здесь.'),
              style: TextStyle(fontSize: 13, color: palette.secondary),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final crossAxisCount = width >= 1200
            ? 4
            : width >= 850
            ? 3
            : width >= 550
            ? 2
            : 1;

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 1 ? 2.8 : 0.95,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            return _buildEntryCard(entries[index], palette);
          },
        );
      },
    );
  }

  Widget _buildEntryCard(WishlistEntry entry, LunoraPalette palette) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetails(entry),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.text.withValues(alpha: 0.08)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (entry.imagePath != null && entry.imagePath!.isNotEmpty)
                      Image.file(
                        File(entry.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _imagePlaceholder(palette);
                        },
                      )
                    else
                      _imagePlaceholder(palette),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _chip(entry.category, palette.accent),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _chip(
                        _priorityLabel(entry.priority),
                        _priorityColor(entry.priority, palette),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                        child: Text(
                          entry.description.isEmpty
                              ? LunoraLocalization.text('Без описания', 'No description')
                              : entry.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatPrice(entry),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: entry.isPurchased
                                ? LunoraLocalization.text('Вернуть в желания', 'Move back to wishlist')
                                : LunoraLocalization.text('Отметить купленным', 'Mark as purchased'),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () => _togglePurchased(entry),
                              icon: Icon(
                                entry.isPurchased
                                    ? Icons.check_circle
                                    : Icons.shopping_bag_outlined,
                                color: entry.isPurchased
                                    ? palette.accent
                                    : palette.secondary,
                                size: 19,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder(LunoraPalette palette) {
    return Container(
      color: palette.sidebar,
      child: Center(
        child: Icon(
          Icons.auto_awesome_outlined,
          size: 42,
          color: palette.secondary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
