import 'dart:io';

import 'package:flutter/services.dart';

class WindowService {
  const WindowService._();

  static const _channel = MethodChannel('anikin/window');

  static Future<void> toggleFullscreen() async {
    if (!_isDesktop) {
      return;
    }
    await _invoke('toggleFullscreen');
  }

  static Future<void> setFullscreen(bool fullscreen) async {
    if (!_isDesktop) {
      return;
    }
    await _invoke('setFullscreen', fullscreen);
  }

  static Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Non-Windows desktop targets can keep using Flutter's immersive chrome.
    } on PlatformException {
      // Window shortcuts should not interrupt playback if the host rejects them.
    }
  }

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}
