import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/json_utils.dart';
import '../core/text_utils.dart';
import '../models/anilist_airing_schedule.dart';
import '../models/anilist_media.dart';
import '../models/tracking.dart';
import 'anilist_service.dart';
import 'tracking_service.dart';

class ProviderCatalogService implements MediaCatalogService {
  ProviderCatalogService({
    required AniListService aniListService,
    required TrackingService trackingService,
    http.Client? client,
  }) : _aniListService = aniListService,
       _trackingService = trackingService,
       _client = client ?? http.Client();

  final AniListService _aniListService;
  final TrackingService _trackingService;
  final http.Client _client;

  TrackingProvider get _provider => _trackingService.primaryProvider;

  @override
  String get providerLabel => _provider.label;

  @override
  Future<List<AniListMedia>> searchMedia({
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    String? season,
    int? seasonYear,
    List<String>? tags,
    List<String>? genres,
    AniListMediaType mediaType = AniListMediaType.anime,
    required bool includeNonJapanese,
  }) {
    return switch (_provider) {
      TrackingProvider.anilist => _aniListService.searchMedia(
        query: query,
        page: page,
        perPage: perPage,
        sort: sort,
        season: season,
        seasonYear: seasonYear,
        tags: tags,
        genres: genres,
        mediaType: mediaType,
        includeNonJapanese: includeNonJapanese,
      ),
      TrackingProvider.myAnimeList => _malSearch(
        mediaType: mediaType,
        query: query,
        page: page,
        perPage: perPage,
        sort: sort,
        tags: tags,
        genres: genres,
      ),
      TrackingProvider.kitsu => _kitsuSearch(
        mediaType: mediaType,
        query: query,
        page: page,
        perPage: perPage,
        sort: sort,
        tags: tags,
        genres: genres,
      ),
    };
  }

  @override
  Future<List<AniListMedia>> getPopular({required bool includeNonJapanese}) {
    return switch (_provider) {
      TrackingProvider.anilist => _aniListService.getPopular(
        includeNonJapanese: includeNonJapanese,
      ),
      TrackingProvider.myAnimeList => _malRanking(
        mediaType: AniListMediaType.anime,
        rankingType: 'bypopularity',
      ),
      TrackingProvider.kitsu => _kitsuSearch(
        mediaType: AniListMediaType.anime,
        sort: const ['POPULARITY_DESC'],
      ),
    };
  }

  @override
  Future<List<AniListMedia>> getTrending({required bool includeNonJapanese}) {
    return switch (_provider) {
      TrackingProvider.anilist => _aniListService.getTrending(
        includeNonJapanese: includeNonJapanese,
      ),
      TrackingProvider.myAnimeList => _malRanking(
        mediaType: AniListMediaType.anime,
        rankingType: 'airing',
      ),
      TrackingProvider.kitsu => _kitsuSearch(
        mediaType: AniListMediaType.anime,
        sort: const ['TRENDING_DESC'],
      ),
    };
  }

  @override
  Future<List<AniListMedia>> getCurrentSeason({
    required bool includeNonJapanese,
  }) {
    return switch (_provider) {
      TrackingProvider.anilist => _aniListService.getCurrentSeason(
        includeNonJapanese: includeNonJapanese,
      ),
      TrackingProvider.myAnimeList => _malCurrentSeason(),
      TrackingProvider.kitsu => _kitsuCurrentSeason(),
    };
  }

  @override
  Future<List<AniListMedia>> getRecentlyUpdated({
    required bool includeNonJapanese,
  }) {
    return switch (_provider) {
      TrackingProvider.anilist => _aniListService.getRecentlyUpdated(
        includeNonJapanese: includeNonJapanese,
      ),
      TrackingProvider.myAnimeList => _malRanking(
        mediaType: AniListMediaType.anime,
        rankingType: 'airing',
      ),
      TrackingProvider.kitsu => _kitsuSearch(
        mediaType: AniListMediaType.anime,
        sort: const ['UPDATED_AT_DESC'],
      ),
    };
  }

  @override
  Future<List<AniListMedia>> searchManga({
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    List<String>? tags,
    List<String>? genres,
    required bool includeNonJapanese,
  }) {
    return searchMedia(
      query: query,
      page: page,
      perPage: perPage,
      sort: sort,
      tags: tags,
      genres: genres,
      mediaType: AniListMediaType.manga,
      includeNonJapanese: includeNonJapanese,
    );
  }

  @override
  Future<List<String>> getGenreCollection() {
    return switch (_provider) {
      TrackingProvider.anilist => _aniListService.getGenreCollection(),
      TrackingProvider.myAnimeList => Future.value(const <String>[]),
      TrackingProvider.kitsu => Future.value(_kitsuGenres),
    };
  }

  @override
  Future<List<AniListMedia>> getPopularManga({
    required bool includeNonJapanese,
  }) {
    return switch (_provider) {
      TrackingProvider.anilist => _aniListService.getPopularManga(
        includeNonJapanese: includeNonJapanese,
      ),
      TrackingProvider.myAnimeList => _malRanking(
        mediaType: AniListMediaType.manga,
        rankingType: 'bypopularity',
      ),
      TrackingProvider.kitsu => _kitsuSearch(
        mediaType: AniListMediaType.manga,
        sort: const ['POPULARITY_DESC'],
      ),
    };
  }

  @override
  Future<List<AniListMedia>> getTrendingManga({
    required bool includeNonJapanese,
  }) {
    return switch (_provider) {
      TrackingProvider.anilist => _aniListService.getTrendingManga(
        includeNonJapanese: includeNonJapanese,
      ),
      TrackingProvider.myAnimeList => _malRanking(
        mediaType: AniListMediaType.manga,
        rankingType: 'manga',
      ),
      TrackingProvider.kitsu => _kitsuSearch(
        mediaType: AniListMediaType.manga,
        sort: const ['TRENDING_DESC'],
      ),
    };
  }

  @override
  Future<List<AniListMedia>> getRecentlyUpdatedManga({
    required bool includeNonJapanese,
  }) {
    return switch (_provider) {
      TrackingProvider.anilist => _aniListService.getRecentlyUpdatedManga(
        includeNonJapanese: includeNonJapanese,
      ),
      TrackingProvider.myAnimeList => _malRanking(
        mediaType: AniListMediaType.manga,
        rankingType: 'manga',
      ),
      TrackingProvider.kitsu => _kitsuSearch(
        mediaType: AniListMediaType.manga,
        sort: const ['UPDATED_AT_DESC'],
      ),
    };
  }

  @override
  Future<List<AniListMedia>> getTopRatedManga({
    required bool includeNonJapanese,
  }) {
    return switch (_provider) {
      TrackingProvider.anilist => _aniListService.getTopRatedManga(
        includeNonJapanese: includeNonJapanese,
      ),
      TrackingProvider.myAnimeList => _malRanking(
        mediaType: AniListMediaType.manga,
        rankingType: 'manga',
      ),
      TrackingProvider.kitsu => _kitsuSearch(
        mediaType: AniListMediaType.manga,
        sort: const ['SCORE_DESC'],
      ),
    };
  }

  @override
  Future<List<AniListAiringSchedule>> getAiringCalendar({
    required DateTime start,
    required int days,
    required bool includeNonJapanese,
  }) {
    return switch (_provider) {
      TrackingProvider.anilist => _aniListService.getAiringCalendar(
        start: start,
        days: days,
        includeNonJapanese: includeNonJapanese,
      ),
      TrackingProvider.myAnimeList ||
      TrackingProvider.kitsu => Future.value(const <AniListAiringSchedule>[]),
    };
  }

  Future<List<AniListMedia>> _kitsuCurrentSeason() async {
    final now = DateTime.now();
    final season = _seasonForMonth(now.month);
    final items = await _kitsuSearch(
      mediaType: AniListMediaType.anime,
      sort: const ['UPDATED_AT_DESC'],
    );
    return items
        .where((item) => item.seasonYear == now.year && item.season == season)
        .toList();
  }

  Future<List<AniListMedia>> _kitsuSearch({
    required AniListMediaType mediaType,
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    List<String>? tags,
    List<String>? genres,
  }) async {
    final limit = perPage.clamp(1, 20).toInt();
    final categories = [
      ...?genres,
      ...?tags,
    ].map(_kitsuCategorySlug).where((item) => item.isNotEmpty).toList();
    final queryParameters = <String, String>{
      'page[limit]': limit.toString(),
      'page[offset]': ((page - 1).clamp(0, 99999) * limit).toString(),
      'sort': _kitsuSort(sort),
      'include': 'categories',
    };
    final searchText = _blankToNull(query);
    if (searchText != null) {
      queryParameters['filter[text]'] = searchText;
    }
    if (categories.isNotEmpty) {
      queryParameters['filter[categories]'] = categories.join(',');
    }

    final path = mediaType == AniListMediaType.anime
        ? '/api/edge/anime'
        : '/api/edge/manga';
    final data = await _getJson(
      Uri.https('kitsu.io', path, queryParameters),
      headers: _kitsuHeaders(),
      providerName: 'Kitsu',
    );
    final categoriesById = _kitsuIncludedCategories(data);
    return ((data['data'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map((item) => _kitsuMediaFromJson(item, mediaType, categoriesById))
        .toList();
  }

  Future<List<AniListMedia>> _malCurrentSeason() {
    final now = DateTime.now();
    final season = _seasonForMonth(now.month).toLowerCase();
    final uri = Uri.https(
      'api.myanimelist.net',
      '/v2/anime/season/${now.year}/$season',
      {
        'limit': '50',
        'offset': '0',
        'fields': _malFields(AniListMediaType.anime),
      },
    );
    return _malList(uri, AniListMediaType.anime);
  }

  Future<List<AniListMedia>> _malSearch({
    required AniListMediaType mediaType,
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    List<String>? tags,
    List<String>? genres,
  }) {
    final searchText = _searchText(query, tags: tags, genres: genres);
    if (searchText == null) {
      return _malRanking(
        mediaType: mediaType,
        rankingType: _malRankingType(mediaType, sort),
        page: page,
        perPage: perPage,
      );
    }
    if (searchText.length < 3) {
      return Future.value(const <AniListMedia>[]);
    }

    final path = mediaType == AniListMediaType.anime
        ? '/v2/anime'
        : '/v2/manga';
    final uri = Uri.https('api.myanimelist.net', path, {
      'q': searchText,
      'limit': perPage.clamp(1, 100).toString(),
      'offset': ((page - 1).clamp(0, 99999) * perPage).toString(),
      'fields': _malFields(mediaType),
    });
    return _malList(uri, mediaType);
  }

  Future<List<AniListMedia>> _malRanking({
    required AniListMediaType mediaType,
    required String rankingType,
    int page = 1,
    int perPage = 50,
  }) {
    final path = mediaType == AniListMediaType.anime
        ? '/v2/anime/ranking'
        : '/v2/manga/ranking';
    final uri = Uri.https('api.myanimelist.net', path, {
      'ranking_type': rankingType,
      'limit': perPage.clamp(1, 100).toString(),
      'offset': ((page - 1).clamp(0, 99999) * perPage).toString(),
      'fields': _malFields(mediaType),
    });
    return _malList(uri, mediaType);
  }

  Future<List<AniListMedia>> _malList(
    Uri uri,
    AniListMediaType mediaType,
  ) async {
    final data = await _getJson(
      uri,
      headers: _malHeaders(),
      providerName: 'MyAnimeList',
    );
    return ((data['data'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map((item) => _asMap(item['node']))
        .whereType<Map<String, dynamic>>()
        .map((node) => _malMediaFromJson(node, mediaType))
        .toList();
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    required Map<String, String> headers,
    required String providerName,
  }) async {
    final response = await _client.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        '$providerName returned ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException('$providerName returned an invalid response');
  }

  Map<String, String> _malHeaders() {
    final account = _trackingService.accountFor(TrackingProvider.myAnimeList);
    if (account != null &&
        account.accessToken.isNotEmpty &&
        !account.authExpired) {
      return {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${account.accessToken}',
      };
    }

    return const {
      'Accept': 'application/json',
      'X-MAL-CLIENT-ID': TrackingService.myAnimeListClientId,
    };
  }

  Map<String, String> _kitsuHeaders() {
    final headers = <String, String>{
      'Accept': 'application/vnd.api+json',
      'Content-Type': 'application/vnd.api+json',
    };
    final account = _trackingService.accountFor(TrackingProvider.kitsu);
    if (account != null &&
        account.accessToken.isNotEmpty &&
        !account.authExpired) {
      headers['Authorization'] = 'Bearer ${account.accessToken}';
    }
    return headers;
  }

  static Map<String, String> _kitsuIncludedCategories(
    Map<String, dynamic> json,
  ) {
    final categories = <String, String>{};
    for (final item in ((json['included'] as List?) ?? const [])) {
      final map = _asMap(item);
      if (map == null || map['type'] != 'categories') {
        continue;
      }
      final id = readString(map, 'id');
      final attributes = _asMap(map['attributes']);
      final title = attributes == null
          ? null
          : firstNonBlank([
              readString(attributes, 'title'),
              readString(attributes, 'slug'),
            ]);
      if (id != null && title != null) {
        categories[id] = title;
      }
    }
    return categories;
  }

  static AniListMedia _kitsuMediaFromJson(
    Map<String, dynamic> json,
    AniListMediaType mediaType,
    Map<String, String> categoriesById,
  ) {
    final attributes = _asMap(json['attributes']) ?? const {};
    final titles = _asMap(attributes['titles']) ?? const {};
    final poster = _asMap(attributes['posterImage']);
    final cover = _asMap(attributes['coverImage']);
    final startDate = DateTime.tryParse(
      readString(attributes, 'startDate') ?? '',
    );
    final genres = _kitsuRelationshipIds(
      json,
      'categories',
    ).map((id) => categoriesById[id]).whereType<String>().toList();
    final slug = readString(attributes, 'slug');
    final pathSegment = mediaType == AniListMediaType.anime ? 'anime' : 'manga';
    final averageRating = readDouble(attributes, 'averageRating');
    final subtype = readString(attributes, 'subtype');

    return AniListMedia(
      id: int.tryParse(readString(json, 'id') ?? '') ?? 0,
      title: MediaTitle(
        romaji: firstNonBlank([
          readString(titles, 'en_jp'),
          readString(titles, 'en'),
        ]),
        english: readString(titles, 'en'),
        native: readString(titles, 'ja_jp'),
        userPreferred: firstNonBlank([
          readString(attributes, 'canonicalTitle'),
          readString(titles, 'en'),
          readString(titles, 'en_jp'),
        ]),
      ),
      cover: MediaCover(
        extraLarge: firstNonBlank([
          readString(poster ?? const {}, 'original'),
          readString(poster ?? const {}, 'large'),
        ]),
        large: readString(poster ?? const {}, 'large'),
      ),
      bannerImage: firstNonBlank([
        readString(cover ?? const {}, 'original'),
        readString(cover ?? const {}, 'large'),
      ]),
      description: stripHtml(readString(attributes, 'synopsis')),
      genres: genres,
      meanScore: averageRating?.round(),
      popularity: readInt(attributes, 'userCount'),
      episodes: mediaType == AniListMediaType.anime
          ? readInt(attributes, 'episodeCount')
          : null,
      chapters: mediaType == AniListMediaType.manga
          ? readInt(attributes, 'chapterCount')
          : null,
      volumes: mediaType == AniListMediaType.manga
          ? readInt(attributes, 'volumeCount')
          : null,
      duration: readInt(attributes, 'episodeLength'),
      status: readString(attributes, 'status')?.toUpperCase(),
      season: startDate == null ? null : _seasonForMonth(startDate.month),
      seasonYear: startDate?.year,
      format: subtype?.toUpperCase(),
      siteUrl: slug == null ? null : 'https://kitsu.io/$pathSegment/$slug',
      isAdult: attributes['nsfw'] == true,
      catalogProviderKey: TrackingProvider.kitsu.key,
    );
  }

  static AniListMedia _malMediaFromJson(
    Map<String, dynamic> json,
    AniListMediaType mediaType,
  ) {
    final id = readInt(json, 'id') ?? 0;
    final alternativeTitles = _asMap(json['alternative_titles']);
    final picture = _asMap(json['main_picture']);
    final startSeason = _asMap(json['start_season']);
    final genres = ((json['genres'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => readString(item, 'name'))
        .whereType<String>()
        .toList();
    final mean = readDouble(json, 'mean');
    final startDate = DateTime.tryParse(readString(json, 'start_date') ?? '');
    final durationSeconds = readInt(json, 'average_episode_duration');
    final pathSegment = mediaType == AniListMediaType.anime ? 'anime' : 'manga';
    final siteTitle = Uri.encodeComponent(readString(json, 'title') ?? '');

    return AniListMedia(
      id: id,
      idMal: id,
      title: MediaTitle(
        romaji: readString(json, 'title'),
        english: readString(alternativeTitles ?? const {}, 'en'),
        native: readString(alternativeTitles ?? const {}, 'ja'),
        userPreferred: readString(json, 'title'),
      ),
      cover: MediaCover(
        extraLarge: readString(picture ?? const {}, 'large'),
        large: firstNonBlank([
          readString(picture ?? const {}, 'large'),
          readString(picture ?? const {}, 'medium'),
        ]),
      ),
      description: stripHtml(readString(json, 'synopsis')),
      genres: genres,
      meanScore: mean == null ? null : (mean * 10).round(),
      popularity: readInt(json, 'num_list_users'),
      episodes: mediaType == AniListMediaType.anime
          ? readInt(json, 'num_episodes')
          : null,
      chapters: mediaType == AniListMediaType.manga
          ? readInt(json, 'num_chapters')
          : null,
      volumes: mediaType == AniListMediaType.manga
          ? readInt(json, 'num_volumes')
          : null,
      duration: durationSeconds == null || durationSeconds <= 0
          ? null
          : (durationSeconds / 60).round(),
      status: readString(json, 'status')?.toUpperCase(),
      season: readString(startSeason ?? const {}, 'season')?.toUpperCase(),
      seasonYear: readInt(startSeason ?? const {}, 'year') ?? startDate?.year,
      format: readString(json, 'media_type')?.toUpperCase(),
      siteUrl: 'https://myanimelist.net/$pathSegment/$id/$siteTitle',
      isAdult: (readString(json, 'rating') ?? '').toLowerCase().contains('rx'),
      catalogProviderKey: TrackingProvider.myAnimeList.key,
    );
  }

  static List<String> _kitsuRelationshipIds(
    Map<String, dynamic> json,
    String relationshipName,
  ) {
    final relationships = _asMap(json['relationships']);
    final relationship = _asMap(relationships?[relationshipName]);
    final data = relationship?['data'];
    if (data is! List) {
      return const [];
    }
    return data
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map((item) => readString(item, 'id'))
        .whereType<String>()
        .toList();
  }

  static String _malFields(AniListMediaType mediaType) {
    final baseFields = [
      'id',
      'title',
      'main_picture',
      'alternative_titles',
      'start_date',
      'synopsis',
      'mean',
      'rank',
      'popularity',
      'num_list_users',
      'media_type',
      'status',
      'genres',
    ];
    final kindFields = mediaType == AniListMediaType.anime
        ? ['num_episodes', 'start_season', 'average_episode_duration', 'rating']
        : ['num_chapters', 'num_volumes'];
    return [...baseFields, ...kindFields].join(',');
  }

  static String _malRankingType(
    AniListMediaType mediaType,
    List<String>? sort,
  ) {
    final sorts = sort ?? const <String>[];
    if (sorts.contains('POPULARITY_DESC')) {
      return 'bypopularity';
    }
    if (mediaType == AniListMediaType.anime &&
        (sorts.contains('TRENDING_DESC') ||
            sorts.contains('UPDATED_AT_DESC'))) {
      return 'airing';
    }
    return mediaType == AniListMediaType.anime ? 'all' : 'manga';
  }

  static String _kitsuSort(List<String>? sort) {
    final sorts = sort ?? const <String>[];
    if (sorts.contains('SCORE_DESC')) {
      return '-averageRating';
    }
    if (sorts.contains('UPDATED_AT_DESC')) {
      return '-updatedAt';
    }
    if (sorts.contains('TRENDING_DESC')) {
      return '-favoritesCount';
    }
    return '-userCount';
  }

  static String? _searchText(
    String? query, {
    List<String>? tags,
    List<String>? genres,
  }) {
    return firstNonBlank([query, ...?genres, ...?tags]);
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

  static String _kitsuCategorySlug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return null;
  }
}

const _kitsuGenres = [
  'Action',
  'Adventure',
  'Comedy',
  'Drama',
  'Fantasy',
  'Horror',
  'Magic',
  'Mecha',
  'Music',
  'Mystery',
  'Psychological',
  'Romance',
  'School',
  'Sci-Fi',
  'Slice of Life',
  'Sports',
  'Supernatural',
  'Thriller',
];
