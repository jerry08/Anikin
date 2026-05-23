import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/list_ranges.dart';
import '../models/anilist_media.dart';
import '../models/downloaded_manga.dart';
import '../models/juro_models.dart';
import '../models/tracking.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../widgets/anilist_list_entry_sheet.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_error_view.dart';
import '../widgets/detail_media_tools.dart';
import '../widgets/list_range_selector.dart';
import 'manga_reader_screen.dart';

class MangaDetailScreen extends StatefulWidget {
  const MangaDetailScreen({
    required this.media,
    required this.preferences,
    required this.juroService,
    required this.mangaDownloadService,
    required this.trackingService,
    super.key,
  });

  final AniListMedia media;
  final PreferencesService preferences;
  final JuroService juroService;
  final MangaDownloadService mangaDownloadService;
  final TrackingService trackingService;

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  List<SourceProvider> _providers = [];
  MangaResult? _providerManga;
  MangaInfo? _mangaInfo;
  List<MangaChapter> _chapters = [];
  bool _loading = true;
  bool _isFavorite = false;
  bool _favoriteLoading = false;
  AniListMediaListEntry? _listEntry;
  bool _listEntryLoading = false;
  bool _listEntrySaving = false;
  int _chapterRangeIndex = 0;
  String? _error;
  String? _status;

  String get _providerKey => widget.preferences.lastMangaProviderKey;

  List<MangaChapter> get _displayChapters {
    final chapters = List<MangaChapter>.of(_chapters);
    chapters.sort((a, b) => a.number.compareTo(b.number));
    if (widget.preferences.mangaChaptersDescending) {
      return chapters.reversed.toList();
    }
    return chapters;
  }

  List<ListRange> get _chapterRanges =>
      buildNumberedListRanges(_displayChapters, (chapter) => chapter.number);

  List<MangaChapter> get _visibleChapters =>
      applyListRange(_displayChapters, _chapterRanges, _chapterRangeIndex);

  @override
  void initState() {
    super.initState();
    _load();
    _refreshFavorite();
    _refreshAniListListEntry();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Loading manga providers';
      _chapters = [];
      _chapterRangeIndex = 0;
    });

    try {
      _providers = await widget.juroService.getMangaProviders();
      if (_providers.isNotEmpty &&
          !_providers.any((item) => item.key == _providerKey)) {
        final provider = _providers.first;
        await widget.preferences.setLastMangaProvider(
          SourceProviderChoice(key: provider.key, name: provider.name),
        );
      }

      await _autoMatchAndLoadChapters();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _autoMatchAndLoadChapters() async {
    setState(() => _status = 'Searching ${widget.media.displayTitle}');
    MangaResult? match;

    for (final title in widget.media.title.searchCandidates) {
      final results = await widget.juroService.searchManga(
        title,
        providerKey: _providerKey,
      );
      if (results.isNotEmpty) {
        match = results.first;
        break;
      }
    }

    if (match == null) {
      setState(() {
        _providerManga = null;
        _mangaInfo = null;
        _chapters = [];
        _chapterRangeIndex = 0;
        _status = 'No source match found';
      });
      return;
    }

    await _loadChapters(match);
  }

  Future<void> _loadChapters(MangaResult manga) async {
    setState(() {
      _providerManga = manga;
      _status =
          'Loading chapters from ${widget.preferences.lastMangaProviderName ?? _providerKey}';
    });

    final info = await widget.juroService.getMangaInfo(
      manga.id,
      providerKey: _providerKey,
    );

    setState(() {
      _mangaInfo = info;
      _chapters = info.chapters;
      _chapterRangeIndex = 0;
      _status = info.chapters.isEmpty ? 'No chapters found' : null;
    });
  }

  Future<void> _changeProvider() async {
    final provider = await showAppBottomSheet<SourceProvider>(
      context: context,
      initialChildSize: 0.42,
      minChildSize: 0.28,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Text(
              'Manga provider',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          for (final provider in _providers)
            ListTile(
              leading: Icon(
                provider.key == _providerKey
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(provider.name),
              subtitle: Text(provider.language),
              onTap: () => Navigator.of(context).pop(provider),
            ),
        ],
      ),
    );

    if (provider == null) {
      return;
    }

    await widget.preferences.setLastMangaProvider(
      SourceProviderChoice(key: provider.key, name: provider.name),
    );
    await _load();
  }

  Future<void> _manualMatch() async {
    final match = await showAppBottomSheet<MangaResult>(
      context: context,
      initialChildSize: 0.72,
      minChildSize: 0.34,
      maxChildSize: 1,
      builder: (context, scrollController) => _ManualMangaSearchSheet(
        initialQuery: widget.media.displayTitle,
        providerKey: _providerKey,
        juroService: widget.juroService,
        scrollController: scrollController,
      ),
    );

    if (match == null) {
      return;
    }

    try {
      await _loadChapters(match);
    } catch (error) {
      if (mounted) {
        setState(() => _status = null);
        await showErrorDialog(context, error, title: 'Provider search failed');
      }
    }
  }

  void _openChapter(MangaChapter chapter) {
    final info = _mangaInfo;
    if (info == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MangaReaderScreen(
          media: widget.media,
          mangaInfo: info,
          chapter: chapter,
          chapters: _displayChapters,
          preferences: widget.preferences,
          juroService: widget.juroService,
          mangaDownloadService: widget.mangaDownloadService,
          trackingService: widget.trackingService,
        ),
      ),
    );
  }

  MangaChapterDownloadRequest? _downloadRequestFor(MangaChapter chapter) {
    final info = _mangaInfo;
    if (info == null) {
      return null;
    }
    return MangaChapterDownloadRequest(
      media: widget.media,
      manga: info,
      chapter: chapter,
      providerKey: _providerKey,
      providerName: widget.preferences.lastMangaProviderName ?? _providerKey,
    );
  }

  Future<void> _downloadChapter(MangaChapter chapter) async {
    final request = _downloadRequestFor(chapter);
    if (request == null) {
      return;
    }
    try {
      await widget.mangaDownloadService.startDownload(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading ${chapter.displayTitle}')),
        );
      }
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error, title: 'Chapter download failed');
      }
    }
  }

  Future<void> _downloadAllChapters() async {
    final chapters = _displayChapters;
    if (_mangaInfo == null || chapters.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Queueing ${chapters.length} chapters')),
    );

    var queued = 0;
    var failed = 0;
    Object? firstError;
    for (final chapter in chapters) {
      try {
        final request = _downloadRequestFor(chapter);
        if (request == null ||
            widget.mangaDownloadService.isDownloaded(request.id)) {
          continue;
        }
        await widget.mangaDownloadService.startDownload(request);
        queued++;
      } catch (error) {
        firstError ??= error;
        failed++;
      }
    }

    if (mounted) {
      if (failed == 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Queued $queued chapters')));
      } else {
        await showErrorDialog(
          context,
          firstError ?? 'Queued $queued chapters, $failed failed.',
          title: 'Some chapters failed',
        );
      }
    }
  }

  Future<void> _openAniList() async {
    final siteUrl = widget.media.siteUrl;
    if (siteUrl == null) {
      return;
    }
    final uri = Uri.parse(siteUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _refreshFavorite() async {
    if (!widget.trackingService.isLoggedIn(TrackingProvider.anilist)) {
      return;
    }
    try {
      final favorite = await widget.trackingService.isAniListFavorite(
        media: widget.media,
        kind: TrackingMediaKind.manga,
      );
      if (mounted) {
        setState(() => _isFavorite = favorite);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteLoading) {
      return;
    }
    if (!widget.trackingService.isLoggedIn(TrackingProvider.anilist)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to AniList to sync favorites')),
      );
      return;
    }
    setState(() {
      _favoriteLoading = true;
      _isFavorite = !_isFavorite;
    });
    try {
      final favorite = await widget.trackingService.toggleAniListFavorite(
        media: widget.media,
        kind: TrackingMediaKind.manga,
      );
      if (mounted) {
        setState(() => _isFavorite = favorite);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isFavorite = !_isFavorite);
        await showErrorDialog(context, error, title: 'Favorite sync failed');
      }
    } finally {
      if (mounted) {
        setState(() => _favoriteLoading = false);
      }
    }
  }

  Future<void> _refreshAniListListEntry({bool showErrors = false}) async {
    if (!widget.trackingService.isLoggedIn(TrackingProvider.anilist)) {
      if (mounted) {
        setState(() => _listEntry = null);
      }
      return;
    }
    if (mounted) {
      setState(() => _listEntryLoading = true);
    }
    try {
      final entry = await widget.trackingService.aniListMediaListEntry(
        media: widget.media,
        kind: TrackingMediaKind.manga,
      );
      if (mounted) {
        setState(() => _listEntry = entry);
      }
    } catch (error) {
      if (mounted && showErrors) {
        await showErrorDialog(
          context,
          error,
          title: 'AniList list sync failed',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _listEntryLoading = false);
      }
    }
  }

  Future<void> _editAniListListEntry() async {
    if (_listEntryLoading || _listEntrySaving) {
      return;
    }
    if (!widget.trackingService.isLoggedIn(TrackingProvider.anilist)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to AniList to edit lists')),
      );
      return;
    }

    setState(() => _listEntryLoading = true);
    AniListMediaListEntry? entry;
    try {
      entry = await widget.trackingService.aniListMediaListEntry(
        media: widget.media,
        kind: TrackingMediaKind.manga,
      );
      if (!mounted) {
        return;
      }
      setState(() => _listEntry = entry);
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          error,
          title: 'AniList list sync failed',
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _listEntryLoading = false);
      }
    }

    if (!mounted) {
      return;
    }
    final result = await showAniListListEntrySheet(
      context: context,
      media: widget.media,
      kind: TrackingMediaKind.manga,
      entry: entry,
    );
    if (!mounted || result == null) {
      return;
    }

    setState(() => _listEntrySaving = true);
    try {
      switch (result.action) {
        case AniListListEntryEditAction.save:
          final saved = await widget.trackingService.saveAniListMediaListEntry(
            result.request!,
          );
          if (mounted) {
            setState(() => _listEntry = saved);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Updated AniList list entry')),
            );
          }
        case AniListListEntryEditAction.delete:
          final entryId = entry?.id;
          if (entryId != null) {
            await widget.trackingService.deleteAniListMediaListEntry(entryId);
          }
          if (mounted) {
            setState(() => _listEntry = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Removed AniList list entry')),
            );
          }
      }
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          error,
          title: 'AniList list update failed',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _listEntrySaving = false);
      }
    }
  }

  Widget _aniListListIcon() {
    if (_listEntryLoading || _listEntrySaving) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(
      _listEntry == null ? Icons.playlist_add : Icons.playlist_add_check,
    );
  }

  void _showImagePreview(String? imageUrl, Map<String, String> headers) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return;
    }
    unawaited(
      showImagePreviewSheet(
        context: context,
        imageUrl: imageUrl,
        title: widget.media.displayTitle,
        headers: headers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.media.displayTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (_status != null) ...[
                const SizedBox(height: 16),
                Text(_status!),
              ],
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.media.displayTitle)),
        body: AppErrorView(message: _error!, onRetry: _load),
      );
    }

    final cover =
        _mangaInfo?.image ?? _providerManga?.image ?? widget.media.cover.best;
    final headers =
        _mangaInfo?.headers ??
        _providerManga?.headers ??
        const <String, String>{};
    final description = _mangaInfo?.description?.isNotEmpty == true
        ? _mangaInfo!.description!
        : widget.media.description;
    final visibleChapters = _visibleChapters;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            actions: [
              IconButton(
                tooltip: _isFavorite ? 'Remove favorite' : 'Favorite',
                onPressed: _favoriteLoading ? null : _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
              ),
              IconButton(
                tooltip: _listEntry == null
                    ? 'Add to AniList list'
                    : 'Edit ${_listEntry!.status.label}',
                onPressed: _listEntryLoading || _listEntrySaving
                    ? null
                    : _editAniListListEntry,
                icon: _aniListListIcon(),
              ),
              IconButton(
                tooltip: 'Provider',
                onPressed: _providers.isEmpty ? null : _changeProvider,
                icon: const Icon(Icons.dns_outlined),
              ),
              IconButton(
                tooltip: 'Manual match',
                onPressed: _manualMatch,
                icon: const Icon(Icons.manage_search),
              ),
              IconButton(
                tooltip: 'AniList',
                onPressed: _openAniList,
                icon: const Icon(Icons.open_in_new),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                bottom: 14,
                end: 200,
              ),
              title: Text(
                widget.media.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.media.bannerImage != null)
                    GestureDetector(
                      onLongPress: () => _showImagePreview(
                        widget.media.bannerImage,
                        const <String, String>{},
                      ),
                      child: CachedNetworkImage(
                        imageUrl: widget.media.bannerImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0xF0000000)],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 58),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _Poster(
                            url: cover,
                            headers: headers,
                            onLongPress: () =>
                                _showImagePreview(cover, headers),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _InfoChip(
                                  icon: Icons.menu_book_outlined,
                                  label: '${_displayChapters.length} chapters',
                                ),
                                if (_mangaInfo?.status != null)
                                  _InfoChip(
                                    icon: Icons.timeline,
                                    label: _mangaInfo!.status!,
                                  ),
                                _InfoChip(
                                  icon: Icons.source_outlined,
                                  label:
                                      widget
                                          .preferences
                                          .lastMangaProviderName ??
                                      _providerKey,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_status != null) ...[
                    Text(
                      _status!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_mangaInfo?.title != null &&
                      _mangaInfo!.title != widget.media.displayTitle) ...[
                    SelectionArea(
                      child: Text(
                        widget.media.displayTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectionArea(
                      child: Text(
                        _mangaInfo!.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    SelectionArea(
                      child: Text(
                        widget.media.displayTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (description.isNotEmpty)
                    ExpandableSelectableText(
                      description,
                      collapsedLines: 6,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (_mangaInfo?.genres.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _mangaInfo!.genres
                          .take(10)
                          .map((genre) => Chip(label: Text(genre)))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chapters',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Download all chapters',
                        onPressed: _displayChapters.isEmpty
                            ? null
                            : () => unawaited(_downloadAllChapters()),
                        icon: const Icon(Icons.download_for_offline_outlined),
                      ),
                      IconButton(
                        tooltip: widget.preferences.mangaChaptersDescending
                            ? 'Descending'
                            : 'Ascending',
                        onPressed: () async {
                          await widget.preferences.setMangaChaptersDescending(
                            !widget.preferences.mangaChaptersDescending,
                          );
                          if (mounted) {
                            setState(() => _chapterRangeIndex = 0);
                          }
                        },
                        icon: Icon(
                          widget.preferences.mangaChaptersDescending
                              ? Icons.south
                              : Icons.north,
                        ),
                      ),
                    ],
                  ),
                  if (_chapterRanges.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ListRangeSelector(
                      ranges: _chapterRanges,
                      selectedIndex: _chapterRangeIndex,
                      onSelected: (index) =>
                          setState(() => _chapterRangeIndex = index),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_displayChapters.isEmpty)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                child: EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No chapters found',
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: visibleChapters.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final chapter = visibleChapters[index];
                final request = _downloadRequestFor(chapter);
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      MangaChapterNumberLabel.format(chapter.number),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  title: Text(
                    chapter.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: chapter.metadata.isEmpty
                      ? null
                      : Text(chapter.metadata),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (request != null)
                        _MangaChapterDownloadStatus(
                          service: widget.mangaDownloadService,
                          request: request,
                          onDownload: () => _downloadChapter(chapter),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _openChapter(chapter),
                );
              },
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: _detailBottomPadding(context)),
          ),
        ],
      ),
    );
  }

  double _detailBottomPadding(BuildContext context) =>
      24 + MediaQuery.viewPaddingOf(context).bottom;
}

class _MangaChapterDownloadStatus extends StatelessWidget {
  const _MangaChapterDownloadStatus({
    required this.service,
    required this.request,
    required this.onDownload,
  });

  final MangaDownloadService service;
  final MangaChapterDownloadRequest request;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final task = service.taskFor(request.id);
        if (task != null) {
          final canceling = task.status == MangaDownloadTaskStatus.canceling;
          return IconButton(
            tooltip: canceling
                ? 'Stopping manga download'
                : 'Cancel manga download',
            visualDensity: VisualDensity.compact,
            onPressed: canceling ? null : () => service.cancelDownload(task.id),
            icon: SizedBox.square(
              dimension: 28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: task.progress,
                    strokeWidth: 2.6,
                  ),
                  Icon(canceling ? Icons.more_horiz : Icons.stop, size: 16),
                ],
              ),
            ),
          );
        }

        if (service.isDownloaded(request.id)) {
          return Tooltip(
            message: 'Downloaded',
            child: Icon(
              Icons.download_done,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        return IconButton(
          tooltip: 'Download chapter',
          visualDensity: VisualDensity.compact,
          onPressed: onDownload,
          icon: const Icon(Icons.download),
        );
      },
    );
  }
}

class _ManualMangaSearchSheet extends StatefulWidget {
  const _ManualMangaSearchSheet({
    required this.initialQuery,
    required this.providerKey,
    required this.juroService,
    required this.scrollController,
  });

  final String initialQuery;
  final String providerKey;
  final JuroService juroService;
  final ScrollController scrollController;

  @override
  State<_ManualMangaSearchSheet> createState() =>
      _ManualMangaSearchSheetState();
}

class _ManualMangaSearchSheetState extends State<_ManualMangaSearchSheet> {
  late final TextEditingController _controller;
  Timer? _debounce;
  List<MangaResult> _results = [];
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _controller.addListener(_onQueryChanged);
    _loading = _controller.text.trim().isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_runSearch());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    setState(() {
      if (query.isEmpty) {
        _generation++;
        _results = [];
        _error = null;
        _loading = false;
      }
    });

    if (query.isEmpty) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_runSearch());
    });
  }

  Future<void> _runSearch() async {
    _debounce?.cancel();
    final query = _controller.text.trim();
    final generation = ++_generation;

    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _error = null;
          _loading = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await widget.juroService.searchManga(
        query,
        providerKey: widget.providerKey,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _results = [];
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _clearQuery() {
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Search provider',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => unawaited(_runSearch()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Provider manga title',
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: _clearQuery,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else
              const SizedBox(height: 4),
            const SizedBox(height: 8),
            Expanded(
              child: CustomScrollView(
                controller: widget.scrollController,
                slivers: [
                  if (query.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ProviderSearchMessage(
                        icon: Icons.manage_search,
                        title: 'Search provider titles',
                        message: 'Type to find a source match.',
                      ),
                    )
                  else if (_error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ProviderSearchMessage(
                        icon: Icons.cloud_off_outlined,
                        title: 'Provider search failed',
                        message: _error,
                        action: FilledButton.icon(
                          onPressed: () => unawaited(_runSearch()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    )
                  else if (!_loading && _results.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ProviderSearchMessage(
                        icon: Icons.search_off,
                        title: 'No provider results',
                      ),
                    )
                  else if (_results.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: SizedBox.shrink(),
                    )
                  else
                    SliverList.builder(
                      itemCount: _results.length * 2 - 1,
                      itemBuilder: (context, index) {
                        if (index.isOdd) {
                          return const Divider(height: 1);
                        }

                        final item = _results[index ~/ 2];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _SmallCover(
                            url: item.image,
                            headers: item.headers,
                          ),
                          title: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: item.displaySubtitle.isEmpty
                              ? null
                              : Text(
                                  item.displaySubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderSearchMessage extends StatelessWidget {
  const _ProviderSearchMessage({
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 42,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class MangaChapterNumberLabel {
  static String format(double value) {
    if (value == 0) {
      return '?';
    }
    return AnimeEpisode.displayNumber(value);
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.headers, this.onLongPress});

  final String? url;
  final Map<String, String> headers;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: url == null || url!.isEmpty ? null : onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 116,
          height: 172,
          child: _CoverImage(url: url, headers: headers),
        ),
      ),
    );
  }
}

class _SmallCover extends StatelessWidget {
  const _SmallCover({required this.url, required this.headers});

  final String? url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 44,
        height: 58,
        child: _CoverImage(url: url, headers: headers),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url, required this.headers});

  final String? url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;
    if (url == null || url!.isEmpty) {
      return ColoredBox(
        color: placeholderColor,
        child: const Center(child: Icon(Icons.menu_book_outlined)),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      httpHeaders: headers,
      fit: BoxFit.cover,
      placeholder: (context, _) => ColoredBox(color: placeholderColor),
      errorWidget: (context, _, _) => ColoredBox(
        color: placeholderColor,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xAA000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
