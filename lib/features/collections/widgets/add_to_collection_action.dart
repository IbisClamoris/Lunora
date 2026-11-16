import 'package:flutter/material.dart';

import '../../../core/localization/lunora_localization.dart';
import '../repositories/collection_repository.dart';
import '../models/collection_entry.dart';

class AddToCollectionAction extends StatelessWidget {
  final String recordModule;
  final String recordId;
  final String recordTitle;

  const AddToCollectionAction({
    super.key,
    required this.recordModule,
    required this.recordId,
    required this.recordTitle,
  });

  Future<void> _addToCollection(BuildContext context) async {
    final repository = CollectionRepository.instance;
    final collectionsFuture = repository.getAll();

    final collectionId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LunoraLocalization.text('Добавить в коллекцию', 'Add to collection')),
        content: SizedBox(
          width: 420,
          child: FutureBuilder<List<CollectionEntry>>(
            future: collectionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(LunoraLocalization.text(
                  'Не удалось загрузить коллекции: ${snapshot.error}',
                  'Could not load collections: ${snapshot.error}',
                ));
              }
              final collections = snapshot.data ?? const <CollectionEntry>[];
              if (collections.isEmpty) {
                return Text(LunoraLocalization.text(
                  'Сначала создай коллекцию в разделе «Коллекции».',
                  'Create a collection in the Collections section first.',
                ));
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: collections.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.folder_outlined,
                        color: collection.colorValue == null
                            ? null
                            : Color(collection.colorValue!),
                      ),
                      title: Text(collection.name),
                      subtitle: Text(LunoraLocalization.text(
                        '${collection.itemCount} записей',
                        '${collection.itemCount} items',
                      )),
                      onTap: () => Navigator.of(dialogContext).pop(collection.id),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(LunoraLocalization.text('Отмена', 'Cancel')),
          ),
        ],
      ),
    );

    if (collectionId == null || !context.mounted) return;

    try {
      final added = await repository.addRecord(
        collectionId: collectionId,
        recordModule: recordModule,
        recordId: recordId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(added
            ? LunoraLocalization.text('«$recordTitle» добавлено в коллекцию.', '“$recordTitle” added to the collection.')
            : LunoraLocalization.text('Эта запись уже есть в коллекции.', 'This item is already in the collection.'))),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text(
          'Не удалось добавить запись: $error',
          'Could not add item: $error',
        ))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: LunoraLocalization.text('В коллекцию', 'Add to collection'),
    onPressed: () => _addToCollection(context),
    icon: const Icon(Icons.library_add_outlined),
  );
}
