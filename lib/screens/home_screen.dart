import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/text_utils.dart';
import '../models/anilist_media.dart';
import '../services/anilist_service.dart';
import '../services/download_service.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/app_error_view.dart';
import '../widgets/media_poster_card.dart';
import 'detail_screen.dart';
import 'manga_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.preferences,
    required this.aniListService,
    required this.juroService,
    required this.watchHistoryService,
    required this.downloadService,
    required this.mangaDownloadService,
    required this.onSearchRequested,
    required this.onSettingsRequested,
    super.key,
  });

  final PreferencesService preferences;
  final AniListService aniListService;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final VoidCallback onSearchRequested;
  final VoidCallback onSettingsRequested;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _HomeContentType { anime, manga }

class _HomeScreenState extends State<HomeScreen> {
  Future<_BrowseData>? _animeFuture;
  Future<_BrowseData>? _mangaFuture;
  _HomeContentType _contentType = _HomeContentType.anime;

  @override
  void initState() {
    super.initState();
    _animeFuture = _loadAnime();
    _mangaFuture = _loadManga();
  }

  Future<_BrowseData> _loadAnime() async {
    final includeNonJapanese = widget.preferences.showNonJapaneseAnime;
    final results = await Future.wait([
      widget.aniListService.getCurrentSeason(
        includeNonJapanese: includeNonJapanese,
      ),
      widget.aniListService.getPopular(includeNonJapanese: includeNonJapanese),
      widget.aniListService.getRecentlyUpdated(
        includeNonJapanese: includeNonJapanese,
      ),
      widget.aniListService.getTrending(includeNonJapanese: includeNonJapanese),
    ]);

    final currentSeason = results[0];
    final popular = results[1];
    final recentlyUpdated = results[2];
    final trending = results[3];
    return _BrowseData(
      featured: _BrowseData.featuredFrom([currentSeason, trending, popular]),
      sections: [
        _BrowseSection(title: 'Top Airing', items: popular),
        _BrowseSection(title: 'Recently Updated', items: recentlyUpdated),
        _BrowseSection(title: 'Current Season', items: currentSeason),
        _BrowseSection(title: 'Trending', items: trending),
      ],
    );
  }

  Future<_BrowseData> _loadManga() async {
    final includeNonJapanese = widget.preferences.showNonJapaneseManga;
    final results = await Future.wait([
      widget.aniListService.getPopularManga(
        includeNonJapanese: includeNonJapanese,
      ),
      widget.aniListService.getTrendingManga(
        includeNonJapanese: includeNonJapanese,
      ),
      widget.aniListService.getRecentlyUpdatedManga(
        includeNonJapanese: includeNonJapanese,
      ),
      widget.aniListService.getTopRatedManga(
        includeNonJapanese: includeNonJapanese,
      ),
    ]);

    final popular = results[0];
    final trending = results[1];
    final recentlyUpdated = results[2];
    final topRated = results[3];
    return _BrowseData(
      featured: _BrowseData.featuredFrom([trending, popular, topRated]),
      sections: [
        _BrowseSection(title: 'Popular Manga', items: popular),
        _BrowseSection(title: 'Trending', items: trending),
        _BrowseSection(title: 'Recently Updated', items: recentlyUpdated),
        _BrowseSection(title: 'Top Rated', items: topRated),
      ],
    );
  }

  Future<_BrowseData> get _activeFuture => switch (_contentType) {
    _HomeContentType.anime => _animeFuture ??= _loadAnime(),
    _HomeContentType.manga => _mangaFuture ??= _loadManga(),
  };

  Future<void> _refresh() async {
    late final Future<_BrowseData> future;
    setState(() {
      switch (_contentType) {
        case _HomeContentType.anime:
          future = _loadAnime();
          _animeFuture = future;
        case _HomeContentType.manga:
          future = _loadManga();
          _mangaFuture = future;
      }
    });
    await future;
  }

  void _retry() {
    setState(() {
      switch (_contentType) {
        case _HomeContentType.anime:
          _animeFuture = _loadAnime();
        case _HomeContentType.manga:
          _mangaFuture = _loadManga();
      }
    });
  }

  void _openMedia(AniListMedia media) {
    switch (_contentType) {
      case _HomeContentType.anime:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetailScreen(
              media: media,
              preferences: widget.preferences,
              juroService: widget.juroService,
              watchHistoryService: widget.watchHistoryService,
              downloadService: widget.downloadService,
            ),
          ),
        );
      case _HomeContentType.manga:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MangaDetailScreen(
              media: media,
              preferences: widget.preferences,
              juroService: widget.juroService,
              mangaDownloadService: widget.mangaDownloadService,
            ),
          ),
        );
    }
  }

  void _setContentType(_HomeContentType contentType) {
    if (_contentType == contentType) {
      return;
    }
    setState(() => _contentType = contentType);
  }

  List<Widget> _contentWidgets(_BrowseData data) {
    return [
      if (data.featured.isNotEmpty)
        _FeatureCarousel(items: data.featured, onItemTap: _openMedia),
      if (data.featured.isEmpty) const _TopChromeSpacer(),
      for (final section in data.sections)
        MediaSection(
          title: section.title,
          items: section.items,
          onItemTap: _openMedia,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BrowseData>(
      future: _activeFuture,
      builder: (context, snapshot) {
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      height: 360,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    SizedBox(
                      height: 360,
                      child: AppErrorView(
                        message: snapshot.error.toString(),
                        onRetry: _retry,
                      ),
                    )
                  else
                    ..._contentWidgets(snapshot.data!),
                ],
              ),
            ),
            _HomeTopBar(
              contentType: _contentType,
              onContentTypeChanged: _setContentType,
              onSearchRequested: widget.onSearchRequested,
              onSettingsRequested: widget.onSettingsRequested,
            ),
          ],
        );
      },
    );
  }
}

class _BrowseData {
  const _BrowseData({required this.featured, required this.sections});

  final List<AniListMedia> featured;
  final List<_BrowseSection> sections;

  static List<AniListMedia> featuredFrom(List<List<AniListMedia>> groups) {
    final seen = <int>{};
    return groups
        .expand((items) => items)
        .where((item) {
          return seen.add(item.id);
        })
        .take(8)
        .toList();
  }
}

class _BrowseSection {
  const _BrowseSection({required this.title, required this.items});

  final String title;
  final List<AniListMedia> items;
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.contentType,
    required this.onContentTypeChanged,
    required this.onSearchRequested,
    required this.onSettingsRequested,
  });

  final _HomeContentType contentType;
  final ValueChanged<_HomeContentType> onContentTypeChanged;
  final VoidCallback onSearchRequested;
  final VoidCallback onSettingsRequested;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
        child: Row(
          children: [
            Image.asset('assets/images/tori_gate.png', width: 34, height: 34),
            const SizedBox(width: 8),
            _ContentSwitch(value: contentType, onChanged: onContentTypeChanged),
            const Spacer(),
            _HeaderIconButton(
              tooltip: 'Search',
              icon: Icons.search,
              onPressed: onSearchRequested,
            ),
            const SizedBox(width: 4),
            _HeaderIconButton(
              tooltip: 'Settings',
              icon: Icons.settings_outlined,
              onPressed: onSettingsRequested,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopChromeSpacer extends StatelessWidget {
  const _TopChromeSpacer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: MediaQuery.paddingOf(context).top + 58);
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0x66000000),
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ContentSwitch extends StatelessWidget {
  const _ContentSwitch({required this.value, required this.onChanged});

  final _HomeContentType value;
  final ValueChanged<_HomeContentType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ContentSwitchButton(
            label: 'Anime',
            icon: Icons.live_tv_outlined,
            selected: value == _HomeContentType.anime,
            onPressed: () => onChanged(_HomeContentType.anime),
          ),
          const SizedBox(width: 2),
          _ContentSwitchButton(
            label: 'Manga',
            icon: Icons.menu_book_outlined,
            selected: value == _HomeContentType.manga,
            onPressed: () => onChanged(_HomeContentType.manga),
          ),
        ],
      ),
    );
  }
}

class _ContentSwitchButton extends StatelessWidget {
  const _ContentSwitchButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected ? Colors.black : Colors.white;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Container(
          width: selected ? 92 : 40,
          height: 36,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: onPressed,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: foregroundColor),
                    if (selected) ...[
                      const SizedBox(width: 5),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          color: foregroundColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
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

class _FeatureCarousel extends StatefulWidget {
  const _FeatureCarousel({required this.items, required this.onItemTap});

  final List<AniListMedia> items;
  final ValueChanged<AniListMedia> onItemTap;

  @override
  State<_FeatureCarousel> createState() => _FeatureCarouselState();
}

class _FeatureCarouselState extends State<_FeatureCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _FeatureCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _index = _index.clamp(0, widget.items.length - 1).toInt();
      _timer?.cancel();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (widget.items.length < 2) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }

      final nextIndex = (_index + 1) % widget.items.length;
      _controller.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.78).clamp(390.0, 440.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final media = widget.items[index];
                return _FeatureBanner(
                  media: media,
                  onTap: () => widget.onItemTap(media),
                );
              },
            ),
          ),
          if (widget.items.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < widget.items.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: index == _index ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == _index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureBanner extends StatelessWidget {
  const _FeatureBanner({required this.media, required this.onTap});

  final AniListMedia media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = media.bannerImage ?? media.cover.best;
    return InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
          else
            ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x22000000), Color(0xF0000000)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Pill(
                      icon: Icons.star_rounded,
                      label: '${media.meanScore ?? '--'}%',
                    ),
                    _Pill(
                      icon: Icons.people_alt_outlined,
                      label: compactNumber(media.popularity),
                    ),
                    if (media.metadata.isNotEmpty)
                      _Pill(icon: Icons.info_outline, label: media.metadata),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
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
    );
  }
}

class MediaSection extends StatelessWidget {
  const MediaSection({
    required this.title,
    required this.items,
    required this.onItemTap,
    super.key,
  });

  final String title;
  final List<AniListMedia> items;
  final ValueChanged<AniListMedia> onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 252,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => MediaPosterCard(
                media: items[index],
                onTap: () => onItemTap(items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
