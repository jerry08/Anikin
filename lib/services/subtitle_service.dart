import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/juro_models.dart';

class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;

  bool contains(Duration position) => position >= start && position <= end;
}

class SubtitleService {
  SubtitleService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<SubtitleCue>> load(
    SubtitleTrack track, {
    Map<String, String> inheritedHeaders = const {},
  }) async {
    final response = await _client.get(
      Uri.parse(track.url),
      headers: _mergeHeaders(inheritedHeaders, track.headers),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    return track.kind == SubtitleKind.ass ? _parseAss(text) : _parse(text);
  }

  static Map<String, String> _mergeHeaders(
    Map<String, String> inherited,
    Map<String, String> overrides,
  ) {
    final overriddenNames = overrides.keys
        .map((key) => key.toLowerCase())
        .toSet();
    return {
      for (final entry in inherited.entries)
        if (!overriddenNames.contains(entry.key.toLowerCase()))
          entry.key: entry.value,
      ...overrides,
    };
  }

  static String? textAt(List<SubtitleCue> cues, Duration position) {
    for (final cue in cues) {
      if (cue.contains(position)) {
        return cue.text;
      }
    }
    return null;
  }

  static List<SubtitleCue> _parse(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    final cues = <SubtitleCue>[];

    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && line != 'WEBVTT')
          .toList();
      if (lines.isEmpty) {
        continue;
      }

      final timingIndex = lines.indexWhere((line) => line.contains('-->'));
      if (timingIndex < 0) {
        continue;
      }

      final parts = lines[timingIndex].split('-->');
      if (parts.length < 2) {
        continue;
      }

      final start = _parseTimestamp(parts[0]);
      final end = _parseTimestamp(parts[1].trim().split(RegExp(r'\s+')).first);
      if (start == null || end == null || end <= start) {
        continue;
      }

      final text = lines
          .skip(timingIndex + 1)
          .join('\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .trim();
      if (text.isEmpty) {
        continue;
      }

      cues.add(SubtitleCue(start: start, end: end, text: text));
    }

    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  static List<SubtitleCue> _parseAss(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final cues = <SubtitleCue>[];
    var inEvents = false;
    var fields = const <String>[];

    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('[') && line.endsWith(']')) {
        inEvents = line.toLowerCase() == '[events]';
        continue;
      }
      if (!inEvents) {
        continue;
      }

      final separator = line.indexOf(':');
      if (separator < 0) {
        continue;
      }
      final key = line.substring(0, separator).trim().toLowerCase();
      final value = line.substring(separator + 1).trimLeft();
      if (key == 'format') {
        fields = value
            .split(',')
            .map((field) => field.trim().toLowerCase())
            .toList();
        continue;
      }
      if (key != 'dialogue' || fields.isEmpty) {
        continue;
      }

      final startIndex = fields.indexOf('start');
      final endIndex = fields.indexOf('end');
      final textIndex = fields.indexOf('text');
      if (startIndex < 0 || endIndex < 0 || textIndex < 0) {
        continue;
      }

      final values = _splitAssFields(value, fields.length);
      if (values.length != fields.length) {
        continue;
      }
      final start = _parseTimestamp(values[startIndex]);
      final end = _parseTimestamp(values[endIndex]);
      if (start == null || end == null || end <= start) {
        continue;
      }

      final text = values[textIndex]
          .replaceAll(RegExp(r'\{[^}]*\}'), '')
          .replaceAll(r'\N', '\n')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\h', ' ')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .trim();
      if (text.isEmpty) {
        continue;
      }
      cues.add(SubtitleCue(start: start, end: end, text: text));
    }

    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  static List<String> _splitAssFields(String value, int fieldCount) {
    final fields = <String>[];
    var remainder = value;
    for (var index = 1; index < fieldCount; index++) {
      final separator = remainder.indexOf(',');
      if (separator < 0) {
        return const [];
      }
      fields.add(remainder.substring(0, separator));
      remainder = remainder.substring(separator + 1);
    }
    fields.add(remainder);
    return fields;
  }

  static Duration? _parseTimestamp(String raw) {
    final value = raw.trim().replaceAll(',', '.');
    final segments = value.split(':');
    if (segments.length < 2 || segments.length > 3) {
      return null;
    }

    final secondsParts = segments.last.split('.');
    final seconds = int.tryParse(secondsParts.first);
    final milliseconds = secondsParts.length > 1
        ? int.tryParse(secondsParts[1].padRight(3, '0').substring(0, 3))
        : 0;
    final minutes = int.tryParse(segments[segments.length - 2]);
    final hours = segments.length == 3 ? int.tryParse(segments.first) : 0;

    if (seconds == null ||
        milliseconds == null ||
        minutes == null ||
        hours == null) {
      return null;
    }

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }
}
