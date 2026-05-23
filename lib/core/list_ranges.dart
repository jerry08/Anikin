class ListRange {
  const ListRange({
    required this.startIndex,
    required this.endIndex,
    required this.label,
  });

  final int startIndex;
  final int endIndex;
  final String label;
}

int listRangeSize(int total) {
  final divisions = total / 10;
  if (divisions < 25) {
    return 25;
  }
  if (divisions < 50) {
    return 50;
  }
  return 100;
}

List<ListRange> buildNumberedListRanges<T>(
  List<T> items,
  double Function(T item) numberOf,
) {
  final rangeSize = listRangeSize(items.length);
  if (items.length <= rangeSize) {
    return const [];
  }

  return [
    for (var start = 0; start < items.length; start += rangeSize)
      _buildRange(
        items,
        numberOf,
        start,
        _min(start + rangeSize, items.length),
      ),
  ];
}

List<T> applyListRange<T>(List<T> items, List<ListRange> ranges, int index) {
  if (ranges.isEmpty) {
    return items;
  }
  final range = ranges[index.clamp(0, ranges.length - 1).toInt()];
  return items.sublist(range.startIndex, range.endIndex);
}

ListRange _buildRange<T>(
  List<T> items,
  double Function(T item) numberOf,
  int start,
  int end,
) {
  final first = numberOf(items[start]);
  final last = numberOf(items[end - 1]);
  final low = first < last ? first : last;
  final high = first < last ? last : first;
  return ListRange(
    startIndex: start,
    endIndex: end,
    label: low == high
        ? _formatNumber(low)
        : '${_formatNumber(low)}-${_formatNumber(high)}',
  );
}

String _formatNumber(double value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value.toString();
}

int _min(int a, int b) => a < b ? a : b;
