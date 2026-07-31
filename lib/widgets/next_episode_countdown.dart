import 'dart:async';

import 'package:flutter/material.dart';

class NextEpisodeCountdown extends StatefulWidget {
  const NextEpisodeCountdown({
    required this.episode,
    required this.airingAt,
    this.now,
    super.key,
  });

  static const maxLeadTime = Duration(days: 28);

  final int episode;
  final DateTime airingAt;
  final DateTime Function()? now;

  @override
  State<NextEpisodeCountdown> createState() => _NextEpisodeCountdownState();
}

class _NextEpisodeCountdownState extends State<NextEpisodeCountdown>
    with WidgetsBindingObserver {
  Timer? _timer;
  late Duration _remaining;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  bool get _isVisible =>
      _remaining > Duration.zero &&
      _remaining <= NextEpisodeCountdown.maxLeadTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restart();
  }

  @override
  void didUpdateWidget(covariant NextEpisodeCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode != widget.episode ||
        oldWidget.airingAt != widget.airingAt ||
        oldWidget.now != widget.now) {
      _restart();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restart(notify: true);
    } else {
      _timer?.cancel();
    }
  }

  void _restart({bool notify = false}) {
    _timer?.cancel();
    _remaining = widget.airingAt.difference(_now);
    if (notify && mounted) {
      setState(() {});
    }
    if (!_isVisible) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = widget.airingAt.difference(_now);
      if (!mounted) {
        return;
      }
      setState(() => _remaining = remaining);
      if (!_isVisible) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final countdown = formatEpisodeCountdown(_remaining);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Semantics(
        key: const ValueKey('next-episode-countdown'),
        container: true,
        liveRegion: true,
        label: 'Episode ${widget.episode} will be released in $countdown',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.72),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                Text(
                  'EPISODE ${widget.episode} WILL BE RELEASED IN',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  countdown,
                  key: const ValueKey('next-episode-countdown-value'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String formatEpisodeCountdown(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final days = totalSeconds ~/ Duration.secondsPerDay;
  final hours =
      (totalSeconds % Duration.secondsPerDay) ~/ Duration.secondsPerHour;
  final minutes =
      (totalSeconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
  final seconds = totalSeconds % Duration.secondsPerMinute;
  return '$days days $hours hrs $minutes mins $seconds secs';
}
