import 'package:anikin/models/juro_models.dart';
import 'package:anikin/services/subtitle_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'subtitle requests inherit source headers with track overrides',
    () async {
      final service = SubtitleService(
        client: MockClient((request) async {
          expect(request.headers['User-Agent'], 'Anikin test agent');
          expect(request.headers['Origin'], 'https://video.example');
          expect(request.headers['Referer'], 'https://subtitle.example/');
          expect(request.headers['X-Subtitle'], 'track-specific');

          return http.Response(
            'WEBVTT\n\n'
            '00:10.290 --> 00:12.200\n'
            'Captain, we should be in this fight.\n',
            200,
          );
        }),
      );

      final cues = await service.load(
        const SubtitleTrack(
          url: 'https://cdn.example/subtitles/eng.vtt',
          language: 'English',
          headers: {
            'referer': 'https://subtitle.example/',
            'X-Subtitle': 'track-specific',
          },
        ),
        inheritedHeaders: const {
          'User-Agent': 'Anikin test agent',
          'Origin': 'https://video.example',
          'Referer': 'https://video.example/',
        },
      );

      expect(cues, hasLength(1));
      expect(cues.single.start, const Duration(seconds: 10, milliseconds: 290));
      expect(cues.single.end, const Duration(seconds: 12, milliseconds: 200));
      expect(cues.single.text, 'Captain, we should be in this fight.');
    },
  );

  test('ASS subtitles retain dialogue commas and line breaks', () async {
    final service = SubtitleService(
      client: MockClient(
        (_) async => http.Response(
          '[Script Info]\n'
          'Title: Example\n\n'
          '[Events]\n'
          'Format: Layer, Start, End, Style, Name, MarginL, MarginR, '
          'MarginV, Effect, Text\n'
          r'Dialogue: 0,0:00:01.20,0:00:04.50,Default,,0,0,0,,{\an8}First line\NSecond, line'
          '\n',
          200,
        ),
      ),
    );

    final cues = await service.load(
      const SubtitleTrack(
        url: 'https://cdn.example/subtitles/eng.ass',
        language: 'English',
        kind: SubtitleKind.ass,
      ),
    );

    expect(cues, hasLength(1));
    expect(cues.single.start, const Duration(seconds: 1, milliseconds: 200));
    expect(cues.single.end, const Duration(seconds: 4, milliseconds: 500));
    expect(cues.single.text, 'First line\nSecond, line');
  });
}
