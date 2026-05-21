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
import '../widgets/app_error_view.dart';
import '../widgets/media_poster_card.dart';
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
  final AniListService aniListService;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final TrackingService trackingService;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _SearchContentType { anime, manga }

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

  _SearchContentType _contentType = _SearchContentType.anime;
  Timer? _debounce;
  int _page = 1;
  int _searchGeneration = 0;
  bool _isLoading = false;
  bool _canLoadMore = false;
  String? _error;

  bool get _hasSearchInput =>
      _controller.text.trim().isNotEmpty || _selectedTags.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _runSearch(reset: true),
    );
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
        case _SearchContentType.anime:
          result = await widget.aniListService.searchMedia(
            query: query,
            page: requestPage,
            tags: tags,
            includeNonJapanese: includeNonJapanese,
          );
        case _SearchContentType.manga:
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
      case _SearchContentType.anime:
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
      case _SearchContentType.manga:
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

  void _setContentType(_SearchContentType contentType) {
    if (_contentType == contentType) {
      return;
    }

    setState(() {
      _contentType = contentType;
      _page = 1;
      _items.clear();
      _canLoadMore = false;
      _error = null;
    });

    if (_hasSearchInput) {
      _runSearch(reset: true);
    }
  }

  bool _includeNonJapaneseResults(String query) {
    if (query.isNotEmpty) {
      return true;
    }

    return switch (_contentType) {
      _SearchContentType.anime => widget.preferences.showNonJapaneseAnime,
      _SearchContentType.manga => widget.preferences.showNonJapaneseManga,
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
    final selectedTags = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _TagFilterSheet(selectedTags: _selectedTags),
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
    _SearchContentType.anime => 'Search anime',
    _SearchContentType.manga => 'Search manga',
  };

  IconData get _emptyIcon => switch (_contentType) {
    _SearchContentType.anime => Icons.manage_search,
    _SearchContentType.manga => Icons.menu_book_outlined,
  };

  String get _emptyTitle {
    if (_hasSearchInput) {
      return 'No results';
    }
    return switch (_contentType) {
      _SearchContentType.anime => 'Search AniList',
      _SearchContentType.manga => 'Search manga',
    };
  }

  String get _emptyMessage {
    if (_hasSearchInput) {
      return 'Try changing the title or selected tags.';
    }
    return switch (_contentType) {
      _SearchContentType.anime =>
        'Pick a title or tag and Anikin will find playable episodes through your Juro providers.',
      _SearchContentType.manga =>
        'Pick a title or tag and Anikin will find readable chapters through your Juro providers.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_SearchContentType>(
                selected: {_contentType},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    _setContentType(selection.single),
                segments: const [
                  ButtonSegment(
                    value: _SearchContentType.anime,
                    icon: Icon(Icons.live_tv_outlined),
                    label: Text('Anime'),
                  ),
                  ButtonSegment(
                    value: _SearchContentType.manga,
                    icon: Icon(Icons.menu_book_outlined),
                    label: Text('Manga'),
                  ),
                ],
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
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _runSearch(reset: true),
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
          Expanded(child: _buildBody()),
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
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
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
  const _TagFilterSheet({required this.selectedTags});

  final Set<String> selectedTags;

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
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Search tags',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Tags are applied to AniList search results.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
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
      ),
    );
  }
}
