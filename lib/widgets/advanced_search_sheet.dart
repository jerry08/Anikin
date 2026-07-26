import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/media_search_filters.dart';
import 'app_sheet_action_bar.dart';

class AdvancedSearchSheet extends StatefulWidget {
  const AdvancedSearchSheet({
    required this.filters,
    required this.isAnime,
    required this.genres,
    required this.tags,
    required this.scrollController,
    super.key,
  });

  final MediaSearchFilters filters;
  final bool isAnime;
  final List<String> genres;
  final List<String> tags;
  final ScrollController scrollController;

  @override
  State<AdvancedSearchSheet> createState() => _AdvancedSearchSheetState();
}

class _AdvancedSearchSheetState extends State<AdvancedSearchSheet> {
  late MediaSearchSort _sort;
  late String? _status;
  late String? _source;
  late String? _format;
  late String? _season;
  late String? _country;
  late final TextEditingController _yearController;
  late final Set<String> _includedGenres;
  late final Set<String> _excludedGenres;
  late final Set<String> _includedTags;
  late final Set<String> _excludedTags;

  @override
  void initState() {
    super.initState();
    final filters = widget.filters;
    _sort = filters.sort;
    _status = filters.status;
    _source = filters.source;
    _format = filters.format;
    _season = filters.season;
    _country = filters.countryOfOrigin;
    _yearController = TextEditingController(
      text: filters.seasonYear?.toString() ?? '',
    );
    _includedGenres = {...filters.includedGenres};
    _excludedGenres = {...filters.excludedGenres};
    _includedTags = {...filters.includedTags};
    _excludedTags = {...filters.excludedTags};
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _sort = MediaSearchSort.popularity;
      _status = null;
      _source = null;
      _format = null;
      _season = null;
      _country = null;
      _yearController.clear();
      _includedGenres.clear();
      _excludedGenres.clear();
      _includedTags.clear();
      _excludedTags.clear();
    });
  }

  void _apply() {
    final year = int.tryParse(_yearController.text.trim());
    Navigator.of(context).pop(
      MediaSearchFilters(
        sort: _sort,
        status: _status,
        source: _source,
        format: _format,
        season: widget.isAnime ? _season : null,
        seasonYear: year,
        countryOfOrigin: _country,
        includedGenres: {..._includedGenres},
        excludedGenres: {..._excludedGenres},
        includedTags: {..._includedTags},
        excludedTags: {..._excludedTags},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = widget.isAnime ? animeFormats : mangaFormats;
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
              'Advanced search',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap genre and tag chips to include them; tap again to exclude.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<MediaSearchSort>(
                      initialValue: _sort,
                      decoration: const InputDecoration(labelText: 'Sort by'),
                      items: [
                        for (final sort in MediaSearchSort.values)
                          DropdownMenuItem(
                            value: sort,
                            child: Text(sort.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sort = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StringFilterDropdown(
                            label: 'Status',
                            value: _status,
                            choices: mediaStatuses,
                            onChanged: (value) =>
                                setState(() => _status = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StringFilterDropdown(
                            label: 'Format',
                            value: _format,
                            choices: formats,
                            onChanged: (value) =>
                                setState(() => _format = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StringFilterDropdown(
                      label: 'Source material',
                      value: _source,
                      choices: mediaSources,
                      onChanged: (value) => setState(() => _source = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (widget.isAnime) ...[
                          Expanded(
                            child: _StringFilterDropdown(
                              label: 'Season',
                              value: _season,
                              choices: mediaSeasons,
                              onChanged: (value) =>
                                  setState(() => _season = value),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: TextField(
                            controller: _yearController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              hintText: 'Any',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StringFilterDropdown(
                            label: 'Country',
                            value: _country,
                            choices: mediaCountries,
                            onChanged: (value) =>
                                setState(() => _country = value),
                          ),
                        ),
                      ],
                    ),
                    if (widget.genres.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _FilterSectionTitle(
                        title: 'Genres',
                        included: _includedGenres.length,
                        excluded: _excludedGenres.length,
                      ),
                      const SizedBox(height: 8),
                      _TriStateFilterChips(
                        values: widget.genres,
                        included: _includedGenres,
                        excluded: _excludedGenres,
                        onChanged: () => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _FilterSectionTitle(
                      title: 'Tags',
                      included: _includedTags.length,
                      excluded: _excludedTags.length,
                    ),
                    const SizedBox(height: 8),
                    _TriStateFilterChips(
                      values: widget.tags,
                      included: _includedTags,
                      excluded: _excludedTags,
                      onChanged: () => setState(() {}),
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
                TextButton(onPressed: _clear, child: const Text('Reset')),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(onPressed: _apply, child: const Text('Apply')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StringFilterDropdown extends StatelessWidget {
  const _StringFilterDropdown({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> choices;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('Any')),
        for (final entry in choices.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: onChanged,
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({
    required this.title,
    required this.included,
    required this.excluded,
  });

  final String title;
  final int included;
  final int excluded;

  @override
  Widget build(BuildContext context) {
    final counts = [
      if (included > 0) '$included included',
      if (excluded > 0) '$excluded excluded',
    ];
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (counts.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              counts.join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TriStateFilterChips extends StatelessWidget {
  const _TriStateFilterChips({
    required this.values,
    required this.included,
    required this.excluded,
    required this.onChanged,
  });

  final List<String> values;
  final Set<String> included;
  final Set<String> excluded;
  final VoidCallback onChanged;

  void _cycle(String value) {
    if (included.remove(value)) {
      excluded.add(value);
    } else if (!excluded.remove(value)) {
      included.add(value);
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          FilterChip(
            selected: included.contains(value) || excluded.contains(value),
            selectedColor: excluded.contains(value)
                ? colors.errorContainer
                : colors.secondaryContainer,
            avatar: excluded.contains(value)
                ? const Icon(Icons.remove, size: 17)
                : included.contains(value)
                ? const Icon(Icons.add, size: 17)
                : null,
            label: Text(value),
            onSelected: (_) => _cycle(value),
          ),
      ],
    );
  }
}
