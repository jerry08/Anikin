String stripHtml(String? html) {
  if (html == null || html.isEmpty) {
    return '';
  }

  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String compactNumber(num? value) {
  if (value == null) {
    return '--';
  }
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toStringAsFixed(0);
}

String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 999999);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Formats AniList enum values ("RELEASING", "TV_SHORT", "NOT_YET_RELEASED")
/// as readable labels ("Releasing", "TV Short", "Not Yet Released").
String? mediaEnumLabel(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  const acronyms = {'TV', 'OVA', 'ONA'};
  return value
      .trim()
      .split(RegExp(r'[_\s]+'))
      .map((word) {
        final upper = word.toUpperCase();
        if (acronyms.contains(upper)) {
          return upper;
        }
        if (word.isEmpty) {
          return word;
        }
        return upper[0] + word.substring(1).toLowerCase();
      })
      .join(' ');
}

String? firstNonBlank(Iterable<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

String _normalizeForMatch(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Normalized Levenshtein similarity in [0, 1]; 1 means identical titles.
double titleSimilarity(String a, String b) {
  final left = _normalizeForMatch(a);
  final right = _normalizeForMatch(b);
  if (left.isEmpty || right.isEmpty) {
    return left == right ? 1 : 0;
  }
  if (left == right) {
    return 1;
  }
  var previous = List<int>.generate(right.length + 1, (index) => index);
  var current = List<int>.filled(right.length + 1, 0);
  for (var i = 1; i <= left.length; i++) {
    current[0] = i;
    for (var j = 1; j <= right.length; j++) {
      final substitution =
          previous[j - 1] +
          (left.codeUnitAt(i - 1) == right.codeUnitAt(j - 1) ? 0 : 1);
      final insertion = current[j - 1] + 1;
      final deletion = previous[j] + 1;
      current[j] = [
        substitution,
        insertion,
        deletion,
      ].reduce((a, b) => a < b ? a : b);
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  final distance = previous[right.length];
  final longest = left.length > right.length ? left.length : right.length;
  return 1 - distance / longest;
}

/// Picks the item whose title is closest to any of [candidates], mirroring
/// Dantotsu's closest-string matching instead of trusting result order.
T? bestTitleMatch<T>(
  List<T> items,
  Iterable<String> candidates,
  String Function(T item) titleOf,
) {
  T? best;
  var bestScore = -1.0;
  for (final item in items) {
    final title = titleOf(item);
    for (final candidate in candidates) {
      final score = titleSimilarity(title, candidate);
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
  }
  return best;
}
