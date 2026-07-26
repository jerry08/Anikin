import '../core/json_utils.dart';
import '../core/text_utils.dart';
import 'anilist_media.dart';

enum AniListPersonKind {
  character,
  staff;

  String get label => switch (this) {
    AniListPersonKind.character => 'Character',
    AniListPersonKind.staff => 'Staff',
  };
}

class AniListPersonDetails {
  const AniListPersonDetails({
    required this.id,
    required this.kind,
    required this.name,
    this.nativeName,
    this.alternativeNames = const [],
    this.imageUrl,
    this.description = '',
    this.gender,
    this.age,
    this.dateOfBirth,
    this.homeTown,
    this.bloodType,
    this.primaryOccupations = const [],
    this.favourites,
    this.siteUrl,
    this.knownFor = const [],
  });

  final int id;
  final AniListPersonKind kind;
  final String name;
  final String? nativeName;
  final List<String> alternativeNames;
  final String? imageUrl;
  final String description;
  final String? gender;
  final String? age;
  final String? dateOfBirth;
  final String? homeTown;
  final String? bloodType;
  final List<String> primaryOccupations;
  final int? favourites;
  final String? siteUrl;
  final List<AniListMedia> knownFor;

  factory AniListPersonDetails.fromJson(
    Map<String, dynamic> json, {
    required AniListPersonKind kind,
  }) {
    final name = _asMap(json['name']);
    final image = _asMap(json['image']);
    final mediaConnection = _asMap(
      json[kind == AniListPersonKind.character ? 'media' : 'staffMedia'],
    );
    final date = _asMap(json['dateOfBirth']);
    final mediaNodes = ((mediaConnection?['nodes'] as List?) ?? const [])
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map(AniListMedia.fromJson)
        .toList(growable: false);

    return AniListPersonDetails(
      id: readInt(json, 'id') ?? 0,
      kind: kind,
      name:
          firstNonBlank([
            if (name != null) readString(name, 'full'),
            if (name != null) readString(name, 'userPreferred'),
          ]) ??
          'Unknown',
      nativeName: name == null ? null : readString(name, 'native'),
      alternativeNames: name == null
          ? const []
          : readStringList(name['alternative']),
      imageUrl: image == null ? null : readString(image, 'large'),
      description: stripHtml(readString(json, 'description')),
      gender: readString(json, 'gender'),
      age: _stringValue(json['age']),
      dateOfBirth: _formatDate(date),
      homeTown: readString(json, 'homeTown'),
      bloodType: readString(json, 'bloodType'),
      primaryOccupations: readStringList(json['primaryOccupations']),
      favourites: readInt(json, 'favourites'),
      siteUrl: readString(json, 'siteUrl'),
      knownFor: mediaNodes,
    );
  }

  AniListPersonDetails copyWith({List<AniListMedia>? knownFor}) {
    return AniListPersonDetails(
      id: id,
      kind: kind,
      name: name,
      nativeName: nativeName,
      alternativeNames: alternativeNames,
      imageUrl: imageUrl,
      description: description,
      gender: gender,
      age: age,
      dateOfBirth: dateOfBirth,
      homeTown: homeTown,
      bloodType: bloodType,
      primaryOccupations: primaryOccupations,
      favourites: favourites,
      siteUrl: siteUrl,
      knownFor: knownFor ?? this.knownFor,
    );
  }
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

String? _stringValue(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _formatDate(Map<String, dynamic>? value) {
  if (value == null) return null;
  final year = readInt(value, 'year');
  final month = readInt(value, 'month');
  final day = readInt(value, 'day');
  if (year == null && month == null && day == null) return null;
  final parts = <String>[
    if (month != null) _months[(month - 1).clamp(0, 11)],
    if (day != null) '$day',
    if (year != null) '$year',
  ];
  return parts.join(' ');
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
