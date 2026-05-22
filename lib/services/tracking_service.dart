import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_constants.dart';
import '../models/anilist_media.dart';
import '../models/tracking.dart';

class TrackingService extends ChangeNotifier {
  TrackingService({
    http.Client? client,
    AppLinks? appLinks,
    bool listenForLinks = true,
  }) : _client = client ?? http.Client(),
       _appLinks = appLinks ?? AppLinks(),
       _listenForLinks = listenForLinks;

  static const _anikinAniListClientId = '14733';
  static const _myAnimeListClientId = 'aeba28135e9a1c1e2dc92113e75fa318';
  static const _kitsuClientId =
      'dd031b32d2f56c990b1425efe6c42ad847e7fe3ab46bf1299f05ecd856bdb7dd';
  static const _kitsuClientSecret =
      '54d7307928f63414defd96399fc31ba847961ceaecef3a5fd93144e960c0e151';

  static const _accountPrefix = 'tracking.account.';
  static const _primaryProviderKey = 'tracking.primaryProvider';
  static const _syncStrategyKey = 'tracking.syncStrategy';
  static const _progressSyncEnabledKey = 'tracking.progressSyncEnabled';
  static const _pendingUpdatesKey = 'tracking.pendingUpdates';
  static const _malCodeVerifierKey = 'tracking.malCodeVerifier';

  static const _aniListMediaFields = r'''
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

  static const _aniListMediaListEntryFields = r'''
id
status
score
progress
progressVolumes
repeat
private
notes
startedAt { year month day }
completedAt { year month day }
updatedAt
media { MEDIA_FIELDS }
''';

  final http.Client _client;
  final AppLinks _appLinks;
  final bool _listenForLinks;
  StreamSubscription<Uri>? _linkSubscription;
  SharedPreferences? _prefs;
  final Map<TrackingProvider, TrackingAccount> _accounts = {};
  final List<PendingTrackingUpdate> _pendingUpdates = [];

  TrackingProvider primaryProvider = TrackingProvider.anilist;
  TrackingSyncStrategy syncStrategy = TrackingSyncStrategy.primaryThenFallback;
  bool progressSyncEnabled = true;
  String? lastMessage;

  bool get hasLoggedInProvider => _accounts.values.any((account) {
    return account.accessToken.isNotEmpty && !account.authExpired;
  });

  int get pendingUpdateCount => _pendingUpdates.length;

  TrackingAccount? accountFor(TrackingProvider provider) => _accounts[provider];

  bool isLoggedIn(TrackingProvider provider) {
    final account = _accounts[provider];
    return account != null &&
        account.accessToken.isNotEmpty &&
        !account.authExpired;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;

    _accounts.clear();
    for (final provider in TrackingProvider.values) {
      final raw = prefs.getString('$_accountPrefix${provider.key}');
      if (raw == null || raw.isEmpty) {
        continue;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final account = TrackingAccount.fromJson(decoded);
        _accounts[provider] = account;
      } else if (decoded is Map) {
        final account = TrackingAccount.fromJson(decoded.cast());
        _accounts[provider] = account;
      }
    }

    primaryProvider =
        TrackingProvider.fromKey(prefs.getString(_primaryProviderKey)) ??
        TrackingProvider.anilist;
    syncStrategy =
        TrackingSyncStrategy.values[(prefs.getInt(_syncStrategyKey) ??
                TrackingSyncStrategy.primaryThenFallback.index)
            .clamp(0, TrackingSyncStrategy.values.length - 1)
            .toInt()];
    progressSyncEnabled = prefs.getBool(_progressSyncEnabledKey) ?? true;
    _pendingUpdates
      ..clear()
      ..addAll(
        decodePendingTrackingUpdates(prefs.getString(_pendingUpdatesKey)),
      );

    if (_listenForLinks) {
      _linkSubscription ??= _appLinks.uriLinkStream.listen(
        (uri) => unawaited(handleIncomingLink(uri)),
      );
      try {
        final initialLink = await _appLinks.getInitialLink();
        if (initialLink != null) {
          await handleIncomingLink(initialLink);
        }
      } catch (_) {}
    }

    unawaited(retryPendingUpdates());
    notifyListeners();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _client.close();
    super.dispose();
  }

  Future<void> setPrimaryProvider(TrackingProvider provider) async {
    primaryProvider = provider;
    await _prefs!.setString(_primaryProviderKey, provider.key);
    notifyListeners();
  }

  Future<void> setSyncStrategy(TrackingSyncStrategy value) async {
    syncStrategy = value;
    await _prefs!.setInt(_syncStrategyKey, value.index);
    notifyListeners();
  }

  Future<void> setProgressSyncEnabled(bool value) async {
    progressSyncEnabled = value;
    await _prefs!.setBool(_progressSyncEnabledKey, value);
    notifyListeners();
  }

  Future<void> loginWithBrowser(TrackingProvider provider) async {
    final uri = await authorizationUri(provider);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw TrackingException('Could not open ${provider.label} login');
    }
  }

  Future<Uri> authorizationUri(TrackingProvider provider) async {
    switch (provider) {
      case TrackingProvider.anilist:
        final clientId = _anikinAniListClientId;
        return Uri.https('anilist.co', '/api/v2/oauth/authorize', {
          'client_id': clientId,
          'response_type': 'token',
        });
      case TrackingProvider.myAnimeList:
        final verifier = _createCodeVerifier();
        await _prefs!.setString(_malCodeVerifierKey, verifier);
        return Uri.https('myanimelist.net', '/v1/oauth2/authorize', {
          'client_id': _myAnimeListClientId,
          'code_challenge': verifier,
          'response_type': 'code',
        });
      case TrackingProvider.kitsu:
        throw const TrackingException('Kitsu uses email and password login');
    }
  }

  Future<void> handleIncomingLink(Uri uri) async {
    final host = uri.host.toLowerCase();
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'anistream' && host == 'anilist') {
      await _loginAniListFromFragment(uri.fragment);
      return;
    }
    if (host == 'anilist-auth') {
      await _loginAniListFromFragment(uri.fragment);
      return;
    }
    if (host == 'myanimelist-auth') {
      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        await logout(TrackingProvider.myAnimeList);
        return;
      }
      await loginMyAnimeListCode(code);
    }
  }

  Future<void> loginKitsu({
    required String username,
    required String password,
  }) async {
    final token =
        await _postForm(Uri.parse('https://kitsu.app/api/oauth/token'), {
          'username': username,
          'password': password,
          'grant_type': 'password',
          'client_id': _kitsuClientId,
          'client_secret': _kitsuClientSecret,
        });
    final accessToken = token['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw const TrackingException('Kitsu did not return an access token');
    }

    final createdAtSeconds =
        (token['created_at'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresInSeconds = (token['expires_in'] as num?)?.toInt();
    final user = await _kitsuCurrentUser(accessToken);
    await _saveAccount(
      TrackingAccount(
        provider: TrackingProvider.kitsu,
        accessToken: accessToken,
        refreshToken: token['refresh_token']?.toString(),
        username: user.name ?? username,
        userId: user.id,
        expiresAtMs: expiresInSeconds == null
            ? null
            : (createdAtSeconds + expiresInSeconds) * 1000,
      ),
    );
    lastMessage = 'Logged in to Kitsu';
  }

  Future<void> loginMyAnimeListCode(String code) async {
    final verifier = _prefs!.getString(_malCodeVerifierKey);
    if (verifier == null || verifier.isEmpty) {
      throw const TrackingException('Missing MAL login verifier');
    }

    final token =
        await _postForm(Uri.parse('https://myanimelist.net/v1/oauth2/token'), {
          'client_id': _myAnimeListClientId,
          'code': code,
          'code_verifier': verifier,
          'grant_type': 'authorization_code',
        });
    final accessToken = token['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw const TrackingException('MAL did not return an access token');
    }
    final expiresInSeconds = (token['expires_in'] as num?)?.toInt();
    final username = await _malCurrentUser(accessToken);
    await _saveAccount(
      TrackingAccount(
        provider: TrackingProvider.myAnimeList,
        accessToken: accessToken,
        refreshToken: token['refresh_token']?.toString(),
        username: username,
        expiresAtMs: expiresInSeconds == null
            ? null
            : DateTime.now().millisecondsSinceEpoch + expiresInSeconds * 1000,
      ),
    );
    await _prefs!.remove(_malCodeVerifierKey);
    lastMessage = 'Logged in to MyAnimeList';
  }

  Future<void> logout(TrackingProvider provider) async {
    _accounts.remove(provider);
    await _prefs!.remove('$_accountPrefix${provider.key}');
    lastMessage = 'Logged out of ${provider.label}';
    notifyListeners();
  }

  Future<bool> isAniListFavorite({
    required AniListMedia media,
    required TrackingMediaKind kind,
  }) async {
    final account = _requireAccount(TrackingProvider.anilist);
    final data = await _postAniList(
      account,
      r'''
query FavoriteState($id: Int) {
  Media(id: $id) { isFavourite }
}
''',
      {'id': media.id},
    );
    return data['Media']?['isFavourite'] == true;
  }

  Future<List<AniListMedia>> favoriteMedia(TrackingMediaKind kind) async {
    final account = _requireAccount(TrackingProvider.anilist);
    final isAnime = kind == TrackingMediaKind.anime;
    final data = await _postAniList(
      account,
      isAnime
          ? r'''
query FavoriteAnime {
  Viewer {
    favourites {
      anime(page: 1, perPage: 50) {
        nodes {
          id
          idMal
          title { romaji english native userPreferred }
          coverImage { extraLarge large color }
          bannerImage
          description
          genres
          meanScore
          popularity
          episodes
          duration
          status
          season
          seasonYear
          format
          countryOfOrigin
          siteUrl
        }
      }
    }
  }
}
'''
          : r'''
query FavoriteManga {
  Viewer {
    favourites {
      manga(page: 1, perPage: 50) {
        nodes {
          id
          title { romaji english native userPreferred }
          coverImage { extraLarge large color }
          bannerImage
          description
          genres
          meanScore
          popularity
          chapters
          volumes
          status
          format
          countryOfOrigin
          siteUrl
        }
      }
    }
  }
}
''',
      const {},
    );
    final bucket = isAnime ? 'anime' : 'manga';
    final nodes = data['Viewer']?['favourites']?[bucket]?['nodes'];
    if (nodes is! List) {
      return const [];
    }
    return nodes
        .whereType<Map>()
        .map((item) => AniListMedia.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<AniListMediaListCollection> aniListMediaListCollection() async {
    final results = await Future.wait([
      aniListMediaList(TrackingMediaKind.anime),
      aniListMediaList(TrackingMediaKind.manga),
    ]);
    return AniListMediaListCollection(anime: results[0], manga: results[1]);
  }

  Future<List<AniListMediaListEntry>> aniListMediaList(
    TrackingMediaKind kind,
  ) async {
    final account = _requireAccount(TrackingProvider.anilist);
    final userId = int.tryParse(account.userId ?? '');
    final userName = account.username;
    if (userId == null && (userName == null || userName.isEmpty)) {
      throw const TrackingException('AniList account is missing a user id');
    }

    final data = await _postAniList(
      account,
      r'''
query UserMediaList($userId: Int, $userName: String, $type: MediaType) {
  MediaListCollection(
    userId: $userId,
    userName: $userName,
    type: $type,
    forceSingleCompletedList: true
  ) {
    lists {
      entries {
        id
        status
        score
        progress
        progressVolumes
        repeat
        private
        notes
        startedAt { year month day }
        completedAt { year month day }
        updatedAt
        media { MEDIA_FIELDS }
      }
    }
  }
}
'''
          .replaceAll('MEDIA_FIELDS', _aniListMediaFields),
      {
        'userId': userId,
        'userName': userName,
        'type': kind == TrackingMediaKind.anime ? 'ANIME' : 'MANGA',
      },
    );

    final listGroups = data['MediaListCollection']?['lists'];
    if (listGroups is! List) {
      return const [];
    }

    final entries = <AniListMediaListEntry>[];
    for (final group in listGroups.whereType<Map>()) {
      final groupEntries = group['entries'];
      if (groupEntries is! List) {
        continue;
      }
      for (final entryJson in groupEntries.whereType<Map>()) {
        final entry = AniListMediaListEntry.fromJson(
          entryJson.cast<String, dynamic>(),
          kind,
        );
        if (entry != null) {
          entries.add(entry);
        }
      }
    }
    entries.sort((a, b) => (b.updatedAtMs ?? 0).compareTo(a.updatedAtMs ?? 0));
    return entries;
  }

  Future<AniListMediaListEntry?> aniListMediaListEntry({
    required AniListMedia media,
    required TrackingMediaKind kind,
  }) async {
    final account = _requireAccount(TrackingProvider.anilist);
    final data = await _postAniList(
      account,
      r'''
query MediaListEntry($mediaId: Int) {
  Media(id: $mediaId) {
    mediaListEntry { ENTRY_FIELDS }
  }
}
'''
          .replaceAll('ENTRY_FIELDS', _aniListMediaListEntryFields)
          .replaceAll('MEDIA_FIELDS', _aniListMediaFields),
      {'mediaId': media.id},
    );
    final entryJson = data['Media']?['mediaListEntry'];
    if (entryJson is! Map) {
      return null;
    }
    return AniListMediaListEntry.fromJson(
      entryJson.cast<String, dynamic>(),
      kind,
      fallbackMedia: media,
    );
  }

  Future<AniListMediaListEntry> saveAniListMediaListEntry(
    AniListMediaListSaveRequest request,
  ) async {
    final account = _requireAccount(TrackingProvider.anilist);
    final data = await _postAniList(
      account,
      r'''
mutation SaveListEntry(
  $mediaId: Int,
  $status: MediaListStatus,
  $progress: Int,
  $progressVolumes: Int,
  $score: Float,
  $repeat: Int,
  $private: Boolean,
  $notes: String,
  $startedAt: FuzzyDateInput,
  $completedAt: FuzzyDateInput
) {
  SaveMediaListEntry(
    mediaId: $mediaId,
    status: $status,
    progress: $progress,
    progressVolumes: $progressVolumes,
    score: $score,
    repeat: $repeat,
    private: $private,
    notes: $notes,
    startedAt: $startedAt,
    completedAt: $completedAt
  ) { ENTRY_FIELDS }
}
'''
          .replaceAll('ENTRY_FIELDS', _aniListMediaListEntryFields)
          .replaceAll('MEDIA_FIELDS', _aniListMediaFields),
      {
        'mediaId': request.media.id,
        'status': request.status.graphqlName,
        'progress': request.progress,
        'progressVolumes': request.progressVolumes,
        'score': request.score,
        'repeat': request.repeat,
        'private': request.private,
        'notes': _blankToNull(request.notes),
        'startedAt': AniListFuzzyDate.fromDateTime(request.startedAt)?.toJson(),
        'completedAt': AniListFuzzyDate.fromDateTime(
          request.completedAt,
        )?.toJson(),
      },
    );
    final entryJson = data['SaveMediaListEntry'];
    if (entryJson is! Map) {
      throw const TrackingException('AniList did not return a saved entry');
    }
    final entry = AniListMediaListEntry.fromJson(
      entryJson.cast<String, dynamic>(),
      request.kind,
      fallbackMedia: request.media,
    );
    if (entry == null) {
      throw const TrackingException('AniList returned an invalid list entry');
    }
    lastMessage = 'Updated ${request.media.displayTitle} on AniList';
    notifyListeners();
    return entry;
  }

  Future<void> deleteAniListMediaListEntry(int entryId) async {
    final account = _requireAccount(TrackingProvider.anilist);
    final data = await _postAniList(
      account,
      r'''
mutation DeleteListEntry($id: Int) {
  DeleteMediaListEntry(id: $id) { deleted }
}
''',
      {'id': entryId},
    );
    if (data['DeleteMediaListEntry']?['deleted'] != true) {
      throw const TrackingException('AniList did not delete the list entry');
    }
    lastMessage = 'Removed AniList list entry';
    notifyListeners();
  }

  Future<bool> toggleAniListFavorite({
    required AniListMedia media,
    required TrackingMediaKind kind,
  }) async {
    final account = _requireAccount(TrackingProvider.anilist);
    final isAnime = kind == TrackingMediaKind.anime;
    final data = await _postAniList(
      account,
      isAnime
          ? r'''
mutation ToggleAnimeFavorite($animeId: Int) {
  ToggleFavourite(animeId: $animeId) {
    anime { nodes { id } }
  }
}
'''
          : r'''
mutation ToggleMangaFavorite($mangaId: Int) {
  ToggleFavourite(mangaId: $mangaId) {
    manga { nodes { id } }
  }
}
''',
      {isAnime ? 'animeId' : 'mangaId': media.id},
    );
    final bucket = isAnime ? 'anime' : 'manga';
    final nodes = data['ToggleFavourite']?[bucket]?['nodes'];
    return nodes is List &&
        nodes.any((item) => item is Map && item['id'] == media.id);
  }

  Future<bool> syncEpisodeProgress({
    required AniListMedia media,
    required double episodeNumber,
    required double watchedPercentage,
  }) async {
    if (!progressSyncEnabled || watchedPercentage < 92) {
      return false;
    }
    final progress = episodeNumber.floor();
    if (progress <= 0) {
      return false;
    }
    return syncProgress(
      TrackingProgressRequest(
        media: media,
        kind: TrackingMediaKind.anime,
        progress: progress,
        total: media.episodes,
      ),
      queueOnFailure: true,
    );
  }

  Future<bool> syncProgress(
    TrackingProgressRequest request, {
    bool queueOnFailure = true,
  }) async {
    final providers = _syncProviders();
    if (providers.isEmpty) {
      return false;
    }

    var attempted = false;
    var synced = false;
    for (final provider in providers) {
      if (!isLoggedIn(provider)) {
        continue;
      }
      if (await _alreadySynced(provider, request)) {
        synced = true;
        if (syncStrategy == TrackingSyncStrategy.primaryThenFallback) {
          break;
        }
        continue;
      }
      attempted = true;
      try {
        await _syncProviderProgress(provider, request);
        await _markSynced(provider, request);
        synced = true;
        lastMessage =
            '${provider.label} synced ${request.title} to ${request.progress}';
        if (syncStrategy == TrackingSyncStrategy.primaryThenFallback) {
          break;
        }
      } catch (error) {
        debugPrint('Tracking sync failed for ${provider.label}: $error');
        if (syncStrategy == TrackingSyncStrategy.allLoggedIn) {
          continue;
        }
      }
    }

    if (!synced && attempted && queueOnFailure) {
      await _queuePendingUpdate(request);
    }
    if (synced) {
      await _removePendingUpdate(request);
    }
    notifyListeners();
    return synced;
  }

  Future<void> retryPendingUpdates() async {
    if (_pendingUpdates.isEmpty || !hasLoggedInProvider) {
      return;
    }

    final pending = List<PendingTrackingUpdate>.of(_pendingUpdates);
    for (final update in pending) {
      final synced = await syncProgress(update.request, queueOnFailure: false);
      if (synced) {
        _pendingUpdates.remove(update);
      } else {
        final index = _pendingUpdates.indexOf(update);
        if (index >= 0) {
          _pendingUpdates[index] = update.copyWith(
            attempts: update.attempts + 1,
          );
        }
      }
    }
    await _persistPendingUpdates();
    notifyListeners();
  }

  Future<void> _loginAniListFromFragment(String fragment) async {
    final params = Uri.splitQueryString(fragment);
    final token = params['access_token'];
    if (token == null || token.isEmpty) {
      await logout(TrackingProvider.anilist);
      return;
    }
    final expiresInSeconds = int.tryParse(params['expires_in'] ?? '');
    final data = await _postAniList(
      TrackingAccount(provider: TrackingProvider.anilist, accessToken: token),
      r'''
query ViewerName {
  Viewer { id name }
}
''',
      const {},
    );
    final viewer = data['Viewer'];
    await _saveAccount(
      TrackingAccount(
        provider: TrackingProvider.anilist,
        accessToken: token,
        username: viewer?['name']?.toString(),
        userId: viewer?['id']?.toString(),
        expiresAtMs: expiresInSeconds == null
            ? DateTime.now().millisecondsSinceEpoch + 31536000000
            : DateTime.now().millisecondsSinceEpoch + expiresInSeconds * 1000,
      ),
    );
    lastMessage = 'Logged in to AniList';
  }

  Future<void> _saveAccount(TrackingAccount account) async {
    _accounts[account.provider] = account;
    await _prefs!.setString(
      '$_accountPrefix${account.provider.key}',
      jsonEncode(account.toJson()),
    );
    notifyListeners();
  }

  TrackingAccount _requireAccount(TrackingProvider provider) {
    final account = _accounts[provider];
    if (account == null || account.accessToken.isEmpty) {
      throw TrackingException('Login to ${provider.label} first');
    }
    if (account.authExpired) {
      throw TrackingException('${provider.label} login expired');
    }
    return account;
  }

  List<TrackingProvider> _syncProviders() {
    final providers = <TrackingProvider>[
      primaryProvider,
      ...TrackingProvider.values.where(
        (provider) => provider != primaryProvider,
      ),
    ];
    return syncStrategy == TrackingSyncStrategy.allLoggedIn
        ? providers.where(isLoggedIn).toList()
        : providers;
  }

  Future<void> _syncProviderProgress(
    TrackingProvider provider,
    TrackingProgressRequest request,
  ) async {
    switch (provider) {
      case TrackingProvider.anilist:
        await _syncAniListProgress(request);
      case TrackingProvider.myAnimeList:
        await _syncMyAnimeListProgress(request);
      case TrackingProvider.kitsu:
        await _syncKitsuProgress(request);
    }
  }

  Future<void> _syncAniListProgress(TrackingProgressRequest request) async {
    final account = _requireAccount(TrackingProvider.anilist);
    final completed =
        request.total != null &&
        request.total! > 0 &&
        request.progress >= request.total!;
    await _postAniList(
      account,
      r'''
mutation SyncProgress($mediaId: Int, $progress: Int, $status: MediaListStatus) {
  SaveMediaListEntry(mediaId: $mediaId, progress: $progress, status: $status) {
    id
    progress
    status
  }
}
''',
      {
        'mediaId': request.media.id,
        'progress': request.progress,
        'status': completed ? 'COMPLETED' : 'CURRENT',
      },
    );
  }

  Future<void> _syncMyAnimeListProgress(TrackingProgressRequest request) async {
    if (request.kind != TrackingMediaKind.anime) {
      throw const TrackingException('MAL manga sync is not wired yet');
    }
    final account = await _ensureMyAnimeListToken();
    final malId = await _resolveMalAnimeId(request.media);
    if (malId == null) {
      throw TrackingException('Could not match ${request.title} on MAL');
    }
    final completed =
        request.total != null &&
        request.total! > 0 &&
        request.progress >= request.total!;
    await _requestJson(
      'PUT',
      Uri.parse('https://api.myanimelist.net/v2/anime/$malId/my_list_status'),
      headers: {
        'Authorization': 'Bearer ${account.accessToken}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: _formEncode({
        'status': completed ? 'completed' : 'watching',
        'num_watched_episodes': request.progress.toString(),
      }),
    );
  }

  Future<void> _syncKitsuProgress(TrackingProgressRequest request) async {
    if (request.kind != TrackingMediaKind.anime) {
      throw const TrackingException('Kitsu manga sync is not wired yet');
    }
    final account = await _ensureKitsuToken();
    final userId = account.userId;
    if (userId == null || userId.isEmpty) {
      throw const TrackingException('Kitsu user id is missing');
    }
    final animeId = await _resolveKitsuAnimeId(request.media);
    if (animeId == null) {
      throw TrackingException('Could not match ${request.title} on Kitsu');
    }
    final completed =
        request.total != null &&
        request.total! > 0 &&
        request.progress >= request.total!;
    final entryId = await _kitsuLibraryEntryId(
      accessToken: account.accessToken,
      userId: userId,
      animeId: animeId,
    );
    if (entryId == null) {
      await _requestJson(
        'POST',
        Uri.parse('https://kitsu.app/api/edge/library-entries'),
        headers: _kitsuHeaders(account.accessToken),
        body: jsonEncode({
          'data': {
            'type': 'libraryEntries',
            'attributes': {
              'status': completed ? 'completed' : 'current',
              'progress': request.progress,
            },
            'relationships': {
              'user': {
                'data': {'id': userId, 'type': 'users'},
              },
              'media': {
                'data': {'id': animeId, 'type': 'anime'},
              },
            },
          },
        }),
      );
      return;
    }

    await _requestJson(
      'PATCH',
      Uri.parse('https://kitsu.app/api/edge/library-entries/$entryId'),
      headers: _kitsuHeaders(account.accessToken),
      body: jsonEncode({
        'data': {
          'type': 'libraryEntries',
          'id': entryId,
          'attributes': {
            'status': completed ? 'completed' : 'current',
            'progress': request.progress,
          },
        },
      }),
    );
  }

  Future<Map<String, dynamic>> _postAniList(
    TrackingAccount account,
    String query,
    Map<String, dynamic> variables,
  ) async {
    final response = await _client.post(
      Uri.parse(AppConstants.anilistGraphqlEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${account.accessToken}',
      },
      body: jsonEncode({'query': query, 'variables': variables}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrackingException(
        'AniList returned ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw TrackingException(
        errors.first['message']?.toString() ?? 'AniList request failed',
      );
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final request = http.Request(method, uri);
    request.headers.addAll(headers ?? const {});
    if (body != null) {
      request.body = body.toString();
    }
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TrackingException(
        '${uri.host} returned ${response.statusCode}: ${response.body}',
      );
    }
    if (response.body.isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast();
    }
    return const {};
  }

  Future<Map<String, dynamic>> _postForm(Uri uri, Map<String, String> fields) {
    return _requestJson(
      'POST',
      uri,
      headers: const {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: _formEncode(fields),
    );
  }

  static String? _blankToNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  Future<TrackingAccount> _ensureMyAnimeListToken() async {
    var account = _requireAccount(TrackingProvider.myAnimeList);
    if (!account.isExpired) {
      return account;
    }
    final refreshToken = account.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _markAuthExpired(TrackingProvider.myAnimeList);
      throw const TrackingException('MAL login expired');
    }
    try {
      final token = await _postForm(
        Uri.parse('https://myanimelist.net/v1/oauth2/token'),
        {
          'client_id': _myAnimeListClientId,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );
      account = account.copyWith(
        accessToken: token['access_token']?.toString(),
        refreshToken: token['refresh_token']?.toString(),
        expiresAtMs:
            DateTime.now().millisecondsSinceEpoch +
            ((token['expires_in'] as num?)?.toInt() ?? 0) * 1000,
        authExpired: false,
      );
      await _saveAccount(account);
      return account;
    } catch (_) {
      await _markAuthExpired(TrackingProvider.myAnimeList);
      rethrow;
    }
  }

  Future<TrackingAccount> _ensureKitsuToken() async {
    var account = _requireAccount(TrackingProvider.kitsu);
    if (!account.isExpired) {
      return account;
    }
    final refreshToken = account.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _markAuthExpired(TrackingProvider.kitsu);
      throw const TrackingException('Kitsu login expired');
    }
    try {
      final token =
          await _postForm(Uri.parse('https://kitsu.app/api/oauth/token'), {
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
            'client_id': _kitsuClientId,
            'client_secret': _kitsuClientSecret,
          });
      final createdAtSeconds =
          (token['created_at'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresInSeconds = (token['expires_in'] as num?)?.toInt();
      account = account.copyWith(
        accessToken: token['access_token']?.toString(),
        refreshToken: token['refresh_token']?.toString(),
        expiresAtMs: expiresInSeconds == null
            ? null
            : (createdAtSeconds + expiresInSeconds) * 1000,
        authExpired: false,
      );
      await _saveAccount(account);
      return account;
    } catch (_) {
      await _markAuthExpired(TrackingProvider.kitsu);
      rethrow;
    }
  }

  Future<void> _markAuthExpired(TrackingProvider provider) async {
    final account = _accounts[provider];
    if (account == null) {
      return;
    }
    await _saveAccount(account.copyWith(authExpired: true));
  }

  Future<String> _malCurrentUser(String accessToken) async {
    final data = await _requestJson(
      'GET',
      Uri.parse('https://api.myanimelist.net/v2/users/@me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return data['name']?.toString() ?? 'MyAnimeList';
  }

  Future<int?> _resolveMalAnimeId(AniListMedia media) async {
    if (media.idMal != null) {
      return media.idMal;
    }
    final account = await _ensureMyAnimeListToken();
    final uri = Uri.https('api.myanimelist.net', '/v2/anime', {
      'q': media.displayTitle,
      'limit': '5',
      'nsfw': 'true',
    });
    final data = await _requestJson(
      'GET',
      uri,
      headers: {'Authorization': 'Bearer ${account.accessToken}'},
    );
    final items = data['data'];
    if (items is! List || items.isEmpty) {
      return null;
    }
    final first = items.first;
    if (first is Map) {
      return (first['node']?['id'] as num?)?.toInt();
    }
    return null;
  }

  Future<_KitsuUser> _kitsuCurrentUser(String accessToken) async {
    final data = await _requestJson(
      'GET',
      Uri.https('kitsu.app', '/api/edge/users', {'filter[self]': 'true'}),
      headers: _kitsuHeaders(accessToken),
    );
    final users = data['data'];
    if (users is List && users.isNotEmpty && users.first is Map) {
      final first = users.first as Map;
      final attributes = first['attributes'];
      return _KitsuUser(
        id: first['id']?.toString() ?? '',
        name: attributes is Map
            ? (attributes['name'] ?? attributes['slug'])?.toString()
            : null,
      );
    }
    throw const TrackingException('Kitsu did not return a user');
  }

  Future<String?> _resolveKitsuAnimeId(AniListMedia media) async {
    final cacheKey = 'tracking.remote.kitsu.anime.${media.id}';
    final cached = _prefs!.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final data = await _requestJson(
      'GET',
      Uri.https('kitsu.app', '/api/edge/anime', {
        'filter[text]': media.displayTitle,
        'page[limit]': '10',
      }),
      headers: const {'Accept': 'application/vnd.api+json'},
    );
    final items = data['data'];
    if (items is! List || items.isEmpty) {
      return null;
    }
    Map? best;
    for (final item in items.whereType<Map>()) {
      final attributes = item['attributes'];
      final episodeCount = attributes is Map
          ? (attributes['episodeCount'] as num?)?.toInt()
          : null;
      if (media.episodes != null && episodeCount == media.episodes) {
        best = item;
        break;
      }
    }
    if (best == null) {
      final mapItems = items.whereType<Map>();
      if (mapItems.isNotEmpty) {
        best = mapItems.first;
      }
    }
    final id = best?['id']?.toString();
    if (id != null && id.isNotEmpty) {
      await _prefs!.setString(cacheKey, id);
    }
    return id;
  }

  Future<String?> _kitsuLibraryEntryId({
    required String accessToken,
    required String userId,
    required String animeId,
  }) async {
    final data = await _requestJson(
      'GET',
      Uri.https('kitsu.app', '/api/edge/library-entries', {
        'filter[user_id]': userId,
        'filter[anime_id]': animeId,
      }),
      headers: _kitsuHeaders(accessToken),
    );
    final items = data['data'];
    if (items is List && items.isNotEmpty && items.first is Map) {
      return (items.first as Map)['id']?.toString();
    }
    return null;
  }

  Map<String, String> _kitsuHeaders(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/vnd.api+json',
    'Content-Type': 'application/vnd.api+json',
  };

  Future<bool> _alreadySynced(
    TrackingProvider provider,
    TrackingProgressRequest request,
  ) async {
    final value = _prefs!.getInt(_syncedProgressKey(provider, request)) ?? 0;
    return value >= request.progress;
  }

  Future<void> _markSynced(
    TrackingProvider provider,
    TrackingProgressRequest request,
  ) {
    return _prefs!.setInt(
      _syncedProgressKey(provider, request),
      request.progress,
    );
  }

  String _syncedProgressKey(
    TrackingProvider provider,
    TrackingProgressRequest request,
  ) {
    return 'tracking.synced.${provider.key}.${request.kind.name}.${request.media.id}';
  }

  Future<void> _queuePendingUpdate(TrackingProgressRequest request) async {
    _pendingUpdates.removeWhere(
      (item) =>
          item.request.media.id == request.media.id &&
          item.request.kind == request.kind &&
          item.request.progress <= request.progress,
    );
    _pendingUpdates.add(
      PendingTrackingUpdate(
        request: request,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    lastMessage = 'Queued tracker sync for ${request.title}';
    await _persistPendingUpdates();
  }

  Future<void> _removePendingUpdate(TrackingProgressRequest request) async {
    final before = _pendingUpdates.length;
    _pendingUpdates.removeWhere(
      (item) =>
          item.request.media.id == request.media.id &&
          item.request.kind == request.kind &&
          item.request.progress <= request.progress,
    );
    if (_pendingUpdates.length != before) {
      await _persistPendingUpdates();
    }
  }

  Future<void> _persistPendingUpdates() {
    return _prefs!.setString(
      _pendingUpdatesKey,
      jsonEncode(_pendingUpdates.map((item) => item.toJson()).toList()),
    );
  }

  static String _formEncode(Map<String, String?> fields) {
    return fields.entries
        .where((entry) => entry.value != null)
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value!)}',
        )
        .join('&');
  }

  static String _createCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

class _KitsuUser {
  const _KitsuUser({required this.id, required this.name});

  final String id;
  final String? name;
}

class TrackingException implements Exception {
  const TrackingException(this.message);

  final String message;

  @override
  String toString() => message;
}
