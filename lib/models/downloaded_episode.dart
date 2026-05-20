import 'anilist_media.dart';
import 'juro_models.dart';

class DownloadedEpisode {
  const DownloadedEpisode({
    required this.id,
    required this.mediaId,
    required this.mediaTitle,
    required this.providerAnimeId,
    required this.providerAnimeTitle,
    required this.episodeId,
    required this.episodeNumber,
    required this.sourceTitle,
    required this.serverName,
    required this.localPath,
    required this.fileName,
    required this.bytes,
    required this.downloadedAt,
    this.episodeName,
    this.coverUrl,
  });

  final String id;
  final int mediaId;
  final String mediaTitle;
  final String providerAnimeId;
  final String providerAnimeTitle;
  final String episodeId;
  final String? episodeName;
  final double episodeNumber;
  final String? coverUrl;
  final String sourceTitle;
  final String serverName;
  final String localPath;
  final String fileName;
  final int bytes;
  final DateTime downloadedAt;

  String get displayTitle => '$mediaTitle - ${episode.displayName}';

  AniListMedia get media => AniListMedia(
    id: mediaId,
    title: MediaTitle(english: mediaTitle),
    cover: MediaCover(extraLarge: coverUrl, large: coverUrl),
  );

  JuroAnimeInfo get providerAnime => JuroAnimeInfo(
    id: providerAnimeId,
    title: providerAnimeTitle,
    image: coverUrl,
  );

  AnimeEpisode get episode => AnimeEpisode(
    id: episodeId,
    name: episodeName,
    number: episodeNumber,
    image: coverUrl,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'mediaId': mediaId,
    'mediaTitle': mediaTitle,
    'providerAnimeId': providerAnimeId,
    'providerAnimeTitle': providerAnimeTitle,
    'episodeId': episodeId,
    'episodeName': episodeName,
    'episodeNumber': episodeNumber,
    'coverUrl': coverUrl,
    'sourceTitle': sourceTitle,
    'serverName': serverName,
    'localPath': localPath,
    'fileName': fileName,
    'bytes': bytes,
    'downloadedAt': downloadedAt.toIso8601String(),
  };

  factory DownloadedEpisode.fromJson(Map<String, dynamic> json) {
    return DownloadedEpisode(
      id: json['id']?.toString() ?? '',
      mediaId: (json['mediaId'] as num?)?.toInt() ?? 0,
      mediaTitle: json['mediaTitle']?.toString() ?? 'Unknown anime',
      providerAnimeId: json['providerAnimeId']?.toString() ?? '',
      providerAnimeTitle:
          json['providerAnimeTitle']?.toString() ?? 'Unknown anime',
      episodeId: json['episodeId']?.toString() ?? '',
      episodeName: json['episodeName']?.toString(),
      episodeNumber: (json['episodeNumber'] as num?)?.toDouble() ?? 0,
      coverUrl: json['coverUrl']?.toString(),
      sourceTitle: json['sourceTitle']?.toString() ?? 'Offline',
      serverName: json['serverName']?.toString() ?? 'Offline',
      localPath: json['localPath']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      downloadedAt:
          DateTime.tryParse(json['downloadedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class EpisodeDownloadRequest {
  const EpisodeDownloadRequest({
    required this.media,
    required this.providerAnime,
    required this.episode,
    required this.source,
    String? sourceTaskId,
  }) : _sourceTaskId = sourceTaskId;

  final AniListMedia media;
  final JuroAnimeInfo providerAnime;
  final AnimeEpisode episode;
  final VideoSource source;
  final String? _sourceTaskId;

  String get id => '${media.id}-${episode.number}';
  String get taskId =>
      '$id|${source.serverName}|${source.displayTitle}|${source.videoUrl}';
  String get sourceTaskId => _sourceTaskId ?? taskId;
  String get displayTitle => '${media.displayTitle} - ${episode.displayName}';

  EpisodeDownloadRequest copyWith({VideoSource? source, String? sourceTaskId}) {
    return EpisodeDownloadRequest(
      media: media,
      providerAnime: providerAnime,
      episode: episode,
      source: source ?? this.source,
      sourceTaskId: sourceTaskId ?? _sourceTaskId,
    );
  }
}

enum DownloadTaskStatus {
  queued,
  downloading,
  pausing,
  paused,
  canceling,
  completed,
  failed,
}

class EpisodeDownloadProgress {
  const EpisodeDownloadProgress({
    required this.request,
    required this.status,
    this.bytesReceived = 0,
    this.bytesTotal,
    this.itemsCompleted = 0,
    this.itemsTotal,
    this.error,
  });

  final EpisodeDownloadRequest request;
  final DownloadTaskStatus status;
  final int bytesReceived;
  final int? bytesTotal;
  final int itemsCompleted;
  final int? itemsTotal;
  final String? error;

  String get id => request.taskId;
  String get episodeId => request.id;
  String get sourceTaskId => request.sourceTaskId;

  double? get progress {
    final totalBytes = bytesTotal;
    if (totalBytes != null && totalBytes > 0) {
      return (bytesReceived / totalBytes).clamp(0, 1).toDouble();
    }
    final totalItems = itemsTotal;
    if (totalItems != null && totalItems > 0) {
      return (itemsCompleted / totalItems).clamp(0, 1).toDouble();
    }
    return null;
  }

  EpisodeDownloadProgress copyWith({
    DownloadTaskStatus? status,
    int? bytesReceived,
    int? bytesTotal,
    int? itemsCompleted,
    int? itemsTotal,
    String? error,
  }) {
    return EpisodeDownloadProgress(
      request: request,
      status: status ?? this.status,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      itemsCompleted: itemsCompleted ?? this.itemsCompleted,
      itemsTotal: itemsTotal ?? this.itemsTotal,
      error: error ?? this.error,
    );
  }
}
