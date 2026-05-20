import 'dart:async';

import 'package:flutter/material.dart';

import '../models/anilist_media.dart';
import '../services/anilist_service.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../widgets/app_error_view.dart';
import '../widgets/media_poster_card.dart';
import 'manga_detail_screen.dart';

class MangaScreen extends StatefulWidget {
  const MangaScreen({
    required this.preferences,
    required this.aniListService,
    required this.juroService,
    required this.mangaDownloadService,
    super.key,
  });

  final PreferencesService preferences;
  final AniListService aniListService;
  final JuroService juroService;
  final MangaDownloadService mangaDownloadService;

  @override
  State<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends State<MangaScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _items = <AniListMedia>[];

  late Future<MangaHomeData> _future;
  Timer? _debounce;
  int _page = 1;
  bool _isLoading = false;
  bool _canLoadMore = false;
  String? _error;

  bool get _isSearching => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _future = _loadHome();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<MangaHomeData> _loadHome() async {
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

    return MangaHomeData(
      popular: results[0],
      trending: results[1],
      recentlyUpdated: results[2],
      topRated: results[3],
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadHome());
    await _future;
  }

  void _onScroll() {
    if (!_isSearching ||
        !_canLoadMore ||
        _isLoading ||
        _scrollController.position.extentAfter > 600) {
      return;
    }
    _runSearch(reset: false);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _items.clear();
        _error = null;
        _canLoadMore = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _runSearch(reset: true),
    );
  }

  Future<void> _runSearch({required bool reset}) async {
    final query = _controller.text.trim();
    if (query.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _items.clear();
      }
    });

    try {
      final result = await widget.aniListService.searchManga(
        query: query,
        page: _page,
        includeNonJapanese: widget.preferences.showNonJapaneseManga,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result);
        _page++;
        _canLoadMore = result.isNotEmpty;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openMedia(AniListMedia media) {
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Manga',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _runSearch(reset: true),
              decoration: InputDecoration(
                hintText: 'Search manga',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(child: _isSearching ? _buildSearchBody() : _buildHomeBody()),
        ],
      ),
    );
  }

  Widget _buildHomeBody() {
    return FutureBuilder<MangaHomeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return AppErrorView(
            message: snapshot.error.toString(),
            onRetry: () => setState(() => _future = _loadHome()),
          );
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _MangaMediaSection(
                title: 'Popular Manga',
                items: data.popular,
                onItemTap: _openMedia,
              ),
              _MangaMediaSection(
                title: 'Trending',
                items: data.trending,
                onItemTap: _openMedia,
              ),
              _MangaMediaSection(
                title: 'Recently Updated',
                items: data.recentlyUpdated,
                onItemTap: _openMedia,
              ),
              _MangaMediaSection(
                title: 'Top Rated',
                items: data.topRated,
                onItemTap: _openMedia,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBody() {
    if (_error != null && _items.isEmpty) {
      return AppErrorView(
        message: _error!,
        onRetry: () => _runSearch(reset: true),
      );
    }

    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No manga found',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 150).floor().clamp(2, 6);
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: 0.52,
          ),
          itemCount: _items.length + (_isLoading ? columns : 0),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return MediaPosterCard(
              media: _items[index],
              onTap: () => _openMedia(_items[index]),
              width: 150,
            );
          },
        );
      },
    );
  }
}

class MangaHomeData {
  const MangaHomeData({
    required this.popular,
    required this.trending,
    required this.recentlyUpdated,
    required this.topRated,
  });

  final List<AniListMedia> popular;
  final List<AniListMedia> trending;
  final List<AniListMedia> recentlyUpdated;
  final List<AniListMedia> topRated;
}

class _MangaMediaSection extends StatelessWidget {
  const _MangaMediaSection({
    required this.title,
    required this.items,
    required this.onItemTap,
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
