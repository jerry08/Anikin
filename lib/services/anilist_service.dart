import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import '../core/json_utils.dart';
import '../models/anilist_airing_schedule.dart';
import '../models/anilist_media.dart';
import '../models/anilist_media_details.dart';
import '../models/anilist_person_details.dart';
import 'catalog_cache_service.dart';

enum AniListMediaType {
  anime('ANIME'),
  manga('MANGA');

  const AniListMediaType(this.graphqlName);

  final String graphqlName;
}

abstract class MediaCatalogService {
  String get providerLabel;

  Future<List<AniListMedia>> searchMedia({
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    String? season,
    int? seasonYear,
    String? status,
    String? source,
    String? format,
    String? countryOfOrigin,
    List<String>? tags,
    List<String>? excludedTags,
    List<String>? genres,
    List<String>? excludedGenres,
    AniListMediaType mediaType = AniListMediaType.anime,
    required bool includeNonJapanese,
  });

  Future<List<AniListMedia>> getPopular({required bool includeNonJapanese});

  Future<List<AniListMedia>> getTrending({required bool includeNonJapanese});

  Future<List<AniListMedia>> getCurrentSeason({
    required bool includeNonJapanese,
  });

  Future<List<AniListMedia>> getRecentlyUpdated({
    required bool includeNonJapanese,
  });

  Future<List<AniListMedia>> searchManga({
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    String? status,
    String? source,
    String? format,
    String? countryOfOrigin,
    List<String>? tags,
    List<String>? excludedTags,
    List<String>? genres,
    List<String>? excludedGenres,
    required bool includeNonJapanese,
  });

  Future<List<String>> getGenreCollection();

  Future<List<AniListMedia>> getPopularManga({
    required bool includeNonJapanese,
  });

  Future<List<AniListMedia>> getTrendingManga({
    required bool includeNonJapanese,
  });

  Future<List<AniListMedia>> getRecentlyUpdatedManga({
    required bool includeNonJapanese,
  });

  Future<List<AniListMedia>> getTopRatedManga({
    required bool includeNonJapanese,
  });

  Future<List<AniListAiringSchedule>> getAiringCalendar({
    required DateTime start,
    required int days,
    required bool includeNonJapanese,
  });
}

class AniListService implements MediaCatalogService {
  AniListService({
    http.Client? client,
    FutureOr<bool> Function()? includeAdultContentResolver,
    CatalogCacheService? cache,
  }) : _client = client ?? http.Client(),
       _includeAdultContentResolver = includeAdultContentResolver,
       _cache = cache;

  final http.Client _client;
  final FutureOr<bool> Function()? _includeAdultContentResolver;
  final CatalogCacheService? _cache;

  @override
  String get providerLabel => 'AniList';

  static const _mediaFields = r'''
id
idMal
title { romaji english native userPreferred }
coverImage { extraLarge large color }
bannerImage
description(asHtml: false)
genres
meanScore
popularity
favourites
episodes
chapters
volumes
duration
status
season
seasonYear
format
type
source
countryOfOrigin
startDate { year month day }
endDate { year month day }
siteUrl
isAdult
''';

  static const _mediaCardFields = r'''
id
idMal
type
title { romaji english native userPreferred }
coverImage { extraLarge large color }
bannerImage
description(asHtml: false)
genres
meanScore
popularity
favourites
episodes
chapters
volumes
duration
status
season
seasonYear
format
source
countryOfOrigin
startDate { year month day }
endDate { year month day }
siteUrl
isAdult
''';

  @override
  Future<List<AniListMedia>> searchMedia({
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    String? season,
    int? seasonYear,
    String? status,
    String? source,
    String? format,
    String? countryOfOrigin,
    List<String>? tags,
    List<String>? excludedTags,
    List<String>? genres,
    List<String>? excludedGenres,
    AniListMediaType mediaType = AniListMediaType.anime,
    required bool includeNonJapanese,
  }) async {
    final includeAdultContent = await _resolveIncludeAdultContent();
    final tagIn = tags == null || tags.isEmpty ? null : tags;
    final tagNotIn = excludedTags == null || excludedTags.isEmpty
        ? null
        : excludedTags;
    final genreIn = genres == null || genres.isEmpty ? null : genres;
    final genreNotIn = excludedGenres == null || excludedGenres.isEmpty
        ? null
        : excludedGenres;
    final variableDefinitions = [
      r'$page: Int!',
      r'$perPage: Int!',
      r'$search: String',
      r'$sort: [MediaSort]',
      if (season != null) r'$season: MediaSeason',
      if (seasonYear != null) r'$seasonYear: Int',
      if (status != null) r'$status: MediaStatus',
      if (source != null) r'$source: MediaSource',
      if (format != null) r'$format: MediaFormat',
      if (countryOfOrigin != null) r'$countryOfOrigin: CountryCode',
      if (tagIn != null) r'$tagIn: [String]',
      if (tagNotIn != null) r'$tagNotIn: [String]',
      if (genreIn != null) r'$genreIn: [String]',
      if (genreNotIn != null) r'$genreNotIn: [String]',
    ].join(',\n  ');
    final mediaArguments = [
      'type: MEDIA_TYPE',
      if (!includeAdultContent) 'isAdult: false',
      r'search: $search',
      r'sort: $sort',
      if (season != null) r'season: $season',
      if (seasonYear != null) r'seasonYear: $seasonYear',
      if (status != null) r'status: $status',
      if (source != null) r'source: $source',
      if (format != null) r'format: $format',
      if (countryOfOrigin != null) r'countryOfOrigin: $countryOfOrigin',
      if (tagIn != null) r'tag_in: $tagIn',
      if (tagNotIn != null) r'tag_not_in: $tagNotIn',
      if (genreIn != null) r'genre_in: $genreIn',
      if (genreNotIn != null) r'genre_not_in: $genreNotIn',
    ].join(',\n      ');
    final variables = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      'search': _blankToNull(query),
      'sort': sort ?? const ['POPULARITY_DESC'],
    };
    if (season != null) {
      variables['season'] = season;
    }
    if (seasonYear != null) {
      variables['seasonYear'] = seasonYear;
    }
    if (status != null) {
      variables['status'] = status;
    }
    if (source != null) {
      variables['source'] = source;
    }
    if (format != null) {
      variables['format'] = format;
    }
    if (countryOfOrigin != null) {
      variables['countryOfOrigin'] = countryOfOrigin;
    }
    if (tagIn != null) {
      variables['tagIn'] = tagIn;
    }
    if (tagNotIn != null) {
      variables['tagNotIn'] = tagNotIn;
    }
    if (genreIn != null) {
      variables['genreIn'] = genreIn;
    }
    if (genreNotIn != null) {
      variables['genreNotIn'] = genreNotIn;
    }

    final data = await _post(
      '''
query MediaSearch(
  $variableDefinitions
) {
  Page(page: \$page, perPage: \$perPage) {
    media(
      $mediaArguments
    ) {
      MEDIA_FIELDS
    }
  }
}
'''
          .replaceAll('MEDIA_FIELDS', _mediaFields)
          .replaceAll('MEDIA_TYPE', mediaType.graphqlName),
      variables,
    );

    final media = ((data['Page']?['media'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AniListMedia.fromJson)
        .where(
          (item) => _matchesMediaFilters(
            item,
            includeNonJapanese: includeNonJapanese,
            includeAdultContent: includeAdultContent,
          ),
        )
        .toList();
    return media;
  }

  @override
  Future<List<AniListMedia>> getPopular({required bool includeNonJapanese}) {
    return searchMedia(
      sort: const ['POPULARITY_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

  @override
  Future<List<AniListMedia>> getTrending({required bool includeNonJapanese}) {
    return searchMedia(
      sort: const ['TRENDING_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

  @override
  Future<List<AniListMedia>> getCurrentSeason({
    required bool includeNonJapanese,
  }) {
    final now = DateTime.now();
    return searchMedia(
      sort: const ['POPULARITY_DESC'],
      season: _seasonForMonth(now.month),
      seasonYear: now.year,
      includeNonJapanese: includeNonJapanese,
    );
  }

  @override
  Future<List<AniListMedia>> getRecentlyUpdated({
    required bool includeNonJapanese,
  }) async {
    final includeAdultContent = await _resolveIncludeAdultContent();
    final now = DateTime.now();
    final start =
        now.subtract(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000;
    final end = now.millisecondsSinceEpoch ~/ 1000;

    final data = await _post(
      r'''
query RecentlyUpdated($start: Int!, $end: Int!) {
  Page(page: 1, perPage: 50) {
    airingSchedules(
      airingAt_greater: $start,
      airingAt_lesser: $end,
      notYetAired: false,
      sort: TIME_DESC
    ) {
      media { MEDIA_FIELDS }
    }
  }
}
'''
          .replaceAll('MEDIA_FIELDS', _mediaFields),
      {'start': start, 'end': end},
    );

    final seen = <int>{};
    return ((data['Page']?['airingSchedules'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map((item) => item['media'])
        .whereType<Map<String, dynamic>>()
        .map(AniListMedia.fromJson)
        .where(
          (item) => _matchesMediaFilters(
            item,
            includeNonJapanese: includeNonJapanese,
            includeAdultContent: includeAdultContent,
          ),
        )
        .where((item) => seen.add(item.id))
        .toList();
  }

  @override
  Future<List<AniListMedia>> searchManga({
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    String? status,
    String? source,
    String? format,
    String? countryOfOrigin,
    List<String>? tags,
    List<String>? excludedTags,
    List<String>? genres,
    List<String>? excludedGenres,
    required bool includeNonJapanese,
  }) {
    return searchMedia(
      query: query,
      page: page,
      perPage: perPage,
      sort: sort,
      status: status,
      source: source,
      format: format,
      countryOfOrigin: countryOfOrigin,
      tags: tags,
      excludedTags: excludedTags,
      genres: genres,
      excludedGenres: excludedGenres,
      mediaType: AniListMediaType.manga,
      includeNonJapanese: includeNonJapanese,
    );
  }

  @override
  Future<List<String>> getGenreCollection() async {
    final includeAdultContent = await _resolveIncludeAdultContent();
    final data = await _post(r'''
query GenreCollection {
  GenreCollection
}
''', const {});

    return readStringList(data['GenreCollection'])
        .where((item) => item.trim().isNotEmpty)
        .where((item) => includeAdultContent || !_isAdultGenreLabel(item))
        .toSet()
        .toList()
      ..sort();
  }

  Future<AniListMediaDetails> getMediaDetails({
    required int id,
    required AniListMediaType mediaType,
  }) async {
    final data = await _post(
      r'''
query MediaDetails($id: Int!, $type: MediaType!) {
  Media(id: $id, type: $type) {
    MEDIA_FIELDS
    synonyms
    studios(isMain: true) { nodes { name } }
    nextAiringEpisode { airingAt episode }
    trailer { id site thumbnail }
    relations {
      edges {
        relationType(version: 2)
        node { MEDIA_CARD_FIELDS }
      }
    }
    recommendations(sort: RATING_DESC, perPage: 12) {
      nodes { mediaRecommendation { MEDIA_CARD_FIELDS } }
    }
    characters(sort: [ROLE, RELEVANCE, ID], perPage: 12) {
      edges {
        role
        node { id name { full userPreferred } image { large } }
      }
    }
    staff(sort: [RELEVANCE, ID], perPage: 12) {
      edges {
        role
        node { id name { full userPreferred } image { large } }
      }
    }
  }
}
'''
          .replaceAll('MEDIA_FIELDS', _mediaFields)
          .replaceAll('MEDIA_CARD_FIELDS', _mediaCardFields),
      {'id': id, 'type': mediaType.graphqlName},
    );
    final media = data['Media'];
    if (media is! Map<String, dynamic>) {
      throw const ApiException('AniList did not return media details');
    }
    return AniListMediaDetails.fromJson(media);
  }

  Future<AniListPersonDetails> getPersonDetails({
    required int id,
    required AniListPersonKind kind,
  }) async {
    final includeAdultContent = await _resolveIncludeAdultContent();
    final isCharacter = kind == AniListPersonKind.character;
    final rootField = isCharacter ? 'Character' : 'Staff';
    final mediaField = isCharacter ? 'media' : 'staffMedia';
    final extraFields = isCharacter
        ? ''
        : '''
    homeTown
    bloodType
    primaryOccupations
''';
    final query =
        '''
query PersonDetails(\$id: Int!) {
  $rootField(id: \$id) {
    id
    name { full native alternative userPreferred }
    image { large }
    description(asHtml: false)
    gender
    age
    dateOfBirth { year month day }
    favourites
    siteUrl
$extraFields
    $mediaField(page: 1, perPage: 20, sort: [POPULARITY_DESC]) {
      nodes { MEDIA_CARD_FIELDS }
    }
  }
}
'''
            .replaceAll('MEDIA_CARD_FIELDS', _mediaCardFields);
    final data = await _post(query, {'id': id});
    final person = data[rootField];
    if (person is! Map<String, dynamic>) {
      throw ApiException(
        'AniList did not return ${kind.label.toLowerCase()} details',
      );
    }
    final details = AniListPersonDetails.fromJson(person, kind: kind);
    if (includeAdultContent) return details;
    return details.copyWith(
      knownFor: details.knownFor.where((media) => !media.isAdult).toList(),
    );
  }

  @override
  Future<List<AniListMedia>> getPopularManga({
    required bool includeNonJapanese,
  }) {
    return searchManga(
      sort: const ['POPULARITY_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

  @override
  Future<List<AniListMedia>> getTrendingManga({
    required bool includeNonJapanese,
  }) {
    return searchManga(
      sort: const ['TRENDING_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

  @override
  Future<List<AniListMedia>> getRecentlyUpdatedManga({
    required bool includeNonJapanese,
  }) {
    return searchManga(
      sort: const ['UPDATED_AT_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

  @override
  Future<List<AniListMedia>> getTopRatedManga({
    required bool includeNonJapanese,
  }) {
    return searchManga(
      sort: const ['SCORE_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

  @override
  Future<List<AniListAiringSchedule>> getAiringCalendar({
    required DateTime start,
    required int days,
    required bool includeNonJapanese,
  }) async {
    final includeAdultContent = await _resolveIncludeAdultContent();
    final startTime = start.toUtc();
    final endTime = startTime.add(Duration(days: days));
    final startSeconds = startTime.millisecondsSinceEpoch ~/ 1000;
    final endSeconds = endTime.millisecondsSinceEpoch ~/ 1000;

    final data = await _post(
      r'''
query AiringCalendar($start: Int!, $end: Int!) {
  Page(page: 1, perPage: 100) {
    airingSchedules(
      airingAt_greater: $start,
      airingAt_lesser: $end,
      sort: TIME
      notYetAired: true
    ) {
      id
      airingAt
      episode
      media { MEDIA_FIELDS }
    }
  }
}
'''
          .replaceAll('MEDIA_FIELDS', _mediaFields),
      {'start': startSeconds, 'end': endSeconds},
    );

    return ((data['Page']?['airingSchedules'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AniListAiringSchedule.fromJson)
        .where(
          (item) => _matchesMediaFilters(
            item.media,
            includeNonJapanese: includeNonJapanese,
            includeAdultContent: includeAdultContent,
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> _post(
    String query,
    Map<String, dynamic> variables,
  ) async {
    final requestBody = jsonEncode({'query': query, 'variables': variables});
    final cache = _cache;
    final cacheKey = cache == null ? null : await _cacheKey(requestBody);
    if (cache != null && cacheKey != null) {
      final cached = await cache.read(cacheKey);
      if (cached != null) {
        return (jsonDecode(cached) as Map).cast<String, dynamic>();
      }
    }

    try {
      final response = await _client.post(
        Uri.parse(AppConstants.anilistGraphqlEndpoint),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'AniList returned ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final errors = decoded['errors'];
      if (errors is List && errors.isNotEmpty) {
        throw ApiException(
          errors.first['message']?.toString() ?? 'AniList request failed',
        );
      }

      final data = decoded['data'] as Map<String, dynamic>;
      if (cache != null && cacheKey != null) {
        await cache.write(cacheKey, jsonEncode(data));
      }
      return data;
    } catch (_) {
      if (cache != null && cacheKey != null) {
        final stale = await cache.read(cacheKey, allowExpired: true);
        if (stale != null) {
          return (jsonDecode(stale) as Map).cast<String, dynamic>();
        }
      }
      rethrow;
    }
  }

  static Future<String> _cacheKey(String requestBody) async {
    final digest = await Sha256().hash(utf8.encode(requestBody));
    return 'anilist:${digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
  }

  static String? _blankToNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  static String _seasonForMonth(int month) {
    return switch (month) {
      1 || 2 || 3 => 'WINTER',
      4 || 5 || 6 => 'SPRING',
      7 || 8 || 9 => 'SUMMER',
      _ => 'FALL',
    };
  }

  Future<bool> _resolveIncludeAdultContent() async {
    final resolver = _includeAdultContentResolver;
    if (resolver == null) {
      return false;
    }

    return await resolver();
  }

  static bool _matchesMediaFilters(
    AniListMedia item, {
    required bool includeNonJapanese,
    required bool includeAdultContent,
  }) {
    if (!includeNonJapanese && item.countryOfOrigin != 'JP') {
      return false;
    }

    if (!includeAdultContent && item.isAdult) {
      return false;
    }

    return true;
  }

  static bool _isAdultGenreLabel(String genre) {
    return switch (genre.trim().toLowerCase()) {
      'hentai' || 'erotica' => true,
      _ => false,
    };
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
