import '../core/json_utils.dart';

/// Mirrors Aniyomi/Tachiyomi source filters (AnimeFilterList / FilterList) so a
/// generic filter sheet can render them and send selections back to the source.
enum AniyomiFilterType {
  header,
  separator,
  select,
  text,
  checkbox,
  tristate,
  group,
  sort,
  unknown,
}

class AniyomiFilter {
  AniyomiFilter({
    required this.type,
    required this.name,
    this.values = const [],
    this.state,
    this.filters = const [],
  });

  final AniyomiFilterType type;
  final String name;
  final List<String> values;

  /// select: int index, text: String, checkbox: bool, tristate: int (0/1/2),
  /// sort: `{'index': int, 'ascending': bool}`.
  Object? state;
  final List<AniyomiFilter> filters;

  bool get isDisplayOnly =>
      type == AniyomiFilterType.header ||
      type == AniyomiFilterType.separator ||
      type == AniyomiFilterType.unknown;

  factory AniyomiFilter.fromJson(Map<String, dynamic> json) {
    final rawType = readString(json, 'type') ?? '';
    final type = switch (rawType) {
      'header' => AniyomiFilterType.header,
      'separator' => AniyomiFilterType.separator,
      'select' => AniyomiFilterType.select,
      'text' => AniyomiFilterType.text,
      'checkbox' => AniyomiFilterType.checkbox,
      'tristate' => AniyomiFilterType.tristate,
      'group' => AniyomiFilterType.group,
      'sort' => AniyomiFilterType.sort,
      _ => AniyomiFilterType.unknown,
    };
    final rawChildren = readJson(json, 'filters');
    final rawValues = readJson(json, 'values');
    return AniyomiFilter(
      type: type,
      name: readString(json, 'name') ?? '',
      values: rawValues is List
          ? rawValues.map((value) => value.toString()).toList()
          : const [],
      state: switch (type) {
        AniyomiFilterType.sort => readJson(json, 'state') is Map
            ? {
                'index':
                    readInt(
                      (readJson(json, 'state') as Map).map(
                        (key, value) => MapEntry(key.toString(), value),
                      ),
                      'index',
                    ) ??
                    0,
                'ascending':
                    (readJson(json, 'state') as Map)['ascending'] == true,
              }
            : null,
        _ => json['state'],
      },
      filters: rawChildren is List
          ? rawChildren
                .whereType<Map>()
                .map(
                  (item) => AniyomiFilter.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

/// A single filter value change, addressed by its position in the filter list
/// (group children use a two-element path: [groupIndex, childIndex]).
class AniyomiFilterSelection {
  const AniyomiFilterSelection({required this.path, required this.state});

  final List<int> path;
  final Object? state;

  Map<String, Object?> toJson() => {'path': path, 'state': state};
}

/// Collects the non-default states of [filters] into channel-ready selections.
List<AniyomiFilterSelection> collectFilterSelections(
  List<AniyomiFilter> filters, [
  List<int> prefix = const [],
]) {
  final selections = <AniyomiFilterSelection>[];
  for (var index = 0; index < filters.length; index++) {
    final filter = filters[index];
    final path = [...prefix, index];
    switch (filter.type) {
      case AniyomiFilterType.group:
        selections.addAll(collectFilterSelections(filter.filters, path));
      case AniyomiFilterType.select:
      case AniyomiFilterType.text:
      case AniyomiFilterType.checkbox:
      case AniyomiFilterType.tristate:
      case AniyomiFilterType.sort:
        if (filter.state != null) {
          selections.add(AniyomiFilterSelection(path: path, state: filter.state));
        }
      case AniyomiFilterType.header:
      case AniyomiFilterType.separator:
      case AniyomiFilterType.unknown:
        break;
    }
  }
  return selections;
}
