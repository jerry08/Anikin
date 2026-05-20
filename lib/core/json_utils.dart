Object? readJson(Map<String, dynamic> json, String key) {
  if (json.containsKey(key)) {
    return json[key];
  }

  final pascalKey = key[0].toUpperCase() + key.substring(1);
  if (json.containsKey(pascalKey)) {
    return json[pascalKey];
  }

  final lowerKey = key[0].toLowerCase() + key.substring(1);
  if (json.containsKey(lowerKey)) {
    return json[lowerKey];
  }

  return null;
}

String? readString(Map<String, dynamic> json, String key) {
  final value = readJson(json, key);
  if (value == null) {
    return null;
  }
  return value.toString();
}

int? readInt(Map<String, dynamic> json, String key) {
  final value = readJson(json, key);
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

double? readDouble(Map<String, dynamic> json, String key) {
  final value = readJson(json, key);
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

List<String> readStringList(Object? value) {
  if (value is List) {
    return value.whereType<Object>().map((item) => item.toString()).toList();
  }
  return const [];
}

Map<String, String> readStringMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item.toString()));
  }
  return const {};
}
