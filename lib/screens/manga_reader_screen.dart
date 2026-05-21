import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/anilist_media.dart';
import '../models/downloaded_manga.dart';
import '../models/juro_models.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../widgets/app_error_view.dart';

class MangaReaderScreen extends StatefulWidget {
  const MangaReaderScreen({
    required this.media,
    required this.mangaInfo,
    required this.chapter,
    required this.chapters,
    required this.preferences,
    required this.juroService,
    required this.mangaDownloadService,
    required this.trackingService,
    super.key,
  });

  final AniListMedia media;
  final MangaInfo mangaInfo;
  final MangaChapter chapter;
  final List<MangaChapter> chapters;
  final PreferencesService preferences;
  final JuroService juroService;
  final MangaDownloadService mangaDownloadService;
  final TrackingService trackingService;

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  late MangaChapter _chapter;
  late Future<List<MangaChapterPage>> _pagesFuture;
  final _pageController = PageController();
  int _pageIndex = 0;
  bool _chromeVisible = true;
  bool _readerWakelockEnabled = false;

  int get _chapterIndex =>
      widget.chapters.indexWhere((chapter) => chapter.id == _chapter.id);

  bool get _canGoPrevious => _chapterIndex > 0;

  bool get _canGoNext =>
      _chapterIndex >= 0 && _chapterIndex < widget.chapters.length - 1;

  @override
  void initState() {
    super.initState();
    _chapter = widget.chapter;
    _pagesFuture = _loadPages(_chapter);
    _syncWakelock();
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (_readerWakelockEnabled) {
      WakelockPlus.disable();
    }
    super.dispose();
  }

  Future<List<MangaChapterPage>> _loadPages(MangaChapter chapter) async {
    final request = _downloadRequestFor(chapter);
    final offlinePages = await widget.mangaDownloadService.pagesFor(request.id);
    if (offlinePages != null && offlinePages.isNotEmpty) {
      return offlinePages;
    }

    return widget.juroService.getChapterPages(
      chapter.id,
      providerKey: widget.preferences.lastMangaProviderKey,
    );
  }

  MangaChapterDownloadRequest _downloadRequestFor(MangaChapter chapter) {
    return MangaChapterDownloadRequest(
      media: widget.media,
      manga: widget.mangaInfo,
      chapter: chapter,
      providerKey: widget.preferences.lastMangaProviderKey,
      providerName:
          widget.preferences.lastMangaProviderName ??
          widget.preferences.lastMangaProviderKey,
    );
  }

  void _openChapter(MangaChapter chapter) {
    setState(() {
      _chapter = chapter;
      _pagesFuture = _loadPages(chapter);
      _pageIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Future<void> _syncWakelock() async {
    if (widget.preferences.mangaKeepScreenOn) {
      _readerWakelockEnabled = true;
      await WakelockPlus.enable();
    } else if (_readerWakelockEnabled) {
      _readerWakelockEnabled = false;
      await WakelockPlus.disable();
    }
  }

  void _goRelative(int offset) {
    final index = _chapterIndex;
    if (index < 0) {
      return;
    }
    final nextIndex = index + offset;
    if (nextIndex < 0 || nextIndex >= widget.chapters.length) {
      return;
    }
    _openChapter(widget.chapters[nextIndex]);
  }

  Widget _buildPages(List<MangaChapterPage> pages) {
    return switch (widget.preferences.mangaReadingMode) {
      MangaReadingMode.webtoon => _buildWebtoonPages(pages),
      MangaReadingMode.leftToRight => _buildPagedPages(pages, reverse: false),
      MangaReadingMode.rightToLeft => _buildPagedPages(pages, reverse: true),
    };
  }

  Widget _buildWebtoonPages(List<MangaChapterPage> pages) {
    final gap = widget.preferences.mangaPageGap;
    return ListView.builder(
      padding: EdgeInsets.only(
        top: _chromeVisible ? 8 : MediaQuery.paddingOf(context).top + 8,
        bottom: MediaQuery.paddingOf(context).bottom + 18,
      ),
      itemCount: pages.length + 1,
      itemBuilder: (context, index) {
        if (index == pages.length) {
          return _ReaderFooter(
            chapter: _chapter,
            currentIndex: _chapterIndex,
            totalChapters: widget.chapters.length,
            canGoPrevious: _canGoPrevious,
            canGoNext: _canGoNext,
            textColor: _readerForeground,
            subtleTextColor: _readerSubtleForeground,
            onPrevious: () => _goRelative(-1),
            onNext: () => _goRelative(1),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(vertical: gap / 2),
          child: _ReaderPageImage(
            page: pages[index],
            pageNumber: index + 1,
            fit: _imageFit,
            backgroundColor: _pagePlaceholderColor,
          ),
        );
      },
    );
  }

  Widget _buildPagedPages(
    List<MangaChapterPage> pages, {
    required bool reverse,
  }) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 14;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            reverse: reverse,
            itemCount: pages.length,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.all(widget.preferences.mangaPageGap),
              child: Center(
                child: _ReaderPageImage(
                  page: pages[index],
                  pageNumber: index + 1,
                  fit: _imageFit,
                  backgroundColor: _pagePlaceholderColor,
                ),
              ),
            ),
          ),
        ),
        if (_chromeVisible)
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Page ${_pageIndex + 1} of ${pages.length}',
                      style: TextStyle(color: _readerSubtleForeground),
                    ),
                  ),
                  Text(
                    _chapter.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _readerForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  BoxFit get _imageFit => switch (widget.preferences.mangaPageFitMode) {
    MangaPageFitMode.width => BoxFit.fitWidth,
    MangaPageFitMode.contain => BoxFit.contain,
  };

  Color get _readerBackground =>
      switch (widget.preferences.mangaReaderBackground) {
        MangaReaderBackground.black => Colors.black,
        MangaReaderBackground.dark => const Color(0xFF121212),
        MangaReaderBackground.gray => const Color(0xFF777777),
        MangaReaderBackground.white => Colors.white,
      };

  Color get _pagePlaceholderColor =>
      switch (widget.preferences.mangaReaderBackground) {
        MangaReaderBackground.white => const Color(0xFFEAEAEA),
        MangaReaderBackground.gray => const Color(0xFF666666),
        MangaReaderBackground.black => const Color(0xFF111111),
        MangaReaderBackground.dark => const Color(0xFF1C1C1C),
      };

  Color get _readerForeground =>
      widget.preferences.mangaReaderBackground == MangaReaderBackground.white
      ? Colors.black
      : Colors.white;

  Color get _readerSubtleForeground =>
      widget.preferences.mangaReaderBackground == MangaReaderBackground.white
      ? Colors.black54
      : Colors.white70;

  Future<void> _showReaderSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ReaderSettingsSheet(
        preferences: widget.preferences,
        onChanged: () {
          setState(() {});
          _syncWakelock();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = _readerBackground;
    final scaffold = Scaffold(
      backgroundColor: background,
      appBar: _chromeVisible
          ? AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _chapter.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.preferences.lastMangaProviderName ??
                        widget.preferences.lastMangaProviderKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Reader settings',
                  onPressed: _showReaderSettings,
                  icon: const Icon(Icons.tune),
                ),
                IconButton(
                  tooltip: 'Previous chapter',
                  onPressed: _canGoPrevious ? () => _goRelative(-1) : null,
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton(
                  tooltip: 'Next chapter',
                  onPressed: _canGoNext ? () => _goRelative(1) : null,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _chromeVisible = !_chromeVisible),
        child: FutureBuilder<List<MangaChapterPage>>(
          future: _pagesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return AppErrorView(
                message: snapshot.error.toString(),
                onRetry: () =>
                    setState(() => _pagesFuture = _loadPages(_chapter)),
              );
            }

            final pages = snapshot.data ?? const <MangaChapterPage>[];
            if (pages.isEmpty) {
              return const EmptyState(
                icon: Icons.image_not_supported_outlined,
                title: 'No pages found',
              );
            }

            return _buildPages(pages);
          },
        ),
      ),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(surface: Colors.black, onSurface: Colors.white),
      ),
      child: scaffold,
    );
  }
}

class _ReaderPageImage extends StatelessWidget {
  const _ReaderPageImage({
    required this.page,
    required this.pageNumber,
    required this.fit,
    required this.backgroundColor,
  });

  final MangaChapterPage page;
  final int pageNumber;
  final BoxFit fit;
  final Color backgroundColor;

  bool get _isLocal =>
      !page.image.startsWith('http://') && !page.image.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: _isLocal
          ? Image.file(
              File(page.image),
              width: double.infinity,
              fit: fit,
              errorBuilder: (context, _, _) => _ReaderPageError(
                pageNumber: pageNumber,
                backgroundColor: backgroundColor,
              ),
            )
          : CachedNetworkImage(
              imageUrl: page.image,
              httpHeaders: page.headers,
              width: double.infinity,
              fit: fit,
              placeholder: (context, _) => AspectRatio(
                aspectRatio: 0.68,
                child: ColoredBox(
                  color: backgroundColor,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
              errorWidget: (context, _, _) => _ReaderPageError(
                pageNumber: pageNumber,
                backgroundColor: backgroundColor,
              ),
            ),
    );
  }
}

class _ReaderPageError extends StatelessWidget {
  const _ReaderPageError({
    required this.pageNumber,
    required this.backgroundColor,
  });

  final int pageNumber;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.68,
      child: ColoredBox(
        color: backgroundColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, color: Colors.white70),
              const SizedBox(height: 8),
              Text(
                'Page $pageNumber failed to load',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderSettingsSheet extends StatelessWidget {
  const _ReaderSettingsSheet({
    required this.preferences,
    required this.onChanged,
  });

  final PreferencesService preferences;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: preferences,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Text(
              'Reader settings',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Text('Reading mode', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<MangaReadingMode>(
              segments: const [
                ButtonSegment(
                  value: MangaReadingMode.webtoon,
                  icon: Icon(Icons.vertical_align_bottom),
                  label: Text('Webtoon'),
                ),
                ButtonSegment(
                  value: MangaReadingMode.leftToRight,
                  icon: Icon(Icons.swipe_right_alt),
                  label: Text('LTR'),
                ),
                ButtonSegment(
                  value: MangaReadingMode.rightToLeft,
                  icon: Icon(Icons.swipe_left_alt),
                  label: Text('RTL'),
                ),
              ],
              selected: {preferences.mangaReadingMode},
              onSelectionChanged: (value) async {
                await preferences.setMangaReadingMode(value.single);
                onChanged();
              },
            ),
            const SizedBox(height: 18),
            Text('Page fit', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<MangaPageFitMode>(
              segments: const [
                ButtonSegment(
                  value: MangaPageFitMode.width,
                  icon: Icon(Icons.fit_screen),
                  label: Text('Width'),
                ),
                ButtonSegment(
                  value: MangaPageFitMode.contain,
                  icon: Icon(Icons.fullscreen),
                  label: Text('Contain'),
                ),
              ],
              selected: {preferences.mangaPageFitMode},
              onSelectionChanged: (value) async {
                await preferences.setMangaPageFitMode(value.single);
                onChanged();
              },
            ),
            const SizedBox(height: 18),
            Text('Background', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<MangaReaderBackground>(
              segments: const [
                ButtonSegment(
                  value: MangaReaderBackground.black,
                  label: Text('Black'),
                ),
                ButtonSegment(
                  value: MangaReaderBackground.dark,
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: MangaReaderBackground.gray,
                  label: Text('Gray'),
                ),
                ButtonSegment(
                  value: MangaReaderBackground.white,
                  label: Text('White'),
                ),
              ],
              selected: {preferences.mangaReaderBackground},
              onSelectionChanged: (value) async {
                await preferences.setMangaReaderBackground(value.single);
                onChanged();
              },
            ),
            const SizedBox(height: 18),
            Text('Page gap', style: Theme.of(context).textTheme.labelLarge),
            Slider(
              value: preferences.mangaPageGap,
              min: 0,
              max: 24,
              divisions: 12,
              label: preferences.mangaPageGap.round().toString(),
              onChanged: (value) async {
                await preferences.setMangaPageGap(value);
                onChanged();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.lightbulb_outline),
              title: const Text('Keep screen on'),
              value: preferences.mangaKeepScreenOn,
              onChanged: (value) async {
                await preferences.setMangaKeepScreenOn(value);
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderFooter extends StatelessWidget {
  const _ReaderFooter({
    required this.chapter,
    required this.currentIndex,
    required this.totalChapters,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.textColor,
    required this.subtleTextColor,
    required this.onPrevious,
    required this.onNext,
  });

  final MangaChapter chapter;
  final int currentIndex;
  final int totalChapters;
  final bool canGoPrevious;
  final bool canGoNext;
  final Color textColor;
  final Color subtleTextColor;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
      child: Column(
        children: [
          Text(
            chapter.displayTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          if (currentIndex >= 0)
            Text(
              '${currentIndex + 1} of $totalChapters',
              style: TextStyle(color: subtleTextColor),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 44),
                  ),
                  onPressed: canGoPrevious ? onPrevious : null,
                  icon: const Icon(Icons.skip_previous),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 44),
                  ),
                  onPressed: canGoNext ? onNext : null,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
