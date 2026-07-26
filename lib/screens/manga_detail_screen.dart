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
import '../models/downloaded_manga.dart';
import '../models/juro_models.dart';
import '../models/tracking.dart';
import '../services/juro_service.dart';
import '../services/anilist_service.dart';
import '../services/feature_gate_service.dart';
import '../services/manga_download_service.dart';
import '../services/notification_subscription_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../widgets/anilist_list_entry_sheet.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_error_view.dart';
import '../widgets/detail_media_tools.dart';
import '../widgets/list_range_selector.dart';
import '../widgets/media_detail_header.dart';
import '../widgets/media_poster_card.dart';
import '../widgets/rich_media_details.dart';
import 'detail_screen.dart';
import 'manga_reader_screen.dart';
import 'person_detail_screen.dart';

enum _MangaDetailSection { info, read }

enum _MangaDetailMenuAction { openAniList, copyTitle }

class MangaDetailScreen extends StatefulWidget {
  const MangaDetailScreen({
    required this.media,
    required this.preferences,
    required this.juroService,
    required this.mangaDownloadService,
    required this.trackingService,
    this.initialProvider,
    this.initialProviderManga,
    super.key,
  });

  final AniListMedia media;
  final PreferencesService preferences;
  final JuroService juroService;
  final MangaDownloadService mangaDownloadService;
  final TrackingService trackingService;
  final SourceProvider? initialProvider;
  final MangaResult? initialProviderManga;

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  final ScrollController _detailsScrollController = ScrollController();
  final Map<_MangaDetailSection, double> _sectionOffsets = {};
  _MangaDetailSection _selectedSection = _MangaDetailSection.info;
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
  SourceProviderChoice? _localProviderChoice;
  AniListMediaDetails? _richDetails;
  bool _richDetailsRequested = false;
  bool _richDetailsLoading = false;
  bool _sourceFallbackEnabled = false;
  NotificationSubscriptionService? _notificationSubscriptions;
  bool _notificationsFollowed = false;
  bool _notificationsLoading = false;
  MangaReadingProgress? _readingProgress;

  bool get _usesLocalProvider =>
      widget.initialProvider != null || widget.initialProviderManga != null;

  String get _providerKey =>
      _localProviderChoice?.key ?? widget.preferences.lastMangaProviderKey;

  String get _providerName =>
      _localProviderChoice?.name ??
      widget.preferences.lastMangaProviderName ??
      _providerKey;

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
    _selectedSection =
        _MangaDetailSection.values[widget.preferences.detailSectionIndex(
          mediaKind: 'manga',
          mediaId: widget.media.id,
        )];
    _readingProgress = widget.preferences.mangaProgressFor(widget.media.id);
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
    if (_selectedSection == _MangaDetailSection.read) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _restoreSectionOffset(_selectedSection);
        }
      });
    }
  }

  @override
  void dispose() {
    _detailsScrollController.dispose();
    super.dispose();
  }

  void _selectSection(_MangaDetailSection section) {
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
        mediaKind: 'manga',
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

  void _restoreSectionOffset(_MangaDetailSection section) {
    if (!_detailsScrollController.hasClients) {
      return;
    }
    final defaultOffset = section == _MangaDetailSection.info
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
        mediaType: AniListMediaType.manga,
      );
      if (mounted) {
        setState(() => _richDetails = details);
      }
    } catch (_) {
      // Source chapters remain usable if additive AniList metadata is offline.
    } finally {
      if (mounted) {
        setState(() => _richDetailsLoading = false);
      }
    }
  }

  void _openRelatedMedia(AniListMedia media) {
    if (media.mediaType == AniListMediaType.manga.graphqlName) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MangaDetailScreen(
            media: media,
            preferences: widget.preferences,
            juroService: widget.juroService,
            mangaDownloadService: widget.mangaDownloadService,
            trackingService: widget.trackingService,
          ),
        ),
      );
      return;
    }
    final services = AppScope.maybeOf(context);
    if (media.mediaType == AniListMediaType.anime.graphqlName &&
        services != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetailScreen(
            media: media,
            preferences: services.preferences,
            juroService: services.juroService,
            watchHistoryService: services.watchHistoryService,
            downloadService: services.downloadService,
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
      if (role.contains('story') ||
          role.contains('art') ||
          role.contains('original creator') ||
          role.contains('manga')) {
        return person;
      }
    }
    return null;
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
        await widget.preferences.setLastMangaProvider(
          SourceProviderChoice(key: provider.key, name: provider.name),
        );
      }

      final initialManga = widget.initialProviderManga;
      final initialProvider = widget.initialProvider;
      final stillUsingInitialProvider =
          initialProvider == null || _providerKey == initialProvider.key;
      if (initialManga != null &&
          _usesLocalProvider &&
          stillUsingInitialProvider) {
        await _loadChapters(initialManga);
      } else {
        await _autoMatchAndLoadChapters();
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
    return status == 'Loading manga providers' ||
        status == 'Loading chapters from $_providerName' ||
        (status?.startsWith('Searching ') ?? false) ||
        (status?.startsWith('Trying fallback source ') ?? false);
  }

  Future<void> _autoMatchAndLoadChapters() async {
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
      try {
        MangaResult? match;
        for (final title in candidates) {
          final results = await widget.juroService.searchManga(
            title,
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
        await _loadChapters(match);
        if (_chapters.isNotEmpty) {
          return;
        }
      } catch (_) {
        // A failed provider is recorded by JuroService; try the next ranked one.
      }
    }

    setState(() {
      _localProviderChoice = originalChoice;
      _providerManga = null;
      _mangaInfo = null;
      _chapters = [];
      _chapterRangeIndex = 0;
      _status = 'No source match found';
    });
  }

  Future<void> _refreshNotificationFollow() async {
    final service = _notificationSubscriptions;
    if (service == null) return;
    final followed = await service.isManuallySubscribed(
      widget.media.id,
      'manga',
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
        await service.unsubscribeManual(widget.media.id, 'manga');
      } else {
        await service.subscribeManual(
          media: widget.media,
          mediaType: 'manga',
          sourceKey: _providerKey,
          providerItemId: _providerManga?.id,
        );
      }
      await _refreshNotificationFollow();
      if (_notificationsFollowed) {
        unawaited(appServices.notificationCoordinator.syncAndRefresh());
      }
    } finally {
      if (mounted) setState(() => _notificationsLoading = false);
    }
  }

  Future<void> _loadChapters(MangaResult manga) async {
    setState(() {
      _providerManga = manga;
      _status = 'Loading chapters from $_providerName';
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
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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

    if (_usesLocalProvider) {
      _localProviderChoice = SourceProviderChoice(
        key: provider.key,
        name: provider.name,
      );
    } else {
      await widget.preferences.setLastMangaProvider(
        SourceProviderChoice(key: provider.key, name: provider.name),
      );
    }
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

  Future<void> _openChapter(MangaChapter chapter) async {
    final info = _mangaInfo;
    if (info == null) {
      return;
    }

    final readerChapters = List<MangaChapter>.of(_chapters)
      ..sort((a, b) => a.number.compareTo(b.number));
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MangaReaderScreen(
          media: widget.media,
          mangaInfo: info,
          chapter: chapter,
          chapters: readerChapters,
          preferences: widget.preferences,
          juroService: widget.juroService,
          mangaDownloadService: widget.mangaDownloadService,
          trackingService: widget.trackingService,
          providerKey: _providerKey,
          providerName: _providerName,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _readingProgress = widget.preferences.mangaProgressFor(widget.media.id);
    });
    await _refreshAniListListEntry();
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
      providerName: _providerName,
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

  void _handleMenuAction(_MangaDetailMenuAction action) {
    switch (action) {
      case _MangaDetailMenuAction.openAniList:
        unawaited(_openAniList());
      case _MangaDetailMenuAction.copyTitle:
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
    final theme = Theme.of(context);
    final media = _richDetails?.media ?? widget.media;
    final cover =
        _mangaInfo?.image ?? _providerManga?.image ?? widget.media.cover.best;
    final headers =
        _mangaInfo?.headers ??
        _providerManga?.headers ??
        const <String, String>{};
    final banner = media.bannerImage ?? widget.media.bannerImage;
    final visibleChapters = _visibleChapters;
    final canUseAniList = widget.media.hasAniListId;
    final headerHeight = mediaDetailHeaderHeight(context);
    final tabs = [
      const MediaDetailTab(icon: Icons.info_outline_rounded, label: 'Info'),
      MediaDetailTab(
        icon: Icons.import_contacts_outlined,
        label: 'Read',
        badge: _displayChapters.isEmpty ? null : '${_displayChapters.length}',
        badgeLabel: _displayChapters.isEmpty
            ? null
            : '${_displayChapters.length} chapters',
      ),
    ];

    return MediaDetailScaffold(
      tabs: tabs,
      selectedIndex: _selectedSection.index,
      onSelected: (index) => _selectSection(_MangaDetailSection.values[index]),
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
              PopupMenuButton<_MangaDetailMenuAction>(
                tooltip: 'More options',
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _MangaDetailMenuAction.openAniList,
                    enabled: widget.media.siteUrl != null,
                    child: const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.open_in_new),
                      title: Text('Open on AniList'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _MangaDetailMenuAction.copyTitle,
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
                statusText: mediaEnumLabel(media.status) ?? _mangaInfo?.status,
                bannerUrl: banner,
                coverUrl: cover,
                imageHeaders: headers,
                listButtonLabel: canUseAniList ? _listButtonLabel() : null,
                listButtonBusy: _listEntryLoading || _listEntrySaving,
                onListButtonPressed: _editAniListListEntry,
                onBannerLongPress: () => _showImagePreview(
                  banner ?? cover,
                  banner == null ? headers : const <String, String>{},
                ),
                onCoverLongPress: () => _showImagePreview(cover, headers),
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
              primaryActionIcon: Icons.menu_book_rounded,
              primaryActionBusy: _loading && _chapters.isEmpty,
              onPrimaryAction: _loading && _chapters.isEmpty
                  ? null
                  : _handlePrimaryAction,
              actions: [
                MediaDetailActionIcon(
                  tooltip: _notificationsFollowed
                      ? 'Stop manual chapter alerts'
                      : 'Follow chapter alerts',
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
          if (_selectedSection == _MangaDetailSection.info)
            SliverToBoxAdapter(
              child: MediaDetailContentConstraint(child: _buildOverview()),
            ),
          if (_selectedSection == _MangaDetailSection.read)
            SliverToBoxAdapter(
              child: MediaDetailContentConstraint(
                child: _buildChaptersHeader(),
              ),
            ),
          if (_selectedSection == _MangaDetailSection.read && _loading)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (_status case final status?) ...[
                        const SizedBox(height: 12),
                        Text(status),
                      ],
                    ],
                  ),
                ),
              ),
            )
          else if (_selectedSection == _MangaDetailSection.read &&
              _error != null)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                child: AppErrorView(message: _error!, onRetry: _load),
              ),
            )
          else if (_selectedSection == _MangaDetailSection.read &&
              _displayChapters.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 320,
                child: EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: _status ?? 'No chapters found',
                  message:
                      'Try another source or search for the title manually.',
                ),
              ),
            )
          else if (_selectedSection == _MangaDetailSection.read)
            MediaDetailSliverConstraint(
              maxWidth: 840,
              sliver: SliverList.builder(
                itemCount: visibleChapters.length,
                itemBuilder: (context, index) {
                  final chapter = visibleChapters[index];
                  final request = _downloadRequestFor(chapter);
                  return _MangaChapterCard(
                    chapter: chapter,
                    read: _isChapterRead(chapter),
                    current: _continueChapter?.id == chapter.id,
                    pageProgress: _chapterPageProgress(chapter),
                    downloadStatus: request == null
                        ? null
                        : _MangaChapterDownloadStatus(
                            service: widget.mangaDownloadService,
                            request: request,
                            onDownload: () => _downloadChapter(chapter),
                          ),
                    onTap: () => unawaited(_openChapter(chapter)),
                  );
                },
              ),
            ),
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
    final authors = _mangaInfo?.authors ?? const <String>[];
    final description = _mangaInfo?.description?.isNotEmpty == true
        ? _mangaInfo!.description!
        : media.description;
    final genres =
        (media.genres.isNotEmpty
                ? media.genres
                : (_mangaInfo?.genres ?? const <String>[]))
            .take(10)
            .toList();
    final rows = <MediaInfoRowData>[
      if (media.meanScore case final score?)
        MediaInfoRowData('Mean Score', '$score / 100', highlight: true),
      if (mediaEnumLabel(media.status) ?? _mangaInfo?.status case final status?)
        MediaInfoRowData('Status', status),
      if (media.startDate case final date?)
        MediaInfoRowData('Start Date', date),
      if (media.endDate case final date?) MediaInfoRowData('End Date', date),
      if (media.chapters case final chapters?)
        MediaInfoRowData('Total Chapters', '$chapters')
      else if (_chapters.isNotEmpty)
        MediaInfoRowData('Loaded Chapters', '${_chapters.length}'),
      if (media.volumes case final volumes?)
        MediaInfoRowData('Volumes', '$volumes'),
      if (mediaEnumLabel(media.format) case final format?)
        MediaInfoRowData('Format', format),
      if (mediaEnumLabel(media.source) case final source?)
        MediaInfoRowData('Source', source),
      if (creator != null)
        MediaInfoRowData(
          'Creator',
          creator.name,
          highlight: true,
          onTap: () => _openPerson(creator, AniListPersonKind.staff),
          semanticHint: 'Open creator details',
        ),
      if (creator == null && authors.isNotEmpty)
        MediaInfoRowData('Authors', authors.take(3).join(', ')),
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
          if (description.isNotEmpty) ...[
            const SizedBox(height: 18),
            const MediaDetailSectionTitle('Description'),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ExpandableSelectableText(
                description,
                collapsedLines: 6,
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

  Widget _buildChaptersHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaSourceSelectorTile(
            sourceName: _providerName,
            onTap: _providers.isEmpty ? null : _changeProvider,
            matchedTitle: _mangaInfo?.title ?? _providerManga?.title,
            onWrongTitle: _providers.isEmpty ? null : _manualMatch,
            loading: _loading,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chapters',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
              onSelected: (index) => setState(() => _chapterRangeIndex = index),
            ),
          ],
        ],
      ),
    );
  }

  double get _localCompletedChapter {
    final progress = _readingProgress;
    if (progress == null) {
      return 0;
    }
    if (progress.completed) {
      return progress.chapterNumber;
    }
    return (progress.chapterNumber.ceil() - 1)
        .clamp(0, double.infinity)
        .toDouble();
  }

  double get _effectiveProgress {
    final remote = (_listEntry?.progress ?? 0).toDouble();
    return remote > _localCompletedChapter ? remote : _localCompletedChapter;
  }

  MangaChapter? get _continueChapter {
    if (_chapters.isEmpty) {
      return null;
    }
    final ascending = List<MangaChapter>.of(_chapters)
      ..sort((a, b) => a.number.compareTo(b.number));
    final local = _readingProgress;
    if (local != null && !local.completed) {
      for (final chapter in ascending) {
        if (chapter.id == local.chapterId) {
          return chapter;
        }
      }
    }
    final baseline = local?.completed == true
        ? (local!.chapterNumber > _effectiveProgress
              ? local.chapterNumber
              : _effectiveProgress)
        : _effectiveProgress;
    for (final chapter in ascending) {
      if (chapter.number > baseline) {
        return chapter;
      }
    }
    return ascending.first;
  }

  bool _isChapterRead(MangaChapter chapter) {
    final local = _readingProgress;
    if (local?.chapterId == chapter.id && local?.completed == true) {
      return true;
    }
    return chapter.number <= _effectiveProgress;
  }

  double _chapterPageProgress(MangaChapter chapter) {
    final progress = _readingProgress;
    if (progress == null ||
        progress.chapterId != chapter.id ||
        progress.completed) {
      return 0;
    }
    return progress.pageFraction;
  }

  String _primaryActionLabel() {
    if (_loading && _chapters.isEmpty) {
      return 'Finding chapters';
    }
    final chapter = _continueChapter;
    if (chapter == null) {
      return 'Choose a source to read';
    }
    final number = MangaChapterNumberLabel.format(chapter.number);
    final local = _readingProgress;
    if (local?.chapterId == chapter.id && local?.completed == false) {
      return 'Resume chapter $number';
    }
    if (_effectiveProgress <= 0) {
      return 'Read chapter $number';
    }
    if (chapter.number <= _effectiveProgress) {
      return 'Reread chapter $number';
    }
    return 'Continue with chapter $number';
  }

  void _handlePrimaryAction() {
    final chapter = _continueChapter;
    if (chapter == null) {
      _selectSection(_MangaDetailSection.read);
      return;
    }
    unawaited(_openChapter(chapter));
  }

  String _totalRowText() {
    final total =
        widget.media.chapters ?? (_chapters.isEmpty ? null : _chapters.length);
    final progress = MangaChapterNumberLabel.format(_effectiveProgress);
    return 'Read $progress out of ${total ?? '??'}';
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

class _MangaChapterCard extends StatelessWidget {
  const _MangaChapterCard({
    required this.chapter,
    required this.read,
    required this.current,
    required this.pageProgress,
    required this.onTap,
    this.downloadStatus,
  });

  final MangaChapter chapter;
  final bool read;
  final bool current;
  final double pageProgress;
  final VoidCallback onTap;
  final Widget? downloadStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: [
        chapter.displayTitle,
        if (read) 'Read',
        if (current) 'Continue reading',
      ].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Opacity(
          opacity: read && !current ? 0.7 : 1,
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: current
                  ? BorderSide(color: colorScheme.primary, width: 2)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: onTap,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: current
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          foregroundColor: current
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          child: read
                              ? const Icon(Icons.check_rounded)
                              : Text(
                                  MangaChapterNumberLabel.format(
                                    chapter.number,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chapter.displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (chapter.metadata.isNotEmpty ||
                                  read ||
                                  current)
                                Text(
                                  [
                                    if (current) 'Continue reading',
                                    if (read && !current) 'Read',
                                    if (chapter.metadata.isNotEmpty)
                                      chapter.metadata,
                                  ].join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: current
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: current
                                            ? FontWeight.w700
                                            : null,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        ?downloadStatus,
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                  if (pageProgress > 0)
                    LinearProgressIndicator(value: pageProgress, minHeight: 3),
                ],
              ),
            ),
          ),
        ),
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
