import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceFormFactorService {
  const DeviceFormFactorService({
    MethodChannel channel = const MethodChannel(_channelName),
  }) : _channel = channel;

  static const _channelName = 'com.oneb.anikin/device';

  final MethodChannel _channel;

  Future<bool> isTelevision() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
