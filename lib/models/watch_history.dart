import 'anilist_media.dart';
import 'juro_models.dart';

class WatchedEpisode {
  const WatchedEpisode({
    required this.id,
    required this.animeName,
    required this.watchedDurationMs,
    required this.watchedPercentage,
    this.mediaId,
    this.mediaTitle,
    this.mediaCoverUrl,
    this.providerAnimeId,
    this.providerAnimeTitle,
    this.providerAnimeImage,
    this.episodeId,
    this.episodeName,
    this.episodeNumber,
    this.episodeImage,
    this.providerKey,
    this.providerName,
    this.updatedAtMs,
  });

  final String id;
  final String animeName;
  final int watchedDurationMs;
  final double watchedPercentage;
  final int? mediaId;
  final String? mediaTitle;
  final String? mediaCoverUrl;
  final String? providerAnimeId;
  final String? providerAnimeTitle;
  final String? providerAnimeImage;
  final String? episodeId;
  final String? episodeName;
  final double? episodeNumber;
  final String? episodeImage;
  final String? providerKey;
  final String? providerName;
  final int? updatedAtMs;

  Duration get watchedDuration => Duration(milliseconds: watchedDurationMs);

  bool get canResumeAnime =>
      mediaId != null &&
      _hasText(providerAnimeId) &&
      _hasText(episodeId) &&
      episodeNumber != null &&
      _hasText(providerKey);

  String get displayAnimeName => _firstText([mediaTitle, animeName]) ?? '';

  String get displayEpisodeName {
    final number = episodeNumber;
    final name = _firstText([episodeName]);
    if (number == null) {
      return name ?? 'Unknown episode';
    }
    final numberText = AnimeEpisode.displayNumber(number);
    if (name == null || name == numberText) {
      return 'Episode $numberText';
    }
    return 'Ep $numberText • $name';
  }

  AniListMedia get resumeMedia => AniListMedia(
    id: mediaId!,
    title: MediaTitle(english: _firstText([mediaTitle, animeName])),
    cover: MediaCover(extraLarge: mediaCoverUrl, large: mediaCoverUrl),
  );

  JuroAnimeInfo get resumeProviderAnime => JuroAnimeInfo(
    id: providerAnimeId!,
    title:
        _firstText([providerAnimeTitle, mediaTitle, animeName]) ??
        'Unknown anime',
    image: providerAnimeImage ?? mediaCoverUrl,
  );

  AnimeEpisode get resumeEpisode => AnimeEpisode(
    id: episodeId!,
    name: episodeName,
    number: episodeNumber!,
    image: episodeImage ?? providerAnimeImage ?? mediaCoverUrl,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'animeName': animeName,
    'watchedDuration': watchedDurationMs,
    'watchedPercentage': watchedPercentage,
    if (mediaId != null) 'mediaId': mediaId,
    if (_hasText(mediaTitle)) 'mediaTitle': mediaTitle,
    if (_hasText(mediaCoverUrl)) 'mediaCoverUrl': mediaCoverUrl,
    if (_hasText(providerAnimeId)) 'providerAnimeId': providerAnimeId,
    if (_hasText(providerAnimeTitle)) 'providerAnimeTitle': providerAnimeTitle,
    if (_hasText(providerAnimeImage)) 'providerAnimeImage': providerAnimeImage,
    if (_hasText(episodeId)) 'episodeId': episodeId,
    if (_hasText(episodeName)) 'episodeName': episodeName,
    if (episodeNumber != null) 'episodeNumber': episodeNumber,
    if (_hasText(episodeImage)) 'episodeImage': episodeImage,
    if (_hasText(providerKey)) 'providerKey': providerKey,
    if (_hasText(providerName)) 'providerName': providerName,
    if (updatedAtMs != null) 'updatedAtMs': updatedAtMs,
  };

  factory WatchedEpisode.fromJson(Map<String, dynamic> json) {
    return WatchedEpisode(
      id: json['id']?.toString() ?? '',
      animeName: json['animeName']?.toString() ?? '',
      watchedDurationMs: (json['watchedDuration'] as num?)?.toInt() ?? 0,
      watchedPercentage: (json['watchedPercentage'] as num?)?.toDouble() ?? 0,
      mediaId: (json['mediaId'] as num?)?.toInt(),
      mediaTitle: json['mediaTitle']?.toString(),
      mediaCoverUrl: json['mediaCoverUrl']?.toString(),
      providerAnimeId: json['providerAnimeId']?.toString(),
      providerAnimeTitle: json['providerAnimeTitle']?.toString(),
      providerAnimeImage: json['providerAnimeImage']?.toString(),
      episodeId: json['episodeId']?.toString(),
      episodeName: json['episodeName']?.toString(),
      episodeNumber: (json['episodeNumber'] as num?)?.toDouble(),
      episodeImage: json['episodeImage']?.toString(),
      providerKey: json['providerKey']?.toString(),
      providerName: json['providerName']?.toString(),
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt(),
    );
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String? _firstText(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}
