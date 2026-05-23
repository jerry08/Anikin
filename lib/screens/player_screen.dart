import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/app_constants.dart';
import '../core/app_theme.dart';
import '../core/text_utils.dart';
import '../models/anilist_media.dart';
import '../models/juro_models.dart';
import '../models/watch_history.dart';
import '../services/juro_service.dart';
import '../services/preferences_service.dart';
import '../services/subtitle_service.dart';
import '../services/tracking_service.dart';
import '../services/watch_history_service.dart';
import '../widgets/app_error_view.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    required this.media,
    required this.providerAnime,
    required this.episode,
    required this.episodes,
    required this.initialSource,
    required this.preferences,
    required this.juroService,
    required this.watchHistoryService,
    required this.trackingService,
    this.offlineFilePath,
    this.providerKey,
    this.providerName,
    super.key,
  });

  final AniListMedia media;
  final JuroAnimeInfo providerAnime;
  final AnimeEpisode episode;
  final List<AnimeEpisode> episodes;
  final VideoSource? initialSource;
  final PreferencesService preferences;
  final JuroService juroService;
  final WatchHistoryService watchHistoryService;
  final TrackingService trackingService;
  final String? offlineFilePath;
  final String? providerKey;
  final String? providerName;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _subtitleService = SubtitleService();

  VideoPlayerController? _controller;
  VideoSource? _source;
  late AnimeEpisode _episode;
  List<SubtitleCue> _subtitleCues = const [];
  String? _caption;
  String? _error;
  String? _status;
  bool _loading = true;
  bool _showControls = true;
  bool _locked = false;
  bool _completedHandled = false;
  bool _playerModeExited = false;
  bool _closeInProgress = false;
  bool _seekBarActive = false;
  bool _resumeAfterSeekBar = false;
  Timer? _uiTimer;
  Timer? _hideTimer;
  Timer? _seekFeedbackTimer;
  _SeekFeedbackData? _seekFeedback;
  int _seekFeedbackId = 0;
  DateTime _lastProgressSave = DateTime.fromMillisecondsSinceEpoch(0);

  String get _episodeKey => '${widget.media.id}-${_episode.number}';

  bool get _isOffline => widget.offlineFilePath != null;

  String get _providerKey =>
      widget.providerKey ?? widget.preferences.lastAnimeProviderKey;

  String? get _providerName =>
      widget.providerName ?? widget.preferences.lastAnimeProviderName;

  int get _episodeIndex =>
      widget.episodes.indexWhere((item) => item.id == _episode.id);

  @override
  void initState() {
    super.initState();
    _episode = widget.episode;
    _source = widget.initialSource;
    _enterPlayerMode();
    _loadSourceAndPlay();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    unawaited(_saveProgress());
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    unawaited(_exitPlayerMode());
    super.dispose();
  }

  Future<void> _enterPlayerMode() async {
    await WakelockPlus.enable();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.preferences.alwaysLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Future<void> _exitPlayerMode({Brightness? brightness}) async {
    if (_playerModeExited) {
      return;
    }
    _playerModeExited = true;

    SystemChrome.setSystemUIOverlayStyle(
      AppTheme.edgeToEdgeOverlayStyle(
        brightness ??
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
      ),
    );
    if (Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await WakelockPlus.disable();
  }

  Future<void> _closePlayer() async {
    if (_closeInProgress) {
      return;
    }
    _closeInProgress = true;

    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    await _exitPlayerMode(brightness: Theme.of(context).brightness);
    await _saveProgress();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadSourceAndPlay() async {
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Resolving source';
      _caption = null;
      _subtitleCues = const [];
      _completedHandled = false;
    });

    try {
      await _controller?.pause();
      _controller?.removeListener(_onControllerChanged);
      await _controller?.dispose();

      late final VideoPlayerController controller;
      if (_isOffline) {
        _source = widget.initialSource;
        setState(() => _status = 'Opening offline video');
        controller = VideoPlayerController.file(File(widget.offlineFilePath!));
      } else {
        final source =
            _source ??
            await widget.juroService.getPreferredVideo(
              _episode,
              providerKey: _providerKey,
            );

        if (source == null) {
          throw const PlayerException('No playable video source found');
        }

        _source = source;

        final headers = Map<String, String>.from(source.headers);
        final hasUserAgent = headers.keys.any(
          (key) => key.toLowerCase() == 'user-agent',
        );
        if (!hasUserAgent) {
          headers['User-Agent'] = AppConstants.defaultUserAgent;
        }

        controller = VideoPlayerController.networkUrl(
          Uri.parse(source.videoUrl.replaceAll(' ', '%20')),
          httpHeaders: headers,
        );
      }
      _controller = controller;
      controller.addListener(_onControllerChanged);

      setState(
        () => _status = _isOffline ? 'Opening offline video' : 'Opening video',
      );
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setPlaybackSpeed(
        widget.preferences.defaultPlaybackSpeed,
      );

      final watched = await widget.watchHistoryService.get(_episodeKey);
      if (watched != null && watched.watchedPercentage < 92) {
        final seekTo = watched.watchedDuration;
        if (seekTo < controller.value.duration) {
          await controller.seekTo(seekTo);
        }
      }

      final source = _source;
      if (source != null && !_isOffline) {
        await _loadSubtitles(source);
      }
      await controller.play();
      _startTimers();
      _scheduleControlsHide();
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _loadSubtitles(VideoSource source) async {
    if (!widget.preferences.subtitlesEnabled || source.subtitles.isEmpty) {
      return;
    }

    final subtitle = source.subtitles.firstWhere(
      (item) => item.language.toLowerCase().contains('english'),
      orElse: () => source.subtitles.first,
    );

    _subtitleCues = await _subtitleService.load(subtitle);
  }

  void _startTimers() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final controller = _controller;
      if (!mounted || controller == null || !controller.value.isInitialized) {
        return;
      }

      final position = controller.value.position;
      final caption = widget.preferences.subtitlesEnabled
          ? SubtitleService.textAt(_subtitleCues, position)
          : null;
      final shouldSave =
          DateTime.now().difference(_lastProgressSave).inSeconds >= 5;
      if (shouldSave) {
        _lastProgressSave = DateTime.now();
        _saveProgress();
      }

      setState(() => _caption = caption);
    });
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.hasError) {
      setState(
        () => _error =
            controller.value.errorDescription ?? 'Failed to play video',
      );
      return;
    }

    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration.inMilliseconds > 0 &&
        position >= duration - const Duration(milliseconds: 800)) {
      if (!_completedHandled) {
        _completedHandled = true;
        _saveProgress();
        if (widget.preferences.autoPlayNext) {
          _playNext();
        }
      }
    }
  }

  Future<void> _saveProgress() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.duration.inMilliseconds <= 0) {
      return;
    }

    final percentage =
        controller.value.position.inMilliseconds /
        controller.value.duration.inMilliseconds *
        100;
    if (percentage.isNaN || percentage.isInfinite) {
      return;
    }

    await widget.watchHistoryService.save(
      WatchedEpisode(
        id: _episodeKey,
        animeName: widget.providerAnime.title,
        watchedDurationMs: controller.value.position.inMilliseconds,
        watchedPercentage: percentage.clamp(0, 100).toDouble(),
        mediaId: widget.media.id,
        mediaTitle: widget.media.displayTitle,
        mediaCoverUrl: widget.media.cover.best,
        providerAnimeId: widget.providerAnime.id,
        providerAnimeTitle: widget.providerAnime.title,
        providerAnimeImage: widget.providerAnime.image,
        episodeId: _episode.id,
        episodeName: _episode.name,
        episodeNumber: _episode.number,
        episodeImage: _episode.image,
        providerKey: _providerKey,
        providerName: _providerName,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    unawaited(
      widget.trackingService.syncEpisodeProgress(
        media: widget.media,
        episodeNumber: _episode.number,
        watchedPercentage: percentage,
      ),
    );
  }

  Future<void> _playEpisode(AnimeEpisode episode) async {
    await _saveProgress();
    setState(() {
      _episode = episode;
      _source = null;
    });
    await _loadSourceAndPlay();
  }

  Future<void> _playPrevious() async {
    final index = _episodeIndex;
    if (index <= 0) {
      return;
    }
    await _playEpisode(widget.episodes[index - 1]);
  }

  Future<void> _playNext() async {
    final index = _episodeIndex;
    if (index < 0 || index >= widget.episodes.length - 1) {
      return;
    }
    await _playEpisode(widget.episodes[index + 1]);
  }

  Future<void> _seekBy(int seconds, {bool showFeedback = false}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final target = controller.value.position + Duration(seconds: seconds);
    final clampedMs = target.inMilliseconds.clamp(
      0,
      controller.value.duration.inMilliseconds,
    );
    await controller.seekTo(Duration(milliseconds: clampedMs.toInt()));
    if (showFeedback) {
      _showSeekFeedback(seconds);
    }
    _scheduleControlsHide();
  }

  Future<void> _seekTo(Duration position) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final clampedMs = position.inMilliseconds.clamp(
      0,
      controller.value.duration.inMilliseconds,
    );
    await controller.seekTo(Duration(milliseconds: clampedMs.toInt()));
    if (mounted) {
      setState(() {});
    }
    if (!_seekBarActive) {
      _scheduleControlsHide();
    }
  }

  void _beginSeekBarInteraction() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    _seekBarActive = true;
    _resumeAfterSeekBar = controller.value.isPlaying;
    _hideTimer?.cancel();
    if (_resumeAfterSeekBar) {
      unawaited(controller.pause());
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _endSeekBarInteraction() async {
    final controller = _controller;
    final shouldResume = _resumeAfterSeekBar;
    _seekBarActive = false;
    _resumeAfterSeekBar = false;

    if (shouldResume && controller != null && controller.value.isInitialized) {
      await controller.play();
    }
    if (mounted) {
      setState(() {});
    }
    _scheduleControlsHide();
  }

  void _showSeekFeedback(int seconds) {
    final direction = seconds < 0
        ? _SeekFeedbackDirection.backward
        : _SeekFeedbackDirection.forward;
    final previous = _seekFeedback;
    final displayedSeconds = previous?.direction == direction
        ? previous!.seconds + seconds.abs()
        : seconds.abs();

    _seekFeedbackTimer?.cancel();
    setState(() {
      _seekFeedback = _SeekFeedbackData(
        id: _seekFeedbackId++,
        direction: direction,
        seconds: displayedSeconds,
      );
    });
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _seekFeedback = null);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleControlsHide();
    }
  }

  void _scheduleControlsHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      final controller = _controller;
      if (mounted && controller?.value.isPlaying == true && !_locked) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      await _saveProgress();
    } else {
      await controller.play();
      _scheduleControlsHide();
    }
    setState(() {});
  }

  Future<void> _selectSource() async {
    if (_isOffline) {
      return;
    }

    final future = widget.juroService.getVideos(
      _episode.id,
      providerKey: _providerKey,
    );
    final source = await showModalBottomSheet<VideoSource>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.34,
        maxChildSize: 0.92,
        builder: (context, scrollController) =>
            FutureBuilder<List<VideoSource>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AppErrorView(message: snapshot.error.toString());
                }
                final sources = snapshot.data ?? const <VideoSource>[];
                if (sources.isEmpty) {
                  return const EmptyState(
                    icon: Icons.videocam_off_outlined,
                    title: 'No video sources',
                  );
                }

                final grouped = <String, List<VideoSource>>{};
                for (final source in sources) {
                  grouped.putIfAbsent(source.serverName, () => []).add(source);
                }

                return ListView(
                  controller: scrollController,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Text(
                        'Sources',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                      ),
                      for (final source in entry.value)
                        ListTile(
                          leading: Icon(
                            source.videoUrl == _source?.videoUrl
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: Text(source.displayTitle),
                          subtitle: Text(
                            [
                              source.resolution,
                              source.fileType,
                              source.extraNote,
                            ].whereType<String>().join(' • '),
                          ),
                          onTap: () => Navigator.of(context).pop(source),
                        ),
                    ],
                  ],
                );
              },
            ),
      ),
    );

    if (source == null) {
      return;
    }

    await _saveProgress();
    setState(() => _source = source);
    await _loadSourceAndPlay();
  }

  Future<void> _selectSpeed() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final speed = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Playback speed',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          for (final speed in widget.preferences.playbackSpeeds)
            ListTile(
              leading: Icon(
                speed == controller.value.playbackSpeed
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text('${speed}x'),
              onTap: () => Navigator.of(context).pop(speed),
            ),
        ],
      ),
    );

    if (speed != null) {
      await controller.setPlaybackSpeed(speed);
      setState(() {});
    }
  }

  Future<void> _selectResizeMode() async {
    final mode = await showModalBottomSheet<ResizeModeSetting>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Resize mode',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          for (final mode in ResizeModeSetting.values)
            ListTile(
              leading: Icon(
                mode == widget.preferences.resizeMode
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(mode.name[0].toUpperCase() + mode.name.substring(1)),
              onTap: () => Navigator.of(context).pop(mode),
            ),
        ],
      ),
    );

    if (mode != null) {
      await widget.preferences.setResizeMode(mode);
      setState(() {});
    }
  }

  BoxFit get _videoFit => switch (widget.preferences.resizeMode) {
    ResizeModeSetting.original => BoxFit.contain,
    ResizeModeSetting.zoom => BoxFit.cover,
    ResizeModeSetting.stretch => BoxFit.fill,
  };

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final playerControlsVisible =
        !_locked &&
        _showControls &&
        controller != null &&
        controller.value.isInitialized;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_closePlayer());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (controller != null && controller.value.isInitialized)
                _VideoSurface(controller: controller, fit: _videoFit)
              else
                const ColoredBox(color: Colors.black),
              if (widget.preferences.doubleTapSeek && !_locked)
                _PlayerDoubleTapSeekZones(
                  seekSeconds: widget.preferences.seekTimeSeconds,
                  onSeekBackward: () => _seekBy(
                    -widget.preferences.seekTimeSeconds,
                    showFeedback: true,
                  ),
                  onSeekForward: () => _seekBy(
                    widget.preferences.seekTimeSeconds,
                    showFeedback: true,
                  ),
                ),
              _SeekFeedbackLayer(feedback: _seekFeedback),
              if (_caption != null && !_locked)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: _showControls ? 112 : 38,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Text(
                          _caption!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.preferences.subtitleFontSize
                                .toDouble(),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_loading)
                ColoredBox(
                  color: const Color(0xAA000000),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        if (_status != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _status!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (_error != null)
                ColoredBox(
                  color: const Color(0xE6000000),
                  child: AppErrorView(
                    message: _error!,
                    onRetry: _loadSourceAndPlay,
                  ),
                ),
              if (_locked && _showControls)
                Positioned(
                  right: 14,
                  top: 14 + MediaQuery.paddingOf(context).top,
                  child: _ControlButton(
                    icon: Icons.lock,
                    tooltip: 'Unlock controls',
                    onPressed: () => setState(() => _locked = false),
                    filled: true,
                  ),
                )
              else if (playerControlsVisible)
                _PlayerControls(
                  controller: controller,
                  source: _source,
                  episode: _episode,
                  animeTitle: widget.providerAnime.title,
                  hasPrevious: !_isOffline && _episodeIndex > 0,
                  hasNext:
                      !_isOffline &&
                      _episodeIndex >= 0 &&
                      _episodeIndex < widget.episodes.length - 1,
                  onBack: _closePlayer,
                  onTogglePlay: _togglePlay,
                  onSeekBackward: () =>
                      _seekBy(-widget.preferences.seekTimeSeconds),
                  onSeekForward: () =>
                      _seekBy(widget.preferences.seekTimeSeconds),
                  onSeek: _seekTo,
                  onSeekStart: _beginSeekBarInteraction,
                  onSeekEnd: _endSeekBarInteraction,
                  onPrevious: _playPrevious,
                  onNext: _playNext,
                  onSource: _isOffline ? null : _selectSource,
                  onSpeed: _selectSpeed,
                  onResize: _selectResizeMode,
                  onLock: () => setState(() {
                    _locked = true;
                    _showControls = true;
                  }),
                  onEpisodeSelected: _playEpisode,
                  episodes: widget.episodes,
                  currentSpeed: controller.value.playbackSpeed,
                  resizeMode: widget.preferences.resizeMode,
                  seekSeconds: widget.preferences.seekTimeSeconds,
                  showRemainingDuration:
                      widget.preferences.showRemainingDuration,
                ),
              if ((_loading || _error != null) && !playerControlsVisible)
                Positioned(
                  left: 8 + MediaQuery.paddingOf(context).left,
                  top: 6 + MediaQuery.paddingOf(context).top,
                  child: _ControlButton(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: 'Back',
                    onPressed: _closePlayer,
                    filled: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SeekFeedbackDirection { backward, forward }

class _SeekFeedbackData {
  const _SeekFeedbackData({
    required this.id,
    required this.direction,
    required this.seconds,
  });

  final int id;
  final _SeekFeedbackDirection direction;
  final int seconds;
}

class _SeekFeedbackLayer extends StatelessWidget {
  const _SeekFeedbackLayer({required this.feedback});

  final _SeekFeedbackData? feedback;

  @override
  Widget build(BuildContext context) {
    final data = feedback;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        reverseDuration: const Duration(milliseconds: 180),
        child: data == null
            ? const SizedBox.expand(key: ValueKey('empty-seek-feedback'))
            : _SeekFeedbackPulse(key: ValueKey(data.id), feedback: data),
      ),
    );
  }
}

class _SeekFeedbackPulse extends StatelessWidget {
  const _SeekFeedbackPulse({required this.feedback, super.key});

  final _SeekFeedbackData feedback;

  @override
  Widget build(BuildContext context) {
    final isBackward = feedback.direction == _SeekFeedbackDirection.backward;
    final alignment = isBackward ? Alignment.centerLeft : Alignment.centerRight;
    final borderRadius = BorderRadius.horizontal(
      left: isBackward ? Radius.zero : const Radius.circular(260),
      right: isBackward ? const Radius.circular(260) : Radius.zero,
    );
    final icon = isBackward ? Icons.replay : Icons.forward;

    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        widthFactor: 0.48,
        heightFactor: 1,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.82, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x40FFFFFF),
              borderRadius: borderRadius,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 52),
                  const SizedBox(height: 6),
                  Text(
                    '${feedback.seconds}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerDoubleTapSeekZones extends StatelessWidget {
  const _PlayerDoubleTapSeekZones({
    required this.seekSeconds,
    required this.onSeekBackward,
    required this.onSeekForward,
  });

  final int seekSeconds;
  final Future<void> Function() onSeekBackward;
  final Future<void> Function() onSeekForward;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ExcludeSemantics(
        child: SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: 0.58,
              child: Row(
                children: [
                  Expanded(
                    child: _DoubleTapSeekRegion(
                      tooltip: 'Rewind ${seekSeconds}s',
                      onDoubleTap: onSeekBackward,
                    ),
                  ),
                  const SizedBox(width: 140),
                  Expanded(
                    child: _DoubleTapSeekRegion(
                      tooltip: 'Forward ${seekSeconds}s',
                      onDoubleTap: onSeekForward,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoubleTapSeekRegion extends StatelessWidget {
  const _DoubleTapSeekRegion({
    required this.tooltip,
    required this.onDoubleTap,
  });

  final String tooltip;
  final Future<void> Function() onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: () => unawaited(onDoubleTap()),
      child: Semantics(
        button: true,
        label: tooltip,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.controller, required this.fit});

  final VideoPlayerController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    final width = size.width <= 0 ? 16.0 : size.width;
    final height = size.height <= 0 ? 9.0 : size.height;
    return Center(
      child: SizedBox.expand(
        child: FittedBox(
          fit: fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: width,
            height: height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.controller,
    required this.source,
    required this.episode,
    required this.animeTitle,
    required this.hasPrevious,
    required this.hasNext,
    required this.onBack,
    required this.onTogglePlay,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onSeek,
    required this.onSeekStart,
    required this.onSeekEnd,
    required this.onPrevious,
    required this.onNext,
    required this.onSource,
    required this.onSpeed,
    required this.onResize,
    required this.onLock,
    required this.onEpisodeSelected,
    required this.episodes,
    required this.currentSpeed,
    required this.resizeMode,
    required this.seekSeconds,
    required this.showRemainingDuration,
  });

  final VideoPlayerController controller;
  final VideoSource? source;
  final AnimeEpisode episode;
  final String animeTitle;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final Future<void> Function(Duration) onSeek;
  final VoidCallback onSeekStart;
  final Future<void> Function() onSeekEnd;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onSource;
  final VoidCallback onSpeed;
  final VoidCallback onResize;
  final VoidCallback onLock;
  final ValueChanged<AnimeEpisode> onEpisodeSelected;
  final List<AnimeEpisode> episodes;
  final double currentSpeed;
  final ResizeModeSetting resizeMode;
  final int seekSeconds;
  final bool showRemainingDuration;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    final value = controller.value;
    final duration = value.duration;
    final position = value.position > duration ? duration : value.position;
    final displayedPosition = position;
    final remaining = duration > displayedPosition
        ? duration - displayedPosition
        : Duration.zero;
    final currentSource = source;
    final compact = MediaQuery.sizeOf(context).width < 430;
    final controlGap = compact ? 12.0 : 24.0;
    final transportButtonSize = compact ? 56.0 : 66.0;
    final transportIconSize = compact ? 30.0 : 36.0;
    final playIconSize = compact ? 34.0 : 40.0;
    final seekbarColor = Theme.of(context).colorScheme.primary;

    return Stack(
      fit: StackFit.expand,
      children: [
        const _PlayerControlsGradient(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ControlButton(
                        icon: Icons.arrow_back_ios_new,
                        tooltip: 'Back',
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PopupMenuButton<AnimeEpisode>(
                              tooltip: 'Episodes',
                              padding: EdgeInsets.zero,
                              position: PopupMenuPosition.under,
                              onSelected: onEpisodeSelected,
                              itemBuilder: (context) => [
                                for (final item in episodes)
                                  PopupMenuItem(
                                    value: item,
                                    child: Text(
                                      item.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      episode.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: compact ? 16 : 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              animeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (currentSource != null)
                        Flexible(
                          flex: compact ? 1 : 0,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 220),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x59000000),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              '${currentSource.displayTitle} • ${_formatPlayerSpeed(currentSpeed)}x',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      _ControlButton(
                        icon: Icons.lock_open,
                        tooltip: 'Lock controls',
                        onPressed: onLock,
                      ),
                    ],
                  ),
                ),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ControlButton(
                          icon: Icons.skip_previous,
                          tooltip: 'Previous episode',
                          onPressed: hasPrevious ? onPrevious : null,
                          filled: true,
                          buttonSize: transportButtonSize,
                          iconSize: transportIconSize,
                        ),
                        SizedBox(width: controlGap),
                        _ControlButton(
                          icon: _seekBackwardIcon(seekSeconds),
                          tooltip: 'Rewind ${seekSeconds}s',
                          onPressed: onSeekBackward,
                          filled: true,
                          buttonSize: transportButtonSize,
                          iconSize: transportIconSize,
                        ),
                        SizedBox(width: controlGap),
                        _ControlButton(
                          icon: value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          tooltip: value.isPlaying ? 'Pause' : 'Play',
                          onPressed: onTogglePlay,
                          filled: true,
                          buttonSize: transportButtonSize,
                          iconSize: playIconSize,
                        ),
                        SizedBox(width: controlGap),
                        _ControlButton(
                          icon: _seekForwardIcon(seekSeconds),
                          tooltip: 'Forward ${seekSeconds}s',
                          onPressed: onSeekForward,
                          filled: true,
                          buttonSize: transportButtonSize,
                          iconSize: transportIconSize,
                        ),
                        SizedBox(width: controlGap),
                        _ControlButton(
                          icon: Icons.skip_next,
                          tooltip: 'Next episode',
                          onPressed: hasNext ? onNext : null,
                          filled: true,
                          buttonSize: transportButtonSize,
                          iconSize: transportIconSize,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _VideoSeekBar(
                        duration: duration,
                        position: position,
                        buffered: value.buffered,
                        color: seekbarColor,
                        onSeek: onSeek,
                        onSeekStart: onSeekStart,
                        onSeekEnd: onSeekEnd,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            Text(
                              formatDuration(displayedPosition),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              showRemainingDuration
                                  ? '-${formatDuration(remaining)} / ${formatDuration(duration)}'
                                  : formatDuration(duration),
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              resizeMode.name,
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (currentSource?.subtitles.isNotEmpty == true)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.closed_caption,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            _ControlButton(
                              icon: Icons.source_outlined,
                              tooltip: 'Sources',
                              onPressed: onSource,
                              buttonSize: 38,
                              iconSize: 22,
                            ),
                            _ControlButton(
                              icon: Icons.speed,
                              tooltip: 'Speed',
                              onPressed: onSpeed,
                              buttonSize: 38,
                              iconSize: 22,
                            ),
                            _ControlButton(
                              icon: Icons.fit_screen,
                              tooltip: 'Resize',
                              onPressed: onResize,
                              buttonSize: 38,
                              iconSize: 22,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoSeekBar extends StatefulWidget {
  const _VideoSeekBar({
    required this.duration,
    required this.position,
    required this.buffered,
    required this.color,
    required this.onSeek,
    required this.onSeekStart,
    required this.onSeekEnd,
  });

  final Duration duration;
  final Duration position;
  final List<DurationRange> buffered;
  final Color color;
  final Future<void> Function(Duration) onSeek;
  final VoidCallback onSeekStart;
  final Future<void> Function() onSeekEnd;

  @override
  State<_VideoSeekBar> createState() => _VideoSeekBarState();
}

class _VideoSeekBarState extends State<_VideoSeekBar> {
  bool _isDragging = false;
  double? _dragPositionMs;

  @override
  void didUpdateWidget(covariant _VideoSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration && !_isDragging) {
      _dragPositionMs = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = math.max(widget.duration.inMilliseconds, 1).toDouble();
    final positionMs = widget.position.inMilliseconds
        .clamp(0, durationMs.round())
        .toDouble();
    final displayedPositionMs = (_dragPositionMs ?? positionMs)
        .clamp(0, durationMs)
        .toDouble();
    const tooltipWidth = 76.0;
    const trackInset = 14.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _isDragging ? 1 : 0),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      builder: (context, expansion, child) {
        final thumbRadius = 5.0 + 3.0 * expansion;
        final trackHeight = 3.0 + 2.0 * expansion;
        final barHeight = 28.0 + 20.0 * expansion;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final trackWidth = math.max(0.0, width - trackInset * 2);
            final fraction = durationMs <= 0
                ? 0.0
                : displayedPositionMs / durationMs;
            final thumbCenterX = trackInset + trackWidth * fraction;
            final tooltipLeft = math
                .min(
                  math.max(thumbCenterX - tooltipWidth / 2, 0),
                  math.max(width - tooltipWidth, 0),
                )
                .toDouble();

            return SizedBox(
              height: barHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: 28,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _SeekBarTrackPainter(
                                  durationMs: durationMs,
                                  positionMs: displayedPositionMs,
                                  buffered: widget.buffered,
                                  activeColor: widget.color,
                                  trackHeight: trackHeight,
                                  trackInset: trackInset,
                                ),
                              ),
                            ),
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: trackHeight,
                              activeTrackColor: Colors.transparent,
                              inactiveTrackColor: Colors.transparent,
                              secondaryActiveTrackColor: Colors.transparent,
                              disabledActiveTrackColor: Colors.transparent,
                              disabledInactiveTrackColor: Colors.transparent,
                              thumbColor: widget.color,
                              overlayColor: widget.color.withAlpha(0x14),
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: thumbRadius,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: trackInset,
                              ),
                            ),
                            child: Slider(
                              min: 0,
                              max: durationMs,
                              value: displayedPositionMs,
                              onChangeStart: _handleStart,
                              onChanged: _handleChanged,
                              onChangeEnd: _handleEnd,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: tooltipLeft,
                    bottom: 24,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: _isDragging ? 1 : 0,
                        child: Container(
                          width: tooltipWidth,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xE6000000),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            formatDuration(
                              Duration(
                                milliseconds: displayedPositionMs.round(),
                              ),
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleStart(double value) {
    widget.onSeekStart();
    setState(() {
      _isDragging = true;
      _dragPositionMs = value;
    });
    unawaited(widget.onSeek(_positionFor(value)));
  }

  void _handleChanged(double value) {
    setState(() => _dragPositionMs = value);
    unawaited(widget.onSeek(_positionFor(value)));
  }

  void _handleEnd(double value) {
    final position = _positionFor(value);
    setState(() {
      _isDragging = false;
      _dragPositionMs = null;
    });
    unawaited(_finishSeek(position));
  }

  Duration _positionFor(double value) {
    return Duration(milliseconds: value.round());
  }

  Future<void> _finishSeek(Duration position) async {
    try {
      await widget.onSeek(position);
    } finally {
      await widget.onSeekEnd();
    }
  }
}

class _SeekBarTrackPainter extends CustomPainter {
  const _SeekBarTrackPainter({
    required this.durationMs,
    required this.positionMs,
    required this.buffered,
    required this.activeColor,
    required this.trackHeight,
    required this.trackInset,
  });

  final double durationMs;
  final double positionMs;
  final List<DurationRange> buffered;
  final Color activeColor;
  final double trackHeight;
  final double trackInset;

  @override
  void paint(Canvas canvas, Size size) {
    final left = trackInset;
    final right = math.max(left, size.width - trackInset);
    final top = (size.height - trackHeight) / 2;
    final bottom = top + trackHeight;
    final radius = Radius.circular(trackHeight / 2);

    final backgroundPaint = Paint()..color = const Color(0x52FFFFFF);
    canvas.drawRRect(
      RRect.fromLTRBR(left, top, right, bottom, radius),
      backgroundPaint,
    );

    if (durationMs <= 0 || right <= left) {
      return;
    }

    final trackWidth = right - left;
    final bufferPaint = Paint()..color = const Color(0x80FFFFFF);
    for (final range in buffered) {
      final startFraction = (range.start.inMilliseconds / durationMs).clamp(
        0.0,
        1.0,
      );
      final endFraction = (range.end.inMilliseconds / durationMs).clamp(
        0.0,
        1.0,
      );
      final startX = left + trackWidth * startFraction;
      final endX = left + trackWidth * endFraction;
      if (endX <= startX) {
        continue;
      }
      canvas.drawRRect(
        RRect.fromLTRBR(startX, top, endX, bottom, radius),
        bufferPaint,
      );
    }

    final playedFraction = (positionMs / durationMs).clamp(0.0, 1.0);
    final playedRight = left + trackWidth * playedFraction;
    if (playedRight > left) {
      canvas.drawRRect(
        RRect.fromLTRBR(left, top, playedRight, bottom, radius),
        Paint()..color = activeColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SeekBarTrackPainter oldDelegate) {
    return durationMs != oldDelegate.durationMs ||
        positionMs != oldDelegate.positionMs ||
        buffered != oldDelegate.buffered ||
        activeColor != oldDelegate.activeColor ||
        trackHeight != oldDelegate.trackHeight ||
        trackInset != oldDelegate.trackInset;
  }
}

class _PlayerControlsGradient extends StatelessWidget {
  const _PlayerControlsGradient();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Color(0x33000000), Color(0xDD000000)],
            stops: [0, 0.46, 1],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.buttonSize,
    this.iconSize,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final double? buttonSize;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final resolvedButtonSize = buttonSize ?? 42.0;
    final resolvedIconSize = iconSize ?? 24.0;
    final hasBackground = filled;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: resolvedButtonSize,
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(
            width: resolvedButtonSize,
            height: resolvedButtonSize,
          ),
          splashRadius: resolvedButtonSize / 2,
          iconSize: resolvedIconSize,
          color: Colors.white,
          disabledColor: const Color(0x66FFFFFF),
          style: IconButton.styleFrom(
            backgroundColor: hasBackground
                ? const Color(0x59000000)
                : Colors.transparent,
            disabledBackgroundColor: hasBackground
                ? const Color(0x26000000)
                : Colors.transparent,
            shape: const CircleBorder(),
          ),
          icon: Icon(icon),
        ),
      ),
    );
  }
}

String _formatPlayerSpeed(double speed) {
  return speed.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

IconData _seekBackwardIcon(int seconds) {
  return switch (seconds) {
    5 => Icons.replay_5,
    10 => Icons.replay_10,
    30 => Icons.replay_30,
    _ => Icons.replay,
  };
}

IconData _seekForwardIcon(int seconds) {
  return switch (seconds) {
    5 => Icons.forward_5,
    10 => Icons.forward_10,
    30 => Icons.forward_30,
    _ => Icons.forward,
  };
}

class PlayerException implements Exception {
  const PlayerException(this.message);

  final String message;

  @override
  String toString() => message;
}
