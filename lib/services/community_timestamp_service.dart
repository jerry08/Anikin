import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';

class CommunityTimestampService {
  CommunityTimestampService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<CommunitySkipInterval>> getSkipIntervals({
    required int malId,
    required double episodeNumber,
    required Duration episodeDuration,
  }) async {
    if (malId <= 0 || episodeNumber <= 0 || episodeDuration <= Duration.zero) {
      return const [];
    }
    final episode = episodeNumber == episodeNumber.roundToDouble()
        ? episodeNumber.round().toString()
        : episodeNumber.toString();
    final query = [
      'types%5B%5D=op',
      'types%5B%5D=ed',
      'types%5B%5D=recap',
      'types%5B%5D=mixed-op',
      'types%5B%5D=mixed-ed',
      'episodeLength=${episodeDuration.inSeconds}',
    ].join('&');
    final uri = Uri.parse(
      'https://api.aniskip.com/v2/skip-times/$malId/$episode?$query',
    );
    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': AppConstants.defaultUserAgent,
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.length > 1048576) {
        return const [];
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload is! Map || payload['found'] != true) return const [];
      final rawResults = payload['results'];
      if (rawResults is! List) return const [];
      final intervals = <CommunitySkipInterval>[];
      for (final raw in rawResults) {
        if (raw is! Map) continue;
        final interval = raw['interval'];
        if (interval is! Map) continue;
        final start = (interval['startTime'] as num?)?.toDouble();
        final end = (interval['endTime'] as num?)?.toDouble();
        final type = raw['skipType']?.toString() ?? '';
        if (start == null ||
            end == null ||
            !start.isFinite ||
            !end.isFinite ||
            start < 0 ||
            end <= start ||
            end > episodeDuration.inSeconds + 30) {
          continue;
        }
        intervals.add(
          CommunitySkipInterval(
            id: raw['skipId']?.toString() ?? '$type:$start:$end',
            type: type,
            start: Duration(milliseconds: (start * 1000).round()),
            end: Duration(milliseconds: (end * 1000).round()),
          ),
        );
      }
      intervals.sort((left, right) => left.start.compareTo(right.start));
      return intervals;
    } catch (_) {
      return const [];
    }
  }

  void dispose() => _client.close();
}

class CommunitySkipInterval {
  const CommunitySkipInterval({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
  });

  final String id;
  final String type;
  final Duration start;
  final Duration end;

  String get label => switch (type) {
    'op' || 'mixed-op' => 'Skip opening',
    'ed' || 'mixed-ed' => 'Skip ending',
    'recap' => 'Skip recap',
    _ => 'Skip segment',
  };

  bool contains(Duration position) => position >= start && position < end;
}
