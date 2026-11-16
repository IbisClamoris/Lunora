import 'package:flutter/material.dart';

import '../../../core/localization/lunora_localization.dart';
import '../models/collection_entry.dart';
import '../repositories/collection_repository.dart';

/// Adds an existing record to one of the user's personal collections.
class AddToCollectionButton extends StatefulWidget {
  const AddToCollectionButton({
    super.key,
    required this.recordModule,
    required this.recordId,
    required this.recordTitle,
    this.iconColor,
    this.backgroundColor,
    this.compact = false,
  });

  final String recordModule;
  final String recordId;
  final String recordTitle;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool compact;

  @override
  State<AddToCollectionButton> createState() => _AddToCollectionButtonState();
}

class _AddToCollectionButtonState extends State<AddToCollectionButton> {
  bool _busy = false;

  Future<void> _openCollectionPicker() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final collections = await CollectionRepository.instance.getAll();
      if (!mounted) return;

      final selected = await showDialog<CollectionEntry>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(LunoraLocalization.text('Добавить в коллекцию', 'Add to collection')),
          content: SizedBox(
            width: 380,
            child: collections.isEmpty
                ? Text(LunoraLocalization.text(
                    'Пока нет коллекций. Сначала создай коллекцию в разделе «Коллекции».',
                    'There are no collections yet. Create one in the Collections section first.',
                  ))
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: collections.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final collection = collections[index];
                        final color = collection.colorValue == null
                            ? Theme.of(context).colorScheme.primary
                            : Color(collection.colorValue!);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 17,
                            backgroundColor: color.withValues(alpha: 0.16),
                            child: Icon(Icons.collections_bookmark_outlined, color: color, size: 18),
                          ),
                          title: Text(collection.name),
                          subtitle: Text(LunoraLocalization.text(
                            '${collection.itemCount} записей',
                            '${collection.itemCount} items',
                          )),
                          onTap: () => Navigator.pop(dialogContext, collection),
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(LunoraLocalization.text('Закрыть', 'Close')),
            ),
          ],
        ),
      );

      if (selected == null || !mounted) return;

      final added = await CollectionRepository.instance.addRecord(
        collectionId: selected.id,
        recordModule: widget.recordModule,
        recordId: widget.recordId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added
              ? LunoraLocalization.text(
                  '«${widget.recordTitle}» добавлено в «${selected.name}».',
                  '“${widget.recordTitle}” added to “${selected.name}”.',
                )
              : LunoraLocalization.text(
                  'Эта запись уже есть в коллекции.',
                  'This record is already in that collection.',
                )),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text(
          'Не удалось добавить запись: $error',
          'Could not add record: $error',
        ))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
      tooltip: LunoraLocalization.text('В коллекцию', 'Add to collection'),
      onPressed: _busy ? null : _openCollectionPicker,
      style: widget.backgroundColor == null
          ? null
          : IconButton.styleFrom(backgroundColor: widget.backgroundColor),
      icon: _busy
          ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.collections_bookmark_outlined, color: widget.iconColor, size: 19),
    );
  }
}
