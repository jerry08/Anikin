import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_services.dart';
import '../core/list_ranges.dart';
import '../core/text_utils.dart';
import '../models/anilist_media.dart';
import '../models/anilist_media_details.dart';
import '../models/anilist_person_details.dart';
import '../models/downloaded_episode.dart';
import '../models/juro_models.dart';
import '../models/tracking.dart';
import '../models/watch_history.dart';
import '../services/download_service.dart';
import '../services/aniyomi_extension_service.dart';
import '../services/anilist_service.dart';
import '../services/feature_gate_service.dart';
import '../services/juro_service.dart';
import '../services/notification_subscription_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/anilist_list_entry_sheet.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_error_view.dart';
import '../widgets/detail_media_tools.dart';
import '../widgets/list_range_selector.dart';
import '../widgets/media_detail_header.dart';
import '../widgets/media_poster_card.dart';
import '../widgets/rich_media_details.dart';
import 'manga_detail_screen.dart';
import 'player_screen.dart';
import 'person_detail_screen.dart';

enum _AnimeDetailSection { info, watch }

enum _AnimeDetailMenuAction { openAniList, copyTitle }

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    required this.media,
    required this.preferences,
    required this.juroService,
    required this.watchHistoryService,
    required this.downloadService,
    required this.trackingService,
    this.initialProvider,
    this.initialProviderAnime,
    super.key,
  });

  final AniListMedia media;
  final PreferencesService preferences;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final TrackingService trackingService;
  final SourceProvider? initialProvider;
  final JuroAnimeInfo? initialProviderAnime;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ScrollController _detailsScrollController = ScrollController();
  final Map<_AnimeDetailSection, double> _sectionOffsets = {};
  List<SourceProvider> _providers = [];
  JuroAnimeInfo? _providerAnime;
  List<AnimeEpisode> _episodes = [];
  Map<String, WatchedEpisode> _history = {};
  bool _loading = true;
  bool _dub = false;
  bool _isFavorite = false;
  bool _favoriteLoading = false;
  AniListMediaListEntry? _listEntry;
  bool _listEntryLoading = false;
  bool _listEntrySaving = false;
  int _episodeRangeIndex = 0;
  String? _error;
  String? _status;
  SourceProviderChoice? _localProviderChoice;
  AniListMediaDetails? _richDetails;
  bool _richDetailsRequested = false;
  bool _richDetailsLoading = false;
  bool _sourceFallbackEnabled = false;
  NotificationSubscriptionService? _notificationSubscriptions;
  bool _notificationsFollowed = false;
  bool _notificationsLoading = false;
  _AnimeDetailSection _selectedSection = _AnimeDetailSection.watch;

  bool get _usesLocalProvider =>
      widget.initialProvider != null || widget.initialProviderAnime != null;

  String get _providerKey =>
      _localProviderChoice?.key ?? widget.preferences.lastAnimeProviderKey;

  String get _providerName =>
      _localProviderChoice?.name ??
      widget.preferences.lastAnimeProviderName ??
      _providerKey;

  @override
  void initState() {
    super.initState();
    _selectedSection =
        _AnimeDetailSection.values[widget.preferences.detailSectionIndex(
          mediaKind: 'anime',
          mediaId: widget.media.id,
        )];
    final provider = widget.initialProvider;
    if (provider != null) {
      _localProviderChoice = SourceProviderChoice(
        key: provider.key,
        name: provider.name,
      );
    }
    _load();
    _refreshFavorite();
    _refreshAniListListEntry();
    if (_selectedSection == _AnimeDetailSection.watch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _restoreSectionOffset(_selectedSection);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppScope.maybeOf(context);
    if (_notificationSubscriptions == null && services != null) {
      _notificationSubscriptions = services.notificationSubscriptions;
      unawaited(_refreshNotificationFollow());
    }
    _sourceFallbackEnabled =
        services?.featureGates.isEnabled(AppFeature.sourceFallback) ?? false;
    if (_richDetailsRequested || !widget.media.hasAniListId) {
      return;
    }
    if (services == null ||
        !services.featureGates.isEnabled(AppFeature.richMediaDetails)) {
      return;
    }
    _richDetailsRequested = true;
    unawaited(_loadRichDetails(services.aniListService));
  }

  Future<void> _loadRichDetails(AniListService service) async {
    setState(() => _richDetailsLoading = true);
    try {
      final details = await service.getMediaDetails(
        id: widget.media.id,
        mediaType: AniListMediaType.anime,
      );
      if (mounted) {
        setState(() => _richDetails = details);
      }
    } catch (_) {
      // Rich metadata is additive; provider playback remains usable offline.
    } finally {
      if (mounted) {
        setState(() => _richDetailsLoading = false);
      }
    }
  }

  void _openRelatedMedia(AniListMedia media) {
    if (media.mediaType == AniListMediaType.anime.graphqlName) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetailScreen(
            media: media,
            preferences: widget.preferences,
            juroService: widget.juroService,
            watchHistoryService: widget.watchHistoryService,
            downloadService: widget.downloadService,
            trackingService: widget.trackingService,
          ),
        ),
      );
      return;
    }
    final services = AppScope.maybeOf(context);
    if (media.mediaType == AniListMediaType.manga.graphqlName &&
        services != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MangaDetailScreen(
            media: media,
            preferences: services.preferences,
            juroService: services.juroService,
            mangaDownloadService: services.mangaDownloadService,
            trackingService: services.trackingService,
          ),
        ),
      );
      return;
    }
    final siteUrl = media.siteUrl;
    if (siteUrl != null) {
      unawaited(
        launchUrl(Uri.parse(siteUrl), mode: LaunchMode.externalApplication),
      );
    }
  }

  void _openPerson(AniListPersonCredit person, AniListPersonKind kind) {
    final service = AppScope.maybeOf(context)?.aniListService;
    if (service == null || person.id <= 0) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PersonDetailScreen(
          person: person,
          kind: kind,
          aniListService: service,
          onMediaTap: _openRelatedMedia,
        ),
      ),
    );
  }

  AniListPersonCredit? get _primaryCreator {
    final staff = _richDetails?.staff ?? const <AniListPersonCredit>[];
    for (final person in staff) {
      final role = person.role.toLowerCase();
      if (role.contains('director') ||
          role.contains('original creator') ||
          role.contains('series composition')) {
        return person;
      }
    }
    return null;
  }

  void _selectSection(_AnimeDetailSection section) {
    if (_selectedSection == section) {
      _scrollDetailsTo(0);
      return;
    }
    if (_detailsScrollController.hasClients) {
      _sectionOffsets[_selectedSection] = _detailsScrollController.offset;
    }
    setState(() => _selectedSection = section);
    unawaited(
      widget.preferences.setDetailSectionIndex(
        mediaKind: 'anime',
        mediaId: widget.media.id,
        index: section.index,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoreSectionOffset(section);
      }
    });
  }

  void _restoreSectionOffset(_AnimeDetailSection section) {
    if (!_detailsScrollController.hasClients) {
      return;
    }
    final defaultOffset = section == _AnimeDetailSection.info
        ? 0.0
        : mediaDetailHeaderHeight(context) - kToolbarHeight;
    _scrollDetailsTo(_sectionOffsets[section] ?? defaultOffset);
  }

  void _scrollDetailsTo(double requestedOffset) {
    if (!_detailsScrollController.hasClients) {
      return;
    }
    final target = requestedOffset
        .clamp(0, _detailsScrollController.position.maxScrollExtent)
        .toDouble();
    if ((_detailsScrollController.offset - target).abs() < 1) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _detailsScrollController.jumpTo(target);
      return;
    }
    unawaited(
      _detailsScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _showWatchOrder() async {
    final service = AppScope.maybeOf(context)?.watchOrderService;
    if (service == null) return;
    final future = service.orderFor(_richDetails?.media ?? widget.media);
    final selected = await showAppBottomSheet<AniListMedia>(
      context: context,
      builder: (context, scrollController) => FutureBuilder<List<AniListMedia>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorView(message: snapshot.error.toString());
          }
          final items = snapshot.data ?? const [];
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text(
                'Watch order',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Main prequel and sequel chain inferred from AniList relations.',
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < items.length; index++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    selected: items[index].id == widget.media.id,
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(items[index].displayTitle),
                    subtitle: Text(
                      items[index].metadata.isEmpty
                          ? 'Anime'
                          : items[index].metadata,
                    ),
                    trailing: items[index].id == widget.media.id
                        ? const Icon(Icons.play_circle_fill)
                        : const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(items[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
    if (selected != null && selected.id != widget.media.id && mounted) {
      _openRelatedMedia(selected);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Loading providers';
      _episodes = [];
      _episodeRangeIndex = 0;
    });

    try {
      _providers = await widget.juroService.getProviders();
      _providers = await widget.juroService.rankProviders(
        _providers,
        preferredKey: _providerKey,
      );
      if (_usesLocalProvider) {
        final initialProvider = widget.initialProvider;
        if (initialProvider != null &&
            !_providers.any((item) => item.key == initialProvider.key)) {
          _providers = [initialProvider, ..._providers];
        }
      } else if (_providers.isNotEmpty &&
          !_providers.any((item) => item.key == _providerKey)) {
        final provider = _providers.first;
        await widget.preferences.setLastAnimeProvider(
          SourceProviderChoice(key: provider.key, name: provider.name),
        );
      }

      _history = await widget.watchHistoryService.getAll();
      final initialAnime = widget.initialProviderAnime;
      final initialProvider = widget.initialProvider;
      final stillUsingInitialProvider =
          initialProvider == null || _providerKey == initialProvider.key;
      if (initialAnime != null &&
          _usesLocalProvider &&
          stillUsingInitialProvider) {
        await _loadEpisodes(initialAnime);
      } else {
        await _autoMatchAndLoadEpisodes();
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          if (_error != null || _isTransientStatus(_status)) {
            _status = null;
          }
        });
      }
    }
  }

  bool _isTransientStatus(String? status) {
    return status == 'Loading providers' ||
        status == 'Loading episodes from $_providerName' ||
        (status?.startsWith('Searching ') ?? false);
  }

  Future<void> _autoMatchAndLoadEpisodes() async {
    final originalProviderKey = _providerKey;
    final originalChoice = _localProviderChoice;
    SourceProvider? currentProvider;
    for (final provider in _providers) {
      if (provider.key == originalProviderKey) {
        currentProvider = provider;
        break;
      }
    }
    final providerCandidates = <SourceProvider>[
      ?currentProvider,
      if (_sourceFallbackEnabled)
        for (final provider in _providers)
          if (provider.key != originalProviderKey) provider,
    ];
    if (providerCandidates.isEmpty) {
      setState(() => _status = 'No providers available');
      return;
    }

    final candidates = widget.media.title.searchCandidates.toList();
    for (final provider in providerCandidates) {
      if (!mounted) return;
      setState(() {
        _localProviderChoice = SourceProviderChoice(
          key: provider.key,
          name: provider.name,
        );
        _status = provider.key == originalProviderKey
            ? 'Searching ${widget.media.displayTitle}'
            : 'Trying fallback source ${provider.name}';
      });
      // Aniyomi sources index canonical titles; a " (dub)" suffix only breaks
      // their search. Dub selection there happens via source settings/servers.
      final isAniyomiProvider = AniyomiExtensionService.isProviderKey(
        provider.key,
      );
      final dubText = _dub && !isAniyomiProvider ? ' (dub)' : '';
      try {
        JuroAnimeInfo? match;
        for (final title in candidates) {
          final results = await widget.juroService.searchAnime(
            '$title$dubText',
            providerKey: provider.key,
          );
          if (results.isNotEmpty) {
            match =
                bestTitleMatch(results, candidates, (item) => item.title) ??
                results.first;
            break;
          }
        }
        if (match == null) {
          continue;
        }
        await _loadEpisodes(match);
        if (_episodes.isNotEmpty) {
          return;
        }
      } catch (_) {
        // A failed provider is recorded by JuroService; try the next ranked one.
      }
    }

    setState(() {
      _localProviderChoice = originalChoice;
      _providerAnime = null;
      _episodes = [];
      _episodeRangeIndex = 0;
      _status = 'No source match found';
    });
  }

  Future<void> _refreshNotificationFollow() async {
    final service = _notificationSubscriptions;
    if (service == null) return;
    final followed = await service.isManuallySubscribed(
      widget.media.id,
      'anime',
    );
    if (mounted) {
      setState(() => _notificationsFollowed = followed);
    }
  }

  Future<void> _toggleNotificationFollow() async {
    final service = _notificationSubscriptions;
    final appServices = AppScope.maybeOf(context);
    if (service == null || appServices == null || _notificationsLoading) {
      return;
    }
    setState(() => _notificationsLoading = true);
    try {
      if (!appServices.preferences.notificationsEnabled) {
        final enabled = await appServices.notificationCoordinator.setEnabled(
          true,
        );
        if (!enabled) return;
      }
      if (_notificationsFollowed) {
        await service.unsubscribeManual(widget.media.id, 'anime');
      } else {
        await service.subscribeManual(
          media: widget.media,
          mediaType: 'anime',
          sourceKey: _providerKey,
          providerItemId: _providerAnime?.id,
        );
      }
      await _refreshNotificationFollow();
      if (!_notificationsFollowed) return;
      unawaited(appServices.notificationCoordinator.syncAndRefresh());
    } finally {
      if (mounted) setState(() => _notificationsLoading = false);
    }
  }

  Future<void> _loadEpisodes(JuroAnimeInfo anime) async {
    setState(() {
      _providerAnime = anime;
      _status = 'Loading episodes from $_providerName';
    });

    final List<AnimeEpisode> episodes;
    try {
      episodes = List<AnimeEpisode>.of(
        await widget.juroService.getEpisodes(
          anime.id,
          providerKey: _providerKey,
        ),
      );
    } catch (error) {
      if (!AniyomiExtensionService.isExtensionError(error)) {
        rethrow;
      }
      if (!mounted) return;
      setState(() {
        _episodes = [];
        _episodeRangeIndex = 0;
        _status = 'Provider failed to load episodes';
      });
      return;
    }
    episodes.sort((a, b) => a.number.compareTo(b.number));

    setState(() {
      _episodes = episodes
          .map(
            (episode) => episode.copyWith(
              image: episode.image ?? anime.image ?? widget.media.cover.best,
            ),
          )
          .toList();
      _episodeRangeIndex = 0;
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

  List<ListRange> get _episodeRanges =>
      buildNumberedListRanges(_displayEpisodes, (episode) => episode.number);

  List<AnimeEpisode> get _visibleEpisodes =>
      applyListRange(_displayEpisodes, _episodeRanges, _episodeRangeIndex);

  Future<void> _refreshHistory() async {
    final history = await widget.watchHistoryService.getAll();
    if (mounted) {
      setState(() => _history = history);
    }
  }

  Future<void> _changeProvider() async {
    final provider = await showAppBottomSheet<SourceProvider>(
      context: context,
      initialChildSize: 0.42,
      minChildSize: 0.28,
      builder: (context, scrollController) => _AnimeProviderSheet(
        providers: _providers,
        selectedProviderKey: _providerKey,
        scrollController: scrollController,
      ),
    );

    if (provider == null) {
      return;
    }

    final providerChoice = SourceProviderChoice(
      key: provider.key,
      name: provider.name,
    );
    _localProviderChoice = providerChoice;
    if (!_usesLocalProvider) {
      await widget.preferences.setLastAnimeProvider(providerChoice);
    }
    await _load();
  }

  Future<void> _manualMatch() async {
    final match = await showAppBottomSheet<JuroAnimeInfo>(
      context: context,
      initialChildSize: 0.72,
      minChildSize: 0.34,
      maxChildSize: 1,
      builder: (context, scrollController) => _ManualAnimeSearchSheet(
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
      await _loadEpisodes(match);
    } catch (error) {
      if (mounted) {
        setState(() => _status = null);
        await showErrorDialog(context, error, title: 'Provider search failed');
      }
    }
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
          providerKey: _providerKey,
          providerName: _providerName,
        ),
      ),
    );

    await Future.wait([_refreshHistory(), _refreshAniListListEntry()]);
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
    return showAppBottomSheet<VideoSource>(
      context: context,
      initialChildSize: 0.72,
      minChildSize: 0.36,
      maxChildSize: 0.92,
      builder: (context, controller) => _VideoSourcePicker(
        title: title,
        scrollController: controller,
        loadServers: () => widget.juroService.getVideoServers(
          episode.id,
          providerKey: _providerKey,
        ),
        loadVideosForServer: (server) => widget.juroService.getVideos(
          server.embed.url,
          providerKey: _providerKey,
        ),
        loadAllVideos: () =>
            widget.juroService.getVideos(episode.id, providerKey: _providerKey),
        buildSourceTile: (context, source) =>
            _buildVideoSourceTile(context, episode, source, showSourceActions),
      ),
    );
  }

  Widget _buildVideoSourceTile(
    BuildContext context,
    AnimeEpisode episode,
    VideoSource source,
    bool showSourceActions,
  ) {
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
                  onDownload: () => _downloadEpisodeRequest(request),
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
          ? () => _handleVideoSourceAction(source, _VideoSourceAction.copyLink)
          : null,
      onTap: () => Navigator.of(context).pop(source),
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
            await showErrorDialog(
              context,
              'Unable to open $url',
              title: 'Unable to open link',
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

    try {
      await widget.downloadService.startDownload(selectedRequest);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading ${selectedRequest.episode.displayName}'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error, title: 'Episode download failed');
      }
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
        await showErrorDialog(context, error, title: 'Download setup failed');
      }
      return null;
    }

    if (variants.isEmpty) {
      return request;
    }

    final selectedVariant = variants.length == 1
        ? variants.first
        : switch (widget.preferences.downloadQualityPreference) {
            DownloadQualityPreference.askEveryTime =>
              await _chooseHlsDownloadQuality(variants),
            DownloadQualityPreference.highest => variants.first,
            DownloadQualityPreference.dataSaver => variants.last,
          };
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
          AppDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
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
    Object? firstError;
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
        final request = EpisodeDownloadRequest(
          media: widget.media,
          providerAnime: _providerAnime!,
          episode: episode,
          source: source,
        );
        final selectedRequest =
            widget.preferences.downloadQualityPreference ==
                DownloadQualityPreference.askEveryTime
            ? request
            : await _resolveDownloadRequest(request);
        if (selectedRequest == null) {
          failed++;
          continue;
        }
        await widget.downloadService.startDownload(selectedRequest);
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
        ).showSnackBar(SnackBar(content: Text('Queued $queued episodes')));
      } else {
        await showErrorDialog(
          context,
          firstError ?? '$failed episodes could not be queued.',
          title: 'Some episodes failed',
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

  Future<void> _shareMedia(BuildContext shareContext) async {
    final media = _richDetails?.media ?? widget.media;
    final siteUrl = media.siteUrl ?? widget.media.siteUrl;
    final box = shareContext.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await SharePlus.instance.share(
      ShareParams(
        subject: media.displayTitle,
        text: [media.displayTitle, ?siteUrl].join('\n'),
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<void> _copyTitle() async {
    final title = (_richDetails?.media ?? widget.media).displayTitle;
    await Clipboard.setData(ClipboardData(text: title));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied title')));
    }
  }

  void _handleMenuAction(_AnimeDetailMenuAction action) {
    switch (action) {
      case _AnimeDetailMenuAction.openAniList:
        unawaited(_openAniList());
      case _AnimeDetailMenuAction.copyTitle:
        unawaited(_copyTitle());
    }
  }

  Future<void> _refreshFavorite() async {
    if (!widget.media.hasAniListId) {
      return;
    }
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
    if (!widget.media.hasAniListId) {
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
        await showErrorDialog(context, error, title: 'Favorite sync failed');
      }
    } finally {
      if (mounted) {
        setState(() => _favoriteLoading = false);
      }
    }
  }

  Future<void> _refreshAniListListEntry({bool showErrors = false}) async {
    if (!widget.media.hasAniListId) {
      if (mounted) {
        setState(() => _listEntry = null);
      }
      return;
    }
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
        kind: TrackingMediaKind.anime,
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
    if (!widget.media.hasAniListId) {
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
        kind: TrackingMediaKind.anime,
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
      kind: TrackingMediaKind.anime,
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
    final theme = Theme.of(context);
    final media = _richDetails?.media ?? widget.media;
    final banner = media.bannerImage ?? widget.media.bannerImage;
    final cover = media.cover.best ?? widget.media.cover.best;
    final canUseAniList = widget.media.hasAniListId;
    final headerHeight = mediaDetailHeaderHeight(context);
    final tabs = [
      const MediaDetailTab(icon: Icons.info_outline_rounded, label: 'Info'),
      MediaDetailTab(
        icon: Icons.movie_filter_outlined,
        label: 'Watch',
        badge: _episodes.isEmpty ? null : '${_episodes.length}',
        badgeLabel: _episodes.isEmpty ? null : '${_episodes.length} episodes',
      ),
    ];
    return MediaDetailScaffold(
      tabs: tabs,
      selectedIndex: _selectedSection.index,
      onSelected: (index) => _selectSection(_AnimeDetailSection.values[index]),
      body: CustomScrollView(
        controller: _detailsScrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: headerHeight,
            backgroundColor: theme.scaffoldBackgroundColor,
            title: MediaCollapsedTitle(
              controller: _detailsScrollController,
              text: media.displayTitle,
              expandedHeight: headerHeight,
            ),
            actions: [
              IconButton(
                tooltip: 'Watch order',
                onPressed:
                    canUseAniList &&
                        AppScope.maybeOf(context)?.watchOrderService != null
                    ? _showWatchOrder
                    : null,
                icon: const Icon(Icons.account_tree_outlined),
              ),
              PopupMenuButton<_AnimeDetailMenuAction>(
                tooltip: 'More options',
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _AnimeDetailMenuAction.openAniList,
                    enabled: widget.media.siteUrl != null,
                    child: const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.open_in_new),
                      title: Text('Open on AniList'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _AnimeDetailMenuAction.copyTitle,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.copy),
                      title: Text('Copy title'),
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: MediaDetailHeader(
                title: media.displayTitle,
                statusText: mediaEnumLabel(media.status),
                bannerUrl: banner,
                coverUrl: cover,
                listButtonLabel: canUseAniList ? _listButtonLabel() : null,
                listButtonBusy: _listEntryLoading || _listEntrySaving,
                onListButtonPressed: _editAniListListEntry,
                onBannerLongPress: () => _showImagePreview(banner ?? cover),
                onCoverLongPress: () => _showImagePreview(cover),
                onTitleLongPress: _copyTitle,
                scrollController: _detailsScrollController,
                expandedHeight: headerHeight,
                posterHeroTag: mediaPosterHeroTag(media),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: MediaDetailTotalRow(
              text: _totalRowText(),
              primaryActionLabel: _primaryActionLabel(),
              primaryActionBusy: _loading && _episodes.isEmpty,
              onPrimaryAction: _loading && _episodes.isEmpty
                  ? null
                  : _handlePrimaryAction,
              actions: [
                MediaDetailActionIcon(
                  tooltip: _notificationsFollowed
                      ? 'Stop manual release alerts'
                      : 'Follow release alerts',
                  onPressed:
                      !canUseAniList ||
                          _notificationSubscriptions == null ||
                          _notificationsLoading
                      ? null
                      : _toggleNotificationFollow,
                  icon: Icons.notifications_none,
                  activeIcon: Icons.notifications_active,
                  active: _notificationsFollowed,
                  busy: _notificationsLoading,
                ),
                MediaDetailActionIcon(
                  tooltip: _isFavorite ? 'Remove favorite' : 'Favorite',
                  onPressed: !canUseAniList || _favoriteLoading
                      ? null
                      : _toggleFavorite,
                  icon: Icons.favorite_border,
                  activeIcon: Icons.favorite,
                  active: _isFavorite,
                  busy: _favoriteLoading,
                ),
                Builder(
                  builder: (shareContext) => IconButton(
                    tooltip: 'Share',
                    onPressed: () => unawaited(_shareMedia(shareContext)),
                    icon: const Icon(Icons.share_outlined),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedSection == _AnimeDetailSection.info)
            SliverToBoxAdapter(
              child: MediaDetailContentConstraint(child: _buildOverview()),
            ),
          if (_selectedSection == _AnimeDetailSection.watch)
            SliverToBoxAdapter(
              child: MediaDetailContentConstraint(child: _buildEpisodeHeader()),
            ),
          if (_selectedSection == _AnimeDetailSection.watch && _loading)
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
          else if (_selectedSection == _AnimeDetailSection.watch &&
              _error != null)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                child: AppErrorView(message: _error!, onRetry: _load),
              ),
            )
          else if (_selectedSection == _AnimeDetailSection.watch &&
              _episodes.isEmpty)
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
          else if (_selectedSection == _AnimeDetailSection.watch)
            _buildEpisodeSliver(),
          SliverToBoxAdapter(
            child: SizedBox(height: _detailBottomPadding(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    final media = _richDetails?.media ?? widget.media;
    final creator = _primaryCreator;
    final genres = media.genres.take(8).toList();
    final season = [
      ?mediaEnumLabel(media.season),
      if (media.seasonYear case final year?) '$year',
    ].join(' ');
    final rows = <MediaInfoRowData>[
      if (media.meanScore case final score?)
        MediaInfoRowData('Mean Score', '$score / 100', highlight: true),
      if (mediaEnumLabel(media.status) case final status?)
        MediaInfoRowData('Status', status),
      if (media.startDate case final date?)
        MediaInfoRowData('Start Date', date),
      if (media.endDate case final date?) MediaInfoRowData('End Date', date),
      if (media.episodes case final episodes?)
        MediaInfoRowData('Total Episodes', '$episodes')
      else if (_episodes.isNotEmpty)
        MediaInfoRowData('Loaded Episodes', '${_episodes.length}'),
      if (media.duration case final duration?)
        MediaInfoRowData('Episode Duration', '$duration min'),
      if (mediaEnumLabel(media.format) case final format?)
        MediaInfoRowData('Format', format),
      if (mediaEnumLabel(media.source) case final source?)
        MediaInfoRowData('Source', source),
      if (_richDetails?.studios case final studios? when studios.isNotEmpty)
        MediaInfoRowData('Studios', studios.take(3).join(', ')),
      if (creator != null)
        MediaInfoRowData(
          'Creator',
          creator.name,
          highlight: true,
          onTap: () => _openPerson(creator, AniListPersonKind.staff),
          semanticHint: 'Open creator details',
        ),
      if (season.isNotEmpty) MediaInfoRowData('Season', season),
      if (media.countryOfOrigin case final country?)
        MediaInfoRowData('Country', country),
      if (media.popularity case final popularity?)
        MediaInfoRowData('Popularity', compactNumber(popularity)),
      if (media.favourites case final favourites?)
        MediaInfoRowData('Favorites', compactNumber(favourites)),
    ];
    final nameBlocks = <(String, String)>[
      if (media.title.romaji case final romaji?
          when romaji.trim().isNotEmpty && romaji != media.displayTitle)
        ('Name (Romaji)', romaji),
      if (media.title.native case final native? when native.trim().isNotEmpty)
        ('Name (Native)', native),
      if (_richDetails?.synonyms case final synonyms? when synonyms.isNotEmpty)
        ('Also Known As', synonyms.take(5).join(' · ')),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaInfoTable(rows: rows, nameBlocks: nameBlocks),
          if (_richDetails case final details?)
            MediaDetailHighlightsCard(details: details),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 18),
            const MediaDetailSectionTitle('Genres'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
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
            ),
          ],
          if (media.description.isNotEmpty) ...[
            const SizedBox(height: 18),
            const MediaDetailSectionTitle('Description'),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ExpandableSelectableText(
                media.description,
                collapsedLines: 5,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          if (_richDetailsLoading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 2),
          ] else if (_richDetails case final details?) ...[
            const SizedBox(height: 10),
            RichMediaDetailsPanel(
              details: details,
              onMediaTap: _openRelatedMedia,
              onPersonTap: _openPerson,
            ),
          ],
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildEpisodeHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaSourceSelectorTile(
            sourceName: _providerName,
            onTap: _providers.isEmpty ? null : _changeProvider,
            matchedTitle: _providerAnime?.title,
            onWrongTitle: _providers.isEmpty ? null : _manualMatch,
            loading: _loading,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Episodes',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                onPressed: () async {
                  await widget.preferences.setEpisodesDescending(
                    !widget.preferences.episodesDescending,
                  );
                  if (mounted) {
                    setState(() => _episodeRangeIndex = 0);
                  }
                },
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
                onSelected: (value) async {
                  await widget.preferences.setEpisodeLayoutMode(value);
                  if (mounted) {
                    setState(() {});
                  }
                },
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
          if (_episodeRanges.isNotEmpty) ...[
            const SizedBox(height: 10),
            ListRangeSelector(
              ranges: _episodeRanges,
              selectedIndex: _episodeRangeIndex,
              onSelected: (index) => setState(() => _episodeRangeIndex = index),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildEpisodeSliver() {
    final episodes = _visibleEpisodes;
    final nextEpisodeId = _continueEpisode?.id;
    if (widget.preferences.episodeLayoutMode == EpisodeLayoutMode.list) {
      return MediaDetailSliverConstraint(
        maxWidth: 840,
        sliver: SliverList.builder(
          itemCount: episodes.length,
          itemBuilder: (context, index) => _EpisodeListTile(
            episode: episodes[index],
            progress: _progressFor(episodes[index]),
            isNext: nextEpisodeId == episodes[index].id,
            downloadService: widget.downloadService,
            downloadId: _downloadIdFor(episodes[index]),
            onTap: () => _openEpisode(episodes[index]),
            onLongPress: () => _showEpisodeOptions(episodes[index]),
            onOptions: () => _showEpisodeOptions(episodes[index]),
          ),
        ),
      );
    }

    final isFull =
        widget.preferences.episodeLayoutMode == EpisodeLayoutMode.full;
    return MediaDetailSliverConstraint(
      sliver: SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        sliver: SliverGrid.builder(
          itemCount: episodes.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isFull ? 240 : 210,
            mainAxisExtent: isFull ? 252 : 144,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) => _EpisodeCard(
            episode: episodes[index],
            progress: _progressFor(episodes[index]),
            isNext: nextEpisodeId == episodes[index].id,
            full: isFull,
            downloadService: widget.downloadService,
            downloadId: _downloadIdFor(episodes[index]),
            onTap: () => _openEpisode(episodes[index]),
            onLongPress: () => _showEpisodeOptions(episodes[index]),
            onOptions: () => _showEpisodeOptions(episodes[index]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detailsScrollController.dispose();
    super.dispose();
  }

  WatchedEpisode? _historyForEpisode(AnimeEpisode episode) {
    final direct = _history['${widget.media.id}-${episode.number}'];
    if (direct != null) {
      return direct;
    }
    for (final item in _history.values) {
      if (item.mediaId == widget.media.id &&
          item.episodeNumber != null &&
          (item.episodeNumber! - episode.number).abs() < 0.001) {
        return item;
      }
    }
    return null;
  }

  double _localProgressFor(AnimeEpisode episode) {
    return ((_historyForEpisode(episode)?.watchedPercentage ?? 0).clamp(
          0,
          100,
        ) /
        100);
  }

  double _progressFor(AnimeEpisode episode) {
    final local = _localProgressFor(episode);
    final remote = _listEntry?.progress ?? 0;
    if (episode.number.floor() <= remote) {
      return 1;
    }
    return local;
  }

  String _downloadIdFor(AnimeEpisode episode) =>
      '${widget.media.id}-${episode.number}';

  int get _localCompletedProgress {
    var completed = 0;
    for (final episode in _episodes) {
      if (_localProgressFor(episode) >= 0.92) {
        final number = episode.number.floor();
        if (number > completed) {
          completed = number;
        }
      }
    }
    return completed;
  }

  int get _effectiveProgress {
    final remote = _listEntry?.progress ?? 0;
    return remote > _localCompletedProgress ? remote : _localCompletedProgress;
  }

  AnimeEpisode? get _continueEpisode {
    if (_episodes.isEmpty) {
      return null;
    }
    final ascending = List<AnimeEpisode>.of(_episodes)
      ..sort((a, b) => a.number.compareTo(b.number));
    AnimeEpisode? partial;
    var partialUpdatedAt = -1;
    for (final episode in ascending) {
      final history = _historyForEpisode(episode);
      final localProgress = _localProgressFor(episode);
      if (episode.number.floor() > (_listEntry?.progress ?? 0) &&
          localProgress > 0 &&
          localProgress < 0.92 &&
          (history?.updatedAtMs ?? 0) >= partialUpdatedAt) {
        partial = episode;
        partialUpdatedAt = history?.updatedAtMs ?? 0;
      }
    }
    if (partial != null) {
      return partial;
    }
    for (final episode in ascending) {
      if (episode.number.floor() > _effectiveProgress) {
        return episode;
      }
    }
    return ascending.first;
  }

  String _primaryActionLabel() {
    if (_loading && _episodes.isEmpty) {
      return 'Finding episodes';
    }
    final episode = _continueEpisode;
    if (episode == null) {
      return 'Choose a source to watch';
    }
    final number = AnimeEpisode.displayNumber(episode.number);
    final localProgress = _localProgressFor(episode);
    if (localProgress > 0 && localProgress < 0.92) {
      return 'Resume episode $number';
    }
    if (_effectiveProgress <= 0) {
      return 'Watch episode $number';
    }
    if (episode.number.floor() <= _effectiveProgress) {
      return 'Rewatch episode $number';
    }
    return 'Continue with episode $number';
  }

  void _handlePrimaryAction() {
    final episode = _continueEpisode;
    if (episode == null) {
      _selectSection(_AnimeDetailSection.watch);
      return;
    }
    unawaited(_openEpisode(episode));
  }

  String _totalRowText() {
    final total =
        widget.media.episodes ?? (_episodes.isEmpty ? null : _episodes.length);
    return 'Watched $_effectiveProgress out of ${total ?? '??'}';
  }

  String _listButtonLabel() {
    final entry = _listEntry;
    if (entry == null) {
      return 'Add to list';
    }
    return entry.status.label;
  }

  // The bottom nav bar already sits above the system inset.
  double _detailBottomPadding(BuildContext context) => 24;
}

class _AnimeProviderSheet extends StatelessWidget {
  const _AnimeProviderSheet({
    required this.providers,
    required this.selectedProviderKey,
    required this.scrollController,
  });

  final List<SourceProvider> providers;
  final String selectedProviderKey;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final juroProviders = providers
        .where(
          (provider) =>
              !AniyomiExtensionService.isAnimeProviderKey(provider.key),
        )
        .toList();
    final aniyomiProviders = providers
        .where(
          (provider) =>
              AniyomiExtensionService.isAnimeProviderKey(provider.key),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Text(
            'Anime Provider',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.only(
              bottom: 12 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              if (juroProviders.isNotEmpty)
                _ProviderSection(
                  title: 'Juro providers',
                  providers: juroProviders,
                  selectedProviderKey: selectedProviderKey,
                ),
              if (aniyomiProviders.isNotEmpty)
                _ProviderSection(
                  title: 'Aniyomi extensions',
                  providers: aniyomiProviders,
                  selectedProviderKey: selectedProviderKey,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProviderSection extends StatelessWidget {
  const _ProviderSection({
    required this.title,
    required this.providers,
    required this.selectedProviderKey,
  });

  final String title;
  final List<SourceProvider> providers;
  final String selectedProviderKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final provider in providers)
          ListTile(
            leading: Icon(
              provider.key == selectedProviderKey
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(provider.name),
            subtitle: Text(provider.language),
            onTap: () => Navigator.of(context).pop(provider),
          ),
      ],
    );
  }
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

class _ManualAnimeSearchSheet extends StatefulWidget {
  const _ManualAnimeSearchSheet({
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
  State<_ManualAnimeSearchSheet> createState() =>
      _ManualAnimeSearchSheetState();
}

class _ManualAnimeSearchSheetState extends State<_ManualAnimeSearchSheet> {
  late final TextEditingController _controller;
  Timer? _debounce;
  List<JuroAnimeInfo> _results = [];
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
      final results = await widget.juroService.searchAnime(
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
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => unawaited(_runSearch()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Provider title',
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

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.progress,
    required this.isNext,
    required this.full,
    required this.downloadService,
    required this.downloadId,
    required this.onTap,
    required this.onLongPress,
    required this.onOptions,
  });

  final AnimeEpisode episode;
  final double progress;
  final bool isNext;
  final bool full;
  final DownloadService downloadService;
  final String downloadId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final image = episode.image;
    final completed = progress >= 0.92;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: [
        episode.displayName,
        if (completed) 'Watched',
        if (isNext) 'Up next',
      ].join(', '),
      excludeSemantics: true,
      child: Opacity(
        opacity: completed && !isNext ? 0.72 : 1,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isNext
                ? BorderSide(color: colorScheme.primary, width: 2)
                : BorderSide.none,
          ),
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
                        CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          placeholder: (context, _) => ColoredBox(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (context, _, _) => ColoredBox(
                            color: colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        )
                      else
                        ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.movie_outlined),
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0, 0.45, 1],
                            colors: [
                              Color(0x44000000),
                              Colors.transparent,
                              Color(0xE6000000),
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 42, 9),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EP ${AnimeEpisode.displayNumber(episode.number)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (!full)
                                Text(
                                  episode.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        left: 6,
                        child: completed
                            ? const _EpisodeStatePill(
                                icon: Icons.check,
                                label: 'WATCHED',
                              )
                            : isNext
                            ? const _EpisodeStatePill(
                                icon: Icons.play_arrow,
                                label: 'UP NEXT',
                              )
                            : const SizedBox.shrink(),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _EpisodeDownloadStatus(
                              service: downloadService,
                              downloadId: downloadId,
                              compact: true,
                            ),
                            IconButton(
                              tooltip: 'Episode options',
                              visualDensity: VisualDensity.compact,
                              onPressed: onOptions,
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                            ),
                          ],
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (progress > 0)
                  LinearProgressIndicator(value: progress, minHeight: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeStatePill extends StatelessWidget {
  const _EpisodeStatePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeListTile extends StatelessWidget {
  const _EpisodeListTile({
    required this.episode,
    required this.progress,
    required this.isNext,
    required this.downloadService,
    required this.downloadId,
    required this.onTap,
    required this.onLongPress,
    required this.onOptions,
  });

  final AnimeEpisode episode;
  final double progress;
  final bool isNext;
  final DownloadService downloadService;
  final String downloadId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final completed = progress >= 0.92;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: [
        episode.displayName,
        if (completed) 'Watched',
        if (isNext) 'Up next',
      ].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Opacity(
          opacity: completed && !isNext ? 0.72 : 1,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isNext
                  ? BorderSide(color: colorScheme.primary, width: 2)
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
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
                          Row(
                            children: [
                              if (completed)
                                Icon(
                                  Icons.check_circle,
                                  color: colorScheme.primary,
                                  size: 18,
                                )
                              else if (isNext)
                                Icon(
                                  Icons.play_circle_fill,
                                  color: colorScheme.primary,
                                  size: 18,
                                ),
                              if (completed || isNext) const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  episode.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    _EpisodeDownloadStatus(
                      service: downloadService,
                      downloadId: downloadId,
                    ),
                    IconButton(
                      tooltip: 'Episode options',
                      onPressed: onOptions,
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ),
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

/// Two-step video picker: shows the source's server/hoster list first and only
/// extracts videos for the server the user taps. Falls back to a flat list for
/// sources that don't expose servers.
class _VideoSourcePicker extends StatefulWidget {
  const _VideoSourcePicker({
    required this.title,
    required this.scrollController,
    required this.loadServers,
    required this.loadVideosForServer,
    required this.loadAllVideos,
    required this.buildSourceTile,
  });

  final String title;
  final ScrollController scrollController;
  final Future<List<VideoServer>> Function() loadServers;
  final Future<List<VideoSource>> Function(VideoServer server)
  loadVideosForServer;
  final Future<List<VideoSource>> Function() loadAllVideos;
  final Widget Function(BuildContext context, VideoSource source)
  buildSourceTile;

  @override
  State<_VideoSourcePicker> createState() => _VideoSourcePickerState();
}

class _VideoSourcePickerState extends State<_VideoSourcePicker> {
  List<VideoServer>? _servers;
  VideoServer? _selectedServer;
  List<VideoSource>? _videos;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadServers());
  }

  Future<void> _loadServers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    List<VideoServer> servers;
    try {
      servers = await widget.loadServers();
    } catch (_) {
      // Some providers don't expose a server list; fall back to the flat
      // video list instead of failing the sheet.
      servers = const [];
    }
    if (!mounted) return;
    if (servers.isEmpty) {
      try {
        final videos = await widget.loadAllVideos();
        if (!mounted) return;
        setState(() {
          _servers = const [];
          _videos = videos;
          _loading = false;
        });
      } catch (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _loading = false;
          });
        }
      }
      return;
    }
    setState(() {
      _servers = servers;
      _loading = false;
    });
    if (servers.length == 1) {
      await _selectServer(servers.first);
    }
  }

  Future<void> _selectServer(VideoServer server) async {
    setState(() {
      _selectedServer = server;
      _videos = null;
      _loading = true;
      _error = null;
    });
    try {
      final videos = await widget.loadVideosForServer(server);
      if (!mounted || _selectedServer != server) return;
      setState(() {
        _videos = videos;
        _loading = false;
      });
    } catch (error) {
      if (mounted && _selectedServer == server) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  void _backToServers() {
    setState(() {
      _selectedServer = null;
      _videos = null;
      _error = null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final servers = _servers;
    final showBack = _selectedServer != null && (servers?.length ?? 0) > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 8),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  tooltip: 'Back to servers',
                  onPressed: _backToServers,
                  icon: const Icon(Icons.arrow_back),
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedServer == null
                      ? widget.title
                      : _selectedServer!.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorView(
        message: _error!,
        onRetry: _selectedServer == null
            ? () => unawaited(_loadServers())
            : () => unawaited(_selectServer(_selectedServer!)),
      );
    }
    final videos = _videos;
    if (videos != null) {
      if (videos.isEmpty) {
        return const EmptyState(
          icon: Icons.videocam_off_outlined,
          title: 'No video sources',
        );
      }
      // Sources without servers return a mixed list; keep the grouping so
      // qualities stay clustered per server name.
      final grouped = <String, List<VideoSource>>{};
      for (final source in videos) {
        grouped.putIfAbsent(source.serverName, () => []).add(source);
      }
      final showGroups = _selectedServer == null;
      return ListView(
        controller: widget.scrollController,
        children: [
          for (final entry in grouped.entries) ...[
            if (showGroups)
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
              widget.buildSourceTile(context, source),
          ],
        ],
      );
    }
    final servers = _servers ?? const <VideoServer>[];
    if (servers.isEmpty) {
      return const EmptyState(
        icon: Icons.dns_outlined,
        title: 'No servers available',
      );
    }
    return ListView(
      controller: widget.scrollController,
      children: [
        for (final server in servers)
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(server.name),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => unawaited(_selectServer(server)),
          ),
      ],
    );
  }
}
