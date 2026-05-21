import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_constants.dart';
import '../core/app_theme.dart';
import '../screens/downloads_screen.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../services/anilist_service.dart';
import '../services/download_service.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../services/watch_history_service.dart';

class AnikinApp extends StatefulWidget {
  const AnikinApp({
    required this.preferences,
    this.aniListService,
    this.juroService,
    this.watchHistoryService,
    this.downloadService,
    this.mangaDownloadService,
    this.trackingService,
    super.key,
  });

  final PreferencesService preferences;
  final AniListService? aniListService;
  final JuroService? juroService;
  final WatchHistoryService? watchHistoryService;
  final DownloadService? downloadService;
  final MangaDownloadService? mangaDownloadService;
  final TrackingService? trackingService;

  @override
  State<AnikinApp> createState() => _AnikinAppState();
}

class _AnikinAppState extends State<AnikinApp> {
  late final AniListService _aniListService;
  late final JuroService _juroService;
  late final WatchHistoryService _watchHistoryService;
  late final DownloadService _downloadService;
  late final MangaDownloadService _mangaDownloadService;
  late final TrackingService _trackingService;

  @override
  void initState() {
    super.initState();
    _aniListService = widget.aniListService ?? AniListService();
    _juroService = widget.juroService ?? JuroService();
    _watchHistoryService = widget.watchHistoryService ?? WatchHistoryService();
    _downloadService = widget.downloadService ?? DownloadService();
    _mangaDownloadService =
        widget.mangaDownloadService ??
        MangaDownloadService(juroService: _juroService);
    _trackingService = widget.trackingService ?? TrackingService();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.preferences,
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(widget.preferences.themeColorPalette),
          darkTheme: AppTheme.dark(widget.preferences.themeColorPalette),
          themeMode: widget.preferences.themeMode,
          builder: (context, child) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppTheme.edgeToEdgeOverlayStyle(
                Theme.of(context).brightness,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: MainShell(
            preferences: widget.preferences,
            aniListService: _aniListService,
            juroService: _juroService,
            watchHistoryService: _watchHistoryService,
            downloadService: _downloadService,
            mangaDownloadService: _mangaDownloadService,
            trackingService: _trackingService,
          ),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    required this.preferences,
    required this.aniListService,
    required this.juroService,
    required this.watchHistoryService,
    required this.downloadService,
    required this.mangaDownloadService,
    required this.trackingService,
    super.key,
  });

  final PreferencesService preferences;
  final AniListService aniListService;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final TrackingService trackingService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        preferences: widget.preferences,
        aniListService: widget.aniListService,
        juroService: widget.juroService,
        watchHistoryService: widget.watchHistoryService,
        downloadService: widget.downloadService,
        mangaDownloadService: widget.mangaDownloadService,
        trackingService: widget.trackingService,
        onSearchRequested: () => setState(() => _selectedIndex = 1),
        onSettingsRequested: () => setState(() => _selectedIndex = 3),
      ),
      SearchScreen(
        preferences: widget.preferences,
        aniListService: widget.aniListService,
        juroService: widget.juroService,
        watchHistoryService: widget.watchHistoryService,
        downloadService: widget.downloadService,
        mangaDownloadService: widget.mangaDownloadService,
        trackingService: widget.trackingService,
      ),
      LibraryScreen(
        downloadService: widget.downloadService,
        mangaDownloadService: widget.mangaDownloadService,
        preferences: widget.preferences,
        juroService: widget.juroService,
        watchHistoryService: widget.watchHistoryService,
        trackingService: widget.trackingService,
      ),
      SettingsScreen(
        preferences: widget.preferences,
        juroService: widget.juroService,
        trackingService: widget.trackingService,
      ),
    ];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(index: _selectedIndex, children: screens),
          const _TopStatusBarShade(key: ValueKey('top-status-bar-shade')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _TopStatusBarShade extends StatelessWidget {
  const _TopStatusBarShade({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    if (topInset <= 0) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topColor = isDark ? const Color(0x8A000000) : const Color(0xB3FFFFFF);
    final bottomColor = isDark
        ? const Color(0x00000000)
        : const Color(0x00FFFFFF);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: topInset + 8,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topColor, bottomColor],
            ),
          ),
        ),
      ),
    );
  }
}
