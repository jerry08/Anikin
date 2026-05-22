import 'dart:convert';

import 'anilist_media.dart';

enum TrackingProvider {
  anilist('anilist', 'AniList'),
  myAnimeList('myanimelist', 'MyAnimeList'),
  kitsu('kitsu', 'Kitsu');

  const TrackingProvider(this.key, this.label);

  final String key;
  final String label;

  static TrackingProvider? fromKey(String? key) {
    for (final provider in values) {
      if (provider.key == key) {
        return provider;
      }
    }
    return null;
  }
}

enum TrackingMediaKind { anime, manga }

enum AniListMediaListStatus {
  current('CURRENT', 'Current'),
  planning('PLANNING', 'Planning'),
  completed('COMPLETED', 'Completed'),
  paused('PAUSED', 'Paused'),
  dropped('DROPPED', 'Dropped'),
  repeating('REPEATING', 'Repeating');

  const AniListMediaListStatus(this.graphqlName, this.label);

  final String graphqlName;
  final String label;

  static AniListMediaListStatus? fromGraphql(String? value) {
    for (final status in values) {
      if (status.graphqlName == value) {
        return status;
      }
    }
    return null;
  }
}

enum TrackingSyncStrategy {
  primaryThenFallback('Primary, then fallback'),
  allLoggedIn('All logged-in providers');

  const TrackingSyncStrategy(this.label);

  final String label;
}

class AniListFuzzyDate {
  const AniListFuzzyDate({this.year, this.month, this.day});

  final int? year;
  final int? month;
  final int? day;

  bool get isEmpty => year == null && month == null && day == null;

  DateTime? get dateTime {
    final yearValue = year;
    final monthValue = month;
    final dayValue = day;
    if (yearValue == null || monthValue == null || dayValue == null) {
      return null;
    }
    return DateTime(yearValue, monthValue, dayValue);
  }

  String get label {
    final yearValue = year;
    final monthValue = month;
    final dayValue = day;
    if (yearValue == null) {
      return '';
    }
    if (monthValue == null) {
      return yearValue.toString();
    }
    final monthText = monthValue.toString().padLeft(2, '0');
    if (dayValue == null) {
      return '$yearValue-$monthText';
    }
    final dayText = dayValue.toString().padLeft(2, '0');
    return '$yearValue-$monthText-$dayText';
  }

  Map<String, dynamic> toJson() => {'year': year, 'month': month, 'day': day};

  static AniListFuzzyDate? fromDateTime(DateTime? date) {
    if (date == null) {
      return null;
    }
    return AniListFuzzyDate(year: date.year, month: date.month, day: date.day);
  }

  static AniListFuzzyDate? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final date = AniListFuzzyDate(
      year: (json['year'] as num?)?.toInt(),
      month: (json['month'] as num?)?.toInt(),
      day: (json['day'] as num?)?.toInt(),
    );
    return date.isEmpty ? null : date;
  }
}

class TrackingAccount {
  const TrackingAccount({
    required this.provider,
    required this.accessToken,
    this.refreshToken,
    this.username,
    this.userId,
    this.expiresAtMs,
    this.authExpired = false,
  });

  final TrackingProvider provider;
  final String accessToken;
  final String? refreshToken;
  final String? username;
  final String? userId;
  final int? expiresAtMs;
  final bool authExpired;

  bool get isExpired {
    final expiresAt = expiresAtMs;
    if (expiresAt == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch >= expiresAt - 60000;
  }

  TrackingAccount copyWith({
    String? accessToken,
    String? refreshToken,
    String? username,
    String? userId,
    int? expiresAtMs,
    bool? authExpired,
  }) {
    return TrackingAccount(
      provider: provider,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      username: username ?? this.username,
      userId: userId ?? this.userId,
      expiresAtMs: expiresAtMs ?? this.expiresAtMs,
      authExpired: authExpired ?? this.authExpired,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider.key,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'username': username,
    'userId': userId,
    'expiresAtMs': expiresAtMs,
    'authExpired': authExpired,
  };

  factory TrackingAccount.fromJson(Map<String, dynamic> json) {
    return TrackingAccount(
      provider: TrackingProvider.fromKey(json['provider']?.toString())!,
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString(),
      username: json['username']?.toString(),
      userId: json['userId']?.toString(),
      expiresAtMs: (json['expiresAtMs'] as num?)?.toInt(),
      authExpired: json['authExpired'] == true,
    );
  }
}

class TrackingProgressRequest {
  const TrackingProgressRequest({
    required this.media,
    required this.kind,
    required this.progress,
    required this.total,
  });

  final AniListMedia media;
  final TrackingMediaKind kind;
  final int progress;
  final int? total;

  String get title => media.displayTitle;

  Map<String, dynamic> toJson() => {
    'mediaId': media.id,
    'idMal': media.idMal,
    'title': title,
    'kind': kind.name,
    'progress': progress,
    'total': total,
  };

  factory TrackingProgressRequest.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind']?.toString();
    final kind = TrackingMediaKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => TrackingMediaKind.anime,
    );
    return TrackingProgressRequest(
      media: AniListMedia(
        id: (json['mediaId'] as num?)?.toInt() ?? 0,
        idMal: (json['idMal'] as num?)?.toInt(),
        title: MediaTitle(userPreferred: json['title']?.toString()),
        cover: const MediaCover(),
      ),
      kind: kind,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt(),
    );
  }
}

class AniListMediaListEntry {
  const AniListMediaListEntry({
    required this.id,
    required this.media,
    required this.kind,
    required this.status,
    this.progress,
    this.progressVolumes,
    this.score,
    this.repeat,
    this.private = false,
    this.notes,
    this.startedAt,
    this.completedAt,
    this.updatedAtMs,
  });

  final int id;
  final AniListMedia media;
  final TrackingMediaKind kind;
  final AniListMediaListStatus status;
  final int? progress;
  final int? progressVolumes;
  final double? score;
  final int? repeat;
  final bool private;
  final String? notes;
  final AniListFuzzyDate? startedAt;
  final AniListFuzzyDate? completedAt;
  final int? updatedAtMs;

  String get progressLabel {
    final progressValue = progress;
    if (progressValue == null || progressValue <= 0) {
      return '';
    }
    if (kind == TrackingMediaKind.anime) {
      return '$progressValue eps';
    }
    final volumeValue = progressVolumes;
    if (volumeValue != null && volumeValue > 0) {
      return '$progressValue ch / $volumeValue vol';
    }
    return '$progressValue ch';
  }

  String get scoreLabel {
    final scoreValue = score;
    if (scoreValue == null || scoreValue <= 0) {
      return '';
    }
    final rounded = scoreValue.roundToDouble();
    final display = scoreValue == rounded
        ? rounded.toInt().toString()
        : scoreValue.toStringAsFixed(1);
    return 'Score $display';
  }

  static AniListMediaListEntry? fromJson(
    Map<String, dynamic> json,
    TrackingMediaKind kind, {
    AniListMedia? fallbackMedia,
  }) {
    final status = AniListMediaListStatus.fromGraphql(
      json['status']?.toString(),
    );
    final mediaJson = json['media'];
    final media = mediaJson is Map
        ? AniListMedia.fromJson(mediaJson.cast<String, dynamic>())
        : fallbackMedia;
    if (status == null || media == null) {
      return null;
    }
    final updatedAtSeconds = (json['updatedAt'] as num?)?.toInt();
    return AniListMediaListEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      media: media,
      kind: kind,
      status: status,
      progress: (json['progress'] as num?)?.toInt(),
      progressVolumes: (json['progressVolumes'] as num?)?.toInt(),
      score: (json['score'] as num?)?.toDouble(),
      repeat: (json['repeat'] as num?)?.toInt(),
      private: json['private'] == true,
      notes: json['notes']?.toString(),
      startedAt: AniListFuzzyDate.fromJson(json['startedAt']),
      completedAt: AniListFuzzyDate.fromJson(json['completedAt']),
      updatedAtMs: updatedAtSeconds == null ? null : updatedAtSeconds * 1000,
    );
  }
}

class AniListMediaListSaveRequest {
  const AniListMediaListSaveRequest({
    required this.media,
    required this.kind,
    required this.status,
    this.progress,
    this.progressVolumes,
    this.score,
    this.repeat,
    this.private = false,
    this.notes,
    this.startedAt,
    this.completedAt,
  });

  final AniListMedia media;
  final TrackingMediaKind kind;
  final AniListMediaListStatus status;
  final int? progress;
  final int? progressVolumes;
  final double? score;
  final int? repeat;
  final bool private;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? completedAt;
}

class AniListMediaListCollection {
  const AniListMediaListCollection({
    this.anime = const <AniListMediaListEntry>[],
    this.manga = const <AniListMediaListEntry>[],
  });

  final List<AniListMediaListEntry> anime;
  final List<AniListMediaListEntry> manga;

  bool get isEmpty => anime.isEmpty && manga.isEmpty;
}

class PendingTrackingUpdate {
  const PendingTrackingUpdate({
    required this.request,
    required this.createdAtMs,
    this.attempts = 0,
  });

  final TrackingProgressRequest request;
  final int createdAtMs;
  final int attempts;

  PendingTrackingUpdate copyWith({int? attempts}) {
    return PendingTrackingUpdate(
      request: request,
      createdAtMs: createdAtMs,
      attempts: attempts ?? this.attempts,
    );
  }

  Map<String, dynamic> toJson() => {
    'request': request.toJson(),
    'createdAtMs': createdAtMs,
    'attempts': attempts,
  };

  factory PendingTrackingUpdate.fromJson(Map<String, dynamic> json) {
    final requestJson = json['request'];
    return PendingTrackingUpdate(
      request: TrackingProgressRequest.fromJson(
        requestJson is Map<String, dynamic>
            ? requestJson
            : (requestJson as Map).cast<String, dynamic>(),
      ),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

List<PendingTrackingUpdate> decodePendingTrackingUpdates(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    return const [];
  }
  return decoded
      .whereType<Map>()
      .map((item) => PendingTrackingUpdate.fromJson(item.cast()))
      .toList();
}
