import 'package:flutter/material.dart';

import '../core/list_ranges.dart';

class ListRangeSelector extends StatelessWidget {
  const ListRangeSelector({
    required this.ranges,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<ListRange> ranges;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (ranges.isEmpty) {
      return const SizedBox.shrink();
    }

    final selected = selectedIndex.clamp(0, ranges.length - 1).toInt();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < ranges.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            ChoiceChip(
              label: Text(ranges[index].label),
              selected: index == selected,
              onSelected: (_) => onSelected(index),
            ),
          ],
        ],
      ),
    );
  }
}
