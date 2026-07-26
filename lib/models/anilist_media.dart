import '../core/image_url_utils.dart';
import '../core/json_utils.dart';
import '../core/text_utils.dart';

class MediaTitle {
  const MediaTitle({
    this.romaji,
    this.english,
    this.native,
    this.userPreferred,
  });

  final String? romaji;
  final String? english;
  final String? native;
  final String? userPreferred;

  String get preferred =>
      firstNonBlank([userPreferred, english, romaji, native]) ?? 'Untitled';

  List<String> get searchCandidates => [preferred, romaji, native, english]
      .whereType<String>()
      .where((title) => title.trim().isNotEmpty)
      .toSet()
      .toList();

  factory MediaTitle.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MediaTitle();
    }

    return MediaTitle(
      romaji: readString(json, 'romaji'),
      english: readString(json, 'english'),
      native: readString(json, 'native'),
      userPreferred: readString(json, 'userPreferred'),
    );
  }
}

class MediaCover {
  const MediaCover({this.extraLarge, this.large, this.color});

  final String? extraLarge;
  final String? large;
  final String? color;

  String? get best => normalizeImageUrl(firstNonBlank([extraLarge, large]));

  factory MediaCover.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MediaCover();
    }

    return MediaCover(
      extraLarge: normalizeImageUrl(readString(json, 'extraLarge')),
      large: normalizeImageUrl(readString(json, 'large')),
      color: readString(json, 'color'),
    );
  }
}

class AniListMedia {
  const AniListMedia({
    required this.id,
    this.idMal,
    required this.title,
    required this.cover,
    this.bannerImage,
    this.description = '',
    this.genres = const [],
    this.meanScore,
    this.popularity,
    this.favourites,
    this.episodes,
    this.chapters,
    this.volumes,
    this.duration,
    this.status,
    this.season,
    this.seasonYear,
    this.format,
    this.mediaType,
    this.source,
    this.countryOfOrigin,
    this.startDate,
    this.endDate,
    this.siteUrl,
    this.isAdult = false,
    this.catalogProviderKey = 'anilist',
  });

  final int id;
  final int? idMal;
  final MediaTitle title;
  final MediaCover cover;
  final String? bannerImage;
  final String description;
  final List<String> genres;
  final int? meanScore;
  final int? popularity;
  final int? favourites;
  final int? episodes;
  final int? chapters;
  final int? volumes;
  final int? duration;
  final String? status;
  final String? season;
  final int? seasonYear;
  final String? format;
  final String? mediaType;
  final String? source;
  final String? countryOfOrigin;
  final String? startDate;
  final String? endDate;
  final String? siteUrl;
  final bool isAdult;
  final String catalogProviderKey;

  String get displayTitle => title.preferred;

  bool get hasAniListId => catalogProviderKey == 'anilist';

  String get metadata {
    final parts = [
      if (format != null) format!.replaceAll('_', ' '),
      if (seasonYear != null) seasonYear.toString(),
      if (episodes != null) '$episodes eps',
      if (chapters != null) '$chapters ch',
      if (volumes != null) '$volumes vol',
    ];
    return parts.join(' • ');
  }

  factory AniListMedia.fromJson(Map<String, dynamic> json) {
    return AniListMedia(
      id: readInt(json, 'id') ?? 0,
      idMal: readInt(json, 'idMal'),
      title: MediaTitle.fromJson(
        readJson(json, 'title') as Map<String, dynamic>?,
      ),
      cover: MediaCover.fromJson(
        readJson(json, 'coverImage') as Map<String, dynamic>?,
      ),
      bannerImage: normalizeImageUrl(readString(json, 'bannerImage')),
      description: stripHtml(readString(json, 'description')),
      genres: readStringList(readJson(json, 'genres')),
      meanScore: readInt(json, 'meanScore'),
      popularity: readInt(json, 'popularity'),
      favourites: readInt(json, 'favourites'),
      episodes: readInt(json, 'episodes'),
      chapters: readInt(json, 'chapters'),
      volumes: readInt(json, 'volumes'),
      duration: readInt(json, 'duration'),
      status: readString(json, 'status'),
      season: readString(json, 'season'),
      seasonYear: readInt(json, 'seasonYear'),
      format: readString(json, 'format'),
      mediaType: readString(json, 'type'),
      source: readString(json, 'source'),
      countryOfOrigin: readString(json, 'countryOfOrigin'),
      startDate: _formatAniListDate(readJson(json, 'startDate')),
      endDate: _formatAniListDate(readJson(json, 'endDate')),
      siteUrl: readString(json, 'siteUrl'),
      isAdult: json['isAdult'] == true,
      catalogProviderKey: readString(json, 'catalogProviderKey') ?? 'anilist',
    );
  }
}

String? _formatAniListDate(Object? value) {
  if (value is! Map) {
    return null;
  }
  final date = Map<String, dynamic>.from(value);
  final year = readInt(date, 'year');
  if (year == null) {
    return null;
  }
  final month = readInt(date, 'month');
  final day = readInt(date, 'day');
  if (month == null) {
    return '$year';
  }
  final monthText = month.toString().padLeft(2, '0');
  if (day == null) {
    return '$year-$monthText';
  }
  return '$year-$monthText-${day.toString().padLeft(2, '0')}';
}
