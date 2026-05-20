import 'dart:async';
import 'dart:convert';

import 'package:anikin/app/anikin_app.dart';
import 'package:anikin/core/app_constants.dart';
import 'package:anikin/core/app_theme.dart';
import 'package:anikin/models/anilist_media.dart';
import 'package:anikin/models/downloaded_episode.dart';
import 'package:anikin/models/juro_models.dart';
import 'package:anikin/screens/detail_screen.dart';
import 'package:anikin/screens/downloads_screen.dart';
import 'package:anikin/screens/home_screen.dart';
import 'package:anikin/screens/manga_reader_screen.dart';
import 'package:anikin/screens/search_screen.dart';
import 'package:anikin/services/anilist_service.dart';
import 'package:anikin/services/download_service.dart';
import 'package:anikin/services/juro_service.dart';
import 'package:anikin/services/manga_download_service.dart';
import 'package:anikin/services/preferences_service.dart';
import 'package:anikin/services/watch_history_service.dart';
import 'package:anikin/widgets/app_error_view.dart';
import 'package:anikin/widgets/media_poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads the saved theme color palette', () async {
    SharedPreferences.setMockInitialValues({
      'themeColorPalette': ThemeColorPalette.forest.index,
    });
    final preferences = PreferencesService();
    await preferences.load();

    expect(preferences.themeColorPalette, ThemeColorPalette.forest);

    await preferences.setThemeColorPalette(ThemeColorPalette.ocean);

    expect(preferences.themeColorPalette, ThemeColorPalette.ocean);
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
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.byIcon(Icons.live_tv_outlined), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.byKey(const ValueKey('top-status-bar-shade')), findsOneWidget);
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
      ),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('App'), findsOneWidget);
    expect(find.text('Playback'), findsOneWidget);
    expect(find.text('Subtitles'), findsOneWidget);
    expect(find.text('Sources and library'), findsOneWidget);

    await tester.tap(find.text('App'));
    await tester.pumpAndSettle();

    expect(find.text('Color palette'), findsOneWidget);

    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();

    expect(preferences.themeColorPalette, ThemeColorPalette.ocean);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playback'));
    await tester.pumpAndSettle();

    expect(find.text('Default speed'), findsOneWidget);
    expect(find.text('Player behavior'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.text('Double-tap seek'), findsOneWidget);
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
          ),
        ),
      ),
    );

    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Shounen'), findsOneWidget);

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

    expect(find.text('Pick one or more'), findsOneWidget);
    expect(find.text('Search Result'), findsNothing);
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
            onSearchRequested: () {},
            onSettingsRequested: () {},
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
            onSearchRequested: () {},
            onSettingsRequested: () {},
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
        ),
      ),
    );
    await tester.pump();

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

class _FakeJuroService extends JuroService {
  @override
  Future<List<SourceProvider>> getProviders() async => const [];

  @override
  Future<List<SourceProvider>> getMangaProviders() async => const [];
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
