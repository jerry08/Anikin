import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../core/platform_capabilities.dart';
import '../data/app_database.dart';
import 'notification_subscription_service.dart';
import 'watch_history_service.dart';

class HomeWidgetService {
  HomeWidgetService({
    required PlatformCapabilities capabilities,
    required WatchHistoryService watchHistory,
    required NotificationSubscriptionService subscriptions,
  }) : _capabilities = capabilities,
       _watchHistory = watchHistory,
       _subscriptions = subscriptions;

  static const androidProviderName = 'AnikinHomeWidgetProvider';

  final PlatformCapabilities _capabilities;
  final WatchHistoryService _watchHistory;
  final NotificationSubscriptionService _subscriptions;
  bool _listening = false;

  bool get isSupported => _capabilities.supportsHomeWidgets;

  Future<void> initialize() async {
    if (!isSupported) return;
    if (!_listening) {
      _watchHistory.addListener(_handleChanged);
      _subscriptions.addListener(_handleChanged);
      _listening = true;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (!isSupported) return;
    final history =
        (await _watchHistory.getAll()).values
            .where((item) => item.watchedPercentage < 98)
            .toList()
          ..sort(
            (left, right) =>
                (right.updatedAtMs ?? 0).compareTo(left.updatedAtMs ?? 0),
          );
    final subscriptions =
        (await _subscriptions.all(enabledOnly: true))
            .where((item) => item.nextAiringAt?.isAfter(DateTime.now()) == true)
            .toList()
          ..sort(
            (left, right) => left.nextAiringAt!.compareTo(right.nextAiringAt!),
          );

    final current = history.firstOrNull;
    final next = subscriptions.firstOrNull;
    await Future.wait([
      HomeWidget.saveWidgetData<String>(
        'continue_title',
        current?.displayAnimeName ?? 'Nothing in progress',
      ),
      HomeWidget.saveWidgetData<String>(
        'continue_subtitle',
        current == null
            ? 'Watch an episode to see it here'
            : current.displayEpisodeName,
      ),
      HomeWidget.saveWidgetData<int>(
        'continue_progress',
        (current?.watchedPercentage ?? 0).round().clamp(0, 100),
      ),
      HomeWidget.saveWidgetData<String>(
        'next_title',
        next == null
            ? 'No upcoming release synced'
            : (next.mediaTitle.isEmpty ? 'Upcoming release' : next.mediaTitle),
      ),
      HomeWidget.saveWidgetData<String>(
        'next_time',
        next == null
            ? 'Enable release alerts to populate this card'
            : _formatAiring(next),
      ),
    ]);
    await HomeWidget.updateWidget(androidName: androidProviderName);
  }

  Future<bool> requestPin() async {
    if (!isSupported) return false;
    if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
    await HomeWidget.requestPinWidget(androidName: androidProviderName);
    return true;
  }

  void dispose() {
    if (!_listening) return;
    _watchHistory.removeListener(_handleChanged);
    _subscriptions.removeListener(_handleChanged);
    _listening = false;
  }

  void _handleChanged() => unawaited(refresh());

  static String _formatAiring(NotificationSubscription item) {
    final date = item.nextAiringAt!.toLocal();
    return '${DateFormat.MMMd().format(date)} • ${DateFormat.jm().format(date)}';
  }
}
