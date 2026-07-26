import 'package:drift/drift.dart';

import '../data/app_database.dart';

class CatalogCacheService {
  CatalogCacheService(this._database);

  final AppDatabase _database;

  Future<String?> read(String key, {bool allowExpired = false}) async {
    final row = await (_database.select(
      _database.cachedResponses,
    )..where((entry) => entry.key.equals(key))).getSingleOrNull();
    if (row == null ||
        (!allowExpired && row.expiresAt.isBefore(DateTime.now()))) {
      return null;
    }
    return row.body;
  }

  Future<void> write(
    String key,
    String body, {
    Duration ttl = const Duration(minutes: 15),
  }) async {
    final now = DateTime.now();
    await _database
        .into(_database.cachedResponses)
        .insertOnConflictUpdate(
          CachedResponsesCompanion.insert(
            key: key,
            body: body,
            storedAt: now,
            expiresAt: now.add(ttl),
            etag: const Value.absent(),
          ),
        );
  }

  Future<void> clearExpired({
    Duration retainFor = const Duration(days: 30),
  }) async {
    final cutoff = DateTime.now().subtract(retainFor);
    await (_database.delete(
      _database.cachedResponses,
    )..where((entry) => entry.expiresAt.isSmallerThanValue(cutoff))).go();
  }
}
