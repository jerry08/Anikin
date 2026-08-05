import 'package:anikin/core/player_remote_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps Android TV transport and D-pad keys', () {
    PlayerRemoteCommand? command(LogicalKeyboardKey key) =>
        playerRemoteCommandForKey(key, controlsHaveFocus: false);

    expect(
      command(LogicalKeyboardKey.select),
      PlayerRemoteCommand.togglePlayback,
    );
    expect(
      command(LogicalKeyboardKey.mediaPlayPause),
      PlayerRemoteCommand.togglePlayback,
    );
    expect(command(LogicalKeyboardKey.mediaPlay), PlayerRemoteCommand.play);
    expect(command(LogicalKeyboardKey.mediaPause), PlayerRemoteCommand.pause);
    expect(
      command(LogicalKeyboardKey.arrowLeft),
      PlayerRemoteCommand.seekBackward,
    );
    expect(
      command(LogicalKeyboardKey.arrowRight),
      PlayerRemoteCommand.seekForward,
    );
    expect(
      command(LogicalKeyboardKey.arrowDown),
      PlayerRemoteCommand.focusControls,
    );
    expect(command(LogicalKeyboardKey.browserBack), PlayerRemoteCommand.close);
  });

  test('leaves D-pad navigation to focused player controls', () {
    PlayerRemoteCommand? command(LogicalKeyboardKey key) =>
        playerRemoteCommandForKey(key, controlsHaveFocus: true);

    expect(command(LogicalKeyboardKey.select), isNull);
    expect(command(LogicalKeyboardKey.enter), isNull);
    expect(command(LogicalKeyboardKey.arrowLeft), isNull);
    expect(command(LogicalKeyboardKey.arrowRight), isNull);
    expect(command(LogicalKeyboardKey.arrowUp), isNull);
    expect(
      command(LogicalKeyboardKey.mediaPlayPause),
      PlayerRemoteCommand.togglePlayback,
    );
    expect(command(LogicalKeyboardKey.goBack), PlayerRemoteCommand.close);
  });
}
