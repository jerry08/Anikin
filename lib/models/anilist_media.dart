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

  String? get best => firstNonBlank([extraLarge, large]);

  factory MediaCover.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MediaCover();
    }

    return MediaCover(
      extraLarge: readString(json, 'extraLarge'),
      large: readString(json, 'large'),
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
    this.episodes,
    this.chapters,
    this.volumes,
    this.duration,
    this.status,
    this.season,
    this.seasonYear,
    this.format,
    this.countryOfOrigin,
    this.siteUrl,
    this.isAdult = false,
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
  final int? episodes;
  final int? chapters;
  final int? volumes;
  final int? duration;
  final String? status;
  final String? season;
  final int? seasonYear;
  final String? format;
  final String? countryOfOrigin;
  final String? siteUrl;
  final bool isAdult;

  String get displayTitle => title.preferred;

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
      bannerImage: readString(json, 'bannerImage'),
      description: stripHtml(readString(json, 'description')),
      genres: readStringList(readJson(json, 'genres')),
      meanScore: readInt(json, 'meanScore'),
      popularity: readInt(json, 'popularity'),
      episodes: readInt(json, 'episodes'),
      chapters: readInt(json, 'chapters'),
      volumes: readInt(json, 'volumes'),
      duration: readInt(json, 'duration'),
      status: readString(json, 'status'),
      season: readString(json, 'season'),
      seasonYear: readInt(json, 'seasonYear'),
      format: readString(json, 'format'),
      countryOfOrigin: readString(json, 'countryOfOrigin'),
      siteUrl: readString(json, 'siteUrl'),
      isAdult: json['isAdult'] == true,
    );
  }
}
