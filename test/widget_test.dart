import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:anikin/app/anikin_app.dart';
import 'package:anikin/core/app_constants.dart';
import 'package:anikin/core/app_theme.dart';
import 'package:anikin/models/anilist_media.dart';
import 'package:anikin/models/aniyomi_filters.dart';
import 'package:anikin/models/downloaded_episode.dart';
import 'package:anikin/models/juro_models.dart';
import 'package:anikin/models/tracking.dart';
import 'package:anikin/models/watch_history.dart';
import 'package:anikin/screens/detail_screen.dart';
import 'package:anikin/screens/downloads_screen.dart';
import 'package:anikin/screens/home_screen.dart';
import 'package:anikin/screens/manga_reader_screen.dart';
import 'package:anikin/screens/player_screen.dart';
import 'package:anikin/screens/search_screen.dart';
import 'package:anikin/services/anilist_service.dart';
import 'package:anikin/services/aniyomi_extension_service.dart';
import 'package:anikin/services/download_service.dart';
import 'package:anikin/services/juro_service.dart';
import 'package:anikin/services/manga_download_service.dart';
import 'package:anikin/services/preferences_service.dart';
import 'package:anikin/services/tracking_service.dart';
import 'package:anikin/services/update_service.dart';
import 'package:anikin/services/watch_history_service.dart';
import 'package:anikin/widgets/app_error_view.dart';
import 'package:anikin/widgets/media_poster_card.dart';
import 'package:anikin/widgets/media_type_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads the saved theme color palette', () async {
    SharedPreferences.setMockInitialValues({
      'themeColorPalette': ThemeColorPalette.forest.index,
      'automaticUpdateChecks': true,
    });
    final preferences = PreferencesService();
    await preferences.load();

    expect(preferences.themeColorPalette, ThemeColorPalette.forest);
    expect(preferences.automaticUpdateChecks, isTrue);

    await preferences.setThemeColorPalette(ThemeColorPalette.ocean);
    await preferences.setAutomaticUpdateChecks(false);

    expect(preferences.themeColorPalette, ThemeColorPalette.ocean);
    expect(preferences.automaticUpdateChecks, isFalse);
  });

  test('loads and persists the new experience preferences', () async {
    SharedPreferences.setMockInitialValues({
      'appStartTab': AppStartTab.library.index,
      'appMediaType': AppMediaType.manga.index,
      'incognitoMode': true,
      'resumePlayback': false,
      'playerControlsTimeoutSeconds': 8,
      'downloadQualityPreference': DownloadQualityPreference.dataSaver.index,
      'mangaShowPageNumber': false,
      'mangaPreloadPages': 10,
    });
    final preferences = PreferencesService();
    await preferences.load();

    expect(preferences.appStartTab, AppStartTab.library);
    expect(preferences.appMediaType, AppMediaType.manga);
    expect(preferences.incognitoMode, isTrue);
    expect(preferences.resumePlayback, isFalse);
    expect(preferences.playerControlsTimeoutSeconds, 8);
    expect(
      preferences.downloadQualityPreference,
      DownloadQualityPreference.dataSaver,
    );
    expect(preferences.mangaShowPageNumber, isFalse);
    expect(preferences.mangaPreloadPages, 10);

    await preferences.setAppStartTab(AppStartTab.search);
    await preferences.setAppMediaType(AppMediaType.anime);
    await preferences.setIncognitoMode(false);
    await preferences.setResumePlayback(true);
    await preferences.setPlayerControlsTimeoutSeconds(30);
    await preferences.setDownloadQualityPreference(
      DownloadQualityPreference.highest,
    );
    await preferences.setMangaShowPageNumber(true);
    await preferences.setMangaPreloadPages(20);

    final reloaded = PreferencesService();
    await reloaded.load();
    expect(reloaded.appStartTab, AppStartTab.search);
    expect(reloaded.appMediaType, AppMediaType.anime);
    expect(reloaded.incognitoMode, isFalse);
    expect(reloaded.resumePlayback, isTrue);
    expect(reloaded.playerControlsTimeoutSeconds, 15);
    expect(
      reloaded.downloadQualityPreference,
      DownloadQualityPreference.highest,
    );
    expect(reloaded.mangaShowPageNumber, isTrue);
    expect(reloaded.mangaPreloadPages, 12);
  });

  test('watch history loads legacy entries', () async {
    SharedPreferences.setMockInitialValues({
      'player.watchedEpisodes': jsonEncode({
        '42-1': {
          'id': '42-1',
          'animeName': 'Legacy Show',
          'watchedDuration': 90000,
          'watchedPercentage': 35,
        },
      }),
    });
    final service = WatchHistoryService();

    final history = (await service.getAll())['42-1']!;

    expect(history.animeName, 'Legacy Show');
    expect(history.watchedDuration, const Duration(seconds: 90));
    expect(history.watchedPercentage, 35);
    expect(history.canResumeAnime, isFalse);
  });

  test('watch history loads enriched resume entries', () async {
    SharedPreferences.setMockInitialValues({
      'player.watchedEpisodes': jsonEncode({
        '42-1': _watchHistoryJson(
          id: '42-1',
          animeName: 'Resume Show',
          mediaId: 42,
          providerAnimeId: 'provider-show-42',
          episodeId: 'episode-1',
          episodeNumber: 1,
          providerKey: 'Anime',
        ),
      }),
    });
    final service = WatchHistoryService();

    final history = (await service.getAll())['42-1']!;

    expect(history.canResumeAnime, isTrue);
    expect(history.resumeMedia.id, 42);
    expect(history.resumeProviderAnime.id, 'provider-show-42');
    expect(history.resumeEpisode.displayName, 'Ep 1 • Episode One');
    expect(history.providerKey, 'Anime');
  });

  test('watch history can be cleared and notifies listeners', () async {
    SharedPreferences.setMockInitialValues({
      'player.watchedEpisodes': jsonEncode({
        '42-1': {
          'id': '42-1',
          'animeName': 'Clear Me',
          'watchedDuration': 90000,
          'watchedPercentage': 35,
        },
      }),
    });
    final service = WatchHistoryService();
    var notifications = 0;
    service.addListener(() => notifications++);

    expect(await service.getAll(), hasLength(1));
    await service.clear();

    expect(await service.getAll(), isEmpty);
    expect(notifications, 1);
  });

  test('download service reads HLS master playlist qualities', () async {
    final service = DownloadService(
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/master.m3u8');
        return http.Response('''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=4000000,AVERAGE-BANDWIDTH=3500000,RESOLUTION=1920x1080,FRAME-RATE=23.976,CODECS="avc1.640028"
1080/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1800000,RESOLUTION=1280x720
https://cdn.example.com/720/index.m3u8
''', 200);
      }),
    );

    final variants = await service.getHlsVariants(
      const VideoSource(
        title: 'Auto',
        videoUrl: 'https://example.com/master.m3u8',
        format: VideoFormat.hls,
      ),
    );

    expect(variants.map((variant) => variant.resolutionLabel), [
      '1080p',
      '720p',
    ]);
    expect(
      variants.first.uri.toString(),
      'https://example.com/1080/index.m3u8',
    );
    expect(variants.first.bitrateLabel, '3.5 Mbps');
  });

  test('download service runs two episode downloads at a time', () async {
    SharedPreferences.setMockInitialValues({});
    final temp = await _mockApplicationSupportDirectory();
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    final completions = <String, Completer<http.Response>>{};
    final requestedUrls = <String>[];
    final service = DownloadService(
      client: MockClient((request) {
        requestedUrls.add(request.url.toString());
        final completer = Completer<http.Response>();
        completions[request.url.toString()] = completer;
        return completer.future;
      }),
    );
    await service.load();

    final requests = [
      _episodeDownloadRequest(1),
      _episodeDownloadRequest(2),
      _episodeDownloadRequest(3),
    ];
    for (final request in requests) {
      await service.startDownload(request);
    }

    await _waitFor(() => requestedUrls.length == 2);
    expect(
      service.activeTasks.where(
        (task) => task.status == DownloadTaskStatus.downloading,
      ),
      hasLength(2),
    );
    expect(
      service.taskFor(requests[2].taskId)?.status,
      DownloadTaskStatus.queued,
    );

    completions[requests[0].source.videoUrl]!.complete(
      http.Response.bytes([1, 2, 3], 200),
    );
    await _waitFor(() => requestedUrls.length == 3);

    expect(
      service.taskFor(requests[2].taskId)?.status,
      DownloadTaskStatus.downloading,
    );

    completions[requests[1].source.videoUrl]!.complete(
      http.Response.bytes([4, 5, 6], 200),
    );
    completions[requests[2].source.videoUrl]!.complete(
      http.Response.bytes([7, 8, 9], 200),
    );
    await _waitFor(() => service.activeTasks.isEmpty);
  });

  test(
    'download service preserves pause resume and cancel with queued tasks',
    () async {
      SharedPreferences.setMockInitialValues({});
      final temp = await _mockApplicationSupportDirectory();
      addTearDown(() async {
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      });

      final completions = <String, Completer<http.Response>>{};
      final requestedUrls = <String>[];
      final service = DownloadService(
        client: MockClient((request) {
          requestedUrls.add(request.url.toString());
          final completer = Completer<http.Response>();
          completions[request.url.toString()] = completer;
          return completer.future;
        }),
      );
      await service.load();

      final first = _episodeDownloadRequest(1);
      final second = _episodeDownloadRequest(2);
      final third = _episodeDownloadRequest(3);
      await service.startDownload(first);
      await service.startDownload(second);
      await service.startDownload(third);
      await _waitFor(() => requestedUrls.length == 2);

      await service.pauseDownload(first.taskId);
      expect(service.taskFor(first.taskId)?.status, DownloadTaskStatus.pausing);

      completions[first.source.videoUrl]!.complete(
        http.Response.bytes([1, 2, 3], 200),
      );
      await _waitFor(
        () =>
            service.taskFor(first.taskId)?.status == DownloadTaskStatus.paused,
      );
      await _waitFor(() => requestedUrls.length == 3);

      await service.resumeDownload(first.taskId);
      expect(service.taskFor(first.taskId)?.status, DownloadTaskStatus.queued);

      await service.cancelDownload(first.taskId);
      expect(service.taskFor(first.taskId), isNull);

      completions[second.source.videoUrl]!.complete(
        http.Response.bytes([4, 5, 6], 200),
      );
      completions[third.source.videoUrl]!.complete(
        http.Response.bytes([7, 8, 9], 200),
      );
      await _waitFor(() => service.activeTasks.isEmpty);
    },
  );

  test('AniList search posts search text and tags to GraphQL', () async {
    final service = AniListService(
      client: MockClient((request) async {
        expect(request.url.toString(), AppConstants.anilistGraphqlEndpoint);

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final variables = body['variables'] as Map<String, dynamic>;

        expect(body['query'], contains('type: ANIME'));
        expect(body['query'], isNot(contains(r'season: $season')));
        expect(variables['search'], 'Frieren');
        expect(variables['tagIn'], ['Magic', 'Travel']);
        expect(variables.containsKey('season'), isFalse);

        return http.Response(
          jsonEncode({
            'data': {
              'Page': {
                'media': [
                  {
                    'id': 1,
                    'title': {'english': 'Frieren'},
                    'coverImage': {},
                    'genres': ['Adventure'],
                    'countryOfOrigin': 'JP',
                  },
                ],
              },
            },
          }),
          200,
        );
      }),
    );

    final results = await service.searchMedia(
      query: 'Frieren',
      tags: const ['Magic', 'Travel'],
      includeNonJapanese: true,
    );

    expect(results.single.displayTitle, 'Frieren');
  });

  test('AniList search omits null optional filters', () async {
    final service = AniListService(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final query = body['query'] as String;
        final variables = body['variables'] as Map<String, dynamic>;

        expect(query, isNot(contains(r'season: $season')));
        expect(query, isNot(contains(r'seasonYear: $seasonYear')));
        expect(query, isNot(contains(r'tag_in: $tagIn')));
        expect(variables.containsKey('season'), isFalse);
        expect(variables.containsKey('seasonYear'), isFalse);
        expect(variables.containsKey('tagIn'), isFalse);

        return http.Response(
          jsonEncode({
            'data': {
              'Page': {
                'media': [
                  {
                    'id': 9989,
                    'title': {'english': 'Anohana'},
                    'coverImage': {},
                    'genres': [],
                    'countryOfOrigin': 'JP',
                  },
                ],
              },
            },
          }),
          200,
        );
      }),
    );

    final results = await service.searchMedia(
      query: 'anohana',
      includeNonJapanese: true,
    );

    expect(results.single.displayTitle, 'Anohana');
  });

  test('Juro service builds requests from injected base URL', () async {
    final service = JuroService(
      baseUrl: 'https://example.invalid/api/',
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://example.invalid/api/Providers?type=0',
        );
        return http.Response('[]', 200);
      }),
    );

    await service.getProviders();
  });

  test('Juro service reports missing base URL before requests', () async {
    var requested = false;
    final service = JuroService(
      baseUrl: '',
      client: MockClient((request) async {
        requested = true;
        return http.Response('[]', 200);
      }),
    );

    await expectLater(
      service.getProviders(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('JURO_API_BASE_URL'),
        ),
      ),
    );
    expect(requested, isFalse);
  });

  test('Juro service appends Aniyomi extension providers', () async {
    final service = JuroService(
      baseUrl: 'https://example.invalid/api',
      aniyomiExtensionService: _FakeAniyomiExtensionService(),
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://example.invalid/api/Providers?type=0',
        );
        return http.Response(
          jsonEncode([
            {'key': 'Anime', 'name': 'Anime'},
          ]),
          200,
        );
      }),
    );

    final providers = await service.getProviders();

    expect(providers.map((provider) => provider.key), [
      'Anime',
      AniyomiExtensionService.providerKeyForSourceId(123),
    ]);
  });

  test('Juro service appends Aniyomi manga extension providers', () async {
    final service = JuroService(
      baseUrl: 'https://example.invalid/api',
      aniyomiExtensionService: _FakeAniyomiExtensionService(),
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://example.invalid/api/Providers?type=1',
        );
        return http.Response(
          jsonEncode([
            {'key': 'Manga', 'name': 'Manga'},
          ]),
          200,
        );
      }),
    );

    final providers = await service.getMangaProviders();

    expect(providers.map((provider) => provider.key), [
      'Manga',
      AniyomiExtensionService.providerKeyForSourceId(456, type: 1),
    ]);
  });

  test('Juro service excludes Aniyomi providers off Android', () async {
    final service = JuroService(
      baseUrl: 'https://example.invalid/api',
      aniyomiExtensionService: _FakeAniyomiExtensionService(isAndroid: false),
      client: MockClient((request) async {
        final type = request.url.queryParameters['type'];
        return http.Response(
          jsonEncode([
            {'key': type == '1' ? 'Manga' : 'Anime', 'name': 'Built in'},
          ]),
          200,
        );
      }),
    );

    final animeProviders = await service.getProviders();
    final mangaProviders = await service.getMangaProviders();

    expect(animeProviders.map((provider) => provider.key), ['Anime']);
    expect(mangaProviders.map((provider) => provider.key), ['Manga']);
  });

  test(
    'Juro service routes Aniyomi provider calls to extension service',
    () async {
      var requestedBackend = false;
      final extensions = _FakeAniyomiExtensionService();
      final service = JuroService(
        baseUrl: '',
        aniyomiExtensionService: extensions,
        client: MockClient((request) async {
          requestedBackend = true;
          return http.Response('[]', 200);
        }),
      );
      final providerKey = AniyomiExtensionService.providerKeyForSourceId(123);

      final results = await service.searchAnime(
        'frieren',
        providerKey: providerKey,
      );
      final episodes = await service.getEpisodes(
        results.single.id,
        providerKey: providerKey,
      );
      final source = await service.getPreferredVideo(
        episodes.single,
        providerKey: providerKey,
      );

      expect(requestedBackend, isFalse);
      expect(results.single.title, 'Frieren');
      expect(episodes.single.name, 'The Journey Begins');
      expect(source?.videoUrl, 'https://example.com/frieren.m3u8');
      expect(extensions.lastSearchQuery, 'frieren');
      expect(extensions.lastProviderKey, providerKey);
    },
  );

  test(
    'Juro service routes Aniyomi manga calls to extension service',
    () async {
      var requestedBackend = false;
      final extensions = _FakeAniyomiExtensionService();
      final service = JuroService(
        baseUrl: '',
        aniyomiExtensionService: extensions,
        client: MockClient((request) async {
          requestedBackend = true;
          return http.Response('[]', 200);
        }),
      );
      final providerKey = AniyomiExtensionService.providerKeyForSourceId(
        456,
        type: 1,
      );

      final results = await service.searchManga(
        'dungeon',
        providerKey: providerKey,
      );
      final info = await service.getMangaInfo(
        results.single.id,
        providerKey: providerKey,
      );
      final pages = await service.getChapterPages(
        info.chapters.single.id,
        providerKey: providerKey,
      );

      expect(requestedBackend, isFalse);
      expect(results.single.title, 'Dungeon Meshi');
      expect(info.chapters.single.displayTitle, 'Ch 1 • Hot Pot');
      expect(pages.single.image, 'https://example.com/page-1.jpg');
      expect(extensions.lastSearchQuery, 'dungeon');
      expect(extensions.lastProviderKey, providerKey);
    },
  );

  test('update service reports newer GitHub releases', () async {
    final service = UpdateService(
      currentVersion: '3.0.2+46',
      latestReleaseUri: Uri.parse('https://example.invalid/releases/latest'),
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://example.invalid/releases/latest',
        );
        expect(request.headers['Accept'], 'application/vnd.github+json');
        return http.Response(
          jsonEncode({
            'tag_name': 'v3.0.3',
            'name': '3.0.3',
            'html_url': 'https://example.invalid/releases/v3.0.3',
            'body': 'Bug fixes',
          }),
          200,
        );
      }),
    );

    final result = await service.checkForUpdate();

    expect(result.isUpdateAvailable, isTrue);
    expect(result.release.version, '3.0.3');
  });

  test('update service treats matching release versions as current', () async {
    final service = UpdateService(
      currentVersion: '3.0.2+46',
      latestReleaseUri: Uri.parse('https://example.invalid/releases/latest'),
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v3.0.2',
            'html_url': 'https://example.invalid/releases/v3.0.2',
          }),
          200,
        );
      }),
    );

    final result = await service.checkForUpdate();

    expect(result.isUpdateAvailable, isFalse);
  });

  test('AniList favorite toggle only sends anime id for anime', () async {
    SharedPreferences.setMockInitialValues({
      'tracking.account.anilist': jsonEncode({
        'provider': 'anilist',
        'accessToken': 'token',
      }),
    });

    Map<String, dynamic>? postedBody;
    final service = TrackingService(
      listenForLinks: false,
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token');
        postedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {
              'ToggleFavourite': {
                'anime': {
                  'nodes': [
                    {'id': 42},
                  ],
                },
              },
            },
          }),
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    await service.load();

    final favorite = await service.toggleAniListFavorite(
      media: const AniListMedia(
        id: 42,
        title: MediaTitle(english: 'Frieren'),
        cover: MediaCover(),
      ),
      kind: TrackingMediaKind.anime,
    );

    expect(favorite, isTrue);
    final body = postedBody!;
    expect(body['query'], contains('ToggleFavourite(animeId:'));
    expect(body['query'], isNot(contains('mangaId')));
    expect(body['variables'], {'animeId': 42});
  });

  test('AniList favorite toggle only sends manga id for manga', () async {
    SharedPreferences.setMockInitialValues({
      'tracking.account.anilist': jsonEncode({
        'provider': 'anilist',
        'accessToken': 'token',
      }),
    });

    Map<String, dynamic>? postedBody;
    final service = TrackingService(
      listenForLinks: false,
      client: MockClient((request) async {
        postedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {
              'ToggleFavourite': {
                'manga': {
                  'nodes': [
                    {'id': 99},
                  ],
                },
              },
            },
          }),
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    await service.load();

    final favorite = await service.toggleAniListFavorite(
      media: const AniListMedia(
        id: 99,
        title: MediaTitle(english: 'Yotsuba&!'),
        cover: MediaCover(),
      ),
      kind: TrackingMediaKind.manga,
    );

    expect(favorite, isTrue);
    final body = postedBody!;
    expect(body['query'], contains('ToggleFavourite(mangaId:'));
    expect(body['query'], isNot(contains('animeId')));
    expect(body['variables'], {'mangaId': 99});
  });

  testWidgets('renders the migrated app shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      AnikinApp(
        preferences: preferences,
        aniListService: _FakeAniListService(),
        juroService: _FakeJuroService(),
        watchHistoryService: WatchHistoryService(),
        updateService: UpdateService(currentVersion: '0.0.0'),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.byIcon(Icons.live_tv_outlined), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.byKey(const ValueKey('top-status-bar-shade')), findsOneWidget);
  });

  testWidgets('Home and Search share the selected media type', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'automaticUpdateChecks': false});
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      AnikinApp(
        preferences: preferences,
        aniListService: _FakeAniListService(),
        juroService: _FakeJuroService(),
        watchHistoryService: WatchHistoryService(),
        updateService: UpdateService(currentVersion: '0.0.0'),
      ),
    );
    await tester.pumpAndSettle();

    var selector = find.byType(MediaTypeSelector);
    expect(
      tester.widget<MediaTypeSelector>(selector).appearance,
      MediaTypeSelectorAppearance.glass,
    );
    expect(
      find.descendant(of: selector, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    expect(
      tester.widget<MediaTypeSelector>(selector).value,
      AppMediaType.anime,
    );
    expect(
      find.descendant(of: selector, matching: find.text('Anime')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: selector, matching: find.text('Manga')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: selector, matching: find.text('Manga')),
    );
    await tester.pumpAndSettle();

    expect(preferences.appMediaType, AppMediaType.manga);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    selector = find.byType(MediaTypeSelector);
    expect(
      tester.widget<MediaTypeSelector>(selector).appearance,
      MediaTypeSelectorAppearance.surface,
    );
    expect(
      tester.widget<MediaTypeSelector>(selector).value,
      AppMediaType.manga,
    );
    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.decoration?.hintText, 'Search manga');

    final reloaded = PreferencesService();
    await reloaded.load();
    expect(reloaded.appMediaType, AppMediaType.manga);
  });

  testWidgets('opens on the configured start screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'appStartTab': AppStartTab.library.index,
    });
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      AnikinApp(
        preferences: preferences,
        aniListService: _FakeAniListService(),
        juroService: _FakeJuroService(),
        watchHistoryService: WatchHistoryService(),
        updateService: UpdateService(currentVersion: '0.0.0'),
      ),
    );
    await tester.pump();

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 2);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('settings categories open detailed pages', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      AnikinApp(
        preferences: preferences,
        aniListService: _FakeAniListService(),
        juroService: _FakeJuroService(),
        watchHistoryService: WatchHistoryService(),
        updateService: UpdateService(currentVersion: '0.0.0'),
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('App'), findsOneWidget);
    expect(find.text('Data and privacy'), findsOneWidget);
    expect(find.text('Playback'), findsOneWidget);
    expect(find.text('Subtitles'), findsOneWidget);
    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('Tracking and sync', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('App'));
    await tester.pumpAndSettle();

    expect(find.text('Color palette'), findsOneWidget);

    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();

    expect(preferences.themeColorPalette, ThemeColorPalette.ocean);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(find.text('Sources and library'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playback'));
    await tester.pumpAndSettle();

    expect(find.text('Default speed'), findsOneWidget);
    expect(find.text('Player behavior'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.text('Double-tap seek'), findsOneWidget);
  });

  testWidgets('data and privacy settings control incognito and history', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'player.watchedEpisodes': jsonEncode({
        '42-1': {
          'id': '42-1',
          'animeName': 'Private Show',
          'watchedDuration': 90000,
          'watchedPercentage': 35,
        },
      }),
    });
    final preferences = PreferencesService();
    await preferences.load();
    final historyService = WatchHistoryService();

    await tester.pumpWidget(
      AnikinApp(
        preferences: preferences,
        aniListService: _FakeAniListService(),
        juroService: _FakeJuroService(),
        watchHistoryService: historyService,
        updateService: UpdateService(currentVersion: '0.0.0'),
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data and privacy'));
    await tester.pumpAndSettle();

    expect(find.text('Incognito mode'), findsOneWidget);
    expect(find.text('Download quality'), findsOneWidget);
    expect(find.text('1 saved episode'), findsOneWidget);

    await tester.tap(find.text('Incognito mode'));
    await tester.pumpAndSettle();
    expect(preferences.incognitoMode, isTrue);

    await tester.tap(find.text('Clear watch history'));
    await tester.pumpAndSettle();
    expect(find.text('Clear watch history?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(await historyService.getAll(), isEmpty);
    expect(find.text('No saved episode progress'), findsOneWidget);
  });

  testWidgets('Aniyomi settings are hidden off Android', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      AnikinApp(
        preferences: preferences,
        aniListService: _FakeAniListService(),
        aniyomiExtensionService: AniyomiExtensionService(isAndroid: false),
        juroService: _FakeJuroService(),
        watchHistoryService: WatchHistoryService(),
        updateService: UpdateService(currentVersion: '0.0.0'),
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();

    expect(
      find.text('Browse Aniyomi sources', skipOffstage: false),
      findsNothing,
    );
    expect(find.text('Aniyomi extensions', skipOffstage: false), findsNothing);
    expect(find.text('Show NSFW sources', skipOffstage: false), findsNothing);
  });

  testWidgets('Aniyomi settings remain available on Android', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      AnikinApp(
        preferences: preferences,
        aniListService: _FakeAniListService(),
        aniyomiExtensionService: AniyomiExtensionService(isAndroid: true),
        juroService: _FakeJuroService(),
        watchHistoryService: WatchHistoryService(),
        updateService: UpdateService(currentVersion: '0.0.0'),
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();

    expect(
      find.text('Browse Aniyomi sources', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Aniyomi extensions', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Show NSFW sources', skipOffstage: false), findsOneWidget);
  });

  testWidgets('search screen applies AniList tags', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();
    final aniListService = _FakeAniListService(
      searchResults: const [
        AniListMedia(
          id: 91,
          title: MediaTitle(english: 'Search Result'),
          cover: MediaCover(),
          format: 'TV',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(ThemeColorPalette.anikin),
        home: Scaffold(
          body: SearchScreen(
            preferences: preferences,
            aniListService: aniListService,
            juroService: _FakeJuroService(),
            watchHistoryService: WatchHistoryService(),
            downloadService: DownloadService(),
            mangaDownloadService: MangaDownloadService(),
            trackingService: TrackingService(),
          ),
        ),
      ),
    );

    expect(find.text('Tags'), findsNothing);
    expect(find.text('Shounen'), findsOneWidget);
    expect(find.text('Pick one or more'), findsNothing);

    await tester.tap(find.text('Shounen'));
    await tester.pumpAndSettle();

    expect(aniListService.lastSearchTags, contains('Shounen'));
    expect(find.text('Search Result'), findsOneWidget);

    await tester.tap(find.text('Manga'));
    await tester.pumpAndSettle();

    expect(aniListService.lastSearchType, AniListMediaType.manga);
    expect(aniListService.lastSearchTags, contains('Shounen'));

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Pick one or more'), findsNothing);
    expect(find.text('Search Result'), findsNothing);
  });

  testWidgets('search header stays focused on wide layouts', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchScreen(
            preferences: preferences,
            aniListService: _FakeAniListService(),
            juroService: _FakeJuroService(),
            watchHistoryService: WatchHistoryService(),
            downloadService: DownloadService(),
            mangaDownloadService: MangaDownloadService(),
            trackingService: TrackingService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    expect(tester.getSize(searchField).width, lessThanOrEqualTo(808));
    expect(tester.getCenter(searchField).dx, closeTo(720, 0.5));
    expect(
      tester.getSize(find.byType(MediaTypeSelector)).width,
      lessThanOrEqualTo(240),
    );
  });

  testWidgets('search screen keeps the latest AniList result', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();
    final aniListService = _DelayedSearchAniListService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchScreen(
            preferences: preferences,
            aniListService: aniListService,
            juroService: _FakeJuroService(),
            watchHistoryService: WatchHistoryService(),
            downloadService: DownloadService(),
            mangaDownloadService: MangaDownloadService(),
            trackingService: TrackingService(),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 500));

    expect(aniListService.requests.single.query, 'old');

    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 500));

    expect(aniListService.requests.length, 2);
    expect(aniListService.requests.last.query, 'new');
    expect(aniListService.requests.last.includeNonJapanese, isTrue);

    aniListService.complete(0, const [
      AniListMedia(
        id: 100,
        title: MediaTitle(english: 'Old Result'),
        cover: MediaCover(),
      ),
    ]);
    await tester.pump();

    expect(find.text('Old Result'), findsNothing);

    aniListService.complete(1, const [
      AniListMedia(
        id: 101,
        title: MediaTitle(english: 'New Result'),
        cover: MediaCover(),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('New Result'), findsOneWidget);
    expect(find.text('Old Result'), findsNothing);
  });

  testWidgets('search screen shows one loading spinner', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();
    final aniListService = _DelayedSearchAniListService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: SearchScreen(
              preferences: preferences,
              aniListService: aniListService,
              juroService: _FakeJuroService(),
              watchHistoryService: WatchHistoryService(),
              downloadService: DownloadService(),
              mangaDownloadService: MangaDownloadService(),
              trackingService: TrackingService(),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'anohana');
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('search screen finds Anohana by AniList title search', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();
    final aniListService = _FakeAniListService(
      searchResults: const [
        AniListMedia(
          id: 9989,
          title: MediaTitle(english: 'Anohana: The Flower We Saw That Day'),
          cover: MediaCover(),
          countryOfOrigin: 'JP',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchScreen(
            preferences: preferences,
            aniListService: aniListService,
            juroService: _FakeJuroService(),
            watchHistoryService: WatchHistoryService(),
            downloadService: DownloadService(),
            mangaDownloadService: MangaDownloadService(),
            trackingService: TrackingService(),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'anohana');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(aniListService.lastSearchQuery, 'anohana');
    expect(aniListService.lastSearchType, AniListMediaType.anime);
    expect(find.text('Anohana: The Flower We Saw That Day'), findsOneWidget);
  });

  testWidgets('poster cards fit the compact home rail', (
    WidgetTester tester,
  ) async {
    const media = AniListMedia(
      id: 1,
      title: MediaTitle(
        english: 'A Very Long Anime Title That Needs Two Whole Lines',
      ),
      cover: MediaCover(),
      format: 'TV',
      seasonYear: 2026,
      episodes: 24,
      meanScore: 86,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 132,
            height: 252,
            child: MediaPosterCard(media: media, onTap: () {}),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('86%'), findsOneWidget);
  });

  testWidgets('home screen renders featured carousel', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            preferences: preferences,
            aniListService: _FakeAniListService(
              currentSeason: const [
                AniListMedia(
                  id: 11,
                  title: MediaTitle(english: 'Carousel First'),
                  cover: MediaCover(),
                  meanScore: 87,
                  popularity: 12000,
                  episodes: 12,
                  format: 'TV',
                ),
                AniListMedia(
                  id: 12,
                  title: MediaTitle(english: 'Carousel Second'),
                  cover: MediaCover(),
                  meanScore: 91,
                  popularity: 24000,
                  episodes: 24,
                  format: 'TV',
                ),
              ],
            ),
            juroService: _FakeJuroService(),
            watchHistoryService: WatchHistoryService(),
            downloadService: DownloadService(),
            mangaDownloadService: MangaDownloadService(),
            trackingService: TrackingService(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Carousel First'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home screen switches to manga browse', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            preferences: preferences,
            aniListService: _FakeAniListService(
              popularManga: const [
                AniListMedia(
                  id: 21,
                  title: MediaTitle(english: 'Manga First'),
                  cover: MediaCover(),
                  meanScore: 88,
                  popularity: 18000,
                  chapters: 42,
                  format: 'MANGA',
                ),
              ],
            ),
            juroService: _FakeJuroService(),
            watchHistoryService: WatchHistoryService(),
            downloadService: DownloadService(),
            mangaDownloadService: MangaDownloadService(),
            trackingService: TrackingService(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();
    await tester.pump();

    expect(find.text('Popular Manga'), findsOneWidget);
    expect(find.text('Manga First'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home preserves separate Anime and Manga scroll positions', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();
    final animeItems = List.generate(
      8,
      (index) => AniListMedia(
        id: index + 1,
        title: MediaTitle(english: 'Anime $index'),
        cover: const MediaCover(),
        format: 'TV',
      ),
    );
    final mangaItems = List.generate(
      8,
      (index) => AniListMedia(
        id: index + 101,
        title: MediaTitle(english: 'Manga $index'),
        cover: const MediaCover(),
        format: 'MANGA',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            preferences: preferences,
            aniListService: _FakeAniListService(
              currentSeason: animeItems,
              popularManga: mangaItems,
            ),
            juroService: _FakeJuroService(),
            watchHistoryService: WatchHistoryService(),
            downloadService: DownloadService(),
            mangaDownloadService: MangaDownloadService(),
            trackingService: TrackingService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final animeScroll = find.byKey(
      const PageStorageKey<String>('home-anime-scroll'),
    );
    await tester.drag(animeScroll, const Offset(0, -360));
    await tester.pumpAndSettle();
    final animeOffset = tester.widget<ListView>(animeScroll).controller!.offset;
    expect(animeOffset, greaterThan(0));

    var selector = find.byType(MediaTypeSelector);
    await tester.tap(
      find.descendant(of: selector, matching: find.text('Manga')),
    );
    await tester.pumpAndSettle();

    final mangaScroll = find.byKey(
      const PageStorageKey<String>('home-manga-scroll'),
    );
    expect(tester.widget<ListView>(mangaScroll).controller!.offset, 0);

    selector = find.byType(MediaTypeSelector);
    await tester.tap(
      find.descendant(of: selector, matching: find.text('Anime')),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<ListView>(animeScroll).controller!.offset,
      closeTo(animeOffset, 1),
    );
  });

  testWidgets('long pressing an episode opens source options', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'episodeLayoutMode': EpisodeLayoutMode.list.index,
    });
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      MaterialApp(
        home: DetailScreen(
          media: const AniListMedia(
            id: 42,
            title: MediaTitle(english: 'Long Press Show'),
            cover: MediaCover(),
          ),
          preferences: preferences,
          juroService: _EpisodeOptionsJuroService(),
          watchHistoryService: WatchHistoryService(),
          downloadService: DownloadService(),
          trackingService: TrackingService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final episodeTitle = find.text('Ep 1 • The Beginning', skipOffstage: false);
    await tester.ensureVisible(episodeTitle);
    await tester.pump();

    await tester.longPress(find.text('Ep 1 • The Beginning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Select server'), findsOneWidget);
    expect(find.text('Mirror'), findsOneWidget);
    expect(find.text('1080p'), findsWidgets);
    expect(find.byTooltip('Download episode'), findsOneWidget);
    expect(find.byTooltip('Copy link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('anime provider sheet groups Juro and Aniyomi sources', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewPadding: const EdgeInsets.only(bottom: 34)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: DetailScreen(
          media: const AniListMedia(
            id: 42,
            title: MediaTitle(english: 'Provider Sheet Show'),
            cover: MediaCover(),
          ),
          preferences: preferences,
          juroService: _ProviderPickerJuroService(),
          watchHistoryService: WatchHistoryService(),
          downloadService: DownloadService(),
          trackingService: TrackingService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    await tester.tap(find.byTooltip('Provider'));
    await tester.pumpAndSettle();

    expect(find.text('Anime Provider'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Anime Provider'),
      ),
      findsNothing,
    );
    expect(find.text('Juro providers'), findsOneWidget);
    expect(find.text('Aniyomi extensions'), findsOneWidget);
    expect(find.text('Juro Anime'), findsOneWidget);
    expect(find.text('Aniyomi Demo'), findsOneWidget);
    expect(
      tester.widget<ListView>(find.byType(ListView)).padding,
      const EdgeInsets.only(bottom: 46),
    );
    expect(
      tester.getTopLeft(find.text('Juro providers')).dy,
      lessThan(tester.getTopLeft(find.text('Aniyomi extensions')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Aniyomi episode failures show empty detail state', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();
    final provider = SourceProvider(
      key: AniyomiExtensionService.providerKeyForSourceId(123),
      name: 'Aniyomi Demo',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DetailScreen(
          media: const AniListMedia(
            id: 42,
            title: MediaTitle(english: 'Broken Provider Show'),
            cover: MediaCover(),
          ),
          preferences: preferences,
          juroService: _FailingAniyomiEpisodesJuroService(),
          watchHistoryService: WatchHistoryService(),
          downloadService: DownloadService(),
          trackingService: TrackingService(),
          initialProvider: provider,
          initialProviderAnime: const JuroAnimeInfo(
            id: 'extension-anime',
            title: 'Broken Provider Show',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Provider failed to load episodes'), findsOneWidget);
    expect(
      find.text('Try another provider or search the source manually.'),
      findsOneWidget,
    );
    expect(find.byType(AppErrorView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('downloads screen shows progress and cancels active tasks', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();
    final downloadService = _ProgressDownloadService();

    await tester.pumpWidget(
      MaterialApp(
        home: DownloadsScreen(
          downloadService: downloadService,
          mangaDownloadService: MangaDownloadService(),
          preferences: preferences,
          juroService: _FakeJuroService(),
          watchHistoryService: WatchHistoryService(),
          trackingService: TrackingService(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();

    expect(find.text('50% • 512.0 KB / 1.0 MB'), findsOneWidget);
    expect(find.byTooltip('Pause download'), findsOneWidget);
    expect(find.byTooltip('Cancel download'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause download'));
    await tester.pump();

    expect(downloadService.pausedId, _ProgressDownloadService.requestTaskId);
    expect(find.text('50% • Paused'), findsOneWidget);
    expect(find.byTooltip('Resume download'), findsOneWidget);

    await tester.tap(find.byTooltip('Resume download'));
    await tester.pump();

    expect(downloadService.resumedId, _ProgressDownloadService.requestTaskId);

    await tester.tap(find.byTooltip('Cancel download'));
    await tester.pump();

    expect(downloadService.cancelledId, _ProgressDownloadService.requestTaskId);
  });

  testWidgets('continue tab opens enriched online history in the player', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'player.watchedEpisodes': jsonEncode({
        '42-1': _watchHistoryJson(
          id: '42-1',
          animeName: 'Resume Show',
          mediaId: 42,
          providerAnimeId: 'provider-show-42',
          episodeId: 'episode-1',
          episodeNumber: 1,
          providerKey: 'ResumeProvider',
        ),
      }),
    });
    final preferences = PreferencesService();
    await preferences.load();
    final juroService = _ResumeJuroService();
    final navigatorObserver = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [navigatorObserver],
        home: LibraryScreen(
          downloadService: DownloadService(),
          mangaDownloadService: MangaDownloadService(),
          preferences: preferences,
          juroService: juroService,
          watchHistoryService: WatchHistoryService(),
          trackingService: TrackingService(listenForLinks: false),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Resume Show'));
    await tester.pump();
    await tester.pump();

    expect(juroService.lastEpisodeProviderKey, 'ResumeProvider');
    expect(juroService.lastVideoProviderKey, 'ResumeProvider');
    expect(find.byType(PlayerScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('continue tab prefers matching offline downloads', () async {
    final temp = await Directory.systemTemp.createTemp('anikin_offline_test_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });
    final offlineFile = File('${temp.path}${Platform.pathSeparator}ep1.mp4');
    await offlineFile.writeAsBytes([1, 2, 3]);

    SharedPreferences.setMockInitialValues({
      'player.watchedEpisodes': jsonEncode({
        '42-1': _watchHistoryJson(
          id: '42-1',
          animeName: 'Resume Show',
          mediaId: 42,
          providerAnimeId: 'provider-show-42',
          episodeId: 'episode-1',
          episodeNumber: 1,
          providerKey: 'ResumeProvider',
        ),
      }),
      'downloads.episodes': [
        jsonEncode(
          _downloadedEpisodeJson(id: '42-1', localPath: offlineFile.path),
        ),
      ],
    });

    final downloadService = DownloadService();
    await downloadService.load();
    final history = WatchedEpisode.fromJson(
      _watchHistoryJson(
        id: '42-1',
        animeName: 'Resume Show',
        mediaId: 42,
        providerAnimeId: 'provider-show-42',
        episodeId: 'episode-1',
        episodeNumber: 1,
        providerKey: 'ResumeProvider',
      ),
    );

    final download = await offlineResumeDownloadFor(downloadService, history);

    expect(download?.localPath, offlineFile.path);
  });

  testWidgets('continue tab keeps legacy history display only', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'player.watchedEpisodes': jsonEncode({
        '42-1': {
          'id': '42-1',
          'animeName': 'Legacy Show',
          'watchedDuration': 90000,
          'watchedPercentage': 35,
        },
      }),
    });
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          downloadService: DownloadService(),
          mangaDownloadService: MangaDownloadService(),
          preferences: preferences,
          juroService: _ResumeJuroService(),
          watchHistoryService: WatchHistoryService(),
          trackingService: TrackingService(listenForLinks: false),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Legacy Show'), findsOneWidget);
    expect(find.textContaining('Open once to refresh resume'), findsOneWidget);

    await tester.tap(find.text('Legacy Show'), warnIfMissed: false);
    await tester.pump();

    expect(find.byType(PlayerScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HLS master downloads prompt for quality', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'episodeLayoutMode': EpisodeLayoutMode.list.index,
    });
    final preferences = PreferencesService();
    await preferences.load();
    final downloadService = _HlsVariantDownloadService();

    await tester.pumpWidget(
      MaterialApp(
        home: DetailScreen(
          media: const AniListMedia(
            id: 42,
            title: MediaTitle(english: 'Long Press Show'),
            cover: MediaCover(),
          ),
          preferences: preferences,
          juroService: _HlsEpisodeOptionsJuroService(),
          watchHistoryService: WatchHistoryService(),
          downloadService: downloadService,
          trackingService: TrackingService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final episodeTitle = find.text('Ep 1 • The Beginning', skipOffstage: false);
    await tester.ensureVisible(episodeTitle);
    await tester.pump();

    await tester.longPress(find.text('Ep 1 • The Beginning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    await tester.tap(find.byTooltip('Download episode'));
    await tester.pump();

    expect(find.byTooltip('Getting download qualities'), findsOneWidget);

    downloadService.completeVariants();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Download quality'), findsOneWidget);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('720p'), findsOneWidget);

    await tester.tap(find.text('720p'));
    await tester.pump();

    expect(
      downloadService.startedRequest?.source.videoUrl,
      'https://example.com/720/index.m3u8',
    );
    expect(downloadService.startedRequest?.source.resolution, '720p');
    expect(
      downloadService.startedRequest?.sourceTaskId,
      isNot(downloadService.startedRequest?.taskId),
    );
    expect(find.byTooltip('Cancel download'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel download'));
    await tester.pump();

    expect(downloadService.cancelledId, downloadService.startedRequest?.taskId);
  });

  testWidgets('data saver download quality picks the smallest HLS variant', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'episodeLayoutMode': EpisodeLayoutMode.list.index,
      'downloadQualityPreference': DownloadQualityPreference.dataSaver.index,
    });
    final preferences = PreferencesService();
    await preferences.load();
    final downloadService = _HlsVariantDownloadService();

    await tester.pumpWidget(
      MaterialApp(
        home: DetailScreen(
          media: const AniListMedia(
            id: 42,
            title: MediaTitle(english: 'Data Saver Show'),
            cover: MediaCover(),
          ),
          preferences: preferences,
          juroService: _HlsEpisodeOptionsJuroService(),
          watchHistoryService: WatchHistoryService(),
          downloadService: downloadService,
          trackingService: TrackingService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final episodeTitle = find.text('Ep 1 • The Beginning', skipOffstage: false);
    await tester.ensureVisible(episodeTitle);
    await tester.pump();
    await tester.longPress(find.text('Ep 1 • The Beginning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    await tester.tap(find.byTooltip('Download episode'));
    await tester.pump();
    downloadService.completeVariants();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Download quality'), findsNothing);
    expect(
      downloadService.startedRequest?.source.videoUrl,
      'https://example.com/720/index.m3u8',
    );
    expect(downloadService.startedRequest?.source.resolution, '720p');
  });

  testWidgets('manga reader footer buttons match and settings apply', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'mangaKeepScreenOn': false});
    final preferences = PreferencesService();
    await preferences.load();

    await tester.pumpWidget(
      MaterialApp(
        home: MangaReaderScreen(
          media: const AniListMedia(
            id: 9,
            title: MediaTitle(english: 'Reader Show'),
            cover: MediaCover(),
          ),
          mangaInfo: const MangaInfo(id: 'manga-9', title: 'Reader Show'),
          chapter: const MangaChapter(id: 'chapter-1', number: 1),
          chapters: const [
            MangaChapter(id: 'chapter-1', number: 1),
            MangaChapter(id: 'chapter-2', number: 2),
          ],
          preferences: preferences,
          juroService: _MangaReaderJuroService(),
          mangaDownloadService: _NoopMangaDownloadService(),
          trackingService: TrackingService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pump();

    final previousButton = find.widgetWithText(OutlinedButton, 'Previous');
    final nextButton = find.widgetWithText(OutlinedButton, 'Next');
    expect(previousButton, findsOneWidget);
    expect(nextButton, findsOneWidget);
    expect(tester.getSize(previousButton), tester.getSize(nextButton));

    await tester.tap(find.byTooltip('Reader settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Reading mode'), findsOneWidget);
    expect(find.text('Show page number', skipOffstage: false), findsOneWidget);
    expect(find.text('Pages to preload', skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('RTL'));
    await tester.pump();

    expect(preferences.mangaReadingMode, MangaReadingMode.rightToLeft);
  });

  testWidgets(
    'episode source sheet scopes active progress to selected source',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'episodeLayoutMode': EpisodeLayoutMode.list.index,
      });
      final preferences = PreferencesService();
      await preferences.load();
      final downloadService = _ActiveEpisodeDownloadService();

      await tester.pumpWidget(
        MaterialApp(
          home: DetailScreen(
            media: _ActiveEpisodeDownloadService.media,
            preferences: preferences,
            juroService: _MultiSourceEpisodeOptionsJuroService(),
            watchHistoryService: WatchHistoryService(),
            downloadService: downloadService,
            trackingService: TrackingService(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      final episodeTitle = find.text(
        'Ep 1 • The Beginning',
        skipOffstage: false,
      );
      await tester.ensureVisible(episodeTitle);
      await tester.pump();

      expect(find.byTooltip('Pause download'), findsOneWidget);

      await tester.longPress(find.text('Ep 1 • The Beginning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('1080p'), findsWidgets);
      expect(find.text('720p'), findsWidgets);
      expect(find.byTooltip('Pause download'), findsNWidgets(2));
      expect(find.byTooltip('Cancel download'), findsOneWidget);
      expect(find.byTooltip('Download episode'), findsOneWidget);
    },
  );

  testWidgets('error state scrolls in compact panels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 96,
            child: AppErrorView(
              message: 'Juro returned a long provider error. ' * 8,
              onRetry: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

Map<String, Object?> _watchHistoryJson({
  required String id,
  required String animeName,
  required int mediaId,
  required String providerAnimeId,
  required String episodeId,
  required double episodeNumber,
  required String providerKey,
}) {
  return {
    'id': id,
    'animeName': animeName,
    'watchedDuration': 90000,
    'watchedPercentage': 35,
    'mediaId': mediaId,
    'mediaTitle': animeName,
    'mediaCoverUrl': 'https://example.com/cover.jpg',
    'providerAnimeId': providerAnimeId,
    'providerAnimeTitle': animeName,
    'providerAnimeImage': 'https://example.com/provider-cover.jpg',
    'episodeId': episodeId,
    'episodeName': 'Episode One',
    'episodeNumber': episodeNumber,
    'episodeImage': 'https://example.com/episode.jpg',
    'providerKey': providerKey,
    'providerName': 'Resume Provider',
    'updatedAtMs': 123456,
  };
}

Map<String, Object?> _downloadedEpisodeJson({
  required String id,
  required String localPath,
}) {
  return {
    'id': id,
    'mediaId': 42,
    'mediaTitle': 'Resume Show',
    'providerAnimeId': 'provider-show-42',
    'providerAnimeTitle': 'Resume Show',
    'episodeId': 'episode-1',
    'episodeName': 'Episode One',
    'episodeNumber': 1,
    'coverUrl': 'https://example.com/cover.jpg',
    'sourceTitle': 'Offline',
    'serverName': 'Offline',
    'localPath': localPath,
    'fileName': 'ep1.mp4',
    'bytes': 3,
    'downloadedAt': DateTime(2026).toIso8601String(),
  };
}

EpisodeDownloadRequest _episodeDownloadRequest(int number) {
  return EpisodeDownloadRequest(
    media: const AniListMedia(
      id: 900,
      title: MediaTitle(english: 'Queue Show'),
      cover: MediaCover(),
    ),
    providerAnime: const JuroAnimeInfo(id: 'queue-show', title: 'Queue Show'),
    episode: AnimeEpisode(
      id: 'episode-$number',
      name: 'Episode $number',
      number: number.toDouble(),
    ),
    source: VideoSource(
      title: '1080p',
      videoUrl: 'https://example.com/video-$number.mp4',
    ),
  );
}

Future<Directory> _mockApplicationSupportDirectory() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = await Directory.systemTemp.createTemp('anikin_support_');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationSupportDirectory' ||
            call.method == 'getTemporaryDirectory') {
          return directory.path;
        }
        return null;
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  return directory;
}

Future<void> _waitFor(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for async condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}

class _FakeAniListService extends AniListService {
  _FakeAniListService({
    this.currentSeason = const [],
    this.popularManga = const [],
    this.searchResults = const [],
  });

  final List<AniListMedia> currentSeason;
  final List<AniListMedia> popularManga;
  final List<AniListMedia> searchResults;
  String? lastSearchQuery;
  List<String>? lastSearchSort;
  List<String>? lastSearchTags;
  AniListMediaType? lastSearchType;

  @override
  Future<List<AniListMedia>> searchMedia({
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    List<String>? genres,
    String? season,
    int? seasonYear,
    List<String>? tags,
    AniListMediaType mediaType = AniListMediaType.anime,
    required bool includeNonJapanese,
  }) async {
    lastSearchQuery = query;
    lastSearchSort = sort;
    lastSearchTags = tags;
    lastSearchType = mediaType;
    return searchResults;
  }

  @override
  Future<List<AniListMedia>> searchManga({
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    List<String>? genres,
    List<String>? tags,
    required bool includeNonJapanese,
  }) async {
    lastSearchQuery = query;
    lastSearchSort = sort;
    lastSearchTags = tags;
    lastSearchType = AniListMediaType.manga;
    return searchResults;
  }

  @override
  Future<List<AniListMedia>> getCurrentSeason({
    required bool includeNonJapanese,
  }) async => currentSeason;

  @override
  Future<List<AniListMedia>> getPopular({
    required bool includeNonJapanese,
  }) async => const [];

  @override
  Future<List<AniListMedia>> getRecentlyUpdated({
    required bool includeNonJapanese,
  }) async => const [];

  @override
  Future<List<AniListMedia>> getTrending({
    required bool includeNonJapanese,
  }) async => const [];

  @override
  Future<List<AniListMedia>> getPopularManga({
    required bool includeNonJapanese,
  }) async => popularManga;

  @override
  Future<List<AniListMedia>> getTrendingManga({
    required bool includeNonJapanese,
  }) async => const [];

  @override
  Future<List<AniListMedia>> getRecentlyUpdatedManga({
    required bool includeNonJapanese,
  }) async => const [];

  @override
  Future<List<AniListMedia>> getTopRatedManga({
    required bool includeNonJapanese,
  }) async => const [];
}

class _DelayedSearchAniListService extends AniListService {
  final requests = <_DelayedSearchRequest>[];

  void complete(int index, List<AniListMedia> results) {
    requests[index].completer.complete(results);
  }

  @override
  Future<List<AniListMedia>> searchMedia({
    String? query,
    int page = 1,
    int perPage = 50,
    List<String>? sort,
    List<String>? genres,
    String? season,
    int? seasonYear,
    List<String>? tags,
    AniListMediaType mediaType = AniListMediaType.anime,
    required bool includeNonJapanese,
  }) {
    final request = _DelayedSearchRequest(
      query: query,
      includeNonJapanese: includeNonJapanese,
      completer: Completer<List<AniListMedia>>(),
    );
    requests.add(request);
    return request.completer.future;
  }
}

class _DelayedSearchRequest {
  const _DelayedSearchRequest({
    required this.query,
    required this.includeNonJapanese,
    required this.completer,
  });

  final String? query;
  final bool includeNonJapanese;
  final Completer<List<AniListMedia>> completer;
}

class _FakeAniyomiExtensionService extends AniyomiExtensionService {
  _FakeAniyomiExtensionService({bool isAndroid = true})
    : super(isAndroid: isAndroid);

  String? lastProviderKey;
  String? lastSearchQuery;

  @override
  Future<List<SourceProvider>> getAnimeProviders() async => [
    SourceProvider(
      key: AniyomiExtensionService.providerKeyForSourceId(123),
      name: 'Aniyomi Demo',
      language: 'en',
    ),
  ];

  @override
  Future<List<SourceProvider>> getMangaProviders() async => [
    SourceProvider(
      key: AniyomiExtensionService.providerKeyForSourceId(456, type: 1),
      name: 'Aniyomi Manga Demo',
      language: 'en',
    ),
  ];

  @override
  Future<AniyomiPage<JuroAnimeInfo>> searchAnime(
    String query, {
    required String providerKey,
    int page = 1,
    List<AniyomiFilterSelection>? filters,
  }) async {
    lastProviderKey = providerKey;
    lastSearchQuery = query;
    return const AniyomiPage(
      items: [JuroAnimeInfo(id: 'extension-anime', title: 'Frieren')],
      hasNextPage: false,
    );
  }

  @override
  Future<List<AnimeEpisode>> getEpisodes(
    String animeId, {
    required String providerKey,
  }) async {
    lastProviderKey = providerKey;
    return const [
      AnimeEpisode(
        id: 'extension-episode',
        name: 'The Journey Begins',
        number: 1,
      ),
    ];
  }

  @override
  Future<List<VideoServer>> getVideoServers(
    String episodeId, {
    required String providerKey,
  }) async {
    lastProviderKey = providerKey;
    return const [];
  }

  @override
  Future<List<VideoSource>> getVideos(
    String query, {
    required String providerKey,
  }) async {
    lastProviderKey = providerKey;
    return const [
      VideoSource(
        title: 'Auto',
        videoUrl: 'https://example.com/frieren.m3u8',
        format: VideoFormat.hls,
      ),
    ];
  }

  @override
  Future<AniyomiPage<MangaResult>> searchManga(
    String query, {
    required String providerKey,
    int page = 1,
    List<AniyomiFilterSelection>? filters,
  }) async {
    lastProviderKey = providerKey;
    lastSearchQuery = query;
    return const AniyomiPage(
      items: [MangaResult(id: 'extension-manga', title: 'Dungeon Meshi')],
      hasNextPage: false,
    );
  }

  @override
  Future<MangaInfo?> getMangaInfo(
    String mangaId, {
    required String providerKey,
  }) async {
    lastProviderKey = providerKey;
    return const MangaInfo(
      id: 'extension-manga',
      title: 'Dungeon Meshi',
      chapters: [
        MangaChapter(id: 'extension-chapter', title: 'Hot Pot', number: 1),
      ],
    );
  }

  @override
  Future<List<MangaChapterPage>> getChapterPages(
    String chapterId, {
    required String providerKey,
  }) async {
    lastProviderKey = providerKey;
    return const [
      MangaChapterPage(image: 'https://example.com/page-1.jpg', page: 1),
    ];
  }
}

class _FakeJuroService extends JuroService {
  @override
  Future<List<SourceProvider>> getProviders() async => const [];

  @override
  Future<List<SourceProvider>> getMangaProviders() async => const [];
}

class _FailingAniyomiEpisodesJuroService extends _FakeJuroService {
  @override
  Future<List<AnimeEpisode>> getEpisodes(
    String animeId, {
    required String providerKey,
  }) async {
    throw PlatformException(
      code: AniyomiExtensionService.extensionErrorCode,
      message:
          'Unexpected JSON token at offset 179: Expected start of the object',
    );
  }
}

class _ProviderPickerJuroService extends _FakeJuroService {
  @override
  Future<List<SourceProvider>> getProviders() async => [
    const SourceProvider(key: 'Anime', name: 'Juro Anime'),
    SourceProvider(
      key: AniyomiExtensionService.providerKeyForSourceId(123),
      name: 'Aniyomi Demo',
    ),
  ];

  @override
  Future<List<JuroAnimeInfo>> searchAnime(
    String query, {
    required String providerKey,
  }) async => const [];
}

class _ResumeJuroService extends _FakeJuroService {
  String? lastEpisodeProviderKey;
  String? lastVideoProviderKey;

  @override
  Future<List<AnimeEpisode>> getEpisodes(
    String animeId, {
    required String providerKey,
  }) async {
    lastEpisodeProviderKey = providerKey;
    return const [
      AnimeEpisode(id: 'episode-1', name: 'Episode One', number: 1),
      AnimeEpisode(id: 'episode-2', name: 'Episode Two', number: 2),
    ];
  }

  @override
  Future<VideoSource?> getPreferredVideo(
    AnimeEpisode episode, {
    required String providerKey,
  }) async {
    lastVideoProviderKey = providerKey;
    return null;
  }
}

class _EpisodeOptionsJuroService extends JuroService {
  @override
  Future<List<SourceProvider>> getProviders() async => const [
    SourceProvider(key: 'Anime', name: 'Anime'),
  ];

  @override
  Future<List<JuroAnimeInfo>> searchAnime(
    String query, {
    required String providerKey,
  }) async => const [JuroAnimeInfo(id: 'show-1', title: 'Long Press Show')];

  @override
  Future<List<AnimeEpisode>> getEpisodes(
    String animeId, {
    required String providerKey,
  }) async => const [
    AnimeEpisode(id: 'episode-1', name: 'The Beginning', number: 1),
  ];

  @override
  Future<List<VideoSource>> getVideos(
    String query, {
    required String providerKey,
  }) async => const [
    VideoSource(
      title: '1080p',
      resolution: '1080p',
      videoUrl: 'https://example.com/video.mp4',
      videoServer: VideoServer(
        name: 'Mirror',
        embed: FileUrl(url: 'https://example.com/embed'),
      ),
    ),
  ];
}

class _MultiSourceEpisodeOptionsJuroService extends _EpisodeOptionsJuroService {
  @override
  Future<List<VideoSource>> getVideos(
    String query, {
    required String providerKey,
  }) async => const [
    _ActiveEpisodeDownloadService.activeSource,
    VideoSource(
      title: '720p',
      resolution: '720p',
      videoUrl: 'https://example.com/video-720.mp4',
      videoServer: VideoServer(
        name: 'Backup',
        embed: FileUrl(url: 'https://example.com/embed-720'),
      ),
    ),
  ];
}

class _HlsEpisodeOptionsJuroService extends _EpisodeOptionsJuroService {
  @override
  Future<List<VideoSource>> getVideos(
    String query, {
    required String providerKey,
  }) async => const [
    VideoSource(
      title: 'Auto',
      videoUrl: 'https://example.com/master.m3u8',
      fileType: 'm3u8',
      format: VideoFormat.hls,
      videoServer: VideoServer(
        name: 'Mirror',
        embed: FileUrl(url: 'https://example.com/embed'),
      ),
    ),
  ];
}

class _MangaReaderJuroService extends JuroService {
  @override
  Future<List<MangaChapterPage>> getChapterPages(
    String chapterId, {
    required String providerKey,
  }) async => const [MangaChapterPage(image: 'missing-page.jpg', page: 1)];
}

class _NoopMangaDownloadService extends MangaDownloadService {
  @override
  Future<List<MangaChapterPage>?> pagesFor(String id) async => null;

  @override
  Future<void> load() async {}
}

class _ProgressDownloadService extends DownloadService {
  String? cancelledId;
  String? pausedId;
  String? resumedId;
  DownloadTaskStatus status = DownloadTaskStatus.downloading;

  static const _request = EpisodeDownloadRequest(
    media: AniListMedia(
      id: 77,
      title: MediaTitle(english: 'Download Show'),
      cover: MediaCover(),
    ),
    providerAnime: JuroAnimeInfo(id: 'show-77', title: 'Download Show'),
    episode: AnimeEpisode(id: 'episode-1', name: 'The Beginning', number: 1),
    source: VideoSource(
      title: '1080p',
      videoUrl: 'https://example.com/video.mp4',
    ),
  );

  static String get requestTaskId => _request.taskId;

  @override
  List<EpisodeDownloadProgress> get activeTasks => [
    EpisodeDownloadProgress(
      request: _request,
      status: status,
      bytesReceived: 512 * 1024,
      bytesTotal: 1024 * 1024,
    ),
  ];

  @override
  Future<void> load() async {}

  @override
  Future<void> cancelDownload(String id) async {
    cancelledId = id;
  }

  @override
  Future<void> pauseDownload(String id) async {
    pausedId = id;
    status = DownloadTaskStatus.paused;
    notifyListeners();
  }

  @override
  Future<void> resumeDownload(String id) async {
    resumedId = id;
    status = DownloadTaskStatus.downloading;
    notifyListeners();
  }
}

class _ActiveEpisodeDownloadService extends DownloadService {
  static const media = AniListMedia(
    id: 42,
    title: MediaTitle(english: 'Long Press Show'),
    cover: MediaCover(),
  );
  static const providerAnime = JuroAnimeInfo(
    id: 'show-1',
    title: 'Long Press Show',
  );
  static const episode = AnimeEpisode(
    id: 'episode-1',
    name: 'The Beginning',
    number: 1,
  );
  static const activeSource = VideoSource(
    title: '1080p',
    resolution: '1080p',
    videoUrl: 'https://example.com/video.mp4',
    videoServer: VideoServer(
      name: 'Mirror',
      embed: FileUrl(url: 'https://example.com/embed'),
    ),
  );
  static const request = EpisodeDownloadRequest(
    media: media,
    providerAnime: providerAnime,
    episode: episode,
    source: activeSource,
  );
  static const progress = EpisodeDownloadProgress(
    request: request,
    status: DownloadTaskStatus.downloading,
    bytesReceived: 256 * 1024,
    bytesTotal: 1024 * 1024,
  );

  @override
  EpisodeDownloadProgress? taskFor(String id) =>
      id == request.taskId ? progress : null;

  @override
  EpisodeDownloadProgress? taskForSource(String sourceTaskId) =>
      sourceTaskId == request.taskId ? progress : null;

  @override
  EpisodeDownloadProgress? taskForEpisode(String episodeId) =>
      episodeId == request.id ? progress : null;

  @override
  bool isDownloaded(String id) => false;

  @override
  Future<void> load() async {}
}

class _HlsVariantDownloadService extends DownloadService {
  EpisodeDownloadRequest? startedRequest;
  EpisodeDownloadProgress? activeTask;
  String? cancelledId;
  final Completer<List<HlsDownloadVariant>> variantsCompleter = Completer();

  @override
  Future<List<HlsDownloadVariant>> getHlsVariants(VideoSource source) async =>
      variantsCompleter.future;

  void completeVariants() {
    variantsCompleter.complete([
      HlsDownloadVariant(
        uri: Uri.parse('https://example.com/1080/index.m3u8'),
        bandwidth: 4000000,
        width: 1920,
        height: 1080,
      ),
      HlsDownloadVariant(
        uri: Uri.parse('https://example.com/720/index.m3u8'),
        bandwidth: 1800000,
        width: 1280,
        height: 720,
      ),
    ]);
  }

  @override
  Future<void> startDownload(EpisodeDownloadRequest request) async {
    startedRequest = request;
    activeTask = EpisodeDownloadProgress(
      request: request,
      status: DownloadTaskStatus.downloading,
      itemsCompleted: 1,
      itemsTotal: 10,
    );
    notifyListeners();
  }

  @override
  EpisodeDownloadProgress? taskForSource(String sourceTaskId) =>
      activeTask?.sourceTaskId == sourceTaskId ? activeTask : null;

  @override
  Future<void> cancelDownload(String id) async {
    cancelledId = id;
  }

  @override
  bool isDownloaded(String id) => false;

  @override
  Future<void> load() async {}
}
