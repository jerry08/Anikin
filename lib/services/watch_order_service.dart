import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import '../models/anilist_media.dart';
import '../models/anilist_media_details.dart';
import 'anilist_service.dart';

class WatchOrderService {
  WatchOrderService({
    required AppDatabase database,
    required AniListService aniList,
  }) : _database = database,
       _aniList = aniList;

  static const _cacheSource = 'anilist-relations-v1';
  static const _cacheLifetime = Duration(days: 7);

  final AppDatabase _database;
  final AniListService _aniList;

  Future<List<AniListMedia>> orderFor(
    AniListMedia media, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _readCache(media.id);
      if (cached != null) return cached;
    }

    final visited = <int>{media.id};
    final before = <AniListMedia>[];
    final after = <AniListMedia>[];
    AniListMediaDetails cursor;
    try {
      cursor = await _aniList.getMediaDetails(
        id: media.id,
        mediaType: AniListMediaType.anime,
      );
    } catch (_) {
      return [media];
    }
    final resolvedRoot = cursor.media;

    for (var depth = 0; depth < 12; depth++) {
      final relation = _firstUnvisited(cursor.relations, 'prequel', visited);
      if (relation == null) break;
      visited.add(relation.media.id);
      try {
        cursor = await _aniList.getMediaDetails(
          id: relation.media.id,
          mediaType: AniListMediaType.anime,
        );
        before.insert(0, cursor.media);
      } catch (_) {
        before.insert(0, relation.media);
        break;
      }
    }

    try {
      cursor = await _aniList.getMediaDetails(
        id: resolvedRoot.id,
        mediaType: AniListMediaType.anime,
      );
      for (var depth = 0; depth < 12; depth++) {
        final relation = _firstUnvisited(cursor.relations, 'sequel', visited);
        if (relation == null) break;
        visited.add(relation.media.id);
        try {
          cursor = await _aniList.getMediaDetails(
            id: relation.media.id,
            mediaType: AniListMediaType.anime,
          );
          after.add(cursor.media);
        } catch (_) {
          after.add(relation.media);
          break;
        }
      }
    } catch (_) {
      // The resolved root is still useful when a refresh fails midway.
    }

    final result = [...before, resolvedRoot, ...after];
    await _writeCache(media.id, result);
    return result;
  }

  static AniListMediaRelation? _firstUnvisited(
    List<AniListMediaRelation> relations,
    String type,
    Set<int> visited,
  ) {
    for (final relation in relations) {
      if (relation.type.toLowerCase() == type &&
          !visited.contains(relation.media.id) &&
          _isAnime(relation.media)) {
        return relation;
      }
    }
    return null;
  }

  Future<List<AniListMedia>?> _readCache(int mediaId) async {
    final row =
        await (_database.select(_database.watchOrderCacheEntries)..where(
              (entry) =>
                  entry.mediaId.equals(mediaId) &
                  entry.source.equals(_cacheSource) &
                  entry.expiresAt.isBiggerThanValue(DateTime.now()),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      final payload = jsonDecode(row.payload);
      if (payload is! List) return null;
      return payload
          .whereType<Map>()
          .map((item) => AniListMedia.fromJson(item.cast<String, dynamic>()))
          .where((item) => item.id > 0)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(int mediaId, List<AniListMedia> items) {
    final now = DateTime.now();
    return _database
        .into(_database.watchOrderCacheEntries)
        .insertOnConflictUpdate(
          WatchOrderCacheEntriesCompanion.insert(
            mediaId: mediaId,
            source: _cacheSource,
            payload: jsonEncode(items.map(_mediaJson).toList()),
            storedAt: now,
            expiresAt: now.add(_cacheLifetime),
          ),
        );
  }

  static Map<String, Object?> _mediaJson(AniListMedia media) => {
    'id': media.id,
    if (media.idMal != null) 'idMal': media.idMal,
    'title': {
      if (media.title.romaji != null) 'romaji': media.title.romaji,
      if (media.title.english != null) 'english': media.title.english,
      if (media.title.native != null) 'native': media.title.native,
      if (media.title.userPreferred != null)
        'userPreferred': media.title.userPreferred,
    },
    'coverImage': {
      if (media.cover.extraLarge != null) 'extraLarge': media.cover.extraLarge,
      if (media.cover.large != null) 'large': media.cover.large,
      if (media.cover.color != null) 'color': media.cover.color,
    },
    if (media.bannerImage != null) 'bannerImage': media.bannerImage,
    if (media.format != null) 'format': media.format,
    if (media.status != null) 'status': media.status,
    if (media.seasonYear != null) 'seasonYear': media.seasonYear,
    if (media.episodes != null) 'episodes': media.episodes,
    'type': media.mediaType ?? 'ANIME',
    'catalogProviderKey': media.catalogProviderKey,
  };

  static bool _isAnime(AniListMedia media) =>
      media.mediaType == null || media.mediaType!.toUpperCase() == 'ANIME';
}
