import 'dart:io';

import 'package:flutter/material.dart';

import '../models/downloaded_episode.dart';
import '../models/downloaded_manga.dart';
import '../models/juro_models.dart';
import '../models/tracking.dart';
import '../models/anilist_media.dart';
import '../models/watch_history.dart';
import '../services/download_service.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/app_error_view.dart';
import 'detail_screen.dart';
import 'manga_detail_screen.dart';
import 'manga_reader_screen.dart';
import 'player_screen.dart';

class DownloadsScreen extends LibraryScreen {
  const DownloadsScreen({
    required super.downloadService,
    required super.mangaDownloadService,
    required super.preferences,
    required super.juroService,
    required super.watchHistoryService,
    required super.trackingService,
    super.key,
  });
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.downloadService,
    required this.mangaDownloadService,
    required this.preferences,
    required this.juroService,
    required this.watchHistoryService,
    required this.trackingService,
    super.key,
  });

  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final PreferencesService preferences;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final TrackingService trackingService;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final Future<void> _loadFuture;
  late Future<Map<String, WatchedEpisode>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadDownloads();
    _historyFuture = widget.watchHistoryService.getAll();
  }

  Future<void> _loadDownloads() async {
    await Future.wait([
      widget.downloadService.load(),
      widget.mangaDownloadService.load(),
    ]);
  }

  Future<void> _openDownload(DownloadedEpisode download) async {
    if (!await File(download.localPath).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline file is missing')),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          media: download.media,
          providerAnime: download.providerAnime,
          episode: download.episode,
          episodes: [download.episode],
          initialSource: VideoSource(
            title: download.sourceTitle,
            videoUrl: download.localPath,
            fileType: 'Offline',
            videoServer: VideoServer(
              name: download.serverName,
              embed: const FileUrl(url: ''),
            ),
          ),
          preferences: widget.preferences,
          juroService: widget.juroService,
          watchHistoryService: widget.watchHistoryService,
          trackingService: widget.trackingService,
          offlineFilePath: download.localPath,
        ),
      ),
    );
  }

  Future<void> _refreshHistory() async {
    setState(() => _historyFuture = widget.watchHistoryService.getAll());
  }

  Future<void> _openFavorite(AniListMedia media, TrackingMediaKind kind) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => kind == TrackingMediaKind.anime
            ? DetailScreen(
                media: media,
                preferences: widget.preferences,
                juroService: widget.juroService,
                watchHistoryService: widget.watchHistoryService,
                downloadService: widget.downloadService,
                trackingService: widget.trackingService,
              )
            : MangaDetailScreen(
                media: media,
                preferences: widget.preferences,
                juroService: widget.juroService,
                mangaDownloadService: widget.mangaDownloadService,
                trackingService: widget.trackingService,
              ),
      ),
    );
    if (kind == TrackingMediaKind.anime) {
      await _refreshHistory();
    }
  }

  Future<void> _openMangaDownload(DownloadedMangaChapter download) async {
    final pages = await widget.mangaDownloadService.pagesFor(download.id);
    if (pages == null || pages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline manga pages are missing')),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    final chapters =
        widget.mangaDownloadService.items
            .where(
              (item) =>
                  item.mediaId == download.mediaId &&
                  item.mangaId == download.mangaId,
            )
            .map((item) => item.chapter)
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number));

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MangaReaderScreen(
          media: download.media,
          mangaInfo: download.mangaInfo,
          chapter: download.chapter,
          chapters: chapters.isEmpty ? [download.chapter] : chapters,
          preferences: widget.preferences,
          juroService: widget.juroService,
          mangaDownloadService: widget.mangaDownloadService,
          trackingService: widget.trackingService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorView(message: snapshot.error.toString());
          }

          return DefaultTabController(
            length: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text(
                    'Library',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return TabBar(
                      isScrollable: constraints.maxWidth < 380,
                      tabs: const [
                        Tab(text: 'Continue', icon: Icon(Icons.play_arrow)),
                        Tab(
                          text: 'Favorites',
                          icon: Icon(Icons.favorite_border),
                        ),
                        Tab(text: 'Downloads', icon: Icon(Icons.download)),
                        Tab(
                          text: 'Lists',
                          icon: Icon(Icons.format_list_bulleted),
                        ),
                      ],
                    );
                  },
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ContinueTab(historyFuture: _historyFuture),
                      _FavoritesTab(
                        trackingService: widget.trackingService,
                        onOpen: _openFavorite,
                      ),
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          widget.downloadService,
                          widget.mangaDownloadService,
                        ]),
                        builder: (context, _) => _DownloadsBody(
                          service: widget.downloadService,
                          mangaService: widget.mangaDownloadService,
                          onOpen: _openDownload,
                          onOpenManga: _openMangaDownload,
                        ),
                      ),
                      _ListsTab(trackingService: widget.trackingService),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ContinueTab extends StatelessWidget {
  const _ContinueTab({required this.historyFuture});

  final Future<Map<String, WatchedEpisode>> historyFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, WatchedEpisode>>(
      future: historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AppErrorView(message: snapshot.error.toString());
        }
        final items =
            (snapshot.data ?? const <String, WatchedEpisode>{}).values
                .where((item) => item.watchedPercentage > 0)
                .toList()
              ..sort(
                (a, b) => b.watchedPercentage.compareTo(a.watchedPercentage),
              );
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.play_circle_outline,
            title: 'Nothing to continue',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            for (final item in items)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: Text(
                    item.animeName.isEmpty ? 'Unknown anime' : item.animeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.watchedPercentage.clamp(0, 100).round()}% watched • ${_formatDuration(item.watchedDuration)}',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FavoritesTab extends StatefulWidget {
  const _FavoritesTab({required this.trackingService, required this.onOpen});

  final TrackingService trackingService;
  final Future<void> Function(AniListMedia media, TrackingMediaKind kind)
  onOpen;

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> {
  late Future<_FavoriteBuckets> _favoritesFuture;
  bool _loadedForLoggedInAccount = false;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = _loadFavorites();
  }

  Future<_FavoriteBuckets> _loadFavorites() async {
    if (!widget.trackingService.isLoggedIn(TrackingProvider.anilist)) {
      return const _FavoriteBuckets();
    }
    final results = await Future.wait([
      widget.trackingService.favoriteMedia(TrackingMediaKind.anime),
      widget.trackingService.favoriteMedia(TrackingMediaKind.manga),
    ]);
    return _FavoriteBuckets(anime: results[0], manga: results[1]);
  }

  void _refresh() {
    setState(() => _favoritesFuture = _loadFavorites());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.trackingService,
      builder: (context, _) {
        final loggedIn = widget.trackingService.isLoggedIn(
          TrackingProvider.anilist,
        );
        if (!loggedIn) {
          _loadedForLoggedInAccount = false;
          return const EmptyState(
            icon: Icons.favorite_border,
            title: 'Login to AniList for favorites',
          );
        }
        if (!_loadedForLoggedInAccount) {
          _loadedForLoggedInAccount = true;
          _favoritesFuture = _loadFavorites();
        }
        return FutureBuilder<_FavoriteBuckets>(
          future: _favoritesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AppErrorView(message: snapshot.error.toString());
            }
            final favorites = snapshot.data ?? const _FavoriteBuckets();
            if (favorites.anime.isEmpty && favorites.manga.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: const [
                    SizedBox(height: 120),
                    EmptyState(
                      icon: Icons.favorite_border,
                      title: 'No AniList favorites yet',
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  if (favorites.anime.isNotEmpty) ...[
                    const _SectionTitle(title: 'Favorite anime'),
                    for (final media in favorites.anime)
                      _FavoriteMediaTile(
                        media: media,
                        kind: TrackingMediaKind.anime,
                        onTap: () =>
                            widget.onOpen(media, TrackingMediaKind.anime),
                      ),
                  ],
                  if (favorites.manga.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const _SectionTitle(title: 'Favorite manga'),
                    for (final media in favorites.manga)
                      _FavoriteMediaTile(
                        media: media,
                        kind: TrackingMediaKind.manga,
                        onTap: () =>
                            widget.onOpen(media, TrackingMediaKind.manga),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ListsTab extends StatelessWidget {
  const _ListsTab({required this.trackingService});

  final TrackingService trackingService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: trackingService,
      builder: (context, _) {
        final providers = TrackingProvider.values
            .where(trackingService.isLoggedIn)
            .map((provider) => provider.label)
            .join(', ');
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            if (providers.isEmpty)
              const EmptyState(
                icon: Icons.format_list_bulleted,
                title: 'Login to sync lists',
              )
            else
              Card(
                child: ListTile(
                  leading: const Icon(Icons.sync_outlined),
                  title: const Text('Synced providers'),
                  subtitle: Text(providers),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FavoriteMediaTile extends StatelessWidget {
  const _FavoriteMediaTile({
    required this.media,
    required this.kind,
    required this.onTap,
  });

  final AniListMedia media;
  final TrackingMediaKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = media.cover.best;
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: image == null
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const SizedBox(
                    width: 44,
                    height: 56,
                    child: Icon(Icons.movie_outlined),
                  ),
                )
              : Image.network(
                  image,
                  width: 44,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
        title: Text(
          media.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            kind == TrackingMediaKind.anime ? 'Anime' : 'Manga',
            media.metadata,
          ].where((part) => part.isNotEmpty).join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _FavoriteBuckets {
  const _FavoriteBuckets({
    this.anime = const <AniListMedia>[],
    this.manga = const <AniListMedia>[],
  });

  final List<AniListMedia> anime;
  final List<AniListMedia> manga;
}

class _DownloadsBody extends StatelessWidget {
  const _DownloadsBody({
    required this.service,
    required this.mangaService,
    required this.onOpen,
    required this.onOpenManga,
  });

  final DownloadService service;
  final MangaDownloadService mangaService;
  final ValueChanged<DownloadedEpisode> onOpen;
  final ValueChanged<DownloadedMangaChapter> onOpenManga;

  @override
  Widget build(BuildContext context) {
    final tasks = service.activeTasks;
    final downloads = service.items;
    final mangaTasks = mangaService.activeTasks;
    final mangaDownloads = mangaService.items;
    final hasPausableTasks = tasks.any(
      (task) =>
          task.status == DownloadTaskStatus.queued ||
          task.status == DownloadTaskStatus.downloading,
    );
    final hasPausedTasks = tasks.any(
      (task) => task.status == DownloadTaskStatus.paused,
    );

    if (tasks.isEmpty &&
        downloads.isEmpty &&
        mangaTasks.isEmpty &&
        mangaDownloads.isEmpty) {
      return const EmptyState(
        icon: Icons.download_done_outlined,
        title: 'No downloads yet',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Downloads',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (downloads.isNotEmpty || mangaDownloads.isNotEmpty)
              Text(
                _formatBytes(
                  downloads.fold<int>(0, (sum, item) => sum + item.bytes) +
                      mangaDownloads.fold<int>(
                        0,
                        (sum, item) => sum + item.bytes,
                      ),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (tasks.isNotEmpty)
              IconButton(
                tooltip: 'Pause all downloads',
                onPressed: hasPausableTasks ? service.pauseAllDownloads : null,
                icon: const Icon(Icons.pause_circle_outline),
              ),
            if (tasks.isNotEmpty)
              IconButton(
                tooltip: 'Resume paused downloads',
                onPressed: hasPausedTasks ? service.resumeAllDownloads : null,
                icon: const Icon(Icons.play_circle_outline),
              ),
            if (tasks.isNotEmpty || mangaTasks.isNotEmpty)
              IconButton(
                tooltip: 'Cancel all downloads',
                onPressed: () {
                  service.cancelAllDownloads();
                  mangaService.cancelAllDownloads();
                },
                icon: const Icon(Icons.stop_circle_outlined),
              ),
          ],
        ),
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionTitle(title: 'Anime downloads'),
          for (final task in tasks)
            _DownloadTaskTile(service: service, task: task),
        ],
        if (mangaTasks.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionTitle(title: 'Manga downloads'),
          for (final task in mangaTasks)
            _MangaDownloadTaskTile(service: mangaService, task: task),
        ],
        if (downloads.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionTitle(title: 'Offline episodes'),
          for (final download in downloads)
            _DownloadedEpisodeTile(
              service: service,
              download: download,
              onTap: () => onOpen(download),
            ),
        ],
        if (mangaDownloads.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SectionTitle(title: 'Offline manga'),
          for (final download in mangaDownloads)
            _DownloadedMangaChapterTile(
              service: mangaService,
              download: download,
              onTap: () => onOpenManga(download),
            ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DownloadTaskTile extends StatelessWidget {
  const _DownloadTaskTile({required this.service, required this.task});

  final DownloadService service;
  final EpisodeDownloadProgress task;

  @override
  Widget build(BuildContext context) {
    final progress = task.progress;
    final failed = task.status == DownloadTaskStatus.failed;
    final canceling = task.status == DownloadTaskStatus.canceling;
    final pausing = task.status == DownloadTaskStatus.pausing;
    final paused = task.status == DownloadTaskStatus.paused;
    return Card(
      child: ListTile(
        leading: Icon(
          failed
              ? Icons.error_outline
              : canceling
              ? Icons.stop_circle_outlined
              : paused
              ? Icons.pause_circle_outline
              : Icons.downloading,
        ),
        title: Text(
          task.request.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Text(failed ? task.error ?? 'Download failed' : _statusText(task)),
          ],
        ),
        trailing: failed
            ? IconButton(
                tooltip: 'Dismiss',
                onPressed: () => service.delete(task.id),
                icon: const Icon(Icons.close),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: paused
                        ? 'Resume download'
                        : pausing
                        ? 'Pausing download'
                        : 'Pause download',
                    onPressed: canceling || pausing
                        ? null
                        : paused
                        ? () => service.resumeDownload(task.id)
                        : () => service.pauseDownload(task.id),
                    icon: Icon(
                      paused
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                    ),
                  ),
                  IconButton(
                    tooltip: canceling
                        ? 'Stopping download'
                        : 'Cancel download',
                    onPressed: canceling
                        ? null
                        : () => service.cancelDownload(task.id),
                    icon: const Icon(Icons.stop_circle_outlined),
                  ),
                ],
              ),
      ),
    );
  }

  String _statusText(EpisodeDownloadProgress task) {
    if (task.status == DownloadTaskStatus.pausing) {
      return 'Pausing...';
    }
    if (task.status == DownloadTaskStatus.paused) {
      final progress = task.progress;
      final percent = progress == null
          ? null
          : '${(progress * 100).clamp(0, 100).round()}%';
      return [percent, 'Paused'].whereType<String>().join(' • ');
    }
    if (task.status == DownloadTaskStatus.canceling) {
      return 'Stopping...';
    }

    final progress = task.progress;
    final percent = progress == null
        ? null
        : '${(progress * 100).clamp(0, 100).round()}%';
    final total = task.bytesTotal;
    if (total != null && total > 0) {
      return [
        percent,
        '${_formatBytes(task.bytesReceived)} / ${_formatBytes(total)}',
      ].whereType<String>().join(' • ');
    }
    final itemTotal = task.itemsTotal;
    if (itemTotal != null && itemTotal > 0) {
      return [
        percent,
        '${task.itemsCompleted} / $itemTotal segments',
      ].whereType<String>().join(' • ');
    }
    if (task.bytesReceived > 0) {
      return _formatBytes(task.bytesReceived);
    }
    return 'Queued';
  }
}

class _MangaDownloadTaskTile extends StatelessWidget {
  const _MangaDownloadTaskTile({required this.service, required this.task});

  final MangaDownloadService service;
  final MangaChapterDownloadProgress task;

  @override
  Widget build(BuildContext context) {
    final failed = task.status == MangaDownloadTaskStatus.failed;
    final canceling = task.status == MangaDownloadTaskStatus.canceling;
    return Card(
      child: ListTile(
        leading: Icon(
          failed
              ? Icons.error_outline
              : canceling
              ? Icons.stop_circle_outlined
              : Icons.menu_book_outlined,
        ),
        title: Text(
          task.request.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(value: task.progress),
            const SizedBox(height: 6),
            Text(failed ? task.error ?? 'Download failed' : _statusText(task)),
          ],
        ),
        trailing: failed
            ? IconButton(
                tooltip: 'Dismiss',
                onPressed: () => service.delete(task.id),
                icon: const Icon(Icons.close),
              )
            : IconButton(
                tooltip: canceling
                    ? 'Stopping manga download'
                    : 'Cancel manga download',
                onPressed: canceling
                    ? null
                    : () => service.cancelDownload(task.id),
                icon: const Icon(Icons.stop_circle_outlined),
              ),
      ),
    );
  }

  String _statusText(MangaChapterDownloadProgress task) {
    if (task.status == MangaDownloadTaskStatus.canceling) {
      return 'Stopping...';
    }
    final progress = task.progress;
    final percent = progress == null
        ? null
        : '${(progress * 100).clamp(0, 100).round()}%';
    final pageTotal = task.pagesTotal;
    if (pageTotal != null && pageTotal > 0) {
      return [
        percent,
        '${task.pagesCompleted} / $pageTotal pages',
        if (task.bytesReceived > 0) _formatBytes(task.bytesReceived),
      ].whereType<String>().join(' • ');
    }
    if (task.bytesReceived > 0) {
      return _formatBytes(task.bytesReceived);
    }
    return 'Queued';
  }
}

class _DownloadedEpisodeTile extends StatelessWidget {
  const _DownloadedEpisodeTile({
    required this.service,
    required this.download,
    required this.onTap,
  });

  final DownloadService service;
  final DownloadedEpisode download;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: Text(
          download.episode.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${download.mediaTitle} • ${download.sourceTitle} • ${_formatBytes(download.bytes)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Delete download',
          onPressed: () => service.delete(download.id),
          icon: const Icon(Icons.delete_outline),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _DownloadedMangaChapterTile extends StatelessWidget {
  const _DownloadedMangaChapterTile({
    required this.service,
    required this.download,
    required this.onTap,
  });

  final MangaDownloadService service;
  final DownloadedMangaChapter download;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(
          download.chapter.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${download.mediaTitle} • ${download.pages.length} pages • ${_formatBytes(download.bytes)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Delete manga download',
          onPressed: () => service.delete(download.id),
          icon: const Icon(Icons.delete_outline),
        ),
        onTap: onTap,
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}
