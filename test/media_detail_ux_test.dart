import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:anikin/models/anilist_media.dart';
import 'package:anikin/models/juro_models.dart';
import 'package:anikin/screens/manga_detail_screen.dart';
import 'package:anikin/screens/manga_reader_screen.dart';
import 'package:anikin/services/juro_service.dart';
import 'package:anikin/services/manga_download_service.dart';
import 'package:anikin/services/preferences_service.dart';
import 'package:anikin/services/tracking_service.dart';
import 'package:anikin/widgets/app_error_view.dart';
import 'package:anikin/widgets/media_detail_header.dart';
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
