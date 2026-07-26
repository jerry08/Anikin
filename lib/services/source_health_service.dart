import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../models/juro_models.dart';

class SourceHealthService {
  SourceHealthService(this._database);

  final AppDatabase _database;

  Future<void> recordSuccess(String sourceKey, Duration latency) {
    return _record(
      sourceKey,
      succeeded: true,
      latencyMs: latency.inMilliseconds,
    );
  }

  Future<void> recordFailure(String sourceKey, Object error, Duration latency) {
    return _record(
      sourceKey,
      succeeded: false,
      latencyMs: latency.inMilliseconds,
      error: error.toString(),
    );
  }

  Future<List<SourceProvider>> rank(
    List<SourceProvider> providers, {
    String? preferredKey,
  }) async {
    if (providers.length < 2) {
      return providers;
    }
    final rows = await _database.select(_database.sourceHealthEntries).get();
    final health = {for (final row in rows) row.sourceKey: row};
    final ranked = List<SourceProvider>.of(providers);
    ranked.sort((left, right) {
      final leftScore = _score(health[left.key], left.key == preferredKey);
      final rightScore = _score(health[right.key], right.key == preferredKey);
      final scoreOrder = rightScore.compareTo(leftScore);
      return scoreOrder != 0 ? scoreOrder : left.name.compareTo(right.name);
    });
    return ranked;
  }

  Future<void> _record(
    String sourceKey, {
    required bool succeeded,
    required int latencyMs,
    String? error,
  }) async {
    await _database
        .into(_database.sourceHealthEntries)
        .insertOnConflictUpdate(
          SourceHealthEntriesCompanion.insert(
            sourceKey: sourceKey,
            succeeded: succeeded,
            latencyMs: Value(latencyMs),
            lastError: Value(error),
            checkedAt: DateTime.now(),
          ),
        );
  }

  static double _score(SourceHealthEntry? health, bool preferred) {
    var score = preferred ? 30.0 : 0.0;
    if (health == null) {
      return score;
    }
    final age = DateTime.now().difference(health.checkedAt);
    if (age > const Duration(days: 7)) {
      return score;
    }
    score += health.succeeded ? 100 : -100;
    score -= (health.latencyMs ?? 0).clamp(0, 10000) / 200;
    return score;
  }
}
