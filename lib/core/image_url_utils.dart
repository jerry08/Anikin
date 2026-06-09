String? normalizeImageUrl(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  if (trimmed.startsWith('//')) {
    return 'https:$trimmed';
  }

  if (_anilistImageHostPattern.hasMatch(trimmed.split('/').first)) {
    return 'https://$trimmed';
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !_isHttpUri(uri)) {
    return trimmed;
  }

  final embeddedMatch = _embeddedAnilistPathPattern.firstMatch(uri.path);
  if (embeddedMatch == null) {
    return trimmed;
  }

  final host = embeddedMatch.group(1)!;
  final path = embeddedMatch.group(2)!;
  return uri.replace(scheme: 'https', host: host, path: path).toString();
}

bool _isHttpUri(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https';

final _anilistImageHostPattern = RegExp(
  r'^s\d+\.anilist\.co$',
  caseSensitive: false,
);

final _embeddedAnilistPathPattern = RegExp(
  r'^/(?:https?:/)?/?(s\d+\.anilist\.co)(/.*)$',
  caseSensitive: false,
);
