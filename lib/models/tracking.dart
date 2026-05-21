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

enum TrackingSyncStrategy {
  primaryThenFallback('Primary, then fallback'),
  allLoggedIn('All logged-in providers');

  const TrackingSyncStrategy(this.label);

  final String label;
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
