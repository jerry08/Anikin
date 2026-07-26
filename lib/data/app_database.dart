import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class SchemaMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class SearchHistoryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get target => text()();
  TextColumn get query => text()();
  DateTimeColumn get usedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {target, query},
  ];
}

class CachedResponses extends Table {
  TextColumn get key => text()();
  TextColumn get body => text()();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get storedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class SourceHealthEntries extends Table {
  TextColumn get sourceKey => text()();
  BoolColumn get succeeded => boolean()();
  IntColumn get latencyMs => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get checkedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {sourceKey};
}

class NotificationSubscriptions extends Table {
  TextColumn get id => text()();
  IntColumn get mediaId => integer()();
  TextColumn get mediaType => text()();
  TextColumn get origin => text()();
  TextColumn get mediaTitle => text().withDefault(const Constant(''))();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get sourceKey => text().nullable()();
  TextColumn get providerItemId => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyPremiere =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get notifyEpisode => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyChapter => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyAiring => boolean().withDefault(const Constant(true))();
  RealColumn get lastEpisode => real().nullable()();
  TextColumn get lastChapter => text().nullable()();
  DateTimeColumn get nextAiringAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get category => text()();
  IntColumn get mediaId => integer().nullable()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get deepLink => text().nullable()();
  TextColumn get privacyLevel => text()();
  DateTimeColumn get eventAt => dateTime()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class WatchOrderCacheEntries extends Table {
  IntColumn get mediaId => integer()();
  TextColumn get source => text()();
  TextColumn get payload => text()();
  DateTimeColumn get storedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {mediaId, source};
}

class NovelLibraryEntries extends Table {
  TextColumn get id => text()();
  IntColumn get aniListId => integer().nullable()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get providerKey => text().nullable()();
  TextColumn get providerItemId => text().nullable()();
  TextColumn get localPath => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NovelChapterEntries extends Table {
  TextColumn get id => text()();
  TextColumn get novelId => text().references(NovelLibraryEntries, #id)();
  TextColumn get title => text()();
  TextColumn get chapterNumber => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get localPath => text().nullable()();
  RealColumn get progress => real().withDefault(const Constant(0))();
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    SchemaMetadata,
    SearchHistoryEntries,
    CachedResponses,
    SourceHealthEntries,
    NotificationSubscriptions,
    AppNotifications,
    WatchOrderCacheEntries,
    NovelLibraryEntries,
    NovelChapterEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults()
    : super(
        driftDatabase(
          name: 'anikin',
          native: const DriftNativeOptions(shareAcrossIsolates: true),
        ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(
          notificationSubscriptions,
          notificationSubscriptions.mediaTitle,
        );
        await migrator.addColumn(
          notificationSubscriptions,
          notificationSubscriptions.coverUrl,
        );
        await migrator.addColumn(
          notificationSubscriptions,
          notificationSubscriptions.providerItemId,
        );
        await migrator.addColumn(
          notificationSubscriptions,
          notificationSubscriptions.nextAiringAt,
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> initialize() async {
    await customSelect('SELECT 1').getSingle();
  }

  Future<void> setMetadata(String key, String value) async {
    await into(schemaMetadata).insertOnConflictUpdate(
      SchemaMetadataCompanion.insert(key: key, value: value),
    );
  }

  Future<String?> metadata(String key) async {
    final row = await (select(
      schemaMetadata,
    )..where((entry) => entry.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
}
