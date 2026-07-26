import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import 'anilist_service.dart';
import 'juro_service.dart';
import 'local_notification_service.dart';
import 'preferences_service.dart';

class NotificationRefreshService {
  NotificationRefreshService({
    required AppDatabase database,
    required AniListService aniListService,
    required JuroService juroService,
    required LocalNotificationService localNotifications,
    required PreferencesService preferences,
  }) : _database = database,
       _aniListService = aniListService,
       _juroService = juroService,
       _localNotifications = localNotifications,
       _preferences = preferences;

  final AppDatabase _database;
  final AniListService _aniListService;
  final JuroService _juroService;
  final LocalNotificationService _localNotifications;
  final PreferencesService _preferences;

  Future<void> refresh() async {
    if (!_preferences.notificationsEnabled) {
      return;
    }
    final subscriptions = await (_database.select(
      _database.notificationSubscriptions,
    )..where((entry) => entry.enabled.equals(true))).get();
    final groups = <String, List<NotificationSubscription>>{};
    for (final subscription in subscriptions) {
      groups
          .putIfAbsent(
            '${subscription.mediaType}:${subscription.mediaId}',
            () => [],
          )
          .add(subscription);
    }
    for (final group in groups.values) {
      try {
        switch (group.first.mediaType) {
          case 'anime':
            await _refreshAnime(group);
          case 'manga':
            await _refreshManga(group);
        }
      } catch (_) {
        // A single unavailable provider must not prevent other subscriptions.
      }
    }
  }

  Future<void> _refreshAnime(
    List<NotificationSubscription> subscriptions,
  ) async {
    final primary = _primary(subscriptions);
    double? newestEpisode;
    DateTime? nextAiringAt;
    int? nextAiringEpisode;

    if (primary.sourceKey != null && primary.providerItemId != null) {
      final episodes = await _juroService.getEpisodes(
        primary.providerItemId!,
        providerKey: primary.sourceKey!,
      );
      for (final episode in episodes) {
        newestEpisode = math.max(newestEpisode ?? 0, episode.number);
      }
    }

    try {
      final details = await _aniListService.getMediaDetails(
        id: primary.mediaId,
        mediaType: AniListMediaType.anime,
      );
      nextAiringAt = details.nextAiringAt;
      nextAiringEpisode = details.nextAiringEpisode;
      if (nextAiringEpisode != null && nextAiringEpisode > 1) {
        newestEpisode = math.max(
          newestEpisode ?? 0,
          (nextAiringEpisode - 1).toDouble(),
        );
      }
    } catch (_) {
      // Source episode checks still work when AniList is unavailable.
    }

    final previous = subscriptions
        .map((entry) => entry.lastEpisode)
        .whereType<double>()
        .fold<double?>(null, (value, item) => math.max(value ?? 0, item));
    if (newestEpisode != null && previous != null && newestEpisode > previous) {
      if (subscriptions.any((entry) => entry.notifyEpisode)) {
        final episodeLabel = _numberLabel(newestEpisode);
        await _emit(
          eventId:
              '${primary.mediaType}:${primary.mediaId}:episode:$episodeLabel',
          category: 'episode',
          mediaId: primary.mediaId,
          mediaTitle: primary.mediaTitle,
          body: 'Episode $episodeLabel is now available',
          deepLink: 'anikin://media/anime/${primary.mediaId}',
        );
      }
    }

    if (nextAiringAt != null && nextAiringEpisode != null) {
      final isPremiere = nextAiringEpisode == 1;
      final shouldSchedule = subscriptions.any(
        (entry) => isPremiere ? entry.notifyPremiere : entry.notifyAiring,
      );
      if (shouldSchedule) {
        final body = isPremiere
            ? 'The premiere is airing now'
            : 'Episode $nextAiringEpisode is airing now';
        final display = _displayText(primary.mediaTitle, body);
        await _localNotifications.schedule(
          id: _notificationId(
            '${primary.mediaType}:${primary.mediaId}:airing:$nextAiringEpisode',
          ),
          title: display.title,
          body: display.body,
          when: nextAiringAt,
          payload: 'anikin://media/anime/${primary.mediaId}',
        );
      }
    }

    await _updateSubscriptions(
      subscriptions,
      lastEpisode: newestEpisode,
      nextAiringAt: nextAiringAt,
    );
  }

  Future<void> _refreshManga(
    List<NotificationSubscription> subscriptions,
  ) async {
    final primary = _primary(subscriptions);
    final sourceKey = primary.sourceKey;
    final providerItemId = primary.providerItemId;
    double? newestChapter;
    if (sourceKey != null && providerItemId != null) {
      final info = await _juroService.getMangaInfo(
        providerItemId,
        providerKey: sourceKey,
      );
      for (final chapter in info.chapters) {
        newestChapter = math.max(newestChapter ?? 0, chapter.number);
      }
    } else {
      try {
        final details = await _aniListService.getMediaDetails(
          id: primary.mediaId,
          mediaType: AniListMediaType.manga,
        );
        newestChapter = details.media.chapters?.toDouble();
      } catch (_) {
        return;
      }
    }
    if (newestChapter == null) {
      return;
    }
    final previous = subscriptions
        .map((entry) => double.tryParse(entry.lastChapter ?? ''))
        .whereType<double>()
        .fold<double?>(null, (value, item) => math.max(value ?? 0, item));
    if (previous != null &&
        newestChapter > previous &&
        subscriptions.any((entry) => entry.notifyChapter)) {
      final chapterLabel = _numberLabel(newestChapter);
      await _emit(
        eventId:
            '${primary.mediaType}:${primary.mediaId}:chapter:$chapterLabel',
        category: 'chapter',
        mediaId: primary.mediaId,
        mediaTitle: primary.mediaTitle,
        body: 'Chapter $chapterLabel is now available',
        deepLink: 'anikin://media/manga/${primary.mediaId}',
      );
    }
    await _updateSubscriptions(
      subscriptions,
      lastChapter: newestChapter.toString(),
    );
  }

  Future<void> _emit({
    required String eventId,
    required String category,
    required int mediaId,
    required String mediaTitle,
    required String body,
    required String deepLink,
  }) async {
    final existing = await (_database.select(
      _database.appNotifications,
    )..where((entry) => entry.id.equals(eventId))).getSingleOrNull();
    if (existing != null) {
      return;
    }
    final display = _displayText(mediaTitle, body);
    await _database
        .into(_database.appNotifications)
        .insert(
          AppNotificationsCompanion.insert(
            id: eventId,
            category: category,
            mediaId: Value(mediaId),
            title: display.title,
            body: display.body,
            deepLink: Value(deepLink),
            privacyLevel: _preferences.notificationPrivacy.name,
            eventAt: DateTime.now(),
          ),
        );
    await _localNotifications.show(
      id: _notificationId(eventId),
      title: display.title,
      body: display.body,
      payload: deepLink,
    );
  }

  Future<void> _updateSubscriptions(
    List<NotificationSubscription> subscriptions, {
    double? lastEpisode,
    String? lastChapter,
    DateTime? nextAiringAt,
  }) async {
    for (final subscription in subscriptions) {
      await (_database.update(
        _database.notificationSubscriptions,
      )..where((entry) => entry.id.equals(subscription.id))).write(
        NotificationSubscriptionsCompanion(
          lastEpisode: lastEpisode == null
              ? const Value.absent()
              : Value(lastEpisode),
          lastChapter: lastChapter == null
              ? const Value.absent()
              : Value(lastChapter),
          nextAiringAt: Value(nextAiringAt),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  ({String title, String body}) _displayText(String mediaTitle, String body) {
    return switch (_preferences.notificationPrivacy) {
      NotificationPrivacy.full => (title: mediaTitle, body: body),
      NotificationPrivacy.titleOnly => (
        title: mediaTitle,
        body: 'New release available',
      ),
      NotificationPrivacy.generic => (
        title: 'Anikin update',
        body: 'New release available',
      ),
    };
  }

  static NotificationSubscription _primary(
    List<NotificationSubscription> subscriptions,
  ) {
    for (final subscription in subscriptions) {
      if (subscription.sourceKey != null &&
          subscription.providerItemId != null) {
        return subscription;
      }
    }
    return subscriptions.first;
  }

  static String _numberLabel(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static int _notificationId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
