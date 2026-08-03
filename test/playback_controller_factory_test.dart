import 'package:anikin/models/juro_models.dart' as model;
import 'package:anikin/services/playback_controller_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart' as player;

void main() {
  test('adaptive stream formats are forwarded as player hints', () {
    const factory = PlaybackControllerFactory();
    final uri = Uri.parse('http://localhost:1234/m3u8?url=stream');

    final hls = factory.fromNetwork(uri, formatHint: model.VideoFormat.hls);
    final m3u8 = factory.fromNetwork(uri, formatHint: model.VideoFormat.m3u8);
    final dash = factory.fromNetwork(uri, formatHint: model.VideoFormat.dash);
    final container = factory.fromNetwork(
      uri,
      formatHint: model.VideoFormat.container,
    );

    expect(hls.formatHint, player.VideoFormat.hls);
    expect(m3u8.formatHint, player.VideoFormat.hls);
    expect(dash.formatHint, player.VideoFormat.dash);
    expect(container.formatHint, isNull);
  });
}
