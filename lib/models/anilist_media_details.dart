import '../core/json_utils.dart';
import '../core/text_utils.dart';
import 'anilist_media.dart';

class AniListMediaDetails {
  const AniListMediaDetails({
    required this.media,
    this.synonyms = const [],
    this.studios = const [],
    this.relations = const [],
    this.recommendations = const [],
    this.characters = const [],
    this.staff = const [],
    this.nextAiringEpisode,
    this.nextAiringAt,
    this.trailerUrl,
    this.trailerThumbnail,
  });

  final AniListMedia media;
  final List<String> synonyms;
  final List<String> studios;
  final List<AniListMediaRelation> relations;
  final List<AniListMedia> recommendations;
  final List<AniListPersonCredit> characters;
  final List<AniListPersonCredit> staff;
  final int? nextAiringEpisode;
  final DateTime? nextAiringAt;
  final String? trailerUrl;
  final String? trailerThumbnail;

  factory AniListMediaDetails.fromJson(Map<String, dynamic> json) {
    final trailer = _asMap(json['trailer']);
    final nextAiring = _asMap(json['nextAiringEpisode']);
    final nextAiringSeconds = nextAiring == null
        ? null
        : readInt(nextAiring, 'airingAt');
    final trailerSite = trailer == null ? null : readString(trailer, 'site');
    final trailerId = trailer == null ? null : readString(trailer, 'id');

    return AniListMediaDetails(
      media: AniListMedia.fromJson(json),
      synonyms: readStringList(json['synonyms']),
      studios: _connectionNodes(json['studios'])
          .map((item) => readString(item, 'name'))
          .whereType<String>()
          .toList(growable: false),
      relations: _connectionEdges(json['relations'])
          .map((edge) {
            final node = _asMap(edge['node']);
            if (node == null) {
              return null;
            }
            return AniListMediaRelation(
              type: _readableEnum(readString(edge, 'relationType')),
              media: AniListMedia.fromJson(node),
            );
          })
          .whereType<AniListMediaRelation>()
          .toList(growable: false),
      recommendations: _connectionNodes(json['recommendations'])
          .map((node) => _asMap(node['mediaRecommendation']))
          .whereType<Map<String, dynamic>>()
          .map(AniListMedia.fromJson)
          .toList(growable: false),
      characters: _connectionEdges(json['characters'])
          .map(
            (edge) => AniListPersonCredit.fromEdgeJson(
              edge,
              fallbackRole: _readableEnum(readString(edge, 'role')),
            ),
          )
          .whereType<AniListPersonCredit>()
          .toList(growable: false),
      staff: _connectionEdges(json['staff'])
          .map(AniListPersonCredit.fromEdgeJson)
          .whereType<AniListPersonCredit>()
          .toList(growable: false),
      nextAiringEpisode: nextAiring == null
          ? null
          : readInt(nextAiring, 'episode'),
      nextAiringAt: nextAiringSeconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              nextAiringSeconds * 1000,
              isUtc: true,
            ).toLocal(),
      trailerUrl: _trailerUrl(trailerSite, trailerId),
      trailerThumbnail: trailer == null
          ? null
          : readString(trailer, 'thumbnail'),
    );
  }
}

class AniListMediaRelation {
  const AniListMediaRelation({required this.type, required this.media});

  final String type;
  final AniListMedia media;
}

class AniListPersonCredit {
  const AniListPersonCredit({
    required this.id,
    required this.name,
    required this.role,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String role;
  final String? imageUrl;

  static AniListPersonCredit? fromEdgeJson(
    Map<String, dynamic> edge, {
    String fallbackRole = '',
  }) {
    final node = _asMap(edge['node']);
    if (node == null) {
      return null;
    }
    final name = _asMap(node['name']);
    final image = _asMap(node['image']);
    return AniListPersonCredit(
      id: readInt(node, 'id') ?? 0,
      name:
          firstNonBlank([
            if (name != null) readString(name, 'full'),
            if (name != null) readString(name, 'userPreferred'),
          ]) ??
          'Unknown',
      role: firstNonBlank([readString(edge, 'role'), fallbackRole]) ?? '',
      imageUrl: image == null ? null : readString(image, 'large'),
    );
  }
}

List<Map<String, dynamic>> _connectionNodes(Object? value) {
  final connection = _asMap(value);
  return ((connection?['nodes'] as List?) ?? const [])
      .map(_asMap)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

List<Map<String, dynamic>> _connectionEdges(Object? value) {
  final connection = _asMap(value);
  return ((connection?['edges'] as List?) ?? const [])
      .map(_asMap)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return null;
}

String _readableEnum(String? value) {
  if (value == null) {
    return '';
  }
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');
}

String? _trailerUrl(String? site, String? id) {
  if (site == null || id == null) {
    return null;
  }
  return switch (site.toLowerCase()) {
    'youtube' => 'https://www.youtube.com/watch?v=$id',
    'dailymotion' => 'https://www.dailymotion.com/video/$id',
    _ => null,
  };
}
