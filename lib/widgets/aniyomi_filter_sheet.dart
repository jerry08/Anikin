import 'package:flutter/material.dart';

import '../models/aniyomi_filters.dart';

/// Result of the filter sheet: `apply` re-runs the search with the current
/// filter states, `reset` asks the caller to reload default filters.
enum AniyomiFilterSheetAction { apply, reset }

Future<AniyomiFilterSheetAction?> showAniyomiFilterSheet(
  BuildContext context,
  List<AniyomiFilter> filters,
) {
  return showModalBottomSheet<AniyomiFilterSheetAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) =>
          _AniyomiFilterSheet(filters: filters, scrollController: controller),
    ),
  );
}

class _AniyomiFilterSheet extends StatefulWidget {
  const _AniyomiFilterSheet({
    required this.filters,
    required this.scrollController,
  });

  final List<AniyomiFilter> filters;
  final ScrollController scrollController;

  @override
  State<_AniyomiFilterSheet> createState() => _AniyomiFilterSheetState();
}

class _AniyomiFilterSheetState extends State<_AniyomiFilterSheet> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(AniyomiFilterSheetAction.reset),
                child: const Text('Reset'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(AniyomiFilterSheetAction.apply),
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            children: [
              for (final filter in widget.filters)
                _buildFilter(context, filter),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilter(BuildContext context, AniyomiFilter filter) {
    switch (filter.type) {
      case AniyomiFilterType.header:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            filter.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case AniyomiFilterType.separator:
        return const Divider();
      case AniyomiFilterType.checkbox:
        return CheckboxListTile(
          dense: true,
          title: Text(filter.name),
          value: filter.state == true,
          onChanged: (value) => setState(() => filter.state = value ?? false),
        );
      case AniyomiFilterType.tristate:
        final state = filter.state is int ? filter.state as int : 0;
        return CheckboxListTile(
          dense: true,
          tristate: true,
          title: Text(filter.name),
          // 0 = ignore (empty box), 1 = include (check), 2 = exclude (dash)
          value: switch (state) {
            1 => true,
            2 => null,
            _ => false,
          },
          activeColor: state == 2 ? Theme.of(context).colorScheme.error : null,
          onChanged: (_) => setState(() {
            filter.state = (state + 1) % 3;
          }),
        );
      case AniyomiFilterType.select:
        final selected = filter.state is int ? filter.state as int : 0;
        return ListTile(
          dense: true,
          title: Text(filter.name),
          trailing: DropdownButton<int>(
            value: selected >= 0 && selected < filter.values.length
                ? selected
                : 0,
            underline: const SizedBox.shrink(),
            items: [
              for (var index = 0; index < filter.values.length; index++)
                DropdownMenuItem(
                  value: index,
                  child: Text(
                    filter.values[index],
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) =>
                setState(() => filter.state = value ?? selected),
          ),
        );
      case AniyomiFilterType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextFormField(
            initialValue: filter.state?.toString() ?? '',
            decoration: InputDecoration(
              labelText: filter.name,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => filter.state = value,
          ),
        );
      case AniyomiFilterType.sort:
        final state = filter.state is Map ? filter.state as Map : null;
        final selectedIndex = state?['index'] is int
            ? state!['index'] as int
            : -1;
        final ascending = state?['ascending'] == true;
        return ExpansionTile(
          dense: true,
          title: Text(filter.name),
          children: [
            for (var index = 0; index < filter.values.length; index++)
              ListTile(
                dense: true,
                leading: index == selectedIndex
                    ? Icon(
                        ascending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : const SizedBox(width: 18),
                title: Text(filter.values[index]),
                onTap: () => setState(() {
                  filter.state = {
                    'index': index,
                    'ascending': index == selectedIndex && !ascending,
                  };
                }),
              ),
          ],
        );
      case AniyomiFilterType.group:
        return ExpansionTile(
          dense: true,
          title: Text(filter.name),
          children: [
            for (final child in filter.filters) _buildFilter(context, child),
          ],
        );
      case AniyomiFilterType.unknown:
        return const SizedBox.shrink();
    }
  }
}
