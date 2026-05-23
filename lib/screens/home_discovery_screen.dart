import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/anilist_airing_schedule.dart';
import '../models/anilist_media.dart';
import '../services/anilist_service.dart';
import '../services/preferences_service.dart';
import '../widgets/app_error_view.dart';
import '../widgets/media_poster_card.dart';

class HomeMediaCollectionScreen extends StatefulWidget {
  const HomeMediaCollectionScreen({
    required this.title,
    required this.loader,
    required this.onItemTap,
    this.subtitle,
    this.icon = Icons.arrow_forward_ios_rounded,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Future<List<AniListMedia>> Function() loader;
  final ValueChanged<AniListMedia> onItemTap;
  final String emptyTitle;
  final String? emptyMessage;

  @override
  State<HomeMediaCollectionScreen> createState() =>
      _HomeMediaCollectionScreenState();
}

class _HomeMediaCollectionScreenState extends State<HomeMediaCollectionScreen> {
  late Future<List<AniListMedia>> _future;
  _CollectionLayoutMode _layoutMode = _CollectionLayoutMode.grid;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  Future<void> _refresh() async {
    final future = widget.loader();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _layoutMode == _CollectionLayoutMode.grid
                ? 'Show list'
                : 'Show grid',
            onPressed: () {
              setState(() {
                _layoutMode = _layoutMode == _CollectionLayoutMode.grid
                    ? _CollectionLayoutMode.list
                    : _CollectionLayoutMode.grid;
              });
            },
            icon: Icon(
              _layoutMode == _CollectionLayoutMode.grid
                  ? Icons.view_agenda_rounded
                  : Icons.grid_view_rounded,
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<AniListMedia>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return AppErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final items = snapshot.data ?? const <AniListMedia>[];
          if (items.isEmpty) {
            return EmptyState(
              icon: widget.icon,
              title: widget.emptyTitle,
              message: widget.emptyMessage,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 154).floor().clamp(
                  2,
                  6,
                );
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_layoutMode == _CollectionLayoutMode.grid)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final item = items[index];
                            return MediaPosterCard(
                              media: item,
                              width: 150,
                              onTap: () => widget.onItemTap(item),
                            );
                          }, childCount: items.length),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.54,
                              ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        sliver: SliverList.separated(
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _MediaCollectionListTile(
                              media: item,
                              onTap: () => widget.onItemTap(item),
                            );
                          },
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemCount: items.length,
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class GenreBrowseScreen extends StatefulWidget {
  const GenreBrowseScreen({
    required this.mediaType,
    required this.preferences,
    required this.aniListService,
    required this.onItemTap,
    super.key,
  });

  final AniListMediaType mediaType;
  final PreferencesService preferences;
  final AniListService aniListService;
  final ValueChanged<AniListMedia> onItemTap;

  @override
  State<GenreBrowseScreen> createState() => _GenreBrowseScreenState();
}

class _GenreBrowseScreenState extends State<GenreBrowseScreen> {
  late Future<_GenreBrowseData> _future;

  bool get _includeNonJapanese => switch (widget.mediaType) {
    AniListMediaType.anime => widget.preferences.showNonJapaneseAnime,
    AniListMediaType.manga => widget.preferences.showNonJapaneseManga,
  };

  String get _contentLabel => switch (widget.mediaType) {
    AniListMediaType.anime => 'Anime',
    AniListMediaType.manga => 'Manga',
  };

  @override
  void initState() {
    super.initState();
    _future = _loadGenres();
  }

  Future<_GenreBrowseData> _loadGenres() async {
    final genres = await widget.aniListService.getGenreCollection();
    final items = await Future.wait(
      genres.map((genre) async {
        final matches = widget.mediaType == AniListMediaType.anime
            ? await widget.aniListService.searchMedia(
                mediaType: AniListMediaType.anime,
                genres: [genre],
                perPage: 1,
                sort: const ['TRENDING_DESC'],
                includeNonJapanese: _includeNonJapanese,
              )
            : await widget.aniListService.searchManga(
                genres: [genre],
                perPage: 1,
                sort: const ['TRENDING_DESC'],
                includeNonJapanese: _includeNonJapanese,
              );
        return _GenreBrowseItem(
          genre: genre,
          preview: matches.isEmpty ? null : matches.first,
        );
      }),
    );
    return _GenreBrowseData(items: items);
  }

  Future<void> _refresh() async {
    final future = _loadGenres();
    setState(() => _future = future);
    await future;
  }

  void _openGenre(String genre) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomeMediaCollectionScreen(
          title: genre,
          icon: Icons.category_outlined,
          subtitle: 'Popular $_contentLabel picks tagged with $genre.',
          loader: () => widget.mediaType == AniListMediaType.anime
              ? widget.aniListService.searchMedia(
                  mediaType: AniListMediaType.anime,
                  genres: [genre],
                  sort: const ['TRENDING_DESC'],
                  includeNonJapanese: _includeNonJapanese,
                )
              : widget.aniListService.searchManga(
                  genres: [genre],
                  sort: const ['TRENDING_DESC'],
                  includeNonJapanese: _includeNonJapanese,
                ),
          onItemTap: widget.onItemTap,
          emptyTitle: 'No $_contentLabel in this genre',
          emptyMessage: 'Try another genre or refresh this page.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$_contentLabel Genres')),
      body: FutureBuilder<_GenreBrowseData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return AppErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final items = snapshot.data?.items ?? const <_GenreBrowseItem>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.category_outlined,
              title: 'No genres available',
              message: 'AniList did not return any genres to browse right now.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 156).floor().clamp(
                  2,
                  5,
                );
                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 78,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _GenreGridTile(
                      item: item,
                      onTap: () => _openGenre(item.genre),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class AiringCalendarScreen extends StatefulWidget {
  const AiringCalendarScreen({
    required this.preferences,
    required this.aniListService,
    required this.onItemTap,
    super.key,
  });

  final PreferencesService preferences;
  final AniListService aniListService;
  final ValueChanged<AniListMedia> onItemTap;

  @override
  State<AiringCalendarScreen> createState() => _AiringCalendarScreenState();
}

class _AiringCalendarScreenState extends State<AiringCalendarScreen> {
  late Future<List<AniListAiringSchedule>> _future;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    _startDate = _dateOnly(DateTime.now());
    _future = _loadCalendar();
  }

  Future<List<AniListAiringSchedule>> _loadCalendar() {
    return widget.aniListService.getAiringCalendar(
      start: _startDate,
      days: 7,
      includeNonJapanese: widget.preferences.showNonJapaneseAnime,
    );
  }

  Future<void> _refresh() async {
    final future = _loadCalendar();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: FutureBuilder<List<AniListAiringSchedule>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return AppErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final schedules = snapshot.data ?? const <AniListAiringSchedule>[];
          final days = _calendarDaysFrom(_startDate, schedules);

          if (days.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'Nothing scheduled',
              message:
                  'No upcoming airing entries were returned for this week.',
            );
          }

          return DefaultTabController(
            length: days.length,
            child: Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                      unselectedLabelColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      indicator: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      splashBorderRadius: BorderRadius.circular(999),
                      overlayColor: WidgetStateProperty.resolveWith((states) {
                        final colorScheme = Theme.of(context).colorScheme;
                        if (states.contains(WidgetState.pressed)) {
                          return colorScheme.primary.withValues(alpha: 0.14);
                        }
                        if (states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)) {
                          return colorScheme.primary.withValues(alpha: 0.08);
                        }
                        return null;
                      }),
                      tabs: [
                        for (final day in days)
                          Tab(height: 42, child: _CalendarDayTab(day: day)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final day in days)
                        _CalendarDayGrid(
                          day: day,
                          onRefresh: _refresh,
                          onItemTap: widget.onItemTap,
                        ),
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

class _CalendarDayTab extends StatelessWidget {
  const _CalendarDayTab({required this.day});

  final _CalendarDay day;

  @override
  Widget build(BuildContext context) {
    final textColor =
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurfaceVariant;

    return Tooltip(
      message:
          '${DateFormat('EEEE, MMM d').format(day.date)} • ${day.items.length} airing${day.items.length == 1 ? '' : 's'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('EEE d').format(day.date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 7),
            DecoratedBox(
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: textColor.withValues(alpha: 0.18)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Text(
                  '${day.items.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreGridTile extends StatelessWidget {
  const _GenreGridTile({required this.item, required this.onTap});

  final _GenreBrowseItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preview = item.preview;
    final imageUrl = preview?.bannerImage ?? preview?.cover.best;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Opacity(
                opacity: 0.46,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, _) =>
                      ColoredBox(color: colorScheme.surfaceContainerHighest),
                  errorWidget: (context, _, _) =>
                      ColoredBox(color: colorScheme.surfaceContainerHighest),
                ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.surfaceContainerHighest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x8A000000), Color(0xB8000000)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.genre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(color: Color(0x90000000), blurRadius: 12),
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

class _CalendarDayGrid extends StatelessWidget {
  const _CalendarDayGrid({
    required this.day,
    required this.onRefresh,
    required this.onItemTap,
  });

  final _CalendarDay day;
  final Future<void> Function() onRefresh;
  final ValueChanged<AniListMedia> onItemTap;

  @override
  Widget build(BuildContext context) {
    if (day.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: const [
            EmptyState(
              icon: Icons.schedule_outlined,
              title: 'No airings on this day',
              message: 'Pick another tab to browse upcoming episodes.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / 154).floor().clamp(2, 6);
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: day.items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12,
              childAspectRatio: 0.54,
            ),
            itemBuilder: (context, index) {
              final item = day.items[index];
              return _AiringPosterCard(
                schedule: item,
                onTap: () => onItemTap(item.media),
              );
            },
          );
        },
      ),
    );
  }
}

class _AiringPosterCard extends StatelessWidget {
  const _AiringPosterCard({required this.schedule, required this.onTap});

  final AniListAiringSchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MediaPosterCard(
      media: schedule.media,
      onTap: onTap,
      posterOverlay: Positioned(
        left: 7,
        right: 7,
        top: 7,
        child: Row(
          children: [
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _PosterBadge(
                  icon: Icons.schedule_outlined,
                  label: DateFormat('jm').format(schedule.airingDateTime),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: _PosterBadge(
                  icon: Icons.play_circle_outline,
                  label: 'EP ${schedule.episode}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterBadge extends StatelessWidget {
  const _PosterBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xD9000000),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaCollectionListTile extends StatelessWidget {
  const _MediaCollectionListTile({required this.media, required this.onTap});

  final AniListMedia media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 92,
                  height: 132,
                  child: media.cover.best == null
                      ? ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.movie_filter_outlined),
                        )
                      : CachedNetworkImage(
                          imageUrl: media.cover.best!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (media.metadata.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        media.metadata,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (media.meanScore != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFFFD166),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${media.meanScore}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (media.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        media.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarDay {
  const _CalendarDay({required this.date, required this.items});

  final DateTime date;
  final List<AniListAiringSchedule> items;
}

List<_CalendarDay> _calendarDaysFrom(
  DateTime start,
  List<AniListAiringSchedule> schedules,
) {
  final grouped = <DateTime, List<AniListAiringSchedule>>{};
  for (final item in schedules) {
    final key = _dateOnly(item.airingDateTime);
    grouped.putIfAbsent(key, () => <AniListAiringSchedule>[]).add(item);
  }

  return List.generate(7, (index) {
    final date = _dateOnly(start.add(Duration(days: index)));
    final items = [...(grouped[date] ?? const <AniListAiringSchedule>[])];
    items.sort((a, b) => a.airingAt.compareTo(b.airingAt));
    return _CalendarDay(date: date, items: items);
  });
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class _GenreBrowseData {
  const _GenreBrowseData({required this.items});

  final List<_GenreBrowseItem> items;
}

class _GenreBrowseItem {
  const _GenreBrowseItem({required this.genre, required this.preview});

  final String genre;
  final AniListMedia? preview;
}

enum _CollectionLayoutMode { grid, list }
