import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/anilist_media.dart';
import '../models/downloaded_manga.dart';
import '../models/juro_models.dart';
import '../models/tracking.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../services/window_service.dart';
import '../widgets/app_bottom_sheet.dart';
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
    this.providerKey,
    this.providerName,
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
  final String? providerKey;
  final String? providerName;

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen> {
  late MangaChapter _chapter;
  late Future<List<MangaChapterPage>> _pagesFuture;
  late final PageController _pageController;
  final _webtoonController = ScrollController();
  final _keyboardFocusNode = FocusNode(debugLabel: 'Reader shortcuts');
  final Set<String> _precacheUrls = {};
  final Set<String> _syncedChapterIds = {};
  int _pageIndex = 0;
  int _pageCount = 0;
  String? _lastPersistedProgress;
  String? _restoredChapterId;
  bool _chromeVisible = true;
  bool _readerWakelockEnabled = false;

  int get _chapterIndex =>
      widget.chapters.indexWhere((chapter) => chapter.id == _chapter.id);

  bool get _canGoPrevious => _chapterIndex > 0;

  bool get _canGoNext =>
      _chapterIndex >= 0 && _chapterIndex < widget.chapters.length - 1;

  String get _providerKey =>
      widget.providerKey ?? widget.preferences.lastMangaProviderKey;

  String get _providerName =>
      widget.providerName ??
      widget.preferences.lastMangaProviderName ??
      _providerKey;

  @override
  void initState() {
    super.initState();
    _chapter = widget.chapter;
    final saved = widget.preferences.mangaProgressFor(widget.media.id);
    if (saved?.chapterId == _chapter.id) {
      _pageIndex = saved!.pageIndex;
    }
    _pageController = PageController(initialPage: _pageIndex);
    _webtoonController.addListener(_handleWebtoonScroll);
    _pagesFuture = _loadPages(_chapter);
    _syncWakelock();
  }

  @override
  void dispose() {
    if (_pageCount > 0) {
      unawaited(_recordReadingProgress(_pageIndex, _pageCount));
    }
    _pageController.dispose();
    _webtoonController.removeListener(_handleWebtoonScroll);
    _webtoonController.dispose();
    _keyboardFocusNode.dispose();
    WindowService.setFullscreen(false);
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
      providerKey: _providerKey,
    );
  }

  MangaChapterDownloadRequest _downloadRequestFor(MangaChapter chapter) {
    return MangaChapterDownloadRequest(
      media: widget.media,
      manga: widget.mangaInfo,
      chapter: chapter,
      providerKey: _providerKey,
      providerName: _providerName,
    );
  }

  void _openChapter(MangaChapter chapter) {
    final saved = widget.preferences.mangaProgressFor(widget.media.id);
    final savedPage = saved?.chapterId == chapter.id ? saved!.pageIndex : 0;
    setState(() {
      _chapter = chapter;
      _pagesFuture = _loadPages(chapter);
      _pageIndex = savedPage;
      _pageCount = 0;
      _restoredChapterId = null;
      _lastPersistedProgress = null;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(savedPage);
    }
    if (_webtoonController.hasClients) {
      _webtoonController.jumpTo(0);
    }
  }

  void _handleWebtoonScroll() {
    if (!_webtoonController.hasClients || _pageCount <= 0) {
      return;
    }
    final position = _webtoonController.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      return;
    }
    final fraction = (position.pixels / position.maxScrollExtent).clamp(0, 1);
    final index = (fraction * (_pageCount - 1)).round();
    final completed =
        position.pixels >= position.maxScrollExtent - 72 || index >= _pageCount;
    if (index != _pageIndex && mounted) {
      setState(() => _pageIndex = index);
    }
    unawaited(_recordReadingProgress(index, _pageCount, completed: completed));
  }

  void _restoreWebtoonProgress() {
    if (_restoredChapterId == _chapter.id) {
      return;
    }
    _restoredChapterId = _chapter.id;
    final saved = widget.preferences.mangaProgressFor(widget.media.id);
    if (saved?.chapterId != _chapter.id ||
        saved == null ||
        saved.pageIndex <= 0 ||
        saved.completed) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_webtoonController.hasClients ||
          _webtoonController.position.maxScrollExtent <= 0) {
        return;
      }
      final fraction = saved.pageCount <= 1
          ? 0.0
          : saved.pageIndex / (saved.pageCount - 1);
      _webtoonController.jumpTo(
        (_webtoonController.position.maxScrollExtent * fraction).clamp(
          _webtoonController.position.minScrollExtent,
          _webtoonController.position.maxScrollExtent,
        ),
      );
    });
  }

  Future<void> _recordReadingProgress(
    int pageIndex,
    int pageCount, {
    bool completed = false,
  }) async {
    if (pageCount <= 0) {
      return;
    }
    final chapter = _chapter;
    final safeIndex = pageIndex.clamp(0, pageCount - 1).toInt();
    final isComplete = completed || safeIndex >= pageCount - 1;
    final signature =
        '${chapter.id}:$safeIndex:$pageCount:${isComplete ? 1 : 0}';
    if (_lastPersistedProgress == signature) {
      return;
    }
    _lastPersistedProgress = signature;
    await widget.preferences.setMangaReadingProgress(
      MangaReadingProgress(
        mediaId: widget.media.id,
        chapterId: chapter.id,
        chapterNumber: chapter.number,
        pageIndex: safeIndex,
        pageCount: pageCount,
        completed: isComplete,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (!isComplete ||
        chapter.number < 1 ||
        !_syncedChapterIds.add(chapter.id)) {
      return;
    }
    await widget.trackingService.syncProgress(
      TrackingProgressRequest(
        media: widget.media,
        kind: TrackingMediaKind.manga,
        progress: chapter.number.floor(),
        total: widget.media.chapters,
      ),
      queueOnFailure: true,
    );
  }

  void _precachePages(List<MangaChapterPage> pages, int currentIndex) {
    final preloadCount = widget.preferences.mangaPreloadPages;
    if (!mounted || preloadCount <= 0 || pages.isEmpty) {
      return;
    }

    final candidateEnd = currentIndex + preloadCount + 1;
    final end = candidateEnd < pages.length ? candidateEnd : pages.length;
    for (var index = currentIndex + 1; index < end; index++) {
      final page = pages[index];
      final imageUrl = page.image;
      if ((!imageUrl.startsWith('http://') &&
              !imageUrl.startsWith('https://')) ||
          !_precacheUrls.add(imageUrl)) {
        continue;
      }
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(imageUrl, headers: page.headers),
          context,
        ).catchError((Object _) {}),
      );
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
    if (offset > 0 && _pageCount > 0) {
      unawaited(
        _recordReadingProgress(_pageCount - 1, _pageCount, completed: true),
      );
    }
    _openChapter(widget.chapters[nextIndex]);
  }

  void _goPageRelative(int offset) {
    if (widget.preferences.mangaReadingMode == MangaReadingMode.webtoon) {
      _scrollWebtoonRelative(offset > 0 ? 560 : -560);
      return;
    }

    if (!_pageController.hasClients || _pageCount == 0) {
      return;
    }

    final currentPage = (_pageController.page ?? _pageIndex).round();
    final nextPage = (currentPage + offset).clamp(0, _pageCount - 1).toInt();
    if (nextPage == currentPage) {
      return;
    }

    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _goVisualPageRelative(int offset) {
    final adjustedOffset =
        widget.preferences.mangaReadingMode == MangaReadingMode.rightToLeft
        ? -offset
        : offset;
    _goPageRelative(adjustedOffset);
  }

  void _scrollWebtoonRelative(double offset) {
    if (!_webtoonController.hasClients) {
      return;
    }

    final position = _webtoonController.position;
    final target = (position.pixels + offset).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _webtoonController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return;
    }

    final key = event.logicalKey;
    final repeating = event is KeyRepeatEvent;

    if (!repeating &&
        (key == LogicalKeyboardKey.keyF ||
            (key == LogicalKeyboardKey.enter &&
                HardwareKeyboard.instance.isAltPressed))) {
      WindowService.toggleFullscreen();
      return;
    }

    if (!repeating && key == LogicalKeyboardKey.escape) {
      if (!_chromeVisible) {
        setState(() => _chromeVisible = true);
        return;
      }
      WindowService.setFullscreen(false);
      Navigator.of(context).maybePop();
      return;
    }

    if (!repeating && key == LogicalKeyboardKey.space) {
      setState(() => _chromeVisible = !_chromeVisible);
      return;
    }

    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL) {
      _goVisualPageRelative(1);
      return;
    }

    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      _goVisualPageRelative(-1);
      return;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _goPageRelative(1);
      return;
    }

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyK) {
      _goPageRelative(-1);
    }
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
      controller: _webtoonController,
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

        _precachePages(pages, index);
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
            onPageChanged: (index) {
              setState(() => _pageIndex = index);
              _precachePages(pages, index);
              unawaited(_recordReadingProgress(index, pages.length));
            },
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
                    child: widget.preferences.mangaShowPageNumber
                        ? Text(
                            'Page ${_pageIndex + 1} of ${pages.length}',
                            style: TextStyle(color: _readerSubtleForeground),
                          )
                        : const SizedBox.shrink(),
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
    await showAppBottomSheet<void>(
      context: context,
      initialChildSize: 0.7,
      minChildSize: 0.38,
      builder: (context, scrollController) => _ReaderSettingsSheet(
        preferences: widget.preferences,
        scrollController: scrollController,
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
                    _providerName,
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
                onRetry: () {
                  setState(() {
                    _pagesFuture = _loadPages(_chapter);
                  });
                },
              );
            }

            final pages = snapshot.data ?? const <MangaChapterPage>[];
            if (pages.isEmpty) {
              return const EmptyState(
                icon: Icons.image_not_supported_outlined,
                title: 'No pages found',
              );
            }

            _pageCount = pages.length;
            if (_pageIndex >= pages.length) {
              _pageIndex = pages.length - 1;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _pageController.hasClients) {
                  _pageController.jumpToPage(_pageIndex);
                }
              });
            }
            if (widget.preferences.mangaReadingMode ==
                MangaReadingMode.webtoon) {
              _restoreWebtoonProgress();
            } else {
              unawaited(_recordReadingProgress(_pageIndex, pages.length));
            }
            _precachePages(pages, _pageIndex - 1);
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
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: scaffold,
      ),
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
    required this.scrollController,
    required this.onChanged,
  });

  final PreferencesService preferences;
  final ScrollController scrollController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: preferences,
        builder: (context, _) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Text(
              'Reader settings',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.numbers_outlined),
              title: const Text('Show page number'),
              value: preferences.mangaShowPageNumber,
              onChanged: (value) async {
                await preferences.setMangaShowPageNumber(value);
                onChanged();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cached_outlined),
              title: const Text('Pages to preload'),
              subtitle: Slider(
                min: 0,
                max: 12,
                divisions: 6,
                value: preferences.mangaPreloadPages.toDouble(),
                label: preferences.mangaPreloadPages == 0
                    ? 'Off'
                    : preferences.mangaPreloadPages.toString(),
                onChanged: (value) async {
                  await preferences.setMangaPreloadPages(value.round());
                  onChanged();
                },
              ),
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
              fontWeight: FontWeight.w700,
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
