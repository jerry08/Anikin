import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_constants.dart';
import '../core/app_theme.dart';
import '../screens/downloads_screen.dart';
import '../screens/detail_screen.dart';
import '../screens/home_screen.dart';
import '../screens/manga_detail_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../services/anilist_service.dart';
import '../services/aniyomi_extension_service.dart';
import '../services/download_service.dart';
import '../services/feature_gate_service.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../services/update_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/update_dialogs.dart';
import 'app_services.dart';

class AnikinApp extends StatefulWidget {
  const AnikinApp({
    required this.preferences,
    required this.updateService,
    this.aniListService,
    this.aniyomiExtensionService,
    this.juroService,
    this.watchHistoryService,
    this.downloadService,
    this.mangaDownloadService,
    this.trackingService,
    this.appServices,
    super.key,
  });

  AnikinApp.fromServices(AppServices services, {super.key})
    : appServices = services,
      preferences = services.preferences,
      aniListService = services.aniListService,
      aniyomiExtensionService = services.aniyomiExtensionService,
      juroService = services.juroService,
      watchHistoryService = services.watchHistoryService,
      downloadService = services.downloadService,
      mangaDownloadService = services.mangaDownloadService,
      trackingService = services.trackingService,
      updateService = services.updateService;

  final PreferencesService preferences;
  final AniListService? aniListService;
  final AniyomiExtensionService? aniyomiExtensionService;
  final JuroService? juroService;
  final WatchHistoryService? watchHistoryService;
  final DownloadService? downloadService;
  final MangaDownloadService? mangaDownloadService;
  final TrackingService? trackingService;
  final AppServices? appServices;
  final UpdateService updateService;

  @override
  State<AnikinApp> createState() => _AnikinAppState();
}

class _AnikinAppState extends State<AnikinApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AniListService _aniListService;
  late final AniyomiExtensionService _aniyomiExtensionService;
  late final JuroService _juroService;
  late final WatchHistoryService _watchHistoryService;
  late final DownloadService _downloadService;
  late final MangaDownloadService _mangaDownloadService;
  late final TrackingService _trackingService;
  late final UpdateService _updateService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trackingService = widget.trackingService ?? TrackingService();
    _aniListService =
        widget.aniListService ??
        AniListService(
          includeAdultContentResolver: () =>
              _trackingService.aniListAdultContentEnabled,
        );
    _aniyomiExtensionService =
        widget.aniyomiExtensionService ?? AniyomiExtensionService();
    _juroService =
        widget.juroService ??
        JuroService(aniyomiExtensionService: _aniyomiExtensionService);
    _watchHistoryService = widget.watchHistoryService ?? WatchHistoryService();
    _downloadService = widget.downloadService ?? DownloadService();
    _mangaDownloadService =
        widget.mangaDownloadService ??
        MangaDownloadService(juroService: _juroService);
    _updateService = widget.updateService;
    widget.appServices?.localNotificationService.addListener(
      _handleNotificationPayload,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationPayload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AnimatedBuilder(
      animation: Listenable.merge([widget.preferences, _trackingService]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
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
            key: ValueKey(_trackingService.aniListAdultContentEnabled),
            preferences: widget.preferences,
            aniListService: _aniListService,
            aniyomiExtensionService: _aniyomiExtensionService,
            juroService: _juroService,
            watchHistoryService: _watchHistoryService,
            downloadService: _downloadService,
            mangaDownloadService: _mangaDownloadService,
            trackingService: _trackingService,
            updateService: _updateService,
          ),
        );
      },
    );
    final services = widget.appServices;
    return services == null ? app : AppScope(services: services, child: app);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.appServices?.localNotificationService.removeListener(
      _handleNotificationPayload,
    );
    final services = widget.appServices;
    if (services != null) {
      unawaited(services.dispose());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final coordinator = widget.appServices?.notificationCoordinator;
      if (coordinator != null) {
        unawaited(coordinator.syncAndRefresh());
      }
    }
  }

  void _handleNotificationPayload() {
    final services = widget.appServices;
    final payload = services?.localNotificationService.takePendingPayload();
    if (services == null || payload == null) {
      return;
    }
    unawaited(_openNotificationPayload(services, payload));
  }

  Future<void> _openNotificationPayload(
    AppServices services,
    String payload,
  ) async {
    final uri = Uri.tryParse(payload);
    if (uri == null ||
        uri.scheme != 'anikin' ||
        uri.host != 'media' ||
        uri.pathSegments.length < 2) {
      return;
    }
    final mediaType = uri.pathSegments[0];
    final id = int.tryParse(uri.pathSegments[1]);
    if (id == null) return;
    try {
      final isManga = mediaType == 'manga';
      final details = await services.aniListService.getMediaDetails(
        id: id,
        mediaType: isManga ? AniListMediaType.manga : AniListMediaType.anime,
      );
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => isManga
              ? MangaDetailScreen(
                  media: details.media,
                  preferences: services.preferences,
                  juroService: services.juroService,
                  mangaDownloadService: services.mangaDownloadService,
                  trackingService: services.trackingService,
                )
              : DetailScreen(
                  media: details.media,
                  preferences: services.preferences,
                  juroService: services.juroService,
                  watchHistoryService: services.watchHistoryService,
                  downloadService: services.downloadService,
                  trackingService: services.trackingService,
                ),
        ),
      );
    } catch (_) {
      // The alert remains available in the notification inbox when offline.
    }
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    required this.preferences,
    required this.aniListService,
    required this.aniyomiExtensionService,
    required this.juroService,
    required this.watchHistoryService,
    required this.downloadService,
    required this.mangaDownloadService,
    required this.trackingService,
    required this.updateService,
    super.key,
  });

  final PreferencesService preferences;
  final AniListService aniListService;
  final AniyomiExtensionService aniyomiExtensionService;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final TrackingService trackingService;
  final UpdateService updateService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = switch (widget.preferences.appStartTab) {
      AppStartTab.home => 0,
      AppStartTab.search => 1,
      AppStartTab.library => 2,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForStartupUpdate());
    });
  }

  Future<void> _checkForStartupUpdate() async {
    if (!mounted || !widget.preferences.automaticUpdateChecks) {
      return;
    }

    try {
      final result = await widget.updateService.checkForUpdate();
      if (!mounted || !result.isUpdateAvailable) {
        return;
      }
      await showUpdateAvailableDialog(context, result);
    } catch (error) {
      debugPrint('Update check failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final useGlassNavigation =
        AppScope.maybeOf(context)?.featureGates.isEnabled(AppFeature.glassUi) ==
        true;
    final screens = [
      HomeScreen(
        preferences: widget.preferences,
        aniListService: widget.aniListService,
        juroService: widget.juroService,
        watchHistoryService: widget.watchHistoryService,
        downloadService: widget.downloadService,
        mangaDownloadService: widget.mangaDownloadService,
        trackingService: widget.trackingService,
      ),
      SearchScreen(
        preferences: widget.preferences,
        aniListService: widget.aniListService,
        juroService: widget.juroService,
        watchHistoryService: widget.watchHistoryService,
        downloadService: widget.downloadService,
        mangaDownloadService: widget.mangaDownloadService,
        trackingService: widget.trackingService,
        searchHistoryService: AppScope.maybeOf(context)?.searchHistoryService,
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
        aniyomiExtensionService: widget.aniyomiExtensionService,
        watchHistoryService: widget.watchHistoryService,
        downloadService: widget.downloadService,
        mangaDownloadService: widget.mangaDownloadService,
        trackingService: widget.trackingService,
        updateService: widget.updateService,
      ),
    ];

    final content = Stack(
      fit: StackFit.expand,
      children: [
        IndexedStack(index: _selectedIndex, children: screens),
        const _TopStatusBarShade(key: ValueKey('top-status-bar-shade')),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppLayout.wideBreakpoint;
        if (!isWide) {
          return Scaffold(
            body: content,
            bottomNavigationBar: _AppNavigationBar(
              glass: useGlassNavigation,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              _AppNavigationRail(
                glass: useGlassNavigation,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
              ),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _AppNavigationRail extends StatelessWidget {
  const _AppNavigationRail({
    required this.glass,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final bool glass;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final rail = SafeArea(
      child: NavigationRail(
        backgroundColor: glass ? Colors.transparent : null,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelType: NavigationRailLabelType.all,
        groupAlignment: -0.72,
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: Text('Home'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.search),
            label: Text('Search'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: Text('Library'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: Text('Settings'),
          ),
        ],
      ),
    );
    if (!glass) return rail;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: ColoredBox(
            color: scheme.surface.withValues(alpha: 0.78),
            child: rail,
          ),
        ),
      ),
    );
  }
}

class _AppNavigationBar extends StatelessWidget {
  const _AppNavigationBar({
    required this.glass,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final bool glass;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = [
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
  ];

  @override
  Widget build(BuildContext context) {
    final navigation = NavigationBar(
      backgroundColor: glass ? Colors.transparent : null,
      elevation: glass ? 0 : null,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: _destinations,
    );
    if (!glass) return navigation;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: ColoredBox(
            color: scheme.surface.withValues(alpha: 0.78),
            child: navigation,
          ),
        ),
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
