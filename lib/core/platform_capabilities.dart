import 'package:flutter/foundation.dart';

@immutable
class PlatformCapabilities {
  const PlatformCapabilities({required this.platform, this.isWeb = false});

  factory PlatformCapabilities.detect() =>
      PlatformCapabilities(platform: defaultTargetPlatform, isWeb: kIsWeb);

  final TargetPlatform platform;
  final bool isWeb;

  bool get isAndroid => !isWeb && platform == TargetPlatform.android;
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
  bool get supportsHomeWidgets => isAndroid;
  bool get supportsBackgroundScheduling => isAndroid;
  bool get supportsAndroidTv => isAndroid;
  bool get supportsLnReaderPlugins => isAndroid;
  bool get supportsLocalBookImport => !isWeb;
  bool get supportsSecureStorage => !isWeb;
}
