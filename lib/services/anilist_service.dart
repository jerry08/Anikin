import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import '../models/anilist_media.dart';

enum AniListMediaType {
  anime('ANIME'),
  manga('MANGA');

  const AniListMediaType(this.graphqlName);

  final String graphqlName;
}

class AniListService {
  AniListService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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
episodes
chapters
volumes
duration
status
season
seasonYear
format
countryOfOrigin
siteUrl
''';

  Future<List<AniListMedia>> searchMedia({
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    String? season,
    int? seasonYear,
    List<String>? tags,
    AniListMediaType mediaType = AniListMediaType.anime,
    required bool includeNonJapanese,
  }) async {
    final tagIn = tags == null || tags.isEmpty ? null : tags;
    final variableDefinitions = [
      r'$page: Int!',
      r'$perPage: Int!',
      r'$search: String',
      r'$sort: [MediaSort]',
      if (season != null) r'$season: MediaSeason',
      if (seasonYear != null) r'$seasonYear: Int',
      if (tagIn != null) r'$tagIn: [String]',
    ].join(',\n  ');
    final mediaArguments = [
      'type: MEDIA_TYPE',
      'isAdult: false',
      r'search: $search',
      r'sort: $sort',
      if (season != null) r'season: $season',
      if (seasonYear != null) r'seasonYear: $seasonYear',
      if (tagIn != null) r'tag_in: $tagIn',
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
    if (tagIn != null) {
      variables['tagIn'] = tagIn;
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
        .where((item) => includeNonJapanese || item.countryOfOrigin == 'JP')
        .toList();
    return media;
  }

  Future<List<AniListMedia>> getPopular({required bool includeNonJapanese}) {
    return searchMedia(
      sort: const ['POPULARITY_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

  Future<List<AniListMedia>> getTrending({required bool includeNonJapanese}) {
    return searchMedia(
      sort: const ['TRENDING_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

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

  Future<List<AniListMedia>> getRecentlyUpdated({
    required bool includeNonJapanese,
  }) async {
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
        .where((item) => includeNonJapanese || item.countryOfOrigin == 'JP')
        .where((item) => seen.add(item.id))
        .toList();
  }

  Future<List<AniListMedia>> searchManga({
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    List<String>? tags,
    required bool includeNonJapanese,
  }) {
    return searchMedia(
      query: query,
      page: page,
      perPage: perPage,
      sort: sort,
      tags: tags,
      mediaType: AniListMediaType.manga,
      includeNonJapanese: includeNonJapanese,
    );
  }

  Future<List<AniListMedia>> getPopularManga({
    required bool includeNonJapanese,
  }) {
    return searchManga(
      sort: const ['POPULARITY_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

  Future<List<AniListMedia>> getTrendingManga({
    required bool includeNonJapanese,
  }) {
    return searchManga(
      sort: const ['TRENDING_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

  Future<List<AniListMedia>> getRecentlyUpdatedManga({
    required bool includeNonJapanese,
  }) {
    return searchManga(
      sort: const ['UPDATED_AT_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

  Future<List<AniListMedia>> getTopRatedManga({
    required bool includeNonJapanese,
  }) {
    return searchManga(
      sort: const ['SCORE_DESC'],
      includeNonJapanese: includeNonJapanese,
    );
  }

  Future<Map<String, dynamic>> _post(
    String query,
    Map<String, dynamic> variables,
  ) async {
    final response = await _client.post(
      Uri.parse(AppConstants.anilistGraphqlEndpoint),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'query': query, 'variables': variables}),
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

    return decoded['data'] as Map<String, dynamic>;
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
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
