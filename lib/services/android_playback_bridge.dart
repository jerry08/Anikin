import 'dart:io';

import 'package:flutter/services.dart';

class AndroidPlaybackBridge {
  static const _channel = MethodChannel('com.oneb.anikin/playback');

  static Future<bool> isPictureInPictureSupported() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isPictureInPictureSupported') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> enterPictureInPicture({
    required int width,
    required int height,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('enterPictureInPicture', {
            'width': width.clamp(1, 10000),
            'height': height.clamp(1, 10000),
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
