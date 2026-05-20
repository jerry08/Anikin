import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import '../models/juro_models.dart';
import 'anilist_service.dart';

class JuroService {
  JuroService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = _normalizeBaseUrl(baseUrl ?? AppConstants.juroApiBaseUrl);

  final http.Client _client;
  final String? _baseUrl;

  Future<List<SourceProvider>> getProviders() async {
    final uri = _uri('Providers', queryParameters: {'type': '0'});
    final json = await _getList(uri);
    return json
        .whereType<Map<String, dynamic>>()
        .map(SourceProvider.fromJson)
        .toList();
  }

  Future<List<SourceProvider>> getMangaProviders() async {
    final uri = _uri('Providers', queryParameters: {'type': '1'});
    final json = await _getList(uri);
    return json
        .whereType<Map<String, dynamic>>()
        .map(SourceProvider.fromJson)
        .toList();
  }

  Future<List<JuroAnimeInfo>> searchAnime(
    String query, {
    required String providerKey,
  }) async {
    final uri = _uri('$providerKey/Search', queryParameters: {'query': query});
    final json = await _getList(uri);
    return json
        .whereType<Map<String, dynamic>>()
        .map(JuroAnimeInfo.fromJson)
        .toList();
  }

  Future<List<AnimeEpisode>> getEpisodes(
    String animeId, {
    required String providerKey,
  }) async {
    final uri = _uri('$providerKey/Episodes/${Uri.encodeComponent(animeId)}');
    final json = await _getList(uri);
    return json
        .whereType<Map<String, dynamic>>()
        .map(AnimeEpisode.fromJson)
        .toList();
  }

  Future<List<VideoServer>> getVideoServers(
    String episodeId, {
    required String providerKey,
  }) async {
    final uri = _uri(
      '$providerKey/VideoServers/${Uri.encodeComponent(episodeId)}',
    );
    final json = await _getList(uri);
    return json
        .whereType<Map<String, dynamic>>()
        .map(VideoServer.fromJson)
        .toList();
  }

  Future<List<VideoSource>> getVideos(
    String query, {
    required String providerKey,
  }) async {
    final uri = _uri('$providerKey/Videos', queryParameters: {'q': query});
    final json = await _getList(uri);
    return json
        .whereType<Map<String, dynamic>>()
        .map(VideoSource.fromJson)
        .where((source) => source.isPlayable)
        .toList();
  }

  Future<VideoSource?> getPreferredVideo(
    AnimeEpisode episode, {
    required String providerKey,
  }) async {
    final servers = await getVideoServers(episode.id, providerKey: providerKey);
    if (servers.isEmpty) {
      final fallback = await getVideos(episode.id, providerKey: providerKey);
      return fallback.isEmpty ? null : fallback.first;
    }

    final server = servers.firstWhere((item) {
      final name = item.name.toLowerCase();
      return name.contains('streamsb') ||
          name.contains('vidstream') ||
          name == 'mirror';
    }, orElse: () => servers.first);

    final videos = await getVideos(server.embed.url, providerKey: providerKey);
    return videos.isEmpty ? null : videos.first;
  }

  Future<List<MangaResult>> searchManga(
    String query, {
    required String providerKey,
  }) async {
    final uri = _uri('$providerKey/Search', queryParameters: {'q': query});
    final json = await _getList(uri);
    return json
        .whereType<Map<String, dynamic>>()
        .map(MangaResult.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<MangaInfo> getMangaInfo(
    String mangaId, {
    required String providerKey,
  }) async {
    final uri = _uri('$providerKey/${Uri.encodeComponent(mangaId)}');
    final json = await _getMap(uri);
    return MangaInfo.fromJson(json);
  }

  Future<List<MangaChapterPage>> getChapterPages(
    String chapterId, {
    required String providerKey,
  }) async {
    final uri = _uri(
      '$providerKey/ChapterPages/${Uri.encodeComponent(chapterId)}',
    );
    final json = await _getList(uri);
    return json
        .whereType<Map<String, dynamic>>()
        .map(MangaChapterPage.fromJson)
        .where((page) => page.image.isNotEmpty)
        .toList()
      ..sort((a, b) => a.page.compareTo(b.page));
  }

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      throw const ApiException(
        'Missing JURO_API_BASE_URL. Run Flutter with '
        '--dart-define=JURO_API_BASE_URL=<url> or '
        '--dart-define-from-file=env/juro.local.json.',
      );
    }
    return Uri.parse(
      '$baseUrl/$path',
    ).replace(queryParameters: queryParameters);
  }

  static String? _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  Future<List<Object?>> _getList(Uri uri) async {
    final response = await _client.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Juro returned ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded;
    }
    throw const ApiException('Unexpected Juro response shape');
  }

  Future<Map<String, dynamic>> _getMap(Uri uri) async {
    final response = await _client.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Juro returned ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Unexpected Juro response shape');
  }
}
