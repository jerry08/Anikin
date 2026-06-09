import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/anilist_media.dart';
import '../models/juro_models.dart';
import '../services/aniyomi_extension_service.dart';
import '../services/download_service.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../services/watch_history_service.dart';
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
                  ),
                  _SourceListTab(
                    providers: data.manga,
                    mediaType: _SourceMediaType.manga,
                    onRefresh: _refresh,
                    onOpen: _openSource,
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
  });

  final List<SourceProvider> providers;
  final _SourceMediaType mediaType;
  final Future<void> Function() onRefresh;
  final void Function(SourceProvider provider, _SourceMediaType mediaType)
  onOpen;

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
  });

  final SourceProvider provider;
  final _SourceMediaType mediaType;
  final VoidCallback onTap;

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
          subtitle: Text(provider.language.toUpperCase()),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
  Future<List<Object>>? _future;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _future = _load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {});
  }

  Future<List<Object>> _load() async {
    final query = _controller.text.trim();
    switch (widget.mediaType) {
      case _SourceMediaType.anime:
        final results = query.isEmpty
            ? await widget.extensionService.browseAnime(
                providerKey: widget.provider.key,
              )
            : await widget.extensionService.searchAnime(
                query,
                providerKey: widget.provider.key,
              );
        return results.cast<Object>();
      case _SourceMediaType.manga:
        final results = query.isEmpty
            ? await widget.extensionService.browseManga(
                providerKey: widget.provider.key,
              )
            : await widget.extensionService.searchManga(
                query,
                providerKey: widget.provider.key,
              );
        return results.cast<Object>();
    }
  }

  void _run() {
    setState(() {
      _future = _load();
    });
  }

  void _clear() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
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
      appBar: AppBar(title: Text(widget.provider.name)),
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
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: _clear,
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Object>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return AppErrorView(
                      message: snapshot.error.toString(),
                      onRetry: _run,
                    );
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off,
                      title: _controller.text.trim().isEmpty
                          ? 'No popular results'
                          : 'No results',
                      message: _controller.text.trim().isEmpty
                          ? 'This source did not return anything for its browse page.'
                          : null,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _SourceResultTile(
                      item: items[index],
                      onTap: () => _openItem(items[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceResultTile extends StatelessWidget {
  const _SourceResultTile({required this.item, required this.onTap});

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
      MangaResult manga => manga.headers,
      _ => const <String, String>{},
    };
    final title = switch (item) {
      JuroAnimeInfo anime => anime.title,
      MangaResult manga => manga.title,
      _ => 'Untitled',
    };
    final subtitle = switch (item) {
      JuroAnimeInfo anime => anime.status ?? anime.released ?? anime.type ?? '',
      MangaResult manga => manga.displaySubtitle,
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: _ResultImage(url: image, headers: headers),
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ResultImage extends StatelessWidget {
  const _ResultImage({required this.url, required this.headers});

  final String? url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 44,
        height: 58,
        child: url == null || url!.isEmpty
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported_outlined),
              )
            : CachedNetworkImage(
                imageUrl: url!,
                httpHeaders: headers,
                fit: BoxFit.cover,
              ),
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
