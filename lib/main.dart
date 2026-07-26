import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'app/app_services.dart';
import 'app/anikin_app.dart';
import 'core/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.edgeToEdgeOverlayStyle(Brightness.dark),
  );
  VideoPlayerMediaKit.ensureInitialized(windows: true, linux: true);

  final services = await AppServices.bootstrap();
  runApp(AnikinApp.fromServices(services));
}
