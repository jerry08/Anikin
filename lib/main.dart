import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'app/anikin_app.dart';
import 'core/app_theme.dart';
import 'services/download_service.dart';
import 'services/juro_service.dart';
import 'services/manga_download_service.dart';
import 'services/preferences_service.dart';
import 'services/tracking_service.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.edgeToEdgeOverlayStyle(Brightness.dark),
  );
  VideoPlayerMediaKit.ensureInitialized(windows: true, linux: true);

  final preferences = PreferencesService();
  await preferences.load();
  final downloadService = DownloadService();
  await downloadService.load();
  final juroService = JuroService();
  final mangaDownloadService = MangaDownloadService(juroService: juroService);
  await mangaDownloadService.load();
  final trackingService = TrackingService();
  await trackingService.load();

  runApp(
    AnikinApp(
      preferences: preferences,
      juroService: juroService,
      downloadService: downloadService,
      mangaDownloadService: mangaDownloadService,
      trackingService: trackingService,
    ),
  );
}
