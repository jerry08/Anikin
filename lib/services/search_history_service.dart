import 'package:drift/drift.dart';

import '../data/app_database.dart';

class SearchHistoryService {
  SearchHistoryService(this._database);

  final AppDatabase _database;

  Future<List<String>> recent(String target, {int limit = 12}) async {
    final rows =
        await (_database.select(_database.searchHistoryEntries)
              ..where((entry) => entry.target.equals(target))
              ..orderBy([
                (entry) => OrderingTerm.desc(entry.usedAt),
                (entry) => OrderingTerm.desc(entry.id),
              ])
              ..limit(limit))
            .get();
    return rows.map((entry) => entry.query).toList(growable: false);
  }

  Future<void> record(String target, String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final existing =
        await (_database.select(_database.searchHistoryEntries)..where(
              (entry) =>
                  entry.target.equals(target) &
                  entry.query.lower().equals(trimmed.toLowerCase()),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await _database
          .into(_database.searchHistoryEntries)
          .insert(
            SearchHistoryEntriesCompanion.insert(
              target: target,
              query: trimmed,
              usedAt: DateTime.now(),
            ),
          );
      return;
    }

    await _database.transaction(() async {
      await (_database.delete(
        _database.searchHistoryEntries,
      )..where((entry) => entry.id.equals(existing.id))).go();
      await _database
          .into(_database.searchHistoryEntries)
          .insert(
            SearchHistoryEntriesCompanion.insert(
              target: target,
              query: trimmed,
              usedAt: DateTime.now(),
            ),
          );
    });
  }

  Future<void> remove(String target, String query) async {
    await (_database.delete(_database.searchHistoryEntries)..where(
          (entry) =>
              entry.target.equals(target) &
              entry.query.lower().equals(query.trim().toLowerCase()),
        ))
        .go();
  }

  Future<void> clear(String target) async {
    await (_database.delete(
      _database.searchHistoryEntries,
    )..where((entry) => entry.target.equals(target))).go();
  }
}
