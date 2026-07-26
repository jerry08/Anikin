import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../data/app_database.dart';
import '../core/platform_capabilities.dart';
import 'anilist_service.dart';
import 'catalog_cache_service.dart';
import 'juro_service.dart';
import 'home_widget_service.dart';
import 'local_notification_service.dart';
import 'notification_refresh_service.dart';
import 'preferences_service.dart';
import 'notification_subscription_service.dart';
import 'watch_history_service.dart';

const notificationRefreshTaskName = 'anikin.notification.refresh';
const notificationRefreshUniqueName = 'anikin-periodic-release-check';

@pragma('vm:entry-point')
void notificationWorkerDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != notificationRefreshTaskName &&
        task != Workmanager.iOSBackgroundTask) {
      return true;
    }
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final database = AppDatabase.defaults();
    try {
      await database.initialize();
      final preferences = PreferencesService();
      await preferences.load();
      if (!preferences.notificationsEnabled) {
        return true;
      }
      final notifications = LocalNotificationService();
      await notifications.initialize();
      final aniList = AniListService(cache: CatalogCacheService(database));
      await NotificationRefreshService(
        database: database,
        aniListService: aniList,
        juroService: JuroService(),
        localNotifications: notifications,
        preferences: preferences,
      ).refresh();
      await HomeWidgetService(
        capabilities: PlatformCapabilities.detect(),
        watchHistory: WatchHistoryService(),
        subscriptions: NotificationSubscriptionService(database),
      ).refresh();
      return true;
    } catch (_) {
      return false;
    } finally {
      await database.close();
    }
  });
}
