import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/anilist_media.dart';
import '../models/tracking.dart';
import 'preferences_service.dart';
import 'tracking_service.dart';

enum NotificationSubscriptionOrigin {
  manual('manual'),
  aniListCurrent('anilist_current'),
  aniListPlanning('anilist_planning'),
  aniListFavorite('anilist_favorite');

  const NotificationSubscriptionOrigin(this.key);

  final String key;
}

class NotificationSubscriptionService extends ChangeNotifier {
  NotificationSubscriptionService(this._database);

  final AppDatabase _database;

  Future<List<NotificationSubscription>> all({bool enabledOnly = false}) {
    final query = _database.select(_database.notificationSubscriptions)
      ..orderBy([
        (entry) => OrderingTerm.asc(entry.mediaTitle),
        (entry) => OrderingTerm.desc(entry.updatedAt),
      ]);
    if (enabledOnly) {
      query.where((entry) => entry.enabled.equals(true));
    }
    return query.get();
  }

  Future<bool> isSubscribed(int mediaId, String mediaType) async {
    final row =
        await (_database.select(_database.notificationSubscriptions)
              ..where(
                (entry) =>
                    entry.mediaId.equals(mediaId) &
                    entry.mediaType.equals(mediaType) &
                    entry.enabled.equals(true),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<bool> isManuallySubscribed(int mediaId, String mediaType) async {
    final id = _id(
      NotificationSubscriptionOrigin.manual.key,
      mediaType,
      mediaId,
    );
    final row =
        await (_database.select(_database.notificationSubscriptions)..where(
              (entry) => entry.id.equals(id) & entry.enabled.equals(true),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> subscribeManual({
    required AniListMedia media,
    required String mediaType,
    String? sourceKey,
    String? providerItemId,
  }) async {
    final origin = NotificationSubscriptionOrigin.manual.key;
    await _database
        .into(_database.notificationSubscriptions)
        .insertOnConflictUpdate(
          NotificationSubscriptionsCompanion.insert(
            id: _id(origin, mediaType, media.id),
            mediaId: media.id,
            mediaType: mediaType,
            origin: origin,
            mediaTitle: Value(media.displayTitle),
            coverUrl: Value(media.cover.best),
            sourceKey: Value(sourceKey),
            providerItemId: Value(providerItemId),
            enabled: const Value(true),
            updatedAt: DateTime.now(),
          ),
        );
    notifyListeners();
  }

  Future<void> unsubscribeManual(int mediaId, String mediaType) async {
    await (_database.delete(_database.notificationSubscriptions)..where(
          (entry) => entry.id.equals(
            _id(NotificationSubscriptionOrigin.manual.key, mediaType, mediaId),
          ),
        ))
        .go();
    notifyListeners();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await (_database.update(
      _database.notificationSubscriptions,
    )..where((entry) => entry.id.equals(id))).write(
      NotificationSubscriptionsCompanion(
        enabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
    notifyListeners();
  }

  Future<void> setMediaEnabled(
    int mediaId,
    String mediaType,
    bool enabled,
  ) async {
    await (_database.update(_database.notificationSubscriptions)..where(
          (entry) =>
              entry.mediaId.equals(mediaId) & entry.mediaType.equals(mediaType),
        ))
        .write(
          NotificationSubscriptionsCompanion(
            enabled: Value(enabled),
            updatedAt: Value(DateTime.now()),
          ),
        );
    notifyListeners();
  }

  /// Removes subscriptions derived from one automatic AniList source.
  /// Manual follows and other AniList sources are left untouched.
  Future<void> clearOrigin(NotificationSubscriptionOrigin origin) async {
    await _clearOrigin(origin);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await (_database.delete(
      _database.notificationSubscriptions,
    )..where((entry) => entry.id.equals(id))).go();
    notifyListeners();
  }

  Future<void> syncAniListOrigins(
    TrackingService tracking,
    PreferencesService preferences,
  ) async {
    if (!tracking.isLoggedIn(TrackingProvider.anilist)) {
      return;
    }

    if (preferences.notifyAniListCurrent || preferences.notifyAniListPlanning) {
      final collection = await tracking.aniListMediaListCollection();
      final entries = [...collection.anime, ...collection.manga];
      if (preferences.notifyAniListCurrent) {
        await _replaceOrigin(
          NotificationSubscriptionOrigin.aniListCurrent,
          entries
              .where((entry) => entry.status == AniListMediaListStatus.current)
              .map(_trackedItem)
              .toList(),
        );
      } else {
        await _clearOrigin(NotificationSubscriptionOrigin.aniListCurrent);
      }
      if (preferences.notifyAniListPlanning) {
        await _replaceOrigin(
          NotificationSubscriptionOrigin.aniListPlanning,
          entries
              .where((entry) => entry.status == AniListMediaListStatus.planning)
              .map(_trackedItem)
              .toList(),
        );
      } else {
        await _clearOrigin(NotificationSubscriptionOrigin.aniListPlanning);
      }
    } else {
      await _clearOrigin(NotificationSubscriptionOrigin.aniListCurrent);
      await _clearOrigin(NotificationSubscriptionOrigin.aniListPlanning);
    }

    if (preferences.notifyAniListFavorites) {
      final favorites = await Future.wait([
        tracking.favoriteMedia(TrackingMediaKind.anime),
        tracking.favoriteMedia(TrackingMediaKind.manga),
      ]);
      await _replaceOrigin(NotificationSubscriptionOrigin.aniListFavorite, [
        for (final media in favorites[0])
          _SubscriptionSeed(media: media, mediaType: 'anime'),
        for (final media in favorites[1])
          _SubscriptionSeed(media: media, mediaType: 'manga'),
      ]);
    } else {
      await _clearOrigin(NotificationSubscriptionOrigin.aniListFavorite);
    }
    notifyListeners();
  }

  Future<void> _replaceOrigin(
    NotificationSubscriptionOrigin origin,
    List<_SubscriptionSeed> items,
  ) async {
    final ids = <String>[];
    await _database.transaction(() async {
      for (final item in items) {
        final id = _id(origin.key, item.mediaType, item.media.id);
        ids.add(id);
        await _database
            .into(_database.notificationSubscriptions)
            .insertOnConflictUpdate(
              NotificationSubscriptionsCompanion.insert(
                id: id,
                mediaId: item.media.id,
                mediaType: item.mediaType,
                origin: origin.key,
                mediaTitle: Value(item.media.displayTitle),
                coverUrl: Value(item.media.cover.best),
                updatedAt: DateTime.now(),
              ),
            );
      }
      final delete = _database.delete(_database.notificationSubscriptions)
        ..where((entry) => entry.origin.equals(origin.key));
      if (ids.isNotEmpty) {
        delete.where((entry) => entry.id.isNotIn(ids));
      }
      await delete.go();
    });
  }

  Future<void> _clearOrigin(NotificationSubscriptionOrigin origin) async {
    await (_database.delete(
      _database.notificationSubscriptions,
    )..where((entry) => entry.origin.equals(origin.key))).go();
  }

  static _SubscriptionSeed _trackedItem(AniListMediaListEntry entry) {
    return _SubscriptionSeed(
      media: entry.media,
      mediaType: entry.kind == TrackingMediaKind.anime ? 'anime' : 'manga',
    );
  }

  static String _id(String origin, String mediaType, int mediaId) =>
      '$origin:$mediaType:$mediaId';
}

class _SubscriptionSeed {
  const _SubscriptionSeed({required this.media, required this.mediaType});

  final AniListMedia media;
  final String mediaType;
}
