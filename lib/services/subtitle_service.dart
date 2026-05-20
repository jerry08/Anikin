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

  Future<List<SubtitleCue>> load(SubtitleTrack track) async {
    if (track.kind == SubtitleKind.ass) {
      return const [];
    }

    final response = await _client.get(
      Uri.parse(track.url),
      headers: track.headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    return _parse(text);
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
      final end = _parseTimestamp(parts[1].split(RegExp(r'\s+')).first);
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
