import 'dart:async';

import 'package:flutter/material.dart';

import '../models/anilist_media.dart';
import '../models/media_search_filters.dart';
import '../services/anilist_service.dart';
import '../services/download_service.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/search_history_service.dart';
import '../services/tracking_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_content_constraint.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_sheet_action_bar.dart';
import '../widgets/advanced_search_sheet.dart';
import '../widgets/media_poster_card.dart';
import '../widgets/media_type_selector.dart';
import 'detail_screen.dart';
import 'manga_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.preferences,
    required this.aniListService,
    required this.juroService,
    required this.watchHistoryService,
    required this.downloadService,
    required this.mangaDownloadService,
    required this.trackingService,
    this.searchHistoryService,
    super.key,
  });

  final PreferencesService preferences;
  final MediaCatalogService aniListService;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final TrackingService trackingService;
  final SearchHistoryService? searchHistoryService;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

const double _searchHeaderMaxWidth = 840;
const _featuredSearchTags = [
  'Shounen',
  'Isekai',
  'School',
  'Magic',
  'Vampire',
  'Demons',
  'Super Power',
  'Martial Arts',
];

const _allSearchTags = [
  'Shounen',
  'Seinen',
  'Shoujo',
  'Josei',
  'Isekai',
  'School',
  'Magic',
  'Vampire',
  'Demons',
  'Super Power',
  'Martial Arts',
  'Revenge',
  'Survival',
  'Historical',
  'Urban Fantasy',
  'Time Manipulation',
  'Video Games',
  'Female Protagonist',
  'Male Protagonist',
  'Primarily Female Cast',
  'Primarily Male Cast',
  'Villainess',
  'Idol',
  'Music',
  'Gore',
  'Tragedy',
];

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _items = <AniListMedia>[];

  late AppMediaType _contentType;
  MediaSearchFilters _filters = const MediaSearchFilters();
  List<String> _recentSearches = const [];
  List<String>? _genres;
  Timer? _debounce;
  int _page = 1;
  int _searchGeneration = 0;
  bool _isLoading = false;
  bool _canLoadMore = false;
  String? _error;
  late String _catalogProviderKey;

  bool get _hasSearchInput =>
      _controller.text.trim().isNotEmpty || _filters.hasActive;

  Set<String> get _selectedTags => _filters.includedTags;

  String get _historyTarget => _contentType.name;

  @override
  void initState() {
    super.initState();
    _contentType = widget.preferences.appMediaType;
    _catalogProviderKey = widget.trackingService.primaryProvider.key;
    widget.preferences.addListener(_handleMediaTypeChanged);
    widget.trackingService.addListener(_handleCatalogProviderChanged);
    _scrollController.addListener(_onScroll);
    unawaited(_loadHistory());
  }

  @override
  void dispose() {
    widget.preferences.removeListener(_handleMediaTypeChanged);
    widget.trackingService.removeListener(_handleCatalogProviderChanged);
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleMediaTypeChanged() {
    final contentType = widget.preferences.appMediaType;
    if (contentType == _contentType || !mounted) {
      return;
    }

    _debounce?.cancel();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {
      _contentType = contentType;
      _filters = _filters.copyWith(
        format: null,
        season: contentType == AppMediaType.manga ? null : _filters.season,
      );
      _searchGeneration++;
      _page = 1;
      _items.clear();
      _canLoadMore = false;
      _error = null;
      _isLoading = false;
    });
    unawaited(_loadHistory());

    if (_hasSearchInput) {
      unawaited(_runSearch(reset: true));
    }
  }

  void _handleCatalogProviderChanged() {
    final providerKey = widget.trackingService.primaryProvider.key;
    if (providerKey == _catalogProviderKey) {
      return;
    }
    _catalogProviderKey = providerKey;
    _debounce?.cancel();
    setState(() {
      _searchGeneration++;
      _page = 1;
      _items.clear();
      _error = null;
      _canLoadMore = false;
      _isLoading = false;
    });
    if (_hasSearchInput) {
      unawaited(_runSearch(reset: true));
    }
  }

  void _onScroll() {
    if (!_canLoadMore ||
        _isLoading ||
        _scrollController.position.extentAfter > 600) {
      return;
    }
    _runSearch(reset: false);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    if (!_hasSearchInput) {
      _runSearch(reset: true);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _runSearch(reset: true),
    );
  }

  Future<void> _loadHistory() async {
    final service = widget.searchHistoryService;
    if (service == null) {
      return;
    }
    final target = _historyTarget;
    final recent = await service.recent(target);
    if (!mounted || target != _historyTarget) {
      return;
    }
    setState(() => _recentSearches = recent);
  }

  Future<void> _submitSearch() async {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      await widget.searchHistoryService?.record(_historyTarget, query);
      await _loadHistory();
    }
    await _runSearch(reset: true);
  }

  void _useHistory(String query) {
    _debounce?.cancel();
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    setState(() {});
    unawaited(_submitSearch());
  }

  Future<void> _removeHistory(String query) async {
    await widget.searchHistoryService?.remove(_historyTarget, query);
    await _loadHistory();
  }

  void _clearQuery() {
    if (_controller.text.isEmpty) {
      return;
    }

    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    _runSearch(reset: true);
  }

  Future<void> _runSearch({required bool reset}) async {
    final query = _controller.text.trim();
    if (!_hasSearchInput) {
      _searchGeneration++;
      setState(() {
        _items.clear();
        _error = null;
        _canLoadMore = false;
        _isLoading = false;
      });
      return;
    }

    if (!reset && _isLoading) {
      return;
    }

    final requestGeneration = reset ? ++_searchGeneration : _searchGeneration;
    final requestPage = reset ? 1 : _page;
    final tags = _filters.includedTags.toList(growable: false)..sort();
    final excludedTags = _filters.excludedTags.toList(growable: false)..sort();
    final genres = _filters.includedGenres.toList(growable: false)..sort();
    final excludedGenres = _filters.excludedGenres.toList(growable: false)
      ..sort();
    final includeNonJapanese = _includeNonJapaneseResults(query);

    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _items.clear();
      }
    });

    try {
      late final List<AniListMedia> result;
      switch (_contentType) {
        case AppMediaType.anime:
          result = await widget.aniListService.searchMedia(
            query: query,
            page: requestPage,
            sort: [_filters.sort.graphqlName],
            season: _filters.season,
            seasonYear: _filters.seasonYear,
            status: _filters.status,
            source: _filters.source,
            format: _filters.format,
            countryOfOrigin: _filters.countryOfOrigin,
            tags: tags,
            excludedTags: excludedTags,
            genres: genres,
            excludedGenres: excludedGenres,
            includeNonJapanese: includeNonJapanese,
          );
        case AppMediaType.manga:
          result = await widget.aniListService.searchManga(
            query: query,
            page: requestPage,
            sort: [_filters.sort.graphqlName],
            status: _filters.status,
            source: _filters.source,
            format: _filters.format,
            countryOfOrigin: _filters.countryOfOrigin,
            tags: tags,
            excludedTags: excludedTags,
            genres: genres,
            excludedGenres: excludedGenres,
            includeNonJapanese: includeNonJapanese,
          );
      }
      if (!mounted || requestGeneration != _searchGeneration) {
        return;
      }
      setState(() {
        if (reset) {
          _items.clear();
        }
        _items.addAll(result);
        _page = requestPage + 1;
        _canLoadMore = result.isNotEmpty;
      });
    } catch (error) {
      if (mounted && requestGeneration == _searchGeneration) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && requestGeneration == _searchGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openMedia(AniListMedia media) {
    switch (_contentType) {
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

  bool _includeNonJapaneseResults(String query) {
    if (query.isNotEmpty || _filters.countryOfOrigin != null) {
      return true;
    }

    return switch (_contentType) {
      AppMediaType.anime => widget.preferences.showNonJapaneseAnime,
      AppMediaType.manga => widget.preferences.showNonJapaneseManga,
    };
  }

  void _toggleTag(String tag) {
    final included = {..._filters.includedTags};
    final excluded = {..._filters.excludedTags}..remove(tag);
    if (!included.remove(tag)) {
      included.add(tag);
    }
    setState(() {
      _filters = _filters.copyWith(
        includedTags: included,
        excludedTags: excluded,
      );
    });
    _runSearch(reset: true);
  }

  void _clearTags() {
    if (_filters.includedTags.isEmpty && _filters.excludedTags.isEmpty) {
      return;
    }

    setState(() {
      _filters = _filters.copyWith(
        includedTags: const {},
        excludedTags: const {},
      );
    });
    _runSearch(reset: true);
  }

  void _clearFilters() {
    if (!_filters.hasActive) {
      return;
    }
    setState(() => _filters = const MediaSearchFilters());
    _runSearch(reset: true);
  }

  Future<void> _showTagSheet() async {
    final selectedTags = await showAppBottomSheet<Set<String>>(
      context: context,
      initialChildSize: 0.74,
      minChildSize: 0.38,
      maxChildSize: 1,
      builder: (context, scrollController) => _TagFilterSheet(
        selectedTags: _selectedTags,
        scrollController: scrollController,
        providerLabel: widget.aniListService.providerLabel,
      ),
    );

    if (selectedTags == null) {
      return;
    }

    setState(() {
      _filters = _filters.copyWith(
        includedTags: {...selectedTags},
        excludedTags: {..._filters.excludedTags}..removeAll(selectedTags),
      );
    });
    _runSearch(reset: true);
  }

  Future<void> _showAdvancedSearch() async {
    var genres = _genres;
    if (genres == null) {
      try {
        genres = await widget.aniListService.getGenreCollection();
      } catch (_) {
        genres = const [];
      }
      _genres = genres;
    }
    if (!mounted) {
      return;
    }

    final filters = await showAppBottomSheet<MediaSearchFilters>(
      context: context,
      initialChildSize: 0.9,
      minChildSize: 0.56,
      maxChildSize: 1,
      builder: (context, scrollController) => AdvancedSearchSheet(
        filters: _filters,
        isAnime: _contentType == AppMediaType.anime,
        genres: genres!,
        tags: _allSearchTags,
        scrollController: scrollController,
      ),
    );
    if (filters == null || !mounted) {
      return;
    }
    setState(() => _filters = filters);
    _runSearch(reset: true);
  }

  String get _searchHint => switch (_contentType) {
    AppMediaType.anime => 'Search anime',
    AppMediaType.manga => 'Search manga',
  };

  IconData get _emptyIcon => switch (_contentType) {
    AppMediaType.anime => Icons.manage_search,
    AppMediaType.manga => Icons.menu_book_outlined,
  };

  String get _emptyTitle {
    if (_hasSearchInput) {
      return 'No results';
    }
    return switch (_contentType) {
      AppMediaType.anime => 'Search ${widget.aniListService.providerLabel}',
      AppMediaType.manga => 'Search manga',
    };
  }

  String get _emptyMessage {
    if (_hasSearchInput) {
      return 'Try changing the title or selected tags.';
    }
    return switch (_contentType) {
      AppMediaType.anime =>
        'Pick a title or tag and Anikin will find playable episodes through your Juro providers.',
      AppMediaType.manga =>
        'Pick a title or tag and Anikin will find readable chapters through your Juro providers.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _searchHeaderMaxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Center(
                      child: MediaTypeSelector(
                        value: _contentType,
                        onChanged: _setContentType,
                        appearance: MediaTypeSelectorAppearance.glass,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _submitSearch(),
                      decoration: InputDecoration(
                        hintText: _searchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Advanced search filters',
                              icon: Badge(
                                isLabelVisible: _filters.activeCount > 0,
                                label: Text('${_filters.activeCount}'),
                                child: const Icon(Icons.tune),
                              ),
                              onPressed: _showAdvancedSearch,
                            ),
                            if (_controller.text.isNotEmpty)
                              IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close),
                                onPressed: _clearQuery,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _SearchTagsBar(
                    selectedTags: _selectedTags,
                    filterCount: _filters.activeCount,
                    onTagToggled: _toggleTag,
                    onClearTags: _clearTags,
                    onShowAllTags: _showTagSheet,
                    onShowFilters: _showAdvancedSearch,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_contentType),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: 1),
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _items.isEmpty) {
      return AppErrorView(
        message: _error!,
        onRetry: () => _runSearch(reset: true),
      );
    }

    if (_items.isEmpty && !_isLoading) {
      return _SearchEmptyState(
        icon: _emptyIcon,
        title: _emptyTitle,
        message: _emptyMessage,
        recentSearches: _hasSearchInput ? const [] : _recentSearches,
        onRecentSearch: _useHistory,
        onRemoveRecentSearch: _removeHistory,
        onClearFilters: _filters.hasActive ? _clearFilters : null,
      );
    }

    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return AppContentConstraint(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / 150).floor().clamp(2, 8);
          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12,
              childAspectRatio: 0.52,
            ),
            itemCount: _items.length + (_isLoading ? 1 : 0),
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
      ),
    );
  }
}

class _SearchTagsBar extends StatelessWidget {
  const _SearchTagsBar({
    required this.selectedTags,
    required this.filterCount,
    required this.onTagToggled,
    required this.onClearTags,
    required this.onShowAllTags,
    required this.onShowFilters,
  });

  final Set<String> selectedTags;
  final int filterCount;
  final ValueChanged<String> onTagToggled;
  final VoidCallback onClearTags;
  final VoidCallback onShowAllTags;
  final VoidCallback onShowFilters;

  @override
  Widget build(BuildContext context) {
    final visibleTags = [
      ...selectedTags.toList()..sort(),
      for (final tag in _featuredSearchTags)
        if (!selectedTags.contains(tag)) tag,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedTags.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClearTags,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Clear'),
              ),
            ),
            const SizedBox(height: 4),
          ],
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visibleTags.length + 2,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == visibleTags.length) {
                  return ActionChip(
                    avatar: const Icon(Icons.tune, size: 18),
                    label: const Text('All tags'),
                    onPressed: onShowAllTags,
                  );
                }
                if (index == visibleTags.length + 1) {
                  return ActionChip(
                    avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                    label: Text(
                      filterCount == 0 ? 'Filters' : 'Filters ($filterCount)',
                    ),
                    onPressed: onShowFilters,
                  );
                }

                final tag = visibleTags[index];
                return FilterChip(
                  selected: selectedTags.contains(tag),
                  label: Text(tag),
                  onSelected: (_) => onTagToggled(tag),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.recentSearches,
    required this.onRecentSearch,
    required this.onRemoveRecentSearch,
    this.onClearFilters,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<String> recentSearches;
  final ValueChanged<String> onRecentSearch;
  final Future<void> Function(String) onRemoveRecentSearch;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
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
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (recentSearches.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                'Recent searches',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final query in recentSearches)
                    InputChip(
                      avatar: const Icon(Icons.history, size: 17),
                      label: Text(query),
                      onPressed: () => onRecentSearch(query),
                      onDeleted: () => onRemoveRecentSearch(query),
                    ),
                ],
              ),
            ],
            if (onClearFilters != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagFilterSheet extends StatefulWidget {
  const _TagFilterSheet({
    required this.selectedTags,
    required this.scrollController,
    required this.providerLabel,
  });

  final Set<String> selectedTags;
  final ScrollController scrollController;
  final String providerLabel;

  @override
  State<_TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends State<_TagFilterSheet> {
  late final Set<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _selectedTags = {...widget.selectedTags};
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search tags',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Tags are applied to ${widget.providerLabel} search results when supported.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _allSearchTags)
                      FilterChip(
                        selected: _selectedTags.contains(tag),
                        label: Text(tag),
                        onSelected: (_) {
                          setState(() {
                            if (!_selectedTags.remove(tag)) {
                              _selectedTags.add(tag);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            AppSheetActionBar(
              showDivider: false,
              minimum: EdgeInsets.zero,
              children: [
                TextButton(
                  onPressed: _selectedTags.isEmpty
                      ? null
                      : () => setState(_selectedTags.clear),
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selectedTags),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
