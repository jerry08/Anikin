import 'dart:io';

import 'package:video_player/video_player.dart' as player;

import '../models/juro_models.dart' show VideoFormat;

enum PlaybackBackend {
  androidMedia3('Android Media3'),
  appleAvFoundation('AVFoundation'),
  desktopMediaKit('MediaKit'),
  platformDefault('Platform player');

  const PlaybackBackend(this.label);

  final String label;
}

class PlaybackControllerFactory {
  const PlaybackControllerFactory();

  PlaybackBackend get backend {
    if (Platform.isAndroid) {
      return PlaybackBackend.androidMedia3;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return PlaybackBackend.appleAvFoundation;
    }
    if (Platform.isWindows || Platform.isLinux) {
      return PlaybackBackend.desktopMediaKit;
    }
    return PlaybackBackend.platformDefault;
  }

  player.VideoPlayerController fromFile(File file) {
    return player.VideoPlayerController.file(file);
  }

  player.VideoPlayerController fromNetwork(
    Uri uri, {
    Map<String, String> httpHeaders = const {},
    VideoFormat? formatHint,
  }) {
    return player.VideoPlayerController.networkUrl(
      uri,
      httpHeaders: httpHeaders,
      formatHint: switch (formatHint) {
        VideoFormat.hls || VideoFormat.m3u8 => player.VideoFormat.hls,
        VideoFormat.dash => player.VideoFormat.dash,
        VideoFormat.container || null => null,
      },
    );
  }
}
