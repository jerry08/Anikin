import 'dart:async';

import 'package:flutter/material.dart';

import '../models/anilist_media.dart';
import '../services/anilist_service.dart';
import '../services/download_service.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_error_view.dart';
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
  final _selectedTags = <String>{};

  late AppMediaType _contentType;
  Timer? _debounce;
  int _page = 1;
  int _searchGeneration = 0;
  bool _isLoading = false;
  bool _canLoadMore = false;
  String? _error;
  late String _catalogProviderKey;

  bool get _hasSearchInput =>
      _controller.text.trim().isNotEmpty || _selectedTags.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _contentType = widget.preferences.appMediaType;
    _catalogProviderKey = widget.trackingService.primaryProvider.key;
    widget.preferences.addListener(_handleMediaTypeChanged);
    widget.trackingService.addListener(_handleCatalogProviderChanged);
    _scrollController.addListener(_onScroll);
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
      _searchGeneration++;
      _page = 1;
      _items.clear();
      _canLoadMore = false;
      _error = null;
      _isLoading = false;
    });

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
    final tags = _selectedTags.toList(growable: false)..sort();
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
            tags: tags,
            includeNonJapanese: includeNonJapanese,
          );
        case AppMediaType.manga:
          result = await widget.aniListService.searchManga(
            query: query,
            page: requestPage,
            tags: tags,
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
    if (query.isNotEmpty) {
      return true;
    }

    return switch (_contentType) {
      AppMediaType.anime => widget.preferences.showNonJapaneseAnime,
      AppMediaType.manga => widget.preferences.showNonJapaneseManga,
    };
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.remove(tag)) {
        _selectedTags.add(tag);
      }
    });
    _runSearch(reset: true);
  }

  void _clearTags() {
    if (_selectedTags.isEmpty) {
      return;
    }

    setState(_selectedTags.clear);
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
      _selectedTags
        ..clear()
        ..addAll(selectedTags);
    });
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
                      ),
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
                        hintText: _searchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close),
                                onPressed: _clearQuery,
                              ),
                      ),
                    ),
                  ),
                  _SearchTagsBar(
                    selectedTags: _selectedTags,
                    onTagToggled: _toggleTag,
                    onClearTags: _clearTags,
                    onShowAllTags: _showTagSheet,
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
        onClearTags: _selectedTags.isEmpty ? null : _clearTags,
      );
    }

    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 150).floor().clamp(2, 6);
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
    );
  }
}

class _SearchTagsBar extends StatelessWidget {
  const _SearchTagsBar({
    required this.selectedTags,
    required this.onTagToggled,
    required this.onClearTags,
    required this.onShowAllTags,
  });

  final Set<String> selectedTags;
  final ValueChanged<String> onTagToggled;
  final VoidCallback onClearTags;
  final VoidCallback onShowAllTags;

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
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              itemCount: visibleTags.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == visibleTags.length) {
                  return ActionChip(
                    avatar: const Icon(Icons.tune, size: 18),
                    label: const Text('All tags'),
                    onPressed: onShowAllTags,
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
    this.onClearTags,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onClearTags;

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
            if (onClearTags != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onClearTags,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear tags'),
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
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
            Row(
              children: [
                TextButton(
                  onPressed: _selectedTags.isEmpty
                      ? null
                      : () => setState(_selectedTags.clear),
                  child: const Text('Clear'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
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
