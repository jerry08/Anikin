import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/platform_capabilities.dart';
import '../data/app_database.dart';
import '../services/anilist_service.dart';
import '../services/aniyomi_extension_service.dart';
import '../services/backup_service.dart';
import '../services/credential_vault.dart';
import '../services/catalog_cache_service.dart';
import '../services/download_service.dart';
import '../services/feature_gate_service.dart';
import '../services/home_widget_service.dart';
import '../services/juro_service.dart';
import '../services/local_notification_service.dart';
import '../services/lnreader_plugin_service.dart';
import '../services/manga_download_service.dart';
import '../services/notification_coordinator.dart';
import '../services/notification_refresh_service.dart';
import '../services/notification_subscription_service.dart';
import '../services/novel_library_service.dart';
import '../services/preferences_service.dart';
import '../services/search_history_service.dart';
import '../services/source_health_service.dart';
import '../services/tracking_service.dart';
import '../services/update_service.dart';
import '../services/watch_history_service.dart';
import '../services/watch_order_service.dart';

class AppServices {
  AppServices({
    required this.preferences,
    required this.database,
    required this.credentialVault,
    required this.capabilities,
    required this.featureGates,
    required this.aniListService,
    required this.backupService,
    required this.catalogCacheService,
    required this.aniyomiExtensionService,
    required this.juroService,
    required this.homeWidgetService,
    required this.watchHistoryService,
    required this.watchOrderService,
    required this.downloadService,
    required this.mangaDownloadService,
    required this.localNotificationService,
    required this.lnReaderPluginService,
    required this.notificationSubscriptions,
    required this.notificationCoordinator,
    required this.novelLibraryService,
    required this.searchHistoryService,
    required this.sourceHealthService,
    required this.trackingService,
    required this.updateService,
  });

  final PreferencesService preferences;
  final AppDatabase database;
  final CredentialVault credentialVault;
  final PlatformCapabilities capabilities;
  final FeatureGateService featureGates;
  final AniListService aniListService;
  final BackupService backupService;
  final CatalogCacheService catalogCacheService;
  final AniyomiExtensionService aniyomiExtensionService;
  final JuroService juroService;
  final HomeWidgetService homeWidgetService;
  final WatchHistoryService watchHistoryService;
  final WatchOrderService watchOrderService;
  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final LocalNotificationService localNotificationService;
  final LnReaderPluginService lnReaderPluginService;
  final NotificationSubscriptionService notificationSubscriptions;
  final NotificationCoordinator notificationCoordinator;
  final NovelLibraryService novelLibraryService;
  final SearchHistoryService searchHistoryService;
  final SourceHealthService sourceHealthService;
  final TrackingService trackingService;
  final UpdateService updateService;

  static Future<AppServices> bootstrap() async {
    final preferences = PreferencesService();
    await preferences.load();

    final database = AppDatabase.defaults();
    await database.initialize();
    await database.setMetadata('foundation.schema', '2');

    final featureGates = FeatureGateService();
    await featureGates.load();

    final credentialVault = CredentialVault();
    final trackingService = TrackingService(credentialVault: credentialVault);
    await trackingService.load();

    final sourceHealthService = SourceHealthService(database);
    final aniyomiExtensionService = AniyomiExtensionService();
    final juroService = JuroService(
      aniyomiExtensionService: aniyomiExtensionService,
      sourceHealthService: sourceHealthService,
    );
    final downloadService = DownloadService();
    await downloadService.load();
    final mangaDownloadService = MangaDownloadService(juroService: juroService);
    await mangaDownloadService.load();
    final packageInfo = await PackageInfo.fromPlatform();

    final catalogCacheService = CatalogCacheService(database);
    await catalogCacheService.clearExpired();
    final aniListService = AniListService(
      includeAdultContentResolver: () =>
          trackingService.aniListAdultContentEnabled,
      cache: catalogCacheService,
    );

    final localNotificationService = LocalNotificationService();
    final notificationSubscriptions = NotificationSubscriptionService(database);
    final backupService = BackupService(
      database: database,
      preferences: preferences,
    );
    final notificationRefreshService = NotificationRefreshService(
      database: database,
      aniListService: aniListService,
      juroService: juroService,
      localNotifications: localNotificationService,
      preferences: preferences,
    );
    final watchHistoryService = WatchHistoryService();
    final capabilities = PlatformCapabilities.detect();
    final homeWidgetService = HomeWidgetService(
      capabilities: capabilities,
      watchHistory: watchHistoryService,
      subscriptions: notificationSubscriptions,
    );
    final notificationCoordinator = NotificationCoordinator(
      preferences: preferences,
      trackingService: trackingService,
      subscriptions: notificationSubscriptions,
      refreshService: notificationRefreshService,
      localNotifications: localNotificationService,
      refreshHomeWidget: homeWidgetService.refresh,
    );

    final services = AppServices(
      preferences: preferences,
      database: database,
      credentialVault: credentialVault,
      capabilities: capabilities,
      featureGates: featureGates,
      aniListService: aniListService,
      backupService: backupService,
      catalogCacheService: catalogCacheService,
      aniyomiExtensionService: aniyomiExtensionService,
      juroService: juroService,
      homeWidgetService: homeWidgetService,
      watchHistoryService: watchHistoryService,
      watchOrderService: WatchOrderService(
        database: database,
        aniList: aniListService,
      ),
      downloadService: downloadService,
      mangaDownloadService: mangaDownloadService,
      localNotificationService: localNotificationService,
      lnReaderPluginService: LnReaderPluginService(capabilities: capabilities),
      notificationSubscriptions: notificationSubscriptions,
      notificationCoordinator: notificationCoordinator,
      novelLibraryService: NovelLibraryService(database),
      searchHistoryService: SearchHistoryService(database),
      sourceHealthService: sourceHealthService,
      trackingService: trackingService,
      updateService: UpdateService(
        currentVersion: packageInfo.version,
        capabilities: capabilities,
      ),
    );
    await homeWidgetService.initialize();
    await notificationCoordinator.initialize();
    return services;
  }

  Future<void> dispose() async {
    trackingService.dispose();
    localNotificationService.dispose();
    lnReaderPluginService.dispose();
    homeWidgetService.dispose();
    await database.close();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({required this.services, required super.child, super.key});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in this context');
    return scope!.services;
  }

  static AppServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
