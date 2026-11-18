import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lunora/core/database/database_migrations.dart';
import 'package:lunora/features/habits/repositories/habit_repository.dart';

Future<Database> _openDatabase() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE notes (
          id TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT,
          source_module TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        )''');
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('HabitRepository', () {
    late Database db;
    late HabitRepository repository;

    setUp(() async {
      db = await _openDatabase();
      await DatabaseMigrations.migrate(db, 1, 27);
      repository = HabitRepository.forTesting(() async => db);
    });
    tearDown(() => db.close());

    test('creates habits and validates name and weekly target', () async {
      final habit = await repository.create(name: '  Read 10 pages  ', targetPerWeek: 5);
      expect(habit.name, 'Read 10 pages');
      expect(habit.targetPerWeek, 5);
      await expectLater(repository.create(name: '  '), throwsArgumentError);
      await expectLater(repository.create(name: 'Walk', targetPerWeek: 8), throwsArgumentError);
    });

    test('updates, archives and restores habits', () async {
      final habit = await repository.create(name: 'Walk');
      await repository.update(habit.copyWith(name: 'Walk outside', targetPerWeek: 3));
      expect((await repository.getAll()).single.name, 'Walk outside');
      await repository.archive(habit.id);
      expect(await repository.getAll(), isEmpty);
      expect((await repository.getAll(includeArchived: true)).single.isArchived, isTrue);
      await repository.archive(habit.id, archived: false);
      expect((await repository.getAll()).single.isArchived, isFalse);
    });

    test('toggles completion by day without duplicates', () async {
      final habit = await repository.create(name: 'Read');
      final day = DateTime(2026, 11, 18);
      expect(await repository.toggleCompletion(habit.id, day), isTrue);
      expect(await repository.toggleCompletion(habit.id, day), isFalse);
      expect(await repository.getCompletionDates(habit.id, day, day), contains('2026-11-18'));
      expect(await repository.getCompletionDates(habit.id, day, day), hasLength(0));
    });

    test('deleting a habit removes its completion history', () async {
      final habit = await repository.create(name: 'Stretch');
      final day = DateTime(2026, 11, 18);
      await repository.toggleCompletion(habit.id, day);
      await repository.delete(habit.id);
      expect(await db.query('habits'), isEmpty);
      expect(await db.query('habit_completions'), isEmpty);
    });
  });
}
