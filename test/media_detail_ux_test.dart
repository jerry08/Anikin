import 'dart:async';
import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:anikin/core/app_theme.dart';
import 'package:anikin/models/anilist_media.dart';
import 'package:anikin/models/juro_models.dart';
import 'package:anikin/screens/detail_screen.dart';
import 'package:anikin/screens/manga_detail_screen.dart';
import 'package:anikin/screens/manga_reader_screen.dart';
import 'package:anikin/services/download_service.dart';
import 'package:anikin/services/juro_service.dart';
import 'package:anikin/services/manga_download_service.dart';
import 'package:anikin/services/preferences_service.dart';
import 'package:anikin/services/tracking_service.dart';
import 'package:anikin/services/watch_history_service.dart';
import 'package:anikin/widgets/app_error_view.dart';
import 'package:anikin/widgets/episode_action_bar.dart';
import 'package:anikin/widgets/marquee_text.dart';
import 'package:anikin/widgets/media_detail_header.dart';
import 'package:anikin/widgets/next_episode_countdown.dart';
import 'package:anikin/widgets/provider_search_results_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'media detail navigation adapts between bottom bar and side rail',
    (tester) async {
      Future<void> pumpAt(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaDetailScaffold(
              tabs: const [
                MediaDetailTab(icon: Icons.info_outline, label: 'Info'),
                MediaDetailTab(
                  icon: Icons.movie_outlined,
                  label: 'Watch',
                  badge: '12',
                  badgeLabel: '12 episodes',
                ),
              ],
              selectedIndex: 1,
              onSelected: (_) {},
              body: const SizedBox.expand(),
            ),
          ),
        );
        await tester.pump();
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpAt(const Size(390, 800));
      expect(find.byType(MediaDetailNavBar), findsOneWidget);
      expect(find.byType(MediaDetailSideNav), findsNothing);
      final semantics = tester.getSemantics(find.bySemanticsLabel('Watch'));
      expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
      expect(semantics.value, '12 episodes');

      await pumpAt(const Size(1000, 700));
      expect(find.byType(MediaDetailNavBar), findsNothing);
      expect(find.byType(MediaDetailSideNav), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'media detail keeps one scroll attachment across layout changes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      final controller = ScrollController();
      addTearDown(() {
        controller.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MediaDetailScaffold(
            tabs: const [
              MediaDetailTab(icon: Icons.info_outline, label: 'Info'),
              MediaDetailTab(icon: Icons.movie_outlined, label: 'Watch'),
            ],
            selectedIndex: 1,
            onSelected: (_) {},
            body: CustomScrollView(
              controller: controller,
              slivers: [
                SliverAppBar(
                  title: MediaCollapsedTitle(
                    controller: controller,
                    text: 'Responsive detail',
                  ),
                ),
                const SliverFillRemaining(child: SizedBox.expand()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      tester.view.physicalSize = const Size(1000, 700);
      await tester.pump();

      expect(controller.positions, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('media detail header adapts to the available screen height', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<double> headerHeightAt(Size size) async {
      tester.view.physicalSize = size;
      late double headerHeight;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              headerHeight = mediaDetailHeaderHeight(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return headerHeight;
    }

    expect(await headerHeightAt(const Size(390, 700)), 352);
    expect(await headerHeightAt(const Size(390, 800)), 368);
    expect(await headerHeightAt(const Size(390, 1000)), 384);
    expect(await headerHeightAt(const Size(1000, 700)), 304);
  });

  testWidgets('provider search results use an adaptive poster grid', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var taps = 0;

    Future<int> columnsAt(Size size, {double textScale = 1}) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ProviderSearchResultsSliver(
                  itemCount: 8,
                  itemBuilder: (context, index) => ProviderSearchResultCard(
                    key: ValueKey('provider-search-card-$index'),
                    title: 'Provider Result ${index + 1} With A Long Title',
                    subtitle: 'TV • 2026 • Releasing',
                    onTap: () => taps++,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final grid = tester.widget<SliverGrid>(
        find.byKey(const ValueKey('provider-search-results-grid')),
      );
      return (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount;
    }

    expect(await columnsAt(const Size(320, 700), textScale: 1.8), 2);
    final firstTitle = tester.widget<Text>(
      find.text('Provider Result 1 With A Long Title'),
    );
    expect(firstTitle.maxLines, 4);
    expect(firstTitle.style?.fontSize, 13);
    expect(firstTitle.style?.fontWeight, FontWeight.w600);
    expect(tester.takeException(), isNull);
    expect(await columnsAt(const Size(390, 800)), 3);
    expect(await columnsAt(const Size(800, 700)), 4);

    await tester.tap(find.byKey(const ValueKey('provider-search-card-0')));
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('media info table reflows without overflow at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: MediaInfoTable(
            rows: [
              MediaInfoRowData(
                'Episode Duration',
                'A deliberately long metadata value that must wrap',
              ),
              MediaInfoRowData('Mean Score', '92 / 100', highlight: true),
            ],
            nameBlocks: [('Name (Native)', 'とても長いネイティブタイトル')],
          ),
        ),
      ),
    );

    expect(find.text('Episode Duration'), findsOneWidget);
    expect(find.text('92 / 100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed media title switches to a marquee', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: controller,
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 300,
                title: MediaCollapsedTitle(
                  controller: controller,
                  text:
                      'The Extremely Long Anime Title That Cannot Fit the App Bar',
                  expandedHeight: 300,
                ),
                flexibleSpace: const FlexibleSpaceBar(
                  background: ColoredBox(color: Colors.black),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1000)),
            ],
          ),
        ),
      ),
    );

    final marquee = find.byKey(const ValueKey('media-collapsed-title-marquee'));
    expect(marquee, findsOneWidget);
    expect(tester.widget<MarqueeText>(marquee).animate, isFalse);

    controller.jumpTo(260);
    await tester.pump();

    expect(tester.widget<MarqueeText>(marquee).animate, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('source names and matched titles use overflow-aware marquees', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(ThemeColorPalette.anikin),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: MediaSourceSelectorTile(
              sourceName: 'A Provider Name That Is Much Too Long To Fit',
              matchedTitle:
                  'An Extremely Long Matched Anime Title From The Provider',
            ),
          ),
        ),
      ),
    );

    final sourceName = find.byKey(const ValueKey('media-source-name-marquee'));
    final matchedTitle = find.byKey(
      const ValueKey('media-source-match-marquee'),
    );
    expect(sourceName, findsOneWidget);
    expect(matchedTitle, findsOneWidget);
    expect(
      tester.widget<MarqueeText>(sourceName).text,
      'A Provider Name That Is Much Too Long To Fit',
    );
    expect(
      tester.widget<MarqueeText>(matchedTitle).text,
      'Matched as An Extremely Long Matched Anime Title From The Provider',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('next episode countdown ticks within Dantotsu window', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 7, 31, 12);
    final airingAt = now.add(
      const Duration(days: 1, hours: 2, minutes: 3, seconds: 4),
    );

    Widget buildCountdown(DateTime target) {
      return MaterialApp(
        theme: AppTheme.light(ThemeColorPalette.anikin),
        home: Scaffold(
          body: NextEpisodeCountdown(
            episode: 7,
            airingAt: target,
            now: () => now,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildCountdown(airingAt));

    expect(find.text('EPISODE 7 WILL BE RELEASED IN'), findsOneWidget);
    expect(find.text('1 days 2 hrs 3 mins 4 secs'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1 days 2 hrs 3 mins 3 secs'), findsOneWidget);

    now = airingAt;
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('next-episode-countdown')), findsNothing);

    await tester.pumpWidget(buildCountdown(now.add(const Duration(days: 29))));
    expect(find.byKey(const ValueKey('next-episode-countdown')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('episode controls fit content and keep opposite alignment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(ThemeColorPalette.anikin),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: EpisodeActionBar(
              dubbed: false,
              descending: true,
              layoutMode: EpisodeLayoutMode.semi,
              onDubbedChanged: (_) {},
              onSortPressed: () {},
              onLayoutChanged: (_) {},
              onDownloadAll: () {},
            ),
          ),
        ),
      ),
    );

    final actionBarFinder = find.byKey(const ValueKey('episode-action-bar'));
    final audioFinder = find.byKey(const ValueKey('episode-audio-selector'));
    final optionsFinder = find.byKey(const ValueKey('episode-options-button'));
    final audioSize = tester.getSize(audioFinder);
    final optionsSize = tester.getSize(optionsFinder);
    final actionBarRect = tester.getRect(actionBarFinder);
    final audioRect = tester.getRect(audioFinder);
    final optionsRect = tester.getRect(optionsFinder);
    final audioSelector = tester.widget<SegmentedButton<bool>>(audioFinder);
    final actionBar = tester.widget<Padding>(actionBarFinder);
    expect(audioSize.height, closeTo(optionsSize.height, 0.01));
    expect(audioRect.left, closeTo(actionBarRect.left, 0.01));
    expect(optionsRect.right, closeTo(actionBarRect.right, 0.01));
    expect(optionsRect.left - audioRect.right, greaterThan(8));
    expect(actionBar.padding, const EdgeInsets.symmetric(vertical: 4));
    expect(audioSelector.expandedInsets, isNull);
    expect(audioSelector.style?.tapTargetSize, MaterialTapTargetSize.padded);
    expect(tester.takeException(), isNull);
  });

  testWidgets('episode controls stay compact and options open in a dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool? dubbed;
    var sortPresses = 0;
    EpisodeLayoutMode? layout;
    var downloadPresses = 0;
    var cancelDownloadPresses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(ThemeColorPalette.anikin),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: EpisodeActionBar(
              dubbed: false,
              descending: true,
              layoutMode: EpisodeLayoutMode.semi,
              onDubbedChanged: (value) => dubbed = value,
              onSortPressed: () => sortPresses++,
              onLayoutChanged: (value) => layout = value,
              onDownloadAll: () => downloadPresses++,
              onCancelAllDownloads: () => cancelDownloadPresses++,
            ),
          ),
        ),
      ),
    );

    final actionBar = find.byKey(const ValueKey('episode-action-bar'));
    final audioSelector = find.byKey(const ValueKey('episode-audio-selector'));
    final optionsButton = find.byKey(const ValueKey('episode-options-button'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    Future<void> clickWithMouse(Finder finder) async {
      final position = tester.getCenter(finder);
      await mouse.moveTo(position);
      await tester.pump();
      await mouse.down(position);
      await mouse.up();
      await tester.pumpAndSettle();
    }

    expect(find.text('Sub'), findsOneWidget);
    expect(find.text('Dub'), findsOneWidget);
    expect(find.text('Options'), findsOneWidget);
    expect(find.byKey(const ValueKey('episode-sort-option')), findsNothing);
    expect(
      find.byKey(const ValueKey('episode-download-all-button')),
      findsNothing,
    );
    expect(tester.getSize(actionBar).width, lessThanOrEqualTo(296));
    for (final entry in {
      'audio selector': audioSelector,
      'options button': optionsButton,
    }.entries) {
      expect(
        tester.getSize(entry.value).height,
        greaterThanOrEqualTo(AppLayout.minimumTouchTarget),
        reason: '${entry.key} should preserve the app minimum target size',
      );
    }
    expect(
      tester.getSize(audioSelector).height,
      closeTo(tester.getSize(optionsButton).height, 0.01),
    );

    await tester.tap(find.text('Dub'));
    await tester.pump();
    expect(dubbed, isTrue);

    await clickWithMouse(optionsButton);
    final optionsDialog = find.byKey(const ValueKey('episode-options-dialog'));
    final sortOption = find.byKey(const ValueKey('episode-sort-option'));
    final listLayout = find.byKey(const ValueKey('episode-layout-list'));
    final downloadButton = find.byKey(
      const ValueKey('episode-download-all-button'),
    );
    final cancelDownloadsButton = find.byKey(
      const ValueKey('episode-cancel-all-downloads-button'),
    );

    expect(optionsDialog, findsOneWidget);
    expect(find.text('Episode options'), findsOneWidget);
    expect(find.text('Compact grid'), findsOneWidget);
    expect(find.text('Newest first'), findsOneWidget);
    expect(find.text('Download all episodes'), findsOneWidget);
    expect(find.text('Cancel all episode downloads'), findsOneWidget);
    for (final entry in {
      'sort option': sortOption,
      'list layout option': listLayout,
      'download button': downloadButton,
      'cancel downloads button': cancelDownloadsButton,
    }.entries) {
      expect(
        tester.getSize(entry.value).height,
        greaterThanOrEqualTo(AppLayout.minimumTouchTarget),
        reason: '${entry.key} should preserve the app minimum target size',
      );
    }

    await tester.ensureVisible(sortOption);
    await tester.pumpAndSettle();
    await tester.tap(sortOption);
    await tester.pump();
    await tester.ensureVisible(listLayout);
    await tester.pumpAndSettle();
    await tester.tap(listLayout);
    await tester.pump();
    expect(find.text('Oldest first'), findsOneWidget);
    expect(find.text('List view'), findsOneWidget);
    expect(sortPresses, 0);
    expect(layout, isNull);

    await clickWithMouse(find.byKey(const ValueKey('episode-options-cancel')));
    expect(optionsDialog, findsNothing);
    expect(sortPresses, 0);
    expect(layout, isNull);

    await clickWithMouse(optionsButton);
    await tester.ensureVisible(
      find.byKey(const ValueKey('episode-sort-option')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('episode-sort-option')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('episode-layout-list')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('episode-layout-list')));
    await clickWithMouse(find.byKey(const ValueKey('episode-options-apply')));
    expect(sortPresses, 1);
    expect(layout, EpisodeLayoutMode.list);

    await clickWithMouse(optionsButton);
    await tester.ensureVisible(downloadButton);
    await tester.pumpAndSettle();
    await clickWithMouse(downloadButton);
    expect(downloadPresses, 1);
    expect(optionsDialog, findsNothing);

    await clickWithMouse(optionsButton);
    await tester.ensureVisible(cancelDownloadsButton);
    await tester.pumpAndSettle();
    await clickWithMouse(cancelDownloadsButton);
    expect(cancelDownloadPresses, 1);
    expect(optionsDialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('episode options dialog supports intrinsic sizing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(431, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(ThemeColorPalette.anikin),
        home: Scaffold(
          body: Center(
            child: EpisodeActionBar(
              dubbed: false,
              descending: true,
              layoutMode: EpisodeLayoutMode.semi,
              onDubbedChanged: (_) {},
              onSortPressed: () {},
              onLayoutChanged: (_) {},
              onDownloadAll: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('episode-options-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('episode-options-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('media list action stays compact beneath the title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Widget buildHeader({required bool active}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: kMediaDetailHeaderHeight,
            child: MediaDetailHeader(
              title: 'Compact List Action',
              statusText: 'Releasing',
              listButtonLabel: active ? 'Watching' : 'Add to list',
              listButtonActive: active,
              onListButtonPressed: () {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildHeader(active: false));

    final button = find.widgetWithText(OutlinedButton, 'Add to list');
    expect(button, findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(tester.getSize(button).width, lessThan(200));
    expect(
      tester.getTopLeft(button).dx,
      closeTo(tester.getTopLeft(find.text('Compact List Action')).dx, 1),
    );
    expect(
      tester.getTopLeft(button).dy,
      greaterThan(tester.getBottomLeft(find.text('Releasing')).dy),
    );

    await tester.pumpWidget(buildHeader(active: true));
    expect(find.widgetWithText(OutlinedButton, 'Watching'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'anime defaults to Watch and detail selections survive a service reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = PreferencesService();
      await preferences.load();

      expect(
        preferences.detailSectionIndex(mediaKind: 'anime', mediaId: 42),
        1,
      );
      expect(
        preferences.detailSectionIndex(mediaKind: 'manga', mediaId: 91),
        0,
      );

      await preferences.setDetailSectionIndex(
        mediaKind: 'anime',
        mediaId: 42,
        index: 0,
      );
      await preferences.setDetailSectionIndex(
        mediaKind: 'manga',
        mediaId: 91,
        index: 1,
      );
      await preferences.setMangaReadingProgress(
        MangaReadingProgress(
          mediaId: 91,
          chapterId: 'chapter-4',
          chapterNumber: 4,
          pageIndex: 7,
          pageCount: 20,
          completed: false,
          updatedAtMs: 1234,
        ),
      );

      final reloaded = PreferencesService();
      await reloaded.load();
      final progress = reloaded.mangaProgressFor(91);

      expect(reloaded.detailSectionIndex(mediaKind: 'anime', mediaId: 42), 0);
      expect(reloaded.detailSectionIndex(mediaKind: 'manga', mediaId: 91), 1);
      expect(progress?.chapterId, 'chapter-4');
      expect(progress?.pageIndex, 7);
      expect(progress?.pageFraction, closeTo(0.4, 0.001));
      expect(progress?.completed, isFalse);
    },
  );

  testWidgets('anime tabs reset scroll while preserving the selected tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();
    final tracking = TrackingService(listenForLinks: false);
    final watchHistory = WatchHistoryService();
    final downloads = DownloadService();
    addTearDown(tracking.dispose);
    addTearDown(watchHistory.dispose);
    addTearDown(downloads.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DetailScreen(
          media: AniListMedia(
            id: 76,
            title: const MediaTitle(english: 'Fresh Anime Position'),
            cover: const MediaCover(),
            description: List.filled(
              40,
              'A detailed anime synopsis used to make the info tab scroll.',
            ).join(' '),
            episodes: 60,
          ),
          preferences: preferences,
          juroService: _ScrollableAnimeJuroService(),
          watchHistoryService: watchHistory,
          downloadService: downloads,
          trackingService: tracking,
          initialProvider: _ScrollableAnimeJuroService.provider,
          initialProviderAnime: const JuroAnimeInfo(
            id: 'anime-76',
            title: 'Fresh Anime Position',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detailView = find.descendant(
      of: find.byType(DetailScreen),
      matching: find.byType(CustomScrollView),
    );
    final controller = tester.widget<CustomScrollView>(detailView).controller!;
    expect(controller.keepScrollOffset, isFalse);
    expect(controller.offset, closeTo(0, 1));

    final watchStart =
        (mediaDetailHeaderHeight(tester.element(find.byType(DetailScreen))) -
                kToolbarHeight)
            .clamp(0.0, controller.position.maxScrollExtent);
    await tester.drag(detailView, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(watchStart + 100));

    await tester.tap(find.bySemanticsLabel('Info'));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 1));

    await tester.tap(find.bySemanticsLabel('Watch'));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(watchStart, 1));

    await tester.tap(find.bySemanticsLabel('Watch'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.offset, closeTo(watchStart, 1));
    expect(preferences.detailSectionIndex(mediaKind: 'anime', mediaId: 76), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manga tabs reset scroll while preserving the selected tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();
    await preferences.setDetailSectionIndex(
      mediaKind: 'manga',
      mediaId: 77,
      index: 1,
    );
    final tracking = TrackingService(listenForLinks: false);
    addTearDown(tracking.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MangaDetailScreen(
          media: AniListMedia(
            id: 77,
            title: const MediaTitle(english: 'Fresh Manga Position'),
            cover: const MediaCover(),
            description: List.filled(
              40,
              'A detailed manga synopsis used to make the info tab scroll.',
            ).join(' '),
            chapters: 60,
          ),
          preferences: preferences,
          juroService: _ScrollableMangaJuroService(),
          mangaDownloadService: _NoopMangaDownloadService(),
          trackingService: tracking,
          initialProvider: _ScrollableMangaJuroService.provider,
          initialProviderManga: const MangaResult(
            id: 'manga-77',
            title: 'Fresh Manga Position',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detailView = find.descendant(
      of: find.byType(MangaDetailScreen),
      matching: find.byType(CustomScrollView),
    );
    final controller = tester.widget<CustomScrollView>(detailView).controller!;
    expect(controller.keepScrollOffset, isFalse);
    expect(controller.offset, closeTo(0, 1));

    await tester.tap(find.bySemanticsLabel('Info'));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 1));

    await tester.drag(detailView, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(50));

    final requestedReadStart =
        mediaDetailHeaderHeight(
          tester.element(find.byType(MangaDetailScreen)),
        ) -
        kToolbarHeight;
    await tester.tap(find.bySemanticsLabel('Read'));
    await tester.pumpAndSettle();
    final readStart = requestedReadStart.clamp(
      0.0,
      controller.position.maxScrollExtent,
    );
    expect(controller.offset, closeTo(readStart, 1));

    await tester.tap(find.bySemanticsLabel('Read'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.offset, closeTo(readStart, 1));

    await tester.tap(find.bySemanticsLabel('Info'));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 1));
    expect(preferences.detailSectionIndex(mediaKind: 'manga', mediaId: 77), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manga source loading does not replace the detail shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();
    final tracking = TrackingService(listenForLinks: false);
    addTearDown(tracking.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MangaDetailScreen(
          media: const AniListMedia(
            id: 73,
            title: MediaTitle(english: 'Persistent Info'),
            cover: MediaCover(),
            meanScore: 88,
            chapters: 10,
          ),
          preferences: preferences,
          juroService: _PendingMangaJuroService(),
          mangaDownloadService: _NoopMangaDownloadService(),
          trackingService: tracking,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Persistent Info'), findsWidgets);
    expect(find.byType(MediaDetailNavBar), findsOneWidget);
    expect(find.text('Mean Score', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Loading manga providers', skipOffstage: false),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('manga provider errors stay inside the Read tab', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesService();
    await preferences.load();
    final tracking = TrackingService(listenForLinks: false);
    addTearDown(tracking.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MangaDetailScreen(
          media: const AniListMedia(
            id: 74,
            title: MediaTitle(english: 'Offline Manga'),
            cover: MediaCover(),
            meanScore: 80,
          ),
          preferences: preferences,
          juroService: _FailingMangaJuroService(),
          mangaDownloadService: _NoopMangaDownloadService(),
          trackingService: tracking,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mean Score', skipOffstage: false), findsOneWidget);
    expect(find.byType(AppErrorView), findsNothing);

    await tester.tap(find.bySemanticsLabel('Read'));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.textContaining('Manga source unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paged manga reader records partial local progress', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'mangaKeepScreenOn': false,
      'mangaReadingMode': MangaReadingMode.leftToRight.index,
    });
    final preferences = PreferencesService();
    await preferences.load();
    final tracking = TrackingService(listenForLinks: false);
    addTearDown(tracking.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MangaReaderScreen(
          media: const AniListMedia(
            id: 75,
            title: MediaTitle(english: 'Progress Manga'),
            cover: MediaCover(),
            chapters: 3,
          ),
          mangaInfo: const MangaInfo(id: 'manga-75', title: 'Progress Manga'),
          chapter: const MangaChapter(id: 'chapter-1', number: 1),
          chapters: const [MangaChapter(id: 'chapter-1', number: 1)],
          preferences: preferences,
          juroService: _ReaderMangaJuroService(),
          mangaDownloadService: _NoopMangaDownloadService(),
          trackingService: tracking,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    final progress = preferences.mangaProgressFor(75);
    expect(progress?.chapterId, 'chapter-1');
    expect(progress?.pageIndex, 1);
    expect(progress?.pageCount, 3);
    expect(progress?.completed, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _PendingMangaJuroService extends JuroService {
  final Completer<List<SourceProvider>> providers = Completer();

  @override
  Future<List<SourceProvider>> getMangaProviders() => providers.future;
}

class _ScrollableAnimeJuroService extends JuroService {
  static const provider = SourceProvider(key: 'fixture', name: 'Fixture');

  @override
  Future<List<SourceProvider>> getProviders() async => const [provider];

  @override
  Future<List<AnimeEpisode>> getEpisodes(
    String animeId, {
    required String providerKey,
  }) async {
    return List.generate(
      60,
      (index) => AnimeEpisode(id: 'episode-${index + 1}', number: index + 1),
    );
  }
}

class _ScrollableMangaJuroService extends JuroService {
  static const provider = SourceProvider(
    key: 'manga-fixture',
    name: 'Manga Fixture',
    type: 1,
  );

  @override
  Future<List<SourceProvider>> getMangaProviders() async => const [provider];

  @override
  Future<MangaInfo> getMangaInfo(
    String mangaId, {
    required String providerKey,
  }) async {
    return MangaInfo(
      id: mangaId,
      title: 'Fresh Manga Position',
      chapters: List.generate(
        60,
        (index) => MangaChapter(id: 'chapter-${index + 1}', number: index + 1),
      ),
    );
  }
}

class _FailingMangaJuroService extends JuroService {
  @override
  Future<List<SourceProvider>> getMangaProviders() async {
    throw StateError('Manga source unavailable');
  }
}

class _ReaderMangaJuroService extends JuroService {
  @override
  Future<List<MangaChapterPage>> getChapterPages(
    String chapterId, {
    required String providerKey,
  }) async {
    return const [
      MangaChapterPage(image: 'missing-page-1.jpg', page: 1),
      MangaChapterPage(image: 'missing-page-2.jpg', page: 2),
      MangaChapterPage(image: 'missing-page-3.jpg', page: 3),
    ];
  }
}

class _NoopMangaDownloadService extends MangaDownloadService {
  @override
  Future<List<MangaChapterPage>?> pagesFor(String id) async => null;

  @override
  Future<void> load() async {}
}
