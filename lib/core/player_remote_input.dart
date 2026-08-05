import 'package:flutter/services.dart';

enum PlayerRemoteCommand {
  togglePlayback,
  play,
  pause,
  seekBackward,
  seekForward,
  focusControls,
  close,
}

PlayerRemoteCommand? playerRemoteCommandForKey(
  LogicalKeyboardKey key, {
  required bool controlsHaveFocus,
}) {
  if (key == LogicalKeyboardKey.mediaPlayPause) {
    return PlayerRemoteCommand.togglePlayback;
  }
  if (key == LogicalKeyboardKey.mediaPlay) {
    return PlayerRemoteCommand.play;
  }
  if (key == LogicalKeyboardKey.mediaPause) {
    return PlayerRemoteCommand.pause;
  }
  if (key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.browserBack ||
      key == LogicalKeyboardKey.goBack) {
    return PlayerRemoteCommand.close;
  }
  if (key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown) {
    return controlsHaveFocus ? null : PlayerRemoteCommand.focusControls;
  }
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.gameButtonA ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.keyK) {
    return controlsHaveFocus ? null : PlayerRemoteCommand.togglePlayback;
  }
  if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
    return controlsHaveFocus ? null : PlayerRemoteCommand.seekBackward;
  }
  if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) {
    return controlsHaveFocus ? null : PlayerRemoteCommand.seekForward;
  }
  return null;
}
