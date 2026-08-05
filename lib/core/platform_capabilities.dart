import 'package:flutter/foundation.dart';

@immutable
class PlatformCapabilities {
  const PlatformCapabilities({
    required this.platform,
    this.isWeb = false,
    this.isTelevision = false,
  });

  factory PlatformCapabilities.detect({bool isTelevision = false}) =>
      PlatformCapabilities(
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
        isTelevision: isTelevision,
      );

  final TargetPlatform platform;
  final bool isWeb;
  final bool isTelevision;

  bool get isAndroid => !isWeb && platform == TargetPlatform.android;
  bool get isAndroidTv => isAndroid && isTelevision;
  bool get isAppleMobile => !isWeb && platform == TargetPlatform.iOS;
  bool get isDesktop =>
      !isWeb &&
      (platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux ||
          platform == TargetPlatform.macOS);

  bool get supportsAniyomiExtensions => isAndroid;
  bool get supportsAndroidMedia3 => isAndroid;
  bool get supportsPictureInPicture => isAndroid;
  bool get supportsGoogleCast => isAndroid;
  bool get supportsHomeWidgets => isAndroid && !isAndroidTv;
  bool get supportsBackgroundScheduling => isAndroid;
  bool get supportsAndroidTv => isAndroidTv;
  bool get supportsLnReaderPlugins => isAndroid;
  bool get supportsLocalBookImport => !isWeb;
  bool get supportsSecureStorage => !isWeb;
}
