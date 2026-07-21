import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/aniyomi_filters.dart';
import '../models/juro_models.dart';

class AniyomiPage<T> {
  const AniyomiPage({required this.items, required this.hasNextPage});

  static const empty = AniyomiPage<Never>(items: [], hasNextPage: false);

  final List<T> items;
  final bool hasNextPage;
}

enum AniyomiBrowseKind {
  popular('popular'),
  latest('latest');

  const AniyomiBrowseKind(this.wireName);

  final String wireName;
}

class AniyomiExtensionService {
  AniyomiExtensionService({
    MethodChannel? channel,
    @visibleForTesting bool? isAndroid,
  }) : _channel =
           channel ?? const MethodChannel('com.oneb.anikin/aniyomi_extensions'),
       _isAndroid = isAndroid ?? Platform.isAndroid;

  static const providerKeyPrefix = 'aniyomi:';
  static const mangaProviderKeyPrefix = 'aniyomi-manga:';
  static const extensionErrorCode = 'ANIYOMI_EXTENSION_ERROR';

  final MethodChannel _channel;
  final bool _isAndroid;

  bool get isPlatformSupported => _isAndroid;

  static bool isProviderKey(String providerKey) {
    return isAnimeProviderKey(providerKey) || isMangaProviderKey(providerKey);
  }

  static bool isAnimeProviderKey(String providerKey) {
    return providerKey.startsWith(providerKeyPrefix);
  }

  static bool isMangaProviderKey(String providerKey) {
    return providerKey.startsWith(mangaProviderKeyPrefix);
  }

  static String providerKeyForSourceId(Object sourceId, {int type = 0}) {
    return type == 1
        ? '$mangaProviderKeyPrefix$sourceId'
        : '$providerKeyPrefix$sourceId';
  }

  static bool isExtensionError(Object error) {
    return error is PlatformException && error.code == extensionErrorCode;
  }

  Future<bool> isSupported() async {
    if (!_isAndroid) {
      return false;
    }
    final supported = await _invoke<bool>('isSupported');
    return supported ?? false;
  }

  Future<List<SourceProvider>> getAnimeProviders() async {
    final value = await _invoke<Object?>('getAnimeProviders');
    return _readMapList(value).map(SourceProvider.fromJson).toList();
  }

  Future<List<SourceProvider>> getMangaProviders() async {
    final value = await _invoke<Object?>('getMangaProviders');
    return _readMapList(value).map(SourceProvider.fromJson).toList();
  }

  Future<List<String>> getRepos() async {
    final value = await _invoke<Object?>('getRepos');
    if (value is! List) {
      return const [];
    }
    return value.map((item) => item.toString()).toList();
  }

  Future<List<String>> addRepo(String url) async {
    final value = await _invoke<Object?>('addRepo', {'url': url});
    if (value is! List) {
      return const [];
    }
    return value.map((item) => item.toString()).toList();
  }

  Future<List<String>> removeRepo(String url) async {
    final value = await _invoke<Object?>('removeRepo', {'url': url});
    if (value is! List) {
      return const [];
    }
    return value.map((item) => item.toString()).toList();
  }

  Future<List<AniyomiExtensionInfo>> getAvailableExtensions() async {
    final value = await _invoke<Object?>('getAvailableExtensions');
    return _readMapList(value).map(AniyomiExtensionInfo.fromJson).toList();
  }

  Future<List<AniyomiExtensionInfo>> refreshAvailableExtensions() async {
    final value = await _invoke<Object?>('refreshAvailableExtensions');
    return _readMapList(value).map(AniyomiExtensionInfo.fromJson).toList();
  }

  Future<List<AniyomiExtensionInfo>> getInstalledExtensions() async {
    final value = await _invoke<Object?>('getInstalledExtensions');
    return _readMapList(value).map(AniyomiExtensionInfo.fromJson).toList();
  }

  Future<void> installExtension(String pkgName) async {
    await _invoke<Object?>('installExtension', {'pkgName': pkgName});
  }

  Future<void> updateExtension(String pkgName) async {
    await _invoke<Object?>('updateExtension', {'pkgName': pkgName});
  }

  Future<void> uninstallExtension(String pkgName) async {
    await _invoke<Object?>('uninstallExtension', {'pkgName': pkgName});
  }

  Future<AniyomiPage<JuroAnimeInfo>> searchAnime(
    String query, {
    required String providerKey,
    int page = 1,
    List<AniyomiFilterSelection>? filters,
  }) async {
    final value = await _invoke<Object?>('searchAnime', {
      'providerKey': providerKey,
      'query': query,
      'page': page,
      if (filters != null)
        'filters': filters.map((selection) => selection.toJson()).toList(),
    });
    return _readPage(value, JuroAnimeInfo.fromJson);
  }

  Future<AniyomiPage<JuroAnimeInfo>> browseAnime({
    required String providerKey,
    int page = 1,
    AniyomiBrowseKind kind = AniyomiBrowseKind.popular,
  }) async {
    final value = await _invoke<Object?>('browseAnime', {
      'providerKey': providerKey,
      'page': page,
      'kind': kind.wireName,
    });
    return _readPage(value, JuroAnimeInfo.fromJson);
  }

  Future<List<AniyomiFilter>> getFilters(String providerKey) async {
    final value = await _invoke<Object?>('getFilters', {
      'providerKey': providerKey,
    });
    return _readMapList(value).map(AniyomiFilter.fromJson).toList();
  }

  Future<void> openSourcePreferences(
    String providerKey, {
    String? sourceName,
  }) async {
    await _invoke<Object?>('openSourcePreferences', {
      'providerKey': providerKey,
      'sourceName': ?sourceName,
    });
  }

  Future<bool> getNsfwAllowed() async {
    final value = await _invoke<bool>('getNsfwAllowed');
    return value ?? true;
  }

  Future<void> setNsfwAllowed(bool allowed) async {
    await _invoke<Object?>('setNsfwAllowed', {'allowed': allowed});
  }

  Future<List<AnimeEpisode>> getEpisodes(
    String animeId, {
    required String providerKey,
  }) async {
    final value = await _invoke<Object?>('getEpisodes', {
      'providerKey': providerKey,
      'animeId': animeId,
    });
    return _readMapList(value).map(AnimeEpisode.fromJson).toList();
  }

  Future<List<VideoServer>> getVideoServers(
    String episodeId, {
    required String providerKey,
  }) async {
    final value = await _invoke<Object?>('getVideoServers', {
      'providerKey': providerKey,
      'episodeId': episodeId,
    });
    return _readMapList(value).map(VideoServer.fromJson).toList();
  }

  Future<List<VideoSource>> getVideos(
    String query, {
    required String providerKey,
  }) async {
    final value = await _invoke<Object?>('getVideos', {
      'providerKey': providerKey,
      'query': query,
    });
    return _readMapList(
      value,
    ).map(VideoSource.fromJson).where((source) => source.isPlayable).toList();
  }

  Future<AniyomiPage<MangaResult>> browseManga({
    required String providerKey,
    int page = 1,
    AniyomiBrowseKind kind = AniyomiBrowseKind.popular,
  }) async {
    final value = await _invoke<Object?>('browseManga', {
      'providerKey': providerKey,
      'page': page,
      'kind': kind.wireName,
    });
    return _readPage(
      value,
      MangaResult.fromJson,
      where: (item) => item.id.isNotEmpty,
    );
  }

  Future<AniyomiPage<MangaResult>> searchManga(
    String query, {
    required String providerKey,
    int page = 1,
    List<AniyomiFilterSelection>? filters,
  }) async {
    final value = await _invoke<Object?>('searchManga', {
      'providerKey': providerKey,
      'query': query,
      'page': page,
      if (filters != null)
        'filters': filters.map((selection) => selection.toJson()).toList(),
    });
    return _readPage(
      value,
      MangaResult.fromJson,
      where: (item) => item.id.isNotEmpty,
    );
  }

  Future<MangaInfo?> getMangaInfo(
    String mangaId, {
    required String providerKey,
  }) async {
    final value = await _invoke<Object?>('getMangaInfo', {
      'providerKey': providerKey,
      'mangaId': mangaId,
    });
    if (value is! Map) return null;
    return MangaInfo.fromJson(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<List<MangaChapterPage>> getChapterPages(
    String chapterId, {
    required String providerKey,
  }) async {
    final value = await _invoke<Object?>('getChapterPages', {
      'providerKey': providerKey,
      'chapterId': chapterId,
    });
    return _readMapList(value)
        .map(MangaChapterPage.fromJson)
        .where((page) => page.image.isNotEmpty)
        .toList()
      ..sort((a, b) => a.page.compareTo(b.page));
  }

  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!_isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error, stackTrace) {
      if (isExtensionError(error)) {
        _logExtensionError(method, error, stackTrace);
      }
      rethrow;
    }
  }

  void _logExtensionError(
    String method,
    PlatformException error,
    StackTrace stackTrace,
  ) {
    final buffer = StringBuffer()
      ..writeln('$extensionErrorCode while calling $method')
      ..writeln('Message: ${error.message ?? error}')
      ..writeln('Dart stack trace:')
      ..writeln(stackTrace);
    final details = error.details;
    if (details != null) {
      buffer
        ..writeln('Native details:')
        ..writeln(details);
    }
    debugPrint(buffer.toString());
  }

  List<Map<String, dynamic>> _readMapList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  AniyomiPage<T> _readPage<T>(
    Object? value,
    T Function(Map<String, dynamic> json) fromJson, {
    bool Function(T item)? where,
  }) {
    if (value is! Map) {
      return AniyomiPage<T>(items: const [], hasNextPage: false);
    }
    final items = _readMapList(
      value['items'],
    ).map(fromJson).where((item) => where?.call(item) ?? true).toList();
    return AniyomiPage<T>(
      items: items,
      hasNextPage: value['hasNextPage'] == true,
    );
  }
}

class AniyomiExtensionInfo {
  const AniyomiExtensionInfo({
    required this.name,
    required this.pkgName,
    required this.versionName,
    required this.versionCode,
    required this.libVersion,
    this.lang,
    this.isNsfw = false,
    this.apkName,
    this.repoUrl,
    this.iconUrl,
    this.signatureHash,
    this.sources = const [],
    this.isInstalled = false,
    this.hasUpdate = false,
    this.installLocation,
    this.isPrivate = false,
    this.type = 0,
    this.mediaType = 'anime',
  });

  final String name;
  final String pkgName;
  final String versionName;
  final int versionCode;
  final double libVersion;
  final String? lang;
  final bool isNsfw;
  final String? apkName;
  final String? repoUrl;
  final String? iconUrl;
  final String? signatureHash;
  final List<AniyomiExtensionSourceInfo> sources;
  final bool isInstalled;
  final bool hasUpdate;
  final String? installLocation;
  final bool isPrivate;
  final int type;
  final String mediaType;

  bool get isAnime => type == 0 || mediaType == 'anime';
  bool get isManga => type == 1 || mediaType == 'manga';

  String? get installLocationLabel => switch (installLocation) {
    'system' => 'System installed',
    'private' => 'Private fallback',
    _ => null,
  };

  String get displaySubtitle {
    final sourceCount = sources.length;
    return [
      if (lang != null && lang!.isNotEmpty) lang!.toUpperCase(),
      versionName,
      if (isInstalled && installLocationLabel != null) installLocationLabel!,
      if (sourceCount > 0) '$sourceCount source${sourceCount == 1 ? '' : 's'}',
      if (isNsfw) 'NSFW',
    ].join(' • ');
  }

  factory AniyomiExtensionInfo.fromJson(Map<String, dynamic> json) {
    final sources = json['sources'];
    return AniyomiExtensionInfo(
      name: _readString(json, 'name') ?? 'Unknown extension',
      pkgName: _readString(json, 'pkgName') ?? '',
      versionName: _readString(json, 'versionName') ?? '',
      versionCode: _readInt(json, 'versionCode') ?? 0,
      libVersion: _readDouble(json, 'libVersion') ?? 0,
      lang: _readString(json, 'lang'),
      isNsfw: _readBool(json, 'isNsfw'),
      apkName: _readString(json, 'apkName'),
      repoUrl: _readString(json, 'repoUrl'),
      iconUrl: _readString(json, 'iconUrl'),
      signatureHash: _readString(json, 'signatureHash'),
      sources: sources is List
          ? sources
                .whereType<Map>()
                .map(
                  (item) => AniyomiExtensionSourceInfo.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList()
          : const [],
      isInstalled: _readBool(json, 'isInstalled'),
      hasUpdate: _readBool(json, 'hasUpdate'),
      installLocation: _readString(json, 'installLocation'),
      isPrivate: _readBool(json, 'isPrivate'),
      type: _readInt(json, 'type') ?? 0,
      mediaType: _readString(json, 'mediaType') ?? 'anime',
    );
  }
}

class AniyomiExtensionSourceInfo {
  const AniyomiExtensionSourceInfo({
    required this.id,
    required this.key,
    required this.name,
    required this.language,
    this.type = 0,
    this.mediaType = 'anime',
    this.baseUrl,
  });

  final int id;
  final String key;
  final String name;
  final String language;
  final int type;
  final String mediaType;
  final String? baseUrl;

  bool get isAnime => type == 0 || mediaType == 'anime';
  bool get isManga => type == 1 || mediaType == 'manga';

  factory AniyomiExtensionSourceInfo.fromJson(Map<String, dynamic> json) {
    final id = _readInt(json, 'id') ?? 0;
    return AniyomiExtensionSourceInfo(
      id: id,
      key:
          _readString(json, 'key') ??
          AniyomiExtensionService.providerKeyForSourceId(
            id,
            type: _readInt(json, 'type') ?? 0,
          ),
      name: _readString(json, 'name') ?? 'Unknown source',
      language:
          _readString(json, 'language') ?? _readString(json, 'lang') ?? 'en',
      type: _readInt(json, 'type') ?? 0,
      mediaType: _readString(json, 'mediaType') ?? 'anime',
      baseUrl: _readString(json, 'baseUrl'),
    );
  }
}

String? _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int? _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _readDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool _readBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value?.toString().toLowerCase() == 'true';
}
