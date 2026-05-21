import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/anilist_media.dart';
import '../models/downloaded_episode.dart';
import '../models/juro_models.dart';
import '../models/tracking.dart';
import '../models/watch_history.dart';
import '../services/download_service.dart';
import '../services/juro_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/app_error_view.dart';
import '../widgets/detail_media_tools.dart';
import 'player_screen.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    required this.media,
    required this.preferences,
    required this.juroService,
    required this.watchHistoryService,
    required this.downloadService,
    required this.trackingService,
    super.key,
  });

  final AniListMedia media;
  final PreferencesService preferences;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final TrackingService trackingService;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  List<SourceProvider> _providers = [];
  JuroAnimeInfo? _providerAnime;
  List<AnimeEpisode> _episodes = [];
  Map<String, WatchedEpisode> _history = {};
  bool _loading = true;
  bool _dub = false;
  bool _isFavorite = false;
  bool _favoriteLoading = false;
  String? _error;
  String? _status;

  String get _providerKey => widget.preferences.lastAnimeProviderKey;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshFavorite();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Loading providers';
      _episodes = [];
    });

    try {
      _providers = await widget.juroService.getProviders();
      if (_providers.isNotEmpty &&
          !_providers.any((item) => item.key == _providerKey)) {
        final provider = _providers.first;
        await widget.preferences.setLastAnimeProvider(
          SourceProviderChoice(key: provider.key, name: provider.name),
        );
      }

      _history = await widget.watchHistoryService.getAll();
      await _autoMatchAndLoadEpisodes();
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

  Future<void> _autoMatchAndLoadEpisodes() async {
    setState(() => _status = 'Searching ${widget.media.displayTitle}');
    final dubText = _dub ? ' (dub)' : '';
    JuroAnimeInfo? match;

    for (final title in widget.media.title.searchCandidates) {
      final results = await widget.juroService.searchAnime(
        '$title$dubText',
        providerKey: _providerKey,
      );
      if (results.isNotEmpty) {
        match = results.first;
        break;
      }
    }

    if (match == null) {
      setState(() {
        _providerAnime = null;
        _episodes = [];
        _status = 'No source match found';
      });
      return;
    }

    await _loadEpisodes(match);
  }

  Future<void> _loadEpisodes(JuroAnimeInfo anime) async {
    setState(() {
      _providerAnime = anime;
      _status =
          'Loading episodes from ${widget.preferences.lastAnimeProviderName ?? _providerKey}';
    });

    final episodes = List<AnimeEpisode>.of(
      await widget.juroService.getEpisodes(anime.id, providerKey: _providerKey),
    );
    episodes.sort((a, b) => a.number.compareTo(b.number));

    setState(() {
      _episodes = episodes
          .map(
            (episode) => episode.copyWith(
              image: episode.image ?? anime.image ?? widget.media.cover.best,
            ),
          )
          .toList();
      _status = episodes.isEmpty ? 'No episodes found' : null;
    });
  }

  List<AnimeEpisode> get _displayEpisodes {
    final episodes = List<AnimeEpisode>.of(_episodes);
    if (widget.preferences.episodesDescending) {
      return episodes.reversed.toList();
    }
    return episodes;
  }

  Future<void> _refreshHistory() async {
    final history = await widget.watchHistoryService.getAll();
    if (mounted) {
      setState(() => _history = history);
    }
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
              'Anime provider',
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

    await widget.preferences.setLastAnimeProvider(
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
              hintText: 'Provider title',
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
      final results = await widget.juroService.searchAnime(
        query,
        providerKey: _providerKey,
      );
      if (!mounted) return;
      final match = await _chooseProviderAnime(results);
      if (match != null) {
        await _loadEpisodes(match);
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

  Future<JuroAnimeInfo?> _chooseProviderAnime(List<JuroAnimeInfo> results) {
    return showModalBottomSheet<JuroAnimeInfo>(
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
              leading: _SmallCover(url: item.image),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  item.type,
                  item.released,
                  item.status,
                ].whereType<String>().join(' • '),
              ),
              onTap: () => Navigator.of(context).pop(item),
            );
          },
        );
      },
    );
  }

  Future<void> _openEpisode(
    AnimeEpisode episode, {
    VideoSource? selectedSource,
  }) async {
    if (_providerAnime == null) {
      return;
    }

    VideoSource? source = selectedSource;
    if (source == null && widget.preferences.selectServerBeforePlaying) {
      source = await _chooseVideoSource(episode);
      if (!mounted) {
        return;
      }
      if (source == null) {
        return;
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          media: widget.media,
          providerAnime: _providerAnime!,
          episode: episode,
          episodes: _episodes,
          initialSource: source,
          preferences: widget.preferences,
          juroService: widget.juroService,
          watchHistoryService: widget.watchHistoryService,
          trackingService: widget.trackingService,
        ),
      ),
    );

    await _refreshHistory();
  }

  Future<void> _showEpisodeOptions(AnimeEpisode episode) async {
    if (_providerAnime == null) {
      return;
    }

    final source = await _chooseVideoSource(
      episode,
      title: 'Select server',
      showSourceActions: true,
    );
    if (!mounted || source == null) {
      return;
    }

    await _openEpisode(episode, selectedSource: source);
  }

  Future<VideoSource?> _chooseVideoSource(
    AnimeEpisode episode, {
    String title = 'Select source',
    bool showSourceActions = false,
  }) {
    final future = widget.juroService.getVideos(
      episode.id,
      providerKey: _providerKey,
    );
    return showModalBottomSheet<VideoSource>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        minChildSize: 0.36,
        builder: (context, controller) => FutureBuilder<List<VideoSource>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AppErrorView(message: snapshot.error.toString());
            }

            final sources = snapshot.data ?? const <VideoSource>[];
            if (sources.isEmpty) {
              return const EmptyState(
                icon: Icons.videocam_off_outlined,
                title: 'No video sources',
              );
            }

            final grouped = <String, List<VideoSource>>{};
            for (final source in sources) {
              grouped.putIfAbsent(source.serverName, () => []).add(source);
            }

            return ListView(
              controller: controller,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                  for (final source in entry.value)
                    Builder(
                      builder: (context) {
                        final providerAnime = _providerAnime;
                        final request = providerAnime == null
                            ? null
                            : EpisodeDownloadRequest(
                                media: widget.media,
                                providerAnime: providerAnime,
                                episode: episode,
                                source: source,
                              );
                        return ListTile(
                          leading: const Icon(Icons.play_circle_outline),
                          title: Text(source.displayTitle),
                          subtitle: Text(
                            [
                              source.resolution,
                              source.fileType,
                              source.extraNote,
                            ].whereType<String>().join(' • '),
                          ),
                          trailing: showSourceActions && request != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _SourceDownloadButton(
                                      service: widget.downloadService,
                                      request: request,
                                      onDownload: () =>
                                          _downloadEpisodeRequest(request),
                                    ),
                                    IconButton(
                                      tooltip: 'Copy link',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _handleVideoSourceAction(
                                        source,
                                        _VideoSourceAction.copyLink,
                                      ),
                                      icon: const Icon(Icons.copy),
                                    ),
                                    IconButton(
                                      tooltip: 'Open externally',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _handleVideoSourceAction(
                                        source,
                                        _VideoSourceAction.openExternal,
                                      ),
                                      icon: const Icon(Icons.open_in_new),
                                    ),
                                  ],
                                )
                              : null,
                          onLongPress: showSourceActions
                              ? () => _handleVideoSourceAction(
                                  source,
                                  _VideoSourceAction.copyLink,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(source),
                        );
                      },
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleVideoSourceAction(
    VideoSource source,
    _VideoSourceAction action,
  ) async {
    final url = source.videoUrl.replaceAll(' ', '%20');
    switch (action) {
      case _VideoSourceAction.copyLink:
        await Clipboard.setData(ClipboardData(text: url));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Copied video link')));
        }
        break;
      case _VideoSourceAction.openExternal:
        final uri = Uri.tryParse(url);
        if (uri == null ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to open link')),
            );
          }
        }
        break;
    }
  }

  Future<void> _downloadEpisodeRequest(EpisodeDownloadRequest request) async {
    final selectedRequest = await _resolveDownloadRequest(request);
    if (!mounted || selectedRequest == null) {
      return;
    }

    await widget.downloadService.startDownload(selectedRequest);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${selectedRequest.episode.displayName}'),
        ),
      );
    }
  }

  Future<EpisodeDownloadRequest?> _resolveDownloadRequest(
    EpisodeDownloadRequest request,
  ) async {
    late final List<HlsDownloadVariant> variants;
    try {
      variants = await widget.downloadService.getHlsVariants(request.source);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return null;
    }

    if (variants.isEmpty) {
      return request;
    }

    final selectedVariant = variants.length == 1
        ? variants.first
        : await _chooseHlsDownloadQuality(variants);
    if (selectedVariant == null) {
      return null;
    }

    return request.copyWith(
      sourceTaskId: request.taskId,
      source: widget.downloadService.sourceForHlsVariant(
        request.source,
        selectedVariant,
      ),
    );
  }

  Future<HlsDownloadVariant?> _chooseHlsDownloadQuality(
    List<HlsDownloadVariant> variants,
  ) {
    return showDialog<HlsDownloadVariant>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download quality'),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: variants.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final variant = variants[index];
              return ListTile(
                leading: const Icon(Icons.high_quality_outlined),
                title: Text(variant.resolutionLabel ?? variant.displayTitle),
                subtitle: Text(
                  [
                    variant.bitrateLabel,
                    if (variant.frameRate != null)
                      '${variant.frameRate!.toStringAsFixed(0)} fps',
                  ].whereType<String>().join(' • '),
                ),
                onTap: () => Navigator.of(context).pop(variant),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAllEpisodes() async {
    final episodes = _displayEpisodes;
    if (_providerAnime == null || episodes.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Queueing ${episodes.length} episodes')),
    );

    var queued = 0;
    var failed = 0;
    for (final episode in episodes) {
      try {
        final source = await widget.juroService.getPreferredVideo(
          episode,
          providerKey: _providerKey,
        );
        if (source == null) {
          failed++;
          continue;
        }
        await widget.downloadService.startDownload(
          EpisodeDownloadRequest(
            media: widget.media,
            providerAnime: _providerAnime!,
            episode: episode,
            source: source,
          ),
        );
        queued++;
      } catch (_) {
        failed++;
      }
    }

    if (mounted) {
      final message = failed == 0
          ? 'Queued $queued episodes'
          : 'Queued $queued episodes, $failed failed';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
        kind: TrackingMediaKind.anime,
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
        kind: TrackingMediaKind.anime,
      );
      if (mounted) {
        setState(() => _isFavorite = favorite);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isFavorite = !_isFavorite);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _favoriteLoading = false);
      }
    }
  }

  void _showImagePreview(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return;
    }
    unawaited(
      showImagePreviewSheet(
        context: context,
        imageUrl: imageUrl,
        title: widget.media.displayTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.media.bannerImage ?? widget.media.cover.best;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 340,
            actions: [
              IconButton(
                tooltip: _isFavorite ? 'Remove favorite' : 'Favorite',
                onPressed: _favoriteLoading ? null : _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
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
                end: 160,
              ),
              title: Text(
                widget.media.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null)
                    GestureDetector(
                      onLongPress: () => _showImagePreview(image),
                      child: CachedNetworkImage(
                        imageUrl: image,
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
                            url: widget.media.cover.best,
                            onLongPress: () =>
                                _showImagePreview(widget.media.cover.best),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _InfoChip(
                                  icon: Icons.star_rounded,
                                  label: '${widget.media.meanScore ?? '--'}%',
                                ),
                                if (widget.media.metadata.isNotEmpty)
                                  _InfoChip(
                                    icon: Icons.movie_filter_outlined,
                                    label: widget.media.metadata,
                                  ),
                                _InfoChip(
                                  icon: Icons.source_outlined,
                                  label:
                                      widget
                                          .preferences
                                          .lastAnimeProviderName ??
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
          SliverToBoxAdapter(child: _buildOverview()),
          if (_loading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (_status != null) ...[
                      const SizedBox(height: 12),
                      Text(_status!),
                    ],
                  ],
                ),
              ),
            )
          else if (_error != null)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                child: AppErrorView(message: _error!, onRetry: _load),
              ),
            )
          else if (_episodes.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                child: EmptyState(
                  icon: Icons.video_library_outlined,
                  title: _status ?? 'No episodes found',
                  message:
                      'Try another provider or search the source manually.',
                ),
              ),
            )
          else
            _buildEpisodeSliver(),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    final genres = widget.media.genres.take(8).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectionArea(
            child: Text(
              widget.media.displayTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          if (genres.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in genres)
                  Chip(
                    label: Text(genre),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          if (widget.media.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            ExpandableSelectableText(
              widget.media.description,
              collapsedLines: 5,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Episodes',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              FilterChip(
                label: Text(_dub ? 'Dub' : 'Sub'),
                selected: _dub,
                avatar: const Icon(Icons.translate, size: 18),
                onSelected: (value) async {
                  setState(() => _dub = value);
                  await _load();
                },
              ),
              IconButton(
                tooltip: 'Download all episodes',
                onPressed: _providerAnime == null || _episodes.isEmpty
                    ? null
                    : () => unawaited(_downloadAllEpisodes()),
                icon: const Icon(Icons.download_for_offline_outlined),
              ),
              IconButton(
                tooltip: widget.preferences.episodesDescending
                    ? 'Descending'
                    : 'Ascending',
                onPressed: () => widget.preferences.setEpisodesDescending(
                  !widget.preferences.episodesDescending,
                ),
                icon: Icon(
                  widget.preferences.episodesDescending
                      ? Icons.south
                      : Icons.north,
                ),
              ),
              PopupMenuButton<EpisodeLayoutMode>(
                tooltip: 'Layout',
                icon: const Icon(Icons.grid_view),
                initialValue: widget.preferences.episodeLayoutMode,
                onSelected: widget.preferences.setEpisodeLayoutMode,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: EpisodeLayoutMode.semi,
                    child: Text('Semi grid'),
                  ),
                  PopupMenuItem(
                    value: EpisodeLayoutMode.full,
                    child: Text('Full grid'),
                  ),
                  PopupMenuItem(
                    value: EpisodeLayoutMode.list,
                    child: Text('List'),
                  ),
                ],
              ),
            ],
          ),
          if (_providerAnime != null)
            Text(
              'Matched: ${_providerAnime!.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildEpisodeSliver() {
    final episodes = _displayEpisodes;
    if (widget.preferences.episodeLayoutMode == EpisodeLayoutMode.list) {
      return SliverList.builder(
        itemCount: episodes.length,
        itemBuilder: (context, index) => _EpisodeListTile(
          episode: episodes[index],
          progress: _progressFor(episodes[index]),
          downloadService: widget.downloadService,
          downloadId: _downloadIdFor(episodes[index]),
          onTap: () => _openEpisode(episodes[index]),
          onLongPress: () => _showEpisodeOptions(episodes[index]),
        ),
      );
    }

    final isFull =
        widget.preferences.episodeLayoutMode == EpisodeLayoutMode.full;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverGrid.builder(
        itemCount: episodes.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: isFull ? 220 : 170,
          mainAxisExtent: isFull ? 238 : 112,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) => _EpisodeCard(
          episode: episodes[index],
          progress: _progressFor(episodes[index]),
          full: isFull,
          downloadService: widget.downloadService,
          downloadId: _downloadIdFor(episodes[index]),
          onTap: () => _openEpisode(episodes[index]),
          onLongPress: () => _showEpisodeOptions(episodes[index]),
        ),
      ),
    );
  }

  double _progressFor(AnimeEpisode episode) {
    return (_history['${widget.media.id}-${episode.number}']
                    ?.watchedPercentage ??
                0)
            .clamp(0, 100) /
        100;
  }

  String _downloadIdFor(AnimeEpisode episode) =>
      '${widget.media.id}-${episode.number}';
}

enum _VideoSourceAction { copyLink, openExternal }

class _SourceDownloadButton extends StatefulWidget {
  const _SourceDownloadButton({
    required this.service,
    required this.request,
    required this.onDownload,
  });

  final DownloadService service;
  final EpisodeDownloadRequest request;
  final Future<void> Function() onDownload;

  @override
  State<_SourceDownloadButton> createState() => _SourceDownloadButtonState();
}

class _SourceDownloadButtonState extends State<_SourceDownloadButton> {
  bool _loadingQualities = false;

  Future<void> _startDownload() async {
    if (_loadingQualities) {
      return;
    }

    setState(() => _loadingQualities = true);
    try {
      await widget.onDownload();
    } finally {
      if (mounted) {
        setState(() => _loadingQualities = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final task = widget.service.taskForSource(widget.request.taskId);
        if (task != null) {
          final canceling = task.status == DownloadTaskStatus.canceling;
          final pausing = task.status == DownloadTaskStatus.pausing;
          final paused = task.status == DownloadTaskStatus.paused;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  value: task.progress,
                  strokeWidth: 2.4,
                ),
              ),
              IconButton(
                tooltip: paused
                    ? 'Resume download'
                    : pausing
                    ? 'Pausing download'
                    : 'Pause download',
                visualDensity: VisualDensity.compact,
                onPressed: canceling || pausing
                    ? null
                    : paused
                    ? () => widget.service.resumeDownload(task.id)
                    : () => widget.service.pauseDownload(task.id),
                icon: Icon(
                  paused
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                ),
              ),
              IconButton(
                tooltip: canceling ? 'Stopping download' : 'Cancel download',
                visualDensity: VisualDensity.compact,
                onPressed: canceling
                    ? null
                    : () => widget.service.cancelDownload(task.id),
                icon: const Icon(Icons.stop_circle_outlined),
              ),
            ],
          );
        }

        if (_loadingQualities) {
          return IconButton(
            tooltip: 'Getting download qualities',
            visualDensity: VisualDensity.compact,
            onPressed: null,
            icon: const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }

        if (widget.service.isDownloaded(widget.request.id)) {
          return IconButton(
            tooltip: 'Downloaded',
            visualDensity: VisualDensity.compact,
            onPressed: null,
            icon: const Icon(Icons.download_done),
          );
        }

        return IconButton(
          tooltip: 'Download episode',
          visualDensity: VisualDensity.compact,
          onPressed: _startDownload,
          icon: const Icon(Icons.download),
        );
      },
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url, this.onLongPress});

  final String? url;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: url == null ? null : onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 90,
          height: 132,
          child: url == null
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                )
              : CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _SmallCover extends StatelessWidget {
  const _SmallCover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 44,
        height: 58,
        child: url == null
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              )
            : CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover),
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
    final maxChipWidth = (MediaQuery.sizeOf(context).width - 144)
        .clamp(80.0, 360.0)
        .toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xAA000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.progress,
    required this.full,
    required this.downloadService,
    required this.downloadId,
    required this.onTap,
    required this.onLongPress,
  });

  final AnimeEpisode episode;
  final double progress;
  final bool full;
  final DownloadService downloadService;
  final String downloadId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final image = episode.image;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null)
                    CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC000000)],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'EP ${AnimeEpisode.displayNumber(episode.number)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _EpisodeDownloadStatus(
                      service: downloadService,
                      downloadId: downloadId,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
            if (full)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Text(
                  episode.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (progress > 0)
              LinearProgressIndicator(value: progress, minHeight: 3),
          ],
        ),
      ),
    );
  }
}

class _EpisodeListTile extends StatelessWidget {
  const _EpisodeListTile({
    required this.episode,
    required this.progress,
    required this.downloadService,
    required this.downloadId,
    required this.onTap,
    required this.onLongPress,
  });

  final AnimeEpisode episode;
  final double progress;
  final DownloadService downloadService;
  final String downloadId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _SmallCover(url: episode.image),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress, minHeight: 3),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _EpisodeDownloadStatus(
                  service: downloadService,
                  downloadId: downloadId,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeDownloadStatus extends StatelessWidget {
  const _EpisodeDownloadStatus({
    required this.service,
    required this.downloadId,
    this.compact = false,
  });

  final DownloadService service;
  final String downloadId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final task = service.taskForEpisode(downloadId);
        if (task != null) {
          final canceling = task.status == DownloadTaskStatus.canceling;
          final pausing = task.status == DownloadTaskStatus.pausing;
          final paused = task.status == DownloadTaskStatus.paused;
          final size = compact ? 34.0 : 42.0;
          return Tooltip(
            message: paused
                ? 'Resume download'
                : pausing
                ? 'Pausing download'
                : canceling
                ? 'Stopping download'
                : 'Pause download',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: canceling || pausing
                  ? null
                  : paused
                  ? () => service.resumeDownload(task.id)
                  : () => service.pauseDownload(task.id),
              icon: SizedBox.square(
                dimension: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: task.progress,
                      strokeWidth: compact ? 2.4 : 2.8,
                    ),
                    Icon(
                      paused
                          ? Icons.play_arrow
                          : pausing || canceling
                          ? Icons.more_horiz
                          : Icons.pause,
                      size: compact ? 16 : 20,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (service.isDownloaded(downloadId)) {
          return Icon(
            Icons.download_done,
            color: Theme.of(context).colorScheme.primary,
          );
        }

        return compact ? const SizedBox.shrink() : const Icon(Icons.play_arrow);
      },
    );
  }
}
