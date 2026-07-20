import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/anilist_media.dart';
import '../models/aniyomi_filters.dart';
import '../models/juro_models.dart';
import '../services/aniyomi_extension_service.dart';
import '../services/download_service.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/aniyomi_filter_sheet.dart';
import '../widgets/app_error_view.dart';
import 'detail_screen.dart';
import 'manga_detail_screen.dart';

class AniyomiSourcesScreen extends StatefulWidget {
  const AniyomiSourcesScreen({
    required this.extensionService,
    required this.preferences,
    required this.juroService,
    required this.watchHistoryService,
    required this.downloadService,
    required this.mangaDownloadService,
    required this.trackingService,
    super.key,
  });

  final AniyomiExtensionService extensionService;
  final PreferencesService preferences;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final TrackingService trackingService;

  @override
  State<AniyomiSourcesScreen> createState() => _AniyomiSourcesScreenState();
}

class _AniyomiSourcesScreenState extends State<AniyomiSourcesScreen> {
  late Future<_AniyomiSourceLists> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AniyomiSourceLists> _load() async {
    final supported = await widget.extensionService.isSupported();
    if (!supported) return const _AniyomiSourceLists();
    final results = await Future.wait([
      widget.extensionService.getAnimeProviders(),
      widget.extensionService.getMangaProviders(),
    ]);
    return _AniyomiSourceLists(
      anime: _sortedProviders(results[0]),
      manga: _sortedProviders(results[1]),
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  void _openSource(SourceProvider provider, _SourceMediaType mediaType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AniyomiSourceBrowseScreen(
          provider: provider,
          mediaType: mediaType,
          extensionService: widget.extensionService,
          preferences: widget.preferences,
          juroService: widget.juroService,
          watchHistoryService: widget.watchHistoryService,
          downloadService: widget.downloadService,
          mangaDownloadService: widget.mangaDownloadService,
          trackingService: widget.trackingService,
        ),
      ),
    );
  }

  void _openSourceSettings(SourceProvider provider) {
    unawaited(
      widget.extensionService.openSourcePreferences(
        provider.key,
        sourceName: provider.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aniyomi sources'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => unawaited(_refresh()),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.live_tv_outlined), text: 'Anime'),
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Manga'),
            ],
          ),
        ),
        body: SafeArea(
          child: FutureBuilder<_AniyomiSourceLists>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return AppErrorView(
                  message: snapshot.error.toString(),
                  onRetry: () {
                    setState(() {
                      _future = _load();
                    });
                  },
                );
              }
              final data = snapshot.data ?? const _AniyomiSourceLists();
              return TabBarView(
                children: [
                  _SourceListTab(
                    providers: data.anime,
                    mediaType: _SourceMediaType.anime,
                    onRefresh: _refresh,
                    onOpen: _openSource,
                    onOpenSettings: _openSourceSettings,
                  ),
                  _SourceListTab(
                    providers: data.manga,
                    mediaType: _SourceMediaType.manga,
                    onRefresh: _refresh,
                    onOpen: _openSource,
                    onOpenSettings: _openSourceSettings,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AniyomiSourceLists {
  const _AniyomiSourceLists({this.anime = const [], this.manga = const []});

  final List<SourceProvider> anime;
  final List<SourceProvider> manga;
}

class _SourceListTab extends StatelessWidget {
  const _SourceListTab({
    required this.providers,
    required this.mediaType,
    required this.onRefresh,
    required this.onOpen,
    required this.onOpenSettings,
  });

  final List<SourceProvider> providers;
  final _SourceMediaType mediaType;
  final Future<void> Function() onRefresh;
  final void Function(SourceProvider provider, _SourceMediaType mediaType)
  onOpen;
  final void Function(SourceProvider provider) onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (providers.isEmpty)
            EmptyState(
              icon: mediaType.icon,
              title: 'No ${mediaType.label.toLowerCase()} sources',
              message: 'Install extensions to browse their sources.',
            )
          else
            for (final provider in providers)
              _SourceProviderTile(
                provider: provider,
                mediaType: mediaType,
                onTap: () => onOpen(provider, mediaType),
                onOpenSettings: provider.isConfigurable
                    ? () => onOpenSettings(provider)
                    : null,
              ),
        ],
      ),
    );
  }
}

class _SourceProviderTile extends StatelessWidget {
  const _SourceProviderTile({
    required this.provider,
    required this.mediaType,
    required this.onTap,
    this.onOpenSettings,
  });

  final SourceProvider provider;
  final _SourceMediaType mediaType;
  final VoidCallback onTap;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: _IconBadge(icon: mediaType.icon, color: colorScheme.primary),
          title: Text(provider.name),
          subtitle: Text(
            [
              provider.language.toUpperCase(),
              if (provider.isNsfw) 'NSFW',
            ].join(' • '),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onOpenSettings != null)
                IconButton(
                  tooltip: 'Source settings',
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _AniyomiSourceBrowseScreen extends StatefulWidget {
  const _AniyomiSourceBrowseScreen({
    required this.provider,
    required this.mediaType,
    required this.extensionService,
    required this.preferences,
    required this.juroService,
    required this.watchHistoryService,
    required this.downloadService,
    required this.mangaDownloadService,
    required this.trackingService,
  });

  final SourceProvider provider;
  final _SourceMediaType mediaType;
  final AniyomiExtensionService extensionService;
  final PreferencesService preferences;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final TrackingService trackingService;

  @override
  State<_AniyomiSourceBrowseScreen> createState() =>
      _AniyomiSourceBrowseScreenState();
}

class _AniyomiSourceBrowseScreenState
    extends State<_AniyomiSourceBrowseScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  AniyomiBrowseKind _kind = AniyomiBrowseKind.popular;
  List<AniyomiFilter>? _filters;
  bool _filtersActive = false;

  final List<Object> _items = [];
  bool _hasNextPage = false;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasNextPage || _loadingMore || _loading) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(_loadMore());
    }
  }

  bool get _isSearching =>
      _controller.text.trim().isNotEmpty || _filtersActive;

  Future<AniyomiPage<Object>> _fetchPage(int page) async {
    final query = _controller.text.trim();
    final selections = _filtersActive && _filters != null
        ? collectFilterSelections(_filters!)
        : null;
    switch (widget.mediaType) {
      case _SourceMediaType.anime:
        final result = _isSearching
            ? await widget.extensionService.searchAnime(
                query,
                providerKey: widget.provider.key,
                page: page,
                filters: selections,
              )
            : await widget.extensionService.browseAnime(
                providerKey: widget.provider.key,
                page: page,
                kind: _kind,
              );
        return AniyomiPage<Object>(
          items: result.items,
          hasNextPage: result.hasNextPage,
        );
      case _SourceMediaType.manga:
        final result = _isSearching
            ? await widget.extensionService.searchManga(
                query,
                providerKey: widget.provider.key,
                page: page,
                filters: selections,
              )
            : await widget.extensionService.browseManga(
                providerKey: widget.provider.key,
                page: page,
                kind: _kind,
              );
        return AniyomiPage<Object>(
          items: result.items,
          hasNextPage: result.hasNextPage,
        );
    }
  }

  Future<void> _reload() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _fetchPage(1);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _hasNextPage = result.hasNextPage;
        _page = 1;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final requestId = _requestId;
    setState(() => _loadingMore = true);
    try {
      final result = await _fetchPage(_page + 1);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items.addAll(result.items);
        _hasNextPage = result.hasNextPage;
        _page += 1;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _hasNextPage = false);
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _openFilters() async {
    var filters = _filters;
    if (filters == null) {
      try {
        filters = await widget.extensionService.getFilters(
          widget.provider.key,
        );
      } catch (_) {
        filters = const [];
      }
      if (!mounted) return;
      _filters = filters;
    }
    if (filters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This source has no filters')),
      );
      return;
    }
    final action = await showAniyomiFilterSheet(context, filters);
    if (!mounted || action == null) return;
    switch (action) {
      case AniyomiFilterSheetAction.apply:
        _filtersActive = true;
        unawaited(_reload());
      case AniyomiFilterSheetAction.reset:
        _filters = null;
        _filtersActive = false;
        unawaited(_reload());
    }
  }

  void _run() {
    unawaited(_reload());
  }

  void _clear() {
    if (_controller.text.isEmpty && !_filtersActive) return;
    _controller.clear();
    _filtersActive = false;
    _filters = null;
    _run();
  }

  void _openItem(Object item) {
    switch (item) {
      case JuroAnimeInfo anime:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetailScreen(
              media: _mediaFromAnime(anime, widget.provider),
              preferences: widget.preferences,
              juroService: widget.juroService,
              watchHistoryService: widget.watchHistoryService,
              downloadService: widget.downloadService,
              trackingService: widget.trackingService,
              initialProvider: widget.provider,
              initialProviderAnime: anime,
            ),
          ),
        );
      case MangaResult manga:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(
              media: _mediaFromManga(manga, widget.provider),
              preferences: widget.preferences,
              juroService: widget.juroService,
              mangaDownloadService: widget.mangaDownloadService,
              trackingService: widget.trackingService,
              initialProvider: widget.provider,
              initialProviderManga: manga,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.provider.name),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => unawaited(_openFilters()),
            icon: Badge(
              isLabelVisible: _filtersActive,
              smallSize: 8,
              child: const Icon(Icons.filter_list),
            ),
          ),
          if (widget.provider.isConfigurable)
            IconButton(
              tooltip: 'Source settings',
              onPressed: () => unawaited(
                widget.extensionService.openSourcePreferences(
                  widget.provider.key,
                  sourceName: widget.provider.name,
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _run(),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.mediaType.label.toLowerCase()}',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty && !_filtersActive
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: _clear,
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (!_isSearching && widget.provider.supportsLatest)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SegmentedButton<AniyomiBrowseKind>(
                  segments: const [
                    ButtonSegment(
                      value: AniyomiBrowseKind.popular,
                      label: Text('Popular'),
                      icon: Icon(Icons.local_fire_department_outlined),
                    ),
                    ButtonSegment(
                      value: AniyomiBrowseKind.latest,
                      label: Text('Latest'),
                      icon: Icon(Icons.new_releases_outlined),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (selection) {
                    setState(() => _kind = selection.first);
                    unawaited(_reload());
                  },
                ),
              ),
            Expanded(child: _buildResults(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorView(message: _error!, onRetry: _run);
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: _isSearching ? 'No results' : 'No ${_kind.name} results',
        message: _isSearching
            ? null
            : 'This source did not return anything for its browse page.',
      );
    }
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.56,
      ),
      itemCount: _items.length + (_hasNextPage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Center(
            child: SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
          );
        }
        final item = _items[index];
        return _SourceResultCard(item: item, onTap: () => _openItem(item));
      },
    );
  }
}

class _SourceResultCard extends StatelessWidget {
  const _SourceResultCard({required this.item, required this.onTap});

  final Object item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = switch (item) {
      JuroAnimeInfo anime => anime.image,
      MangaResult manga => manga.image,
      _ => null,
    };
    final headers = switch (item) {
      JuroAnimeInfo anime => anime.headers,
      MangaResult manga => manga.headers,
      _ => const <String, String>{},
    };
    final title = switch (item) {
      JuroAnimeInfo anime => anime.title,
      MangaResult manga => manga.title,
      _ => 'Untitled',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.expand(
                child: image == null || image.isEmpty
                    ? ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined),
                      )
                    : CachedNetworkImage(
                        imageUrl: image,
                        httpHeaders: headers.isEmpty ? null : headers,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (context, url, error) => ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox.square(
        dimension: 40,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

enum _SourceMediaType { anime, manga }

extension on _SourceMediaType {
  String get label => switch (this) {
    _SourceMediaType.anime => 'Anime',
    _SourceMediaType.manga => 'Manga',
  };

  IconData get icon => switch (this) {
    _SourceMediaType.anime => Icons.live_tv_outlined,
    _SourceMediaType.manga => Icons.menu_book_outlined,
  };
}

List<SourceProvider> _sortedProviders(List<SourceProvider> providers) {
  return providers.toList()..sort((a, b) {
    final language = a.language.compareTo(b.language);
    if (language != 0) return language;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}

AniListMedia _mediaFromAnime(JuroAnimeInfo anime, SourceProvider provider) {
  return AniListMedia(
    id: _stableId('${provider.key}:${anime.id}'),
    title: MediaTitle(
      romaji: anime.title,
      english: anime.title,
      userPreferred: anime.title,
    ),
    cover: MediaCover(extraLarge: anime.image, large: anime.image),
    bannerImage: anime.image,
    description: anime.summary ?? '',
    genres: anime.genres.map((genre) => genre.name).toList(),
    status: anime.status,
    format: anime.type,
    siteUrl: anime.link,
    catalogProviderKey: provider.key,
  );
}

AniListMedia _mediaFromManga(MangaResult manga, SourceProvider provider) {
  return AniListMedia(
    id: _stableId('${provider.key}:${manga.id}'),
    title: MediaTitle(
      romaji: manga.title,
      english: manga.title,
      userPreferred: manga.title,
    ),
    cover: MediaCover(extraLarge: manga.image, large: manga.image),
    bannerImage: manga.image,
    description: manga.description ?? '',
    genres: manga.genres,
    status: manga.status,
    siteUrl: manga.link,
    catalogProviderKey: provider.key,
  );
}

int _stableId(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
