import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService extends ChangeNotifier {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  String? pendingPayload;

  static const _releaseDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'anikin_releases',
      'New releases',
      channelDescription:
          'Anime premieres, airing episodes, and manga chapters',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(threadIdentifier: 'anikin_releases'),
    macOS: DarwinNotificationDetails(threadIdentifier: 'anikin_releases'),
    linux: LinuxNotificationDetails(category: LinuxNotificationCategory.email),
  );

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    tz_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: IOSInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: darwin,
        linux: LinuxInitializationSettings(defaultActionName: 'Open Anikin'),
        windows: WindowsInitializationSettings(
          appName: 'Anikin',
          appUserModelId: 'Oneb.Anikin.App',
          guid: 'b4ba6ac8-550d-4b07-91ce-a5eef705f02f',
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        pendingPayload = response.payload;
        notifyListeners();
      },
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      pendingPayload = launchDetails?.notificationResponse?.payload;
    }
    _initialized = true;
  }

  String? takePendingPayload() {
    final payload = pendingPayload;
    pendingPayload = null;
    return payload;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (Platform.isMacOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _releaseDetails,
      payload: payload,
    );
  }

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    await initialize();
    if (!when.isAfter(DateTime.now())) {
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _releaseDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id: id);
  }
}
