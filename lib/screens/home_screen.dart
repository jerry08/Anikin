import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/text_utils.dart';
import '../models/anilist_media.dart';
import '../services/anilist_service.dart';
import '../services/download_service.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/app_error_view.dart';
import '../widgets/media_poster_card.dart';
import '../widgets/media_type_selector.dart';
import 'detail_screen.dart';
import 'home_discovery_screen.dart';
import 'manga_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.preferences,
    required this.aniListService,
    required this.juroService,
    required this.watchHistoryService,
    required this.downloadService,
    required this.mangaDownloadService,
    required this.trackingService,
    super.key,
  });

  final PreferencesService preferences;
  final MediaCatalogService aniListService;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final TrackingService trackingService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const double _desktopBreakpoint = 900;
const double _desktopContentMaxWidth = 1280;

class _HomeScreenState extends State<HomeScreen> {
  Future<_BrowseData>? _animeFuture;
  Future<_BrowseData>? _mangaFuture;
  late AppMediaType _contentType;
  late String _catalogProviderKey;

  @override
  void initState() {
    super.initState();
    _contentType = widget.preferences.appMediaType;
    _catalogProviderKey = widget.trackingService.primaryProvider.key;
    widget.preferences.addListener(_handleMediaTypeChanged);
    widget.trackingService.addListener(_handleCatalogProviderChanged);
    _animeFuture = _loadAnime();
    _mangaFuture = _loadManga();
  }

  @override
  void dispose() {
    widget.preferences.removeListener(_handleMediaTypeChanged);
    widget.trackingService.removeListener(_handleCatalogProviderChanged);
    super.dispose();
  }

  void _handleMediaTypeChanged() {
    final contentType = widget.preferences.appMediaType;
    if (contentType == _contentType || !mounted) {
      return;
    }
    setState(() => _contentType = contentType);
  }

  void _handleCatalogProviderChanged() {
    final providerKey = widget.trackingService.primaryProvider.key;
    if (providerKey == _catalogProviderKey) {
      return;
    }
    _catalogProviderKey = providerKey;
    setState(() {
      _animeFuture = _loadAnime();
      _mangaFuture = _loadManga();
    });
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
        _BrowseSection(title: 'Recently Updated', items: recentlyUpdated),
        _BrowseSection(title: 'Top Airing', items: popular),
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
        _BrowseSection(title: 'Recently Updated', items: recentlyUpdated),
        _BrowseSection(title: 'Popular Manga', items: popular),
        _BrowseSection(title: 'Trending', items: trending),
        _BrowseSection(title: 'Top Rated', items: topRated),
      ],
    );
  }

  Future<_BrowseData> get _activeFuture => switch (_contentType) {
    AppMediaType.anime => _animeFuture ??= _loadAnime(),
    AppMediaType.manga => _mangaFuture ??= _loadManga(),
  };

  Future<void> _refresh() async {
    late final Future<_BrowseData> future;
    setState(() {
      switch (_contentType) {
        case AppMediaType.anime:
          future = _loadAnime();
          _animeFuture = future;
        case AppMediaType.manga:
          future = _loadManga();
          _mangaFuture = future;
      }
    });
    await future;
  }

  void _retry() {
    setState(() {
      switch (_contentType) {
        case AppMediaType.anime:
          _animeFuture = _loadAnime();
        case AppMediaType.manga:
          _mangaFuture = _loadManga();
      }
    });
  }

  void _openMedia(AniListMedia media, {AppMediaType? contentType}) {
    switch (contentType ?? _contentType) {
      case AppMediaType.anime:
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
      case AppMediaType.manga:
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
    }
  }

  void _setContentType(AppMediaType contentType) {
    if (_contentType == contentType) {
      return;
    }
    unawaited(widget.preferences.setAppMediaType(contentType));
  }

  void _openSection(
    _BrowseSection section, {
    required AppMediaType contentType,
  }) {
    final contentLabel = switch (contentType) {
      AppMediaType.anime => 'anime',
      AppMediaType.manga => 'manga',
    };
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeMediaCollectionScreen(
          title: section.title,
          subtitle:
              'A fuller $contentLabel shelf for ${section.title.toLowerCase()}.',
          loader: () async => section.items,
          onItemTap: (media) => _openMedia(media, contentType: contentType),
          emptyTitle: 'Nothing to show',
          emptyMessage: 'This shelf does not have any titles right now.',
        ),
      ),
    );
  }

  void _openGenres(AppMediaType contentType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GenreBrowseScreen(
          mediaType: switch (contentType) {
            AppMediaType.anime => AniListMediaType.anime,
            AppMediaType.manga => AniListMediaType.manga,
          },
          preferences: widget.preferences,
          aniListService: widget.aniListService,
          onItemTap: (media) => _openMedia(media, contentType: contentType),
        ),
      ),
    );
  }

  void _openCalendar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiringCalendarScreen(
          preferences: widget.preferences,
          aniListService: widget.aniListService,
          onItemTap: _openMedia,
        ),
      ),
    );
  }

  List<Widget> _contentWidgets(_BrowseData data, AppMediaType contentType) {
    return [
      if (data.featured.isNotEmpty)
        _FeatureCarousel(
          items: data.featured,
          onItemTap: (media) => _openMedia(media, contentType: contentType),
        ),
      if (data.featured.isEmpty) const _TopChromeSpacer(),
      _HomeShortcutStrip(
        onGenres: () => _openGenres(contentType),
        onCalendar: contentType == AppMediaType.anime ? _openCalendar : null,
      ),
      for (final section in data.sections)
        MediaSection(
          title: section.title,
          items: section.items,
          onItemTap: (media) => _openMedia(media, contentType: contentType),
          onMoreTap: () => _openSection(section, contentType: contentType),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BrowseData>(
      key: ValueKey('home-${_contentType.name}-future'),
      future: _activeFuture,
      builder: (context, snapshot) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
            final content = <Widget>[
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
                ..._contentWidgets(snapshot.data!, _contentType),
            ];

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_contentType),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    tween: Tween(begin: 0, end: 1),
                    builder: (context, opacity, child) =>
                        Opacity(opacity: opacity, child: child),
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        key: ValueKey<String>('home-${_contentType.name}-list'),
                        primary: false,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (isDesktop)
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: _desktopContentMaxWidth,
                                ),
                                child: Column(children: content),
                              ),
                            )
                          else
                            ...content,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _HomeTopBar(
                    contentType: _contentType,
                    onContentTypeChanged: _setContentType,
                  ),
                ),
              ],
            );
          },
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
  });

  final AppMediaType contentType;
  final ValueChanged<AppMediaType> onContentTypeChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _desktopContentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/tori_gate.png',
                  width: 34,
                  height: 34,
                ),
                const Spacer(),
                MediaTypeSelector(
                  value: contentType,
                  onChanged: onContentTypeChanged,
                  appearance: MediaTypeSelectorAppearance.glass,
                ),
              ],
            ),
          ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final isDesktop = width >= _desktopBreakpoint;
        final height = isDesktop
            ? (width * 0.34).clamp(340.0, 420.0).toDouble()
            : (width * 0.78).clamp(390.0, 440.0).toDouble();

        return Padding(
          padding: EdgeInsets.only(bottom: isDesktop ? 26 : 22),
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
      },
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
      mouseCursor: SystemMouseCursors.click,
      focusColor: Colors.white.withValues(alpha: 0.08),
      hoverColor: Colors.white.withValues(alpha: 0.06),
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
                    fontWeight: FontWeight.w700,
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
    required this.onMoreTap,
    super.key,
  });

  final String title;
  final List<AniListMedia> items;
  final ValueChanged<AniListMedia> onItemTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
        final horizontalPadding = isDesktop ? 20.0 : 12.0;

        return Padding(
          padding: EdgeInsets.only(bottom: isDesktop ? 30 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'View all',
                      onPressed: onMoreTap,
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (isDesktop)
                _DesktopMediaSectionGrid(items: items, onItemTap: onItemTap)
              else
                SizedBox(
                  height: 252,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) => MediaPosterCard(
                      media: items[index],
                      onTap: () => onItemTap(items[index]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopMediaSectionGrid extends StatelessWidget {
  const _DesktopMediaSectionGrid({
    required this.items,
    required this.onItemTap,
  });

  final List<AniListMedia> items;
  final ValueChanged<AniListMedia> onItemTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 158)
            .floor()
            .clamp(4, 8)
            .toInt();
        final visibleCount = math.min(items.length, columns * 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: visibleCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 14,
            crossAxisSpacing: 10,
            childAspectRatio: 0.54,
          ),
          itemBuilder: (context, index) => MediaPosterCard(
            media: items[index],
            width: double.infinity,
            onTap: () => onItemTap(items[index]),
          ),
        );
      },
    );
  }
}

class _HomeShortcutStrip extends StatelessWidget {
  const _HomeShortcutStrip({required this.onGenres, required this.onCalendar});

  static const _genreImageUrl =
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/16498-8jpFCOcDmneX.jpg';
  static const _calendarImageUrl =
      'https://s4.anilist.co/file/anilistcdn/media/anime/banner/125367-hGPJLSNfprO3.jpg';

  final VoidCallback onGenres;
  final VoidCallback? onCalendar;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _HomeShortcutAction(
        label: 'Genres',
        icon: Icons.category_outlined,
        imageUrl: _genreImageUrl,
        onTap: onGenres,
      ),
      if (onCalendar != null)
        _HomeShortcutAction(
          label: 'Calendar',
          icon: Icons.calendar_month_outlined,
          imageUrl: _calendarImageUrl,
          onTap: onCalendar!,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Row(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            Expanded(child: actions[index]),
            if (index < actions.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _HomeShortcutAction extends StatelessWidget {
  const _HomeShortcutAction({
    required this.label,
    required this.icon,
    required this.imageUrl,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.46,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, _) =>
                      ColoredBox(color: colorScheme.surfaceContainerHighest),
                  errorWidget: (context, _, _) =>
                      ColoredBox(color: colorScheme.surfaceContainerHighest),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x8A000000), Color(0xB8000000)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x26FFFFFF)),
                    ),
                    child: Icon(icon, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Color(0x99000000), blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.white70,
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
