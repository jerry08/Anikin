import 'dart:io';

import 'package:workmanager/workmanager.dart';

import 'local_notification_service.dart';
import 'notification_background.dart';
import 'notification_refresh_service.dart';
import 'notification_subscription_service.dart';
import 'preferences_service.dart';
import 'tracking_service.dart';

class NotificationCoordinator {
  NotificationCoordinator({
    required PreferencesService preferences,
    required TrackingService trackingService,
    required NotificationSubscriptionService subscriptions,
    required NotificationRefreshService refreshService,
    required LocalNotificationService localNotifications,
    Future<void> Function()? refreshHomeWidget,
  }) : _preferences = preferences,
       _trackingService = trackingService,
       _subscriptions = subscriptions,
       _refreshService = refreshService,
       _localNotifications = localNotifications,
       _refreshHomeWidget = refreshHomeWidget;

  final PreferencesService _preferences;
  final TrackingService _trackingService;
  final NotificationSubscriptionService _subscriptions;
  final NotificationRefreshService _refreshService;
  final LocalNotificationService _localNotifications;
  final Future<void> Function()? _refreshHomeWidget;
  bool _backgroundInitialized = false;

  Future<void> initialize() async {
    await _localNotifications.initialize();
    if (!_preferences.notificationsEnabled) {
      return;
    }
    await _initializeBackgroundWork();
    await syncAndRefresh();
  }

  Future<bool> setEnabled(bool enabled) async {
    if (!enabled) {
      await _preferences.setNotificationsEnabled(false);
      if (Platform.isAndroid) {
        await Workmanager().cancelByUniqueName(notificationRefreshUniqueName);
      }
      return false;
    }
    final granted = await _localNotifications.requestPermission();
    await _preferences.setNotificationsEnabled(granted);
    if (granted) {
      await _initializeBackgroundWork();
      await syncAndRefresh();
    }
    return granted;
  }

  Future<void> syncAndRefresh() async {
    if (!_preferences.notificationsEnabled) {
      return;
    }
    try {
      await _subscriptions.syncAniListOrigins(_trackingService, _preferences);
    } catch (_) {
      // Existing manual and derived subscriptions remain usable offline.
    }
    await _refreshService.refresh();
    await _refreshHomeWidget?.call();
  }

  Future<void> reschedule() async {
    if (!_preferences.notificationsEnabled) {
      return;
    }
    await _initializeBackgroundWork(forceRegistration: true);
  }

  bool get _supportsBackgroundWork => Platform.isAndroid || Platform.isIOS;

  Future<void> _initializeBackgroundWork({
    bool forceRegistration = false,
  }) async {
    if (!_supportsBackgroundWork) {
      return;
    }
    if (!_backgroundInitialized) {
      await Workmanager().initialize(notificationWorkerDispatcher);
      _backgroundInitialized = true;
    }
    if (Platform.isIOS) {
      return;
    }
    if (!forceRegistration && !_preferences.notificationsEnabled) {
      return;
    }
    await Workmanager().registerPeriodicTask(
      notificationRefreshUniqueName,
      notificationRefreshTaskName,
      frequency: Duration(hours: _preferences.notificationRefreshHours),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }
}
