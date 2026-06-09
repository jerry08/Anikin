import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'app/anikin_app.dart';
import 'core/app_theme.dart';
import 'services/aniyomi_extension_service.dart';
import 'services/download_service.dart';
import 'services/juro_service.dart';
import 'services/manga_download_service.dart';
import 'services/preferences_service.dart';
import 'services/tracking_service.dart';
import 'services/update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.edgeToEdgeOverlayStyle(Brightness.dark),
  );
  VideoPlayerMediaKit.ensureInitialized(windows: true, linux: true);

  final preferences = PreferencesService();
  await preferences.load();
  final downloadService = DownloadService();
  await downloadService.load();
  final aniyomiExtensionService = AniyomiExtensionService();
  final juroService = JuroService(
    aniyomiExtensionService: aniyomiExtensionService,
  );
  final mangaDownloadService = MangaDownloadService(juroService: juroService);
  await mangaDownloadService.load();
  final trackingService = TrackingService();
  await trackingService.load();
  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    AnikinApp(
      preferences: preferences,
      aniyomiExtensionService: aniyomiExtensionService,
      juroService: juroService,
      downloadService: downloadService,
      mangaDownloadService: mangaDownloadService,
      trackingService: trackingService,
      updateService: UpdateService(currentVersion: packageInfo.version),
    ),
  );
}
