import 'dart:io';

import 'package:video_player/video_player.dart';

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

  VideoPlayerController fromFile(File file) {
    return VideoPlayerController.file(file);
  }

  VideoPlayerController fromNetwork(
    Uri uri, {
    Map<String, String> httpHeaders = const {},
  }) {
    return VideoPlayerController.networkUrl(uri, httpHeaders: httpHeaders);
  }
}
