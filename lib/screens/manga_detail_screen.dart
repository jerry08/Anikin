import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/anilist_media.dart';
import '../models/downloaded_manga.dart';
import '../models/juro_models.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../widgets/app_error_view.dart';
import 'manga_reader_screen.dart';

class MangaDetailScreen extends StatefulWidget {
  const MangaDetailScreen({
    required this.media,
    required this.preferences,
    required this.juroService,
    required this.mangaDownloadService,
    super.key,
  });

  final AniListMedia media;
  final PreferencesService preferences;
  final JuroService juroService;
  final MangaDownloadService mangaDownloadService;

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  List<SourceProvider> _providers = [];
  MangaResult? _providerManga;
  MangaInfo? _mangaInfo;
  List<MangaChapter> _chapters = [];
  bool _loading = true;
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Loading manga providers';
      _chapters = [];
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
      _status = info.chapters.isEmpty ? 'No chapters found' : null;
    });
  }

  Future<void> _changeProvider() async {
    final provider = await showModalBottomSheet<SourceProvider>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
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
    final query = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(
          text: widget.media.displayTitle,
        );
        return AlertDialog(
          title: const Text('Search provider'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Provider manga title',
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Search'),
            ),
          ],
        );
      },
    );

    if (query == null || query.trim().isEmpty) {
      return;
    }

    setState(() => _status = 'Searching provider');
    try {
      final results = await widget.juroService.searchManga(
        query,
        providerKey: _providerKey,
      );
      if (!mounted) return;
      final match = await _chooseProviderManga(results);
      if (match != null) {
        await _loadChapters(match);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _status = null);
      }
    }
  }

  Future<MangaResult?> _chooseProviderManga(List<MangaResult> results) {
    return showModalBottomSheet<MangaResult>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        if (results.isEmpty) {
          return const SizedBox(
            height: 260,
            child: EmptyState(
              icon: Icons.search_off,
              title: 'No provider results',
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: results.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Select source match',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              );
            }

            final item = results[index - 1];
            return ListTile(
              leading: _SmallCover(url: item.image, headers: item.headers),
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
        );
      },
    );
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
    await widget.mangaDownloadService.startDownload(request);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading ${chapter.displayTitle}')),
      );
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
    for (final chapter in chapters) {
      final request = _downloadRequestFor(chapter);
      if (request == null ||
          widget.mangaDownloadService.isDownloaded(request.id)) {
        continue;
      }
      await widget.mangaDownloadService.startDownload(request);
      queued++;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Queued $queued chapters')));
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            actions: [
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
                end: 120,
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
                    CachedNetworkImage(
                      imageUrl: widget.media.bannerImage!,
                      fit: BoxFit.cover,
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
                          _Poster(url: cover, headers: headers),
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
                    Text(
                      _mangaInfo!.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
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
                        onPressed: () {
                          widget.preferences.setMangaChaptersDescending(
                            !widget.preferences.mangaChaptersDescending,
                          );
                          setState(() {});
                        },
                        icon: Icon(
                          widget.preferences.mangaChaptersDescending
                              ? Icons.south
                              : Icons.north,
                        ),
                      ),
                    ],
                  ),
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
              itemCount: _displayChapters.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final chapter = _displayChapters[index];
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
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
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

class MangaChapterNumberLabel {
  static String format(double value) {
    if (value == 0) {
      return '?';
    }
    return AnimeEpisode.displayNumber(value);
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.headers});

  final String? url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 116,
        height: 172,
        child: _CoverImage(url: url, headers: headers),
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
