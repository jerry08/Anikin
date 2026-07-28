import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_services.dart';
import '../core/app_theme.dart';
import '../data/app_database.dart';
import '../models/juro_models.dart';
import '../models/tracking.dart';
import '../services/aniyomi_extension_service.dart';
import '../services/backup_service.dart';
import '../services/download_service.dart';
import '../services/feature_gate_service.dart';
import '../services/juro_service.dart';
import '../services/manga_download_service.dart';
import '../services/notification_subscription_service.dart';
import '../services/preferences_service.dart';
import '../services/tracking_service.dart';
import '../services/update_service.dart';
import '../services/watch_history_service.dart';
import 'aniyomi_extensions_screen.dart';
import 'aniyomi_sources_screen.dart';
import '../widgets/app_content_constraint.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_error_view.dart';
import '../widgets/update_dialogs.dart';

const _settingsTileShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.preferences,
    required this.juroService,
    required this.aniyomiExtensionService,
    required this.watchHistoryService,
    required this.downloadService,
    required this.mangaDownloadService,
    required this.trackingService,
    required this.updateService,
    super.key,
  });

  final PreferencesService preferences;
  final JuroService juroService;
  final AniyomiExtensionService aniyomiExtensionService;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final TrackingService trackingService;
  final UpdateService updateService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<SourceProvider>> _providersFuture;
  late Future<List<SourceProvider>> _mangaProvidersFuture;

  @override
  void initState() {
    super.initState();
    _providersFuture = widget.juroService.getProviders();
    _mangaProvidersFuture = widget.juroService.getMangaProviders();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.preferences,
          widget.trackingService,
        ]),
        builder: (context, _) {
          final prefs = widget.preferences;
          final services = AppScope.maybeOf(context);
          return ListTileTheme.merge(
            shape: _settingsTileShape,
            child: AppContentConstraint(
              maxWidth: AppLayout.maxReadableWidth,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle('General'),
                  _SettingsNavigationTile(
                    icon: Icons.tune_outlined,
                    title: 'App',
                    subtitle: _appSummary(prefs),
                    onTap: () => _openSettingsPage(
                      context,
                      _AppSettingsPage(
                        preferences: widget.preferences,
                        updateService: widget.updateService,
                      ),
                    ),
                  ),
                  if (services != null &&
                      services.featureGates.isEnabled(AppFeature.notifications))
                    _SettingsNavigationTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: prefs.notificationsEnabled
                          ? 'Release alerts every ${prefs.notificationRefreshHours}h'
                          : 'Release alerts are off',
                      onTap: () => _openSettingsPage(
                        context,
                        _NotificationSettingsPage(services: services),
                      ),
                    ),
                  if (services?.homeWidgetService.isSupported == true)
                    _HomeWidgetTile(services: services!),
                  _SettingsNavigationTile(
                    icon: Icons.storage_outlined,
                    title: 'Data and privacy',
                    subtitle: _dataSummary(prefs),
                    onTap: () => _openSettingsPage(
                      context,
                      _DataSettingsPage(
                        preferences: widget.preferences,
                        watchHistoryService: widget.watchHistoryService,
                        downloadService: widget.downloadService,
                        mangaDownloadService: widget.mangaDownloadService,
                        services: services,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _SectionTitle('Watching'),
                  _SettingsNavigationTile(
                    icon: Icons.play_circle_outline,
                    title: 'Playback',
                    subtitle: _playbackSummary(prefs),
                    onTap: () => _openSettingsPage(
                      context,
                      _PlaybackSettingsPage(preferences: widget.preferences),
                    ),
                  ),
                  _SettingsNavigationTile(
                    icon: Icons.subtitles_outlined,
                    title: 'Subtitles',
                    subtitle: _subtitlesSummary(prefs),
                    onTap: () => _openSettingsPage(
                      context,
                      _SubtitleSettingsPage(preferences: widget.preferences),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _SectionTitle('Reading'),
                  _SettingsNavigationTile(
                    icon: Icons.chrome_reader_mode_outlined,
                    title: 'Reader',
                    subtitle: _readerSummary(prefs),
                    onTap: () => _openSettingsPage(
                      context,
                      _ReaderSettingsPage(preferences: widget.preferences),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _SectionTitle('Accounts'),
                  _SettingsNavigationTile(
                    icon: Icons.sync_outlined,
                    title: 'Tracking and sync',
                    subtitle: _trackingSummary(widget.trackingService),
                    onTap: () => _openSettingsPage(
                      context,
                      _TrackingSettingsPage(
                        trackingService: widget.trackingService,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _SectionTitle('Library'),
                  _SettingsNavigationTile(
                    icon: Icons.source_outlined,
                    title: 'Sources and library',
                    subtitle: _sourcesSummary(prefs),
                    onTap: () => _openSettingsPage(
                      context,
                      _SourcesSettingsPage(
                        preferences: widget.preferences,
                        providersFuture: _providersFuture,
                        mangaProvidersFuture: _mangaProvidersFuture,
                      ),
                    ),
                  ),
                  if (widget.aniyomiExtensionService.isPlatformSupported) ...[
                    _SettingsNavigationTile(
                      icon: Icons.travel_explore_outlined,
                      title: 'Browse Aniyomi sources',
                      subtitle: 'Open installed extension sources',
                      onTap: () => _openSettingsPage(
                        context,
                        AniyomiSourcesScreen(
                          extensionService: widget.aniyomiExtensionService,
                          preferences: widget.preferences,
                          juroService: widget.juroService,
                          watchHistoryService: widget.watchHistoryService,
                          downloadService: widget.downloadService,
                          mangaDownloadService: widget.mangaDownloadService,
                          trackingService: widget.trackingService,
                        ),
                      ),
                    ),
                    _SettingsNavigationTile(
                      icon: Icons.extension_outlined,
                      title: 'Aniyomi extensions',
                      subtitle: 'Android extension sources',
                      onTap: () => _openSettingsPage(
                        context,
                        AniyomiExtensionsScreen(
                          extensionService: widget.aniyomiExtensionService,
                        ),
                      ),
                    ),
                    _NsfwSourcesTile(
                      extensionService: widget.aniyomiExtensionService,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSettingsPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _HomeWidgetTile extends StatefulWidget {
  const _HomeWidgetTile({required this.services});

  final AppServices services;

  @override
  State<_HomeWidgetTile> createState() => _HomeWidgetTileState();
}

class _HomeWidgetTileState extends State<_HomeWidgetTile> {
  bool _busy = false;

  Future<void> _addWidget() async {
    setState(() => _busy = true);
    try {
      await widget.services.homeWidgetService.refresh();
      final requested = await widget.services.homeWidgetService.requestPin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              requested
                  ? 'Widget request sent to your launcher'
                  : 'Add the Anikin widget from your launcher’s widget picker',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          error.toString(),
          title: 'Unable to add widget',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.widgets_outlined),
      title: const Text('Home Screen widget'),
      subtitle: const Text('Continue watching and upcoming release'),
      trailing: _busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add),
      enabled: !_busy,
      onTap: _busy ? null : _addWidget,
    );
  }
}

class _NsfwSourcesTile extends StatefulWidget {
  const _NsfwSourcesTile({required this.extensionService});

  final AniyomiExtensionService extensionService;

  @override
  State<_NsfwSourcesTile> createState() => _NsfwSourcesTileState();
}

class _NsfwSourcesTileState extends State<_NsfwSourcesTile> {
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final allowed = await widget.extensionService.getNsfwAllowed();
      if (mounted) setState(() => _allowed = allowed);
    } catch (_) {
      if (mounted) setState(() => _allowed = true);
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _allowed = value);
    try {
      await widget.extensionService.setNsfwAllowed(value);
    } catch (_) {
      if (mounted) setState(() => _allowed = !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.explicit_outlined),
      title: const Text('Show NSFW sources'),
      subtitle: const Text('Include 18+ extensions and sources in listings'),
      value: _allowed ?? true,
      onChanged: _allowed == null ? null : (value) => unawaited(_toggle(value)),
    );
  }
}

class _AppSettingsPage extends StatelessWidget {
  const _AppSettingsPage({
    required this.preferences,
    required this.updateService,
  });

  final PreferencesService preferences;
  final UpdateService updateService;

  @override
  Widget build(BuildContext context) {
    return _SettingsPageScaffold(
      title: 'App',
      preferences: preferences,
      childrenBuilder: (context, prefs) => [
        const _SectionTitle('Display'),
        _SelectionTile<ThemeMode>(
          icon: Icons.brightness_4_outlined,
          title: 'Theme',
          value: prefs.themeMode,
          values: ThemeMode.values,
          labelBuilder: (value) => _formatEnumLabel(value.name),
          onChanged: (value) {
            if (value != null) prefs.setThemeMode(value);
          },
        ),
        _PalettePicker(
          value: prefs.themeColorPalette,
          onChanged: prefs.setThemeColorPalette,
        ),
        _SelectionTile<AppStartTab>(
          icon: Icons.first_page_outlined,
          title: 'Start screen',
          value: prefs.appStartTab,
          values: AppStartTab.values,
          labelBuilder: _appStartTabLabel,
          onChanged: (value) {
            if (value != null) prefs.setAppStartTab(value);
          },
        ),
        const SizedBox(height: 10),
        const _SectionTitle('Diagnostics'),
        SwitchListTile(
          secondary: const Icon(Icons.code),
          title: const Text('Developer error details'),
          value: prefs.developerMode,
          onChanged: prefs.setDeveloperMode,
        ),
        const SizedBox(height: 10),
        const _SectionTitle('Updates'),
        SwitchListTile(
          secondary: const Icon(Icons.update),
          title: const Text('Check on startup'),
          subtitle: const Text('Look for new GitHub releases automatically'),
          value: prefs.automaticUpdateChecks,
          onChanged: prefs.setAutomaticUpdateChecks,
        ),
        _UpdateCheckTile(updateService: updateService),
      ],
    );
  }
}

class _UpdateCheckTile extends StatefulWidget {
  const _UpdateCheckTile({required this.updateService});

  final UpdateService updateService;

  @override
  State<_UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<_UpdateCheckTile> {
  bool _checking = false;

  Future<void> _checkForUpdates() async {
    if (_checking) {
      return;
    }

    setState(() => _checking = true);
    try {
      final result = await widget.updateService.checkForUpdate();
      if (!mounted) {
        return;
      }
      if (result.isUpdateAvailable) {
        await showUpdateAvailableDialog(context, result, widget.updateService);
      } else {
        await showNoUpdateDialog(context, result);
      }
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error, title: 'Update check failed');
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _checking
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : const Icon(Icons.system_update_alt),
      title: const Text('Check for updates'),
      subtitle: Text('Current version ${widget.updateService.currentVersion}'),
      trailing: const Icon(Icons.chevron_right),
      enabled: !_checking,
      onTap: _checking ? null : () => unawaited(_checkForUpdates()),
    );
  }
}

class _PlaybackSettingsPage extends StatelessWidget {
  const _PlaybackSettingsPage({required this.preferences});

  final PreferencesService preferences;

  @override
  Widget build(BuildContext context) {
    return _SettingsPageScaffold(
      title: 'Playback',
      preferences: preferences,
      childrenBuilder: (context, prefs) => [
        const _SectionTitle('Defaults'),
        _SelectionTile<double>(
          icon: Icons.slow_motion_video,
          title: 'Default speed',
          value: prefs.defaultPlaybackSpeed,
          values: prefs.playbackSpeeds,
          labelBuilder: (value) => '${_formatSpeed(value)}x',
          onChanged: (value) {
            if (value == null) return;
            prefs.setDefaultSpeedIndex(prefs.playbackSpeeds.indexOf(value));
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.accessible_forward),
          title: const Text('Cursed speeds'),
          value: prefs.cursedSpeeds,
          onChanged: prefs.setCursedSpeeds,
        ),
        _SelectionTile<ResizeModeSetting>(
          icon: Icons.fullscreen,
          title: 'Resize mode',
          value: prefs.resizeMode,
          values: ResizeModeSetting.values,
          labelBuilder: (value) => _formatEnumLabel(value.name),
          onChanged: (value) {
            if (value != null) prefs.setResizeMode(value);
          },
        ),
        const SizedBox(height: 10),
        const _SectionTitle('Player behavior'),
        SwitchListTile(
          secondary: const Icon(Icons.screen_rotation_alt),
          title: const Text('Always landscape player'),
          value: prefs.alwaysLandscape,
          onChanged: prefs.setAlwaysLandscape,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.dns_outlined),
          title: const Text('Select server before playing'),
          value: prefs.selectServerBeforePlaying,
          onChanged: prefs.setSelectServerBeforePlaying,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.history),
          title: const Text('Resume playback'),
          subtitle: const Text('Continue from your last watched position'),
          value: prefs.resumePlayback,
          onChanged: prefs.setResumePlayback,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.skip_next),
          title: const Text('Autoplay next episode'),
          value: prefs.autoPlayNext,
          onChanged: prefs.setAutoPlayNext,
        ),
        const SizedBox(height: 10),
        const _SectionTitle('Controls'),
        _SelectionTile<int>(
          icon: Icons.visibility_off_outlined,
          title: 'Hide controls after',
          value: prefs.playerControlsTimeoutSeconds,
          values: const [2, 4, 6, 8, 10, 15],
          labelBuilder: (value) => '$value seconds',
          onChanged: (value) {
            if (value != null) prefs.setPlayerControlsTimeoutSeconds(value);
          },
        ),
        ListTile(
          leading: const Icon(Icons.fast_forward),
          title: Text('Seek time: ${prefs.seekTimeSeconds}s'),
          subtitle: Slider(
            min: 5,
            max: 120,
            divisions: 23,
            value: prefs.seekTimeSeconds.toDouble(),
            label: '${prefs.seekTimeSeconds}s',
            onChanged: (value) => prefs.setSeekTimeSeconds(value.round()),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.touch_app_outlined),
          title: const Text('Double-tap seek'),
          value: prefs.doubleTapSeek,
          onChanged: prefs.setDoubleTapSeek,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.timer_outlined),
          title: const Text('Show remaining time'),
          subtitle: const Text('Show time left beside total duration'),
          value: prefs.showRemainingDuration,
          onChanged: prefs.setShowRemainingDuration,
        ),
      ],
    );
  }
}

class _SubtitleSettingsPage extends StatelessWidget {
  const _SubtitleSettingsPage({required this.preferences});

  final PreferencesService preferences;

  @override
  Widget build(BuildContext context) {
    return _SettingsPageScaffold(
      title: 'Subtitles',
      preferences: preferences,
      childrenBuilder: (context, prefs) => [
        const _SectionTitle('Display'),
        SwitchListTile(
          secondary: const Icon(Icons.subtitles_outlined),
          title: const Text('Show subtitles'),
          value: prefs.subtitlesEnabled,
          onChanged: prefs.setSubtitlesEnabled,
        ),
        ListTile(
          leading: const Icon(Icons.format_size),
          title: Text('Subtitle size: ${prefs.subtitleFontSize}'),
          subtitle: Slider(
            min: 12,
            max: 42,
            divisions: 30,
            value: prefs.subtitleFontSize.toDouble(),
            label: prefs.subtitleFontSize.toString(),
            onChanged: (value) => prefs.setSubtitleFontSize(value.round()),
          ),
        ),
        const SizedBox(height: 10),
        const _SectionTitle('Timestamps'),
        SwitchListTile(
          secondary: const Icon(Icons.timer_outlined),
          title: const Text('Timestamps enabled'),
          value: prefs.timeStampsEnabled,
          onChanged: prefs.setTimeStampsEnabled,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.smart_button_outlined),
          title: const Text('Show timestamp skip button'),
          value: prefs.showTimeStampButton,
          onChanged: prefs.setShowTimeStampButton,
        ),
      ],
    );
  }
}

class _DataSettingsPage extends StatelessWidget {
  const _DataSettingsPage({
    required this.preferences,
    required this.watchHistoryService,
    required this.downloadService,
    required this.mangaDownloadService,
    this.services,
  });

  final PreferencesService preferences;
  final WatchHistoryService watchHistoryService;
  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;
  final AppServices? services;

  @override
  Widget build(BuildContext context) {
    return _SettingsPageScaffold(
      title: 'Data and privacy',
      preferences: preferences,
      childrenBuilder: (context, prefs) => [
        const _SectionTitle('Privacy'),
        SwitchListTile(
          secondary: const Icon(Icons.visibility_off_outlined),
          title: const Text('Incognito mode'),
          subtitle: const Text(
            'Do not save watch progress or send automatic tracker updates',
          ),
          value: prefs.incognitoMode,
          onChanged: prefs.setIncognitoMode,
        ),
        const SizedBox(height: 10),
        const _SectionTitle('Downloads'),
        _SelectionTile<DownloadQualityPreference>(
          icon: Icons.high_quality_outlined,
          title: 'Download quality',
          value: prefs.downloadQualityPreference,
          values: DownloadQualityPreference.values,
          labelBuilder: _downloadQualityLabel,
          onChanged: (value) {
            if (value != null) prefs.setDownloadQualityPreference(value);
          },
        ),
        _DownloadedMediaTile(
          downloadService: downloadService,
          mangaDownloadService: mangaDownloadService,
        ),
        if (services != null) ...[
          const SizedBox(height: 10),
          const _SectionTitle('Backup and restore'),
          _BackupSettingsSection(service: services!.backupService),
        ],
        const SizedBox(height: 10),
        const _SectionTitle('History'),
        _ClearHistoryTile(service: watchHistoryService),
      ],
    );
  }
}

class _BackupSettingsSection extends StatefulWidget {
  const _BackupSettingsSection({required this.service});

  final BackupService service;

  @override
  State<_BackupSettingsSection> createState() => _BackupSettingsSectionState();
}

class _BackupSettingsSectionState extends State<_BackupSettingsSection> {
  bool _busy = false;

  Future<void> _export() async {
    final password = await _requestBackupPassword(context, confirm: true);
    if (password == null || !mounted) return;
    final date = DateTime.now().toIso8601String().split('T').first;
    final fileName = 'anikin-backup-$date.anikinbackup';
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await widget.service.create(password);
      await XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'application/octet-stream',
      ).saveTo(location.path);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Encrypted backup saved')));
      }
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          error.toString(),
          title: 'Unable to create backup',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Anikin backups',
          extensions: ['anikinbackup'],
          mimeTypes: ['application/octet-stream'],
          uniformTypeIdentifiers: ['public.data'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    final password = await _requestBackupPassword(context);
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await widget.service.restore(
        await file.readAsBytes(),
        password,
      );
      if (!mounted) return;
      await showAppMessageDialog(
        context,
        title: 'Backup restored',
        message:
            'Merged ${result.preferences} settings and ${result.records} '
            'library records. Restart Anikin to reload every service.',
        icon: Icons.restore_outlined,
      );
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          error.toString(),
          title: 'Unable to restore backup',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Create encrypted backup'),
          subtitle: const Text(
            'Settings, history, search, follows, and alerts. Account credentials '
            'and downloaded media are never exported.',
          ),
          trailing: _busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          enabled: !_busy,
          onTap: _busy ? null : _export,
        ),
        ListTile(
          leading: const Icon(Icons.settings_backup_restore),
          title: const Text('Restore encrypted backup'),
          subtitle: const Text(
            'Merge portable data without deleting current data',
          ),
          enabled: !_busy,
          onTap: _busy ? null : _restore,
        ),
      ],
    );
  }
}

Future<String?> _requestBackupPassword(
  BuildContext context, {
  bool confirm = false,
}) async {
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();
  String? error;
  var obscure = true;
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(confirm ? 'Protect your backup' : 'Unlock backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              autofocus: true,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: error,
                suffixIcon: IconButton(
                  onPressed: () => setDialogState(() => obscure = !obscure),
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                ),
              ),
            ),
            if (confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: confirmationController,
                obscureText: obscure,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Passwords cannot be recovered. Use at least 8 characters.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          AppDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppDialogAction(
            label: confirm ? 'Continue' : 'Unlock',
            onPressed: () {
              final password = passwordController.text;
              if (password.length < 8) {
                setDialogState(() => error = 'Use at least 8 characters');
                return;
              }
              if (confirm && password != confirmationController.text) {
                setDialogState(() => error = 'Passwords do not match');
                return;
              }
              Navigator.of(context).pop(password);
            },
          ),
        ],
      ),
    ),
  );
  passwordController.dispose();
  confirmationController.dispose();
  return result;
}

class _NotificationSettingsPage extends StatefulWidget {
  const _NotificationSettingsPage({required this.services});

  final AppServices services;

  @override
  State<_NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<_NotificationSettingsPage> {
  bool _busy = false;

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _busy = true);
    try {
      final granted = await widget.services.notificationCoordinator.setEnabled(
        enabled,
      );
      if (!mounted) return;
      if (enabled && !granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission was not granted'),
          ),
        );
      } else if (!enabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Release checks paused. Your follows were kept.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await widget.services.notificationCoordinator.syncAndRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Release subscriptions refreshed')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateAniListSetting({
    required bool enabled,
    required NotificationSubscriptionOrigin origin,
    required Future<void> update,
  }) async {
    setState(() => _busy = true);
    try {
      await update;
      if (!enabled) {
        await widget.services.notificationSubscriptions.clearOrigin(origin);
      } else if (widget.services.preferences.notificationsEnabled) {
        await widget.services.notificationCoordinator.syncAndRefresh();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSubscriptions() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _NotificationSubscriptionsPage(services: widget.services),
      ),
    );
  }

  void _openInbox() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _NotificationInboxPage(services: widget.services),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final preferences = services.preferences;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            preferences,
            services.notificationSubscriptions,
          ]),
          builder: (context, _) => FutureBuilder<List<NotificationSubscription>>(
            future: services.notificationSubscriptions.all(),
            builder: (context, subscriptionsSnapshot) {
              final subscriptions = subscriptionsSnapshot.data ?? const [];
              final titleCount = _subscriptionTitleCount(subscriptions);
              final manualCount = subscriptions
                  .where(
                    (item) =>
                        item.origin ==
                        NotificationSubscriptionOrigin.manual.key,
                  )
                  .length;
              final aniListConnected = services.trackingService.isLoggedIn(
                TrackingProvider.anilist,
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _NotificationStatusCard(
                    enabled: preferences.notificationsEnabled,
                    busy: _busy,
                    titleCount: titleCount,
                    onChanged: _setEnabled,
                  ),
                  const _SectionTitle('Follow automatically'),
                  if (!aniListConnected)
                    const _NotificationHint(
                      icon: Icons.link_off,
                      text:
                          'Connect AniList in Tracking and sync to follow list entries automatically.',
                    ),
                  SwitchListTile(
                    secondary: const Icon(Icons.playlist_play_outlined),
                    title: const Text('Watching and reading'),
                    subtitle: const Text(
                      'Follow titles in your AniList Current lists',
                    ),
                    value: preferences.notifyAniListCurrent,
                    onChanged:
                        _busy ||
                            (!aniListConnected &&
                                !preferences.notifyAniListCurrent)
                        ? null
                        : (value) => _updateAniListSetting(
                            enabled: value,
                            origin:
                                NotificationSubscriptionOrigin.aniListCurrent,
                            update: preferences.setNotifyAniListCurrent(value),
                          ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.event_note_outlined),
                    title: const Text('Planning'),
                    subtitle: const Text(
                      'Follow titles in your AniList Planning lists',
                    ),
                    value: preferences.notifyAniListPlanning,
                    onChanged:
                        _busy ||
                            (!aniListConnected &&
                                !preferences.notifyAniListPlanning)
                        ? null
                        : (value) => _updateAniListSetting(
                            enabled: value,
                            origin:
                                NotificationSubscriptionOrigin.aniListPlanning,
                            update: preferences.setNotifyAniListPlanning(value),
                          ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.favorite_border),
                    title: const Text('Favorites'),
                    subtitle: const Text('Follow favorite anime and manga'),
                    value: preferences.notifyAniListFavorites,
                    onChanged:
                        _busy ||
                            (!aniListConnected &&
                                !preferences.notifyAniListFavorites)
                        ? null
                        : (value) => _updateAniListSetting(
                            enabled: value,
                            origin:
                                NotificationSubscriptionOrigin.aniListFavorite,
                            update: preferences.setNotifyAniListFavorites(
                              value,
                            ),
                          ),
                  ),
                  _SettingsNavigationTile(
                    icon: Icons.notifications_none,
                    title: 'Manage followed titles',
                    subtitle: titleCount == 0
                        ? 'No titles followed yet'
                        : '$titleCount title${titleCount == 1 ? '' : 's'} · $manualCount followed manually',
                    onTap: _openSubscriptions,
                  ),
                  const SizedBox(height: 10),
                  const _SectionTitle('Delivery'),
                  _SelectionTile<NotificationPrivacy>(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Lock-screen privacy',
                    value: preferences.notificationPrivacy,
                    values: NotificationPrivacy.values,
                    labelBuilder: (value) => switch (value) {
                      NotificationPrivacy.full => 'Title and release details',
                      NotificationPrivacy.titleOnly => 'Title only',
                      NotificationPrivacy.generic => 'Hide title and details',
                    },
                    onChanged: (value) {
                      if (value != null) {
                        preferences.setNotificationPrivacy(value);
                      }
                    },
                  ),
                  _SelectionTile<int>(
                    icon: Icons.refresh_outlined,
                    title: 'Background check interval',
                    value: preferences.notificationRefreshHours,
                    values: const [1, 3, 6, 12, 24],
                    labelBuilder: (value) =>
                        value == 1 ? 'Hourly' : 'Every $value hours',
                    onChanged: (value) async {
                      if (value == null) return;
                      await preferences.setNotificationRefreshHours(value);
                      await services.notificationCoordinator.reschedule();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Refresh now'),
                    subtitle: const Text(
                      'Sync selected AniList lists and check for releases',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: preferences.notificationsEnabled && !_busy,
                    onTap: _refresh,
                  ),
                  const SizedBox(height: 10),
                  const _SectionTitle('History'),
                  FutureBuilder<List<AppNotification>>(
                    future:
                        (services.database.select(
                              services.database.appNotifications,
                            )..orderBy([
                              (entry) => OrderingTerm.desc(entry.eventAt),
                            ]))
                            .get(),
                    builder: (context, snapshot) {
                      final alerts = snapshot.data ?? const [];
                      final unread = alerts
                          .where((item) => !item.isRead)
                          .length;
                      return _SettingsNavigationTile(
                        icon: Icons.inbox_outlined,
                        title: 'Notification inbox',
                        subtitle: alerts.isEmpty
                            ? 'No release alerts yet'
                            : '${alerts.length} alert${alerts.length == 1 ? '' : 's'}${unread == 0 ? '' : ' · $unread unread'}',
                        onTap: _openInbox,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationStatusCard extends StatelessWidget {
  const _NotificationStatusCard({
    required this.enabled,
    required this.busy,
    required this.titleCount,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final int titleCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: !busy,
      toggled: enabled,
      label: enabled ? 'Disable release alerts' : 'Enable release alerts',
      child: Card(
        color: enabled
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHigh,
        margin: const EdgeInsets.only(bottom: 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : () => onChanged(!enabled),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: enabled
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  foregroundColor: enabled
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          enabled
                              ? Icons.notifications_active
                              : Icons.notifications_paused_outlined,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enabled
                            ? 'Release alerts are on'
                            : 'Release alerts paused',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        enabled
                            ? '$titleCount followed title${titleCount == 1 ? '' : 's'} will be checked.'
                            : 'Your $titleCount followed ${titleCount == 1 ? 'title stays' : 'titles stay'} saved until you turn alerts back on.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: Switch(
                      value: enabled,
                      onChanged: busy ? null : (_) {},
                    ),
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

class _NotificationHint extends StatelessWidget {
  const _NotificationHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

enum _SubscriptionFilter { all, manual, aniList, paused }

class _NotificationSubscriptionsPage extends StatefulWidget {
  const _NotificationSubscriptionsPage({required this.services});

  final AppServices services;

  @override
  State<_NotificationSubscriptionsPage> createState() =>
      _NotificationSubscriptionsPageState();
}

class _NotificationSubscriptionsPageState
    extends State<_NotificationSubscriptionsPage> {
  String _query = '';
  _SubscriptionFilter _filter = _SubscriptionFilter.all;

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return Scaffold(
      appBar: AppBar(title: const Text('Followed titles')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            services.preferences,
            services.notificationSubscriptions,
          ]),
          builder: (context, _) {
            return FutureBuilder<List<NotificationSubscription>>(
              future: services.notificationSubscriptions.all(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final groups = _groupSubscriptions(snapshot.data ?? const [])
                    .where(_matchesFilter)
                    .where(
                      (group) => group.title.toLowerCase().contains(
                        _query.trim().toLowerCase(),
                      ),
                    )
                    .toList();
                return Column(
                  children: [
                    if (!services.preferences.notificationsEnabled)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _NotificationHint(
                          icon: Icons.pause_circle_outline,
                          text:
                              'All release checks are paused. These follows are kept and will resume when notifications are enabled.',
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: SearchBar(
                        leading: const Icon(Icons.search),
                        hintText: 'Search followed titles',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<_SubscriptionFilter>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: _SubscriptionFilter.all,
                            label: Text('All'),
                          ),
                          ButtonSegment(
                            value: _SubscriptionFilter.manual,
                            label: Text('Manual'),
                          ),
                          ButtonSegment(
                            value: _SubscriptionFilter.aniList,
                            label: Text('AniList'),
                          ),
                          ButtonSegment(
                            value: _SubscriptionFilter.paused,
                            label: Text('Paused'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (value) =>
                            setState(() => _filter = value.first),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: groups.isEmpty
                          ? const EmptyState(
                              icon: Icons.notifications_none,
                              title: 'No followed titles here',
                              message:
                                  'Use the bell on a media page or enable an AniList list above.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                              itemCount: groups.length,
                              itemBuilder: (context, index) =>
                                  _SubscriptionGroupCard(
                                    group: groups[index],
                                    onEnabledChanged: (value) => services
                                        .notificationSubscriptions
                                        .setMediaEnabled(
                                          groups[index].mediaId,
                                          groups[index].mediaType,
                                          value,
                                        ),
                                    onRemoveManual: groups[index].hasManual
                                        ? () => services
                                              .notificationSubscriptions
                                              .unsubscribeManual(
                                                groups[index].mediaId,
                                                groups[index].mediaType,
                                              )
                                        : null,
                                  ),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _matchesFilter(_SubscriptionGroup group) {
    return switch (_filter) {
      _SubscriptionFilter.all => true,
      _SubscriptionFilter.manual => group.hasManual,
      _SubscriptionFilter.aniList => group.hasAniList,
      _SubscriptionFilter.paused => !group.enabled,
    };
  }
}

class _SubscriptionGroupCard extends StatelessWidget {
  const _SubscriptionGroupCard({
    required this.group,
    required this.onEnabledChanged,
    this.onRemoveManual,
  });

  final _SubscriptionGroup group;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback? onRemoveManual;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 66,
                child: group.coverUrl == null
                    ? ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          group.mediaType == 'anime'
                              ? Icons.movie_outlined
                              : Icons.menu_book_outlined,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: group.coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            const Icon(Icons.image_not_supported_outlined),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final origin in group.origins)
                        _OriginChip(label: _originLabel(origin)),
                    ],
                  ),
                ],
              ),
            ),
            Switch(value: group.enabled, onChanged: onEnabledChanged),
            if (onRemoveManual != null)
              PopupMenuButton<String>(
                tooltip: 'Subscription actions',
                onSelected: (_) => onRemoveManual?.call(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'remove_manual',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.notifications_off_outlined),
                      title: Text('Remove manual follow'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OriginChip extends StatelessWidget {
  const _OriginChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _SubscriptionGroup {
  const _SubscriptionGroup({
    required this.mediaId,
    required this.mediaType,
    required this.title,
    required this.coverUrl,
    required this.enabled,
    required this.origins,
  });

  final int mediaId;
  final String mediaType;
  final String title;
  final String? coverUrl;
  final bool enabled;
  final List<String> origins;

  bool get hasManual =>
      origins.contains(NotificationSubscriptionOrigin.manual.key);
  bool get hasAniList => origins.any((origin) => origin != 'manual');
}

List<_SubscriptionGroup> _groupSubscriptions(
  List<NotificationSubscription> subscriptions,
) {
  final grouped = <String, List<NotificationSubscription>>{};
  for (final item in subscriptions) {
    grouped
        .putIfAbsent('${item.mediaType}:${item.mediaId}', () => [])
        .add(item);
  }
  return grouped.values.map((rows) {
    final first = rows.first;
    final title = rows
        .map((item) => item.mediaTitle.trim())
        .firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => 'Media ${first.mediaId}',
        );
    final covers = rows
        .map((item) => item.coverUrl)
        .whereType<String>()
        .where((value) => value.isNotEmpty);
    return _SubscriptionGroup(
      mediaId: first.mediaId,
      mediaType: first.mediaType,
      title: title,
      coverUrl: covers.isEmpty ? null : covers.first,
      enabled: rows.any((item) => item.enabled),
      origins: rows.map((item) => item.origin).toSet().toList(),
    );
  }).toList()..sort(
    (left, right) =>
        left.title.toLowerCase().compareTo(right.title.toLowerCase()),
  );
}

int _subscriptionTitleCount(List<NotificationSubscription> subscriptions) {
  return subscriptions
      .map((item) => '${item.mediaType}:${item.mediaId}')
      .toSet()
      .length;
}

String _originLabel(String origin) {
  return switch (origin) {
    'manual' => 'Manual',
    'anilist_current' => 'Current',
    'anilist_planning' => 'Planning',
    'anilist_favorite' => 'Favorite',
    _ => origin.replaceAll('_', ' '),
  };
}

class _NotificationInboxPage extends StatefulWidget {
  const _NotificationInboxPage({required this.services});

  final AppServices services;

  @override
  State<_NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<_NotificationInboxPage> {
  late Future<List<AppNotification>> _alertsFuture = _load();

  Future<List<AppNotification>> _load() {
    return (widget.services.database.select(
      widget.services.database.appNotifications,
    )..orderBy([(entry) => OrderingTerm.desc(entry.eventAt)])).get();
  }

  void _reload() {
    setState(() => _alertsFuture = _load());
  }

  Future<void> _markRead(AppNotification alert) async {
    if (alert.isRead) return;
    await (widget.services.database.update(
      widget.services.database.appNotifications,
    )..where((entry) => entry.id.equals(alert.id))).write(
      const AppNotificationsCompanion(isRead: Value(true)),
    );
    _reload();
  }

  Future<void> _markAllRead() async {
    await widget.services.database
        .update(widget.services.database.appNotifications)
        .write(const AppNotificationsCompanion(isRead: Value(true)));
    _reload();
  }

  Future<void> _clear() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Clear notification history?',
      message:
          'This removes the inbox history. It does not remove followed titles.',
      confirmLabel: 'Clear',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (!confirmed) return;
    await widget.services.database
        .delete(widget.services.database.appNotifications)
        .go();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification inbox'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all),
          ),
          IconButton(
            tooltip: 'Clear history',
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _alertsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final alerts = snapshot.data ?? const [];
          if (alerts.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No alerts yet',
              message:
                  'New episodes, chapters, and airing reminders appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: alerts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Card(
                color: alert.isRead
                    ? null
                    : Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: Icon(
                    alert.category.contains('chapter')
                        ? Icons.menu_book_outlined
                        : Icons.notifications_outlined,
                  ),
                  title: Text(
                    alert.title,
                    style: TextStyle(
                      fontWeight: alert.isRead
                          ? FontWeight.normal
                          : FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.body),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, y · jm').format(alert.eventAt),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  onTap: () => _markRead(alert),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ClearHistoryTile extends StatefulWidget {
  const _ClearHistoryTile({required this.service});

  final WatchHistoryService service;

  @override
  State<_ClearHistoryTile> createState() => _ClearHistoryTileState();
}

class _ClearHistoryTileState extends State<_ClearHistoryTile> {
  int? _count;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_handleHistoryChanged);
    unawaited(_loadCount());
  }

  @override
  void didUpdateWidget(covariant _ClearHistoryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service == widget.service) {
      return;
    }
    oldWidget.service.removeListener(_handleHistoryChanged);
    widget.service.addListener(_handleHistoryChanged);
    unawaited(_loadCount());
  }

  @override
  void dispose() {
    widget.service.removeListener(_handleHistoryChanged);
    super.dispose();
  }

  void _handleHistoryChanged() {
    unawaited(_loadCount());
  }

  Future<void> _loadCount() async {
    final count = (await widget.service.getAll()).length;
    if (mounted) {
      setState(() => _count = count);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Clear watch history?',
      message:
          'All saved episode positions will be removed. Downloads and '
          'tracker lists are not affected.',
      confirmLabel: 'Clear',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (!confirmed) {
      return;
    }

    await widget.service.clear();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Watch history cleared')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    return ListTile(
      leading: const Icon(Icons.delete_sweep_outlined),
      title: const Text('Clear watch history'),
      subtitle: Text(
        count == null
            ? 'Checking saved progress…'
            : count == 0
            ? 'No saved episode progress'
            : '$count saved ${count == 1 ? 'episode' : 'episodes'}',
      ),
      enabled: count != null && count > 0,
      onTap: count != null && count > 0 ? () => unawaited(_clear()) : null,
    );
  }
}

class _DownloadedMediaTile extends StatelessWidget {
  const _DownloadedMediaTile({
    required this.downloadService,
    required this.mangaDownloadService,
  });

  final DownloadService downloadService;
  final MangaDownloadService mangaDownloadService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([downloadService, mangaDownloadService]),
      builder: (context, _) {
        final episodeDownloads = downloadService.items;
        final mangaDownloads = mangaDownloadService.items;
        final itemCount = episodeDownloads.length + mangaDownloads.length;
        final bytes =
            episodeDownloads.fold<int>(0, (sum, item) => sum + item.bytes) +
            mangaDownloads.fold<int>(0, (sum, item) => sum + item.bytes);
        return ListTile(
          leading: const Icon(Icons.download_done_outlined),
          title: const Text('Downloaded media'),
          subtitle: Text(
            itemCount == 0
                ? 'No completed downloads'
                : '$itemCount ${itemCount == 1 ? 'item' : 'items'} • '
                      '${_formatStorageBytes(bytes)}',
          ),
          trailing: itemCount == 0
              ? null
              : TextButton(
                  onPressed: () => unawaited(_clear(context)),
                  child: const Text('Clear'),
                ),
        );
      },
    );
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete all downloaded media?',
      message:
          'Completed anime episodes and manga chapters will be permanently '
          'removed from this device.',
      confirmLabel: 'Delete all',
      destructive: true,
      icon: Icons.delete_forever_outlined,
    );
    if (!confirmed) {
      return;
    }

    final episodeIds = downloadService.items.map((item) => item.id).toList();
    final mangaIds = mangaDownloadService.items.map((item) => item.id).toList();
    for (final id in episodeIds) {
      await downloadService.delete(id);
    }
    for (final id in mangaIds) {
      await mangaDownloadService.delete(id);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Downloaded media deleted')));
    }
  }
}

class _ReaderSettingsPage extends StatelessWidget {
  const _ReaderSettingsPage({required this.preferences});

  final PreferencesService preferences;

  @override
  Widget build(BuildContext context) {
    return _SettingsPageScaffold(
      title: 'Reader',
      preferences: preferences,
      childrenBuilder: (context, prefs) => [
        const _SectionTitle('Layout'),
        _SelectionTile<MangaReadingMode>(
          icon: Icons.chrome_reader_mode_outlined,
          title: 'Reading mode',
          value: prefs.mangaReadingMode,
          values: MangaReadingMode.values,
          labelBuilder: _mangaReadingModeLabel,
          onChanged: (value) {
            if (value != null) prefs.setMangaReadingMode(value);
          },
        ),
        _SelectionTile<MangaPageFitMode>(
          icon: Icons.fit_screen_outlined,
          title: 'Page fit',
          value: prefs.mangaPageFitMode,
          values: MangaPageFitMode.values,
          labelBuilder: (value) => switch (value) {
            MangaPageFitMode.width => 'Fit width',
            MangaPageFitMode.contain => 'Fit screen',
          },
          onChanged: (value) {
            if (value != null) prefs.setMangaPageFitMode(value);
          },
        ),
        _SelectionTile<MangaReaderBackground>(
          icon: Icons.format_color_fill_outlined,
          title: 'Background',
          value: prefs.mangaReaderBackground,
          values: MangaReaderBackground.values,
          labelBuilder: (value) => _formatEnumLabel(value.name),
          onChanged: (value) {
            if (value != null) prefs.setMangaReaderBackground(value);
          },
        ),
        ListTile(
          leading: const Icon(Icons.space_bar),
          title: Text('Page gap: ${prefs.mangaPageGap.round()}'),
          subtitle: Slider(
            min: 0,
            max: 24,
            divisions: 12,
            value: prefs.mangaPageGap,
            label: prefs.mangaPageGap.round().toString(),
            onChanged: prefs.setMangaPageGap,
          ),
        ),
        const SizedBox(height: 10),
        const _SectionTitle('Reading behavior'),
        SwitchListTile(
          secondary: const Icon(Icons.lightbulb_outline),
          title: const Text('Keep screen on'),
          value: prefs.mangaKeepScreenOn,
          onChanged: prefs.setMangaKeepScreenOn,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.numbers_outlined),
          title: const Text('Show page number'),
          value: prefs.mangaShowPageNumber,
          onChanged: prefs.setMangaShowPageNumber,
        ),
        _SelectionTile<int>(
          icon: Icons.cached_outlined,
          title: 'Pages to preload',
          value: prefs.mangaPreloadPages,
          values: const [0, 2, 4, 6, 8, 10, 12],
          labelBuilder: (value) => value == 0 ? 'Off' : '$value pages',
          onChanged: (value) {
            if (value != null) prefs.setMangaPreloadPages(value);
          },
        ),
        const SizedBox(height: 10),
        const _SectionTitle('Novels'),
        _SelectionTile<NovelReaderTheme>(
          icon: Icons.palette_outlined,
          title: 'Novel theme',
          value: prefs.novelReaderTheme,
          values: NovelReaderTheme.values,
          labelBuilder: (value) => _formatEnumLabel(value.name),
          onChanged: (value) {
            if (value != null) prefs.setNovelReaderTheme(value);
          },
        ),
        ListTile(
          leading: const Icon(Icons.format_size),
          title: Text('Novel text size: ${prefs.novelFontSize.round()}'),
          subtitle: Slider(
            min: 12,
            max: 36,
            divisions: 24,
            value: prefs.novelFontSize,
            onChanged: prefs.setNovelFontSize,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.format_line_spacing),
          title: Text(
            'Novel line height: ${prefs.novelLineHeight.toStringAsFixed(1)}',
          ),
          subtitle: Slider(
            min: 1.1,
            max: 2.4,
            divisions: 13,
            value: prefs.novelLineHeight,
            onChanged: prefs.setNovelLineHeight,
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.lightbulb_outline),
          title: const Text('Keep screen on for novels'),
          value: prefs.novelKeepScreenOn,
          onChanged: prefs.setNovelKeepScreenOn,
        ),
      ],
    );
  }
}

class _TrackingSettingsPage extends StatelessWidget {
  const _TrackingSettingsPage({required this.trackingService});

  final TrackingService trackingService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking and sync')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: trackingService,
          builder: (context, _) {
            return ListTileTheme.merge(
              shape: _settingsTileShape,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  const _SectionTitle('Sync'),
                  SwitchListTile(
                    secondary: const Icon(Icons.cloud_sync_outlined),
                    title: const Text('Sync completed episodes'),
                    value: trackingService.progressSyncEnabled,
                    onChanged: (value) => unawaited(
                      trackingService.setProgressSyncEnabled(value),
                    ),
                  ),
                  _SelectionTile<TrackingProvider>(
                    icon: Icons.account_tree_outlined,
                    title: 'Primary provider',
                    value: trackingService.primaryProvider,
                    values: TrackingProvider.values,
                    labelBuilder: (provider) => provider.label,
                    onChanged: (provider) {
                      if (provider != null) {
                        unawaited(trackingService.setPrimaryProvider(provider));
                      }
                    },
                  ),
                  _SelectionTile<TrackingSyncStrategy>(
                    icon: Icons.alt_route,
                    title: 'Sync behavior',
                    value: trackingService.syncStrategy,
                    values: TrackingSyncStrategy.values,
                    labelBuilder: (strategy) => strategy.label,
                    onChanged: (strategy) {
                      if (strategy != null) {
                        unawaited(trackingService.setSyncStrategy(strategy));
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.pending_actions_outlined),
                    title: Text(
                      'Queued updates: ${trackingService.pendingUpdateCount}',
                    ),
                    subtitle: trackingService.lastMessage == null
                        ? null
                        : Text(trackingService.lastMessage!),
                    trailing: IconButton(
                      tooltip: 'Retry queued sync',
                      onPressed: trackingService.pendingUpdateCount == 0
                          ? null
                          : () => unawaited(
                              _retryPending(context, trackingService),
                            ),
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _SectionTitle('Services'),
                  for (final provider in TrackingProvider.values)
                    _TrackingProviderTile(
                      provider: provider,
                      trackingService: trackingService,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _retryPending(
    BuildContext context,
    TrackingService service,
  ) async {
    await service.retryPendingUpdates();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tracker sync retried')));
    }
  }
}

class _TrackingProviderTile extends StatelessWidget {
  const _TrackingProviderTile({
    required this.provider,
    required this.trackingService,
  });

  final TrackingProvider provider;
  final TrackingService trackingService;

  @override
  Widget build(BuildContext context) {
    final account = trackingService.accountFor(provider);
    final loggedIn = trackingService.isLoggedIn(provider);
    return ListTile(
      leading: Icon(_providerIcon(provider)),
      title: Text(provider.label),
      subtitle: Text(
        loggedIn
            ? 'Logged in as ${account?.username ?? account?.userId ?? 'account'}'
            : account?.authExpired == true
            ? 'Login expired'
            : 'Not logged in',
      ),
      trailing: loggedIn
          ? TextButton(
              onPressed: () => _confirmLogout(context),
              child: const Text('Logout'),
            )
          : FilledButton(
              onPressed: () => _login(context),
              child: const Text('Login'),
            ),
    );
  }

  Future<void> _login(BuildContext context) async {
    try {
      if (provider == TrackingProvider.kitsu) {
        await _showKitsuLogin(context);
      } else {
        await trackingService.loginWithBrowser(provider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Continue ${provider.label} login in browser'),
            ),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        await showErrorDialog(
          context,
          error,
          title: '${provider.label} login failed',
        );
      }
    }
  }

  Future<void> _showKitsuLogin(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kitsu login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.email_outlined),
                  labelText: 'Email',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline),
                  labelText: 'Password',
                ),
                onSubmitted: (_) => Navigator.of(context).pop(true),
              ),
            ],
          ),
          actions: [
            AppDialogAction(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            AppDialogAction(
              label: 'Login',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      if (submitted != true) {
        return;
      }
      await trackingService.loginKitsu(
        username: emailController.text.trim(),
        password: passwordController.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Logged in to Kitsu')));
      }
    } finally {
      emailController.dispose();
      passwordController.dispose();
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Logout of ${provider.label}?',
      confirmLabel: 'Logout',
      destructive: true,
      icon: Icons.logout,
    );
    if (confirmed) {
      await trackingService.logout(provider);
    }
  }

  IconData _providerIcon(TrackingProvider provider) {
    return switch (provider) {
      TrackingProvider.anilist => Icons.hub_outlined,
      TrackingProvider.myAnimeList => Icons.list_alt_outlined,
      TrackingProvider.kitsu => Icons.auto_awesome_outlined,
    };
  }
}

class _SourcesSettingsPage extends StatelessWidget {
  const _SourcesSettingsPage({
    required this.preferences,
    required this.providersFuture,
    required this.mangaProvidersFuture,
  });

  final PreferencesService preferences;
  final Future<List<SourceProvider>> providersFuture;
  final Future<List<SourceProvider>> mangaProvidersFuture;

  @override
  Widget build(BuildContext context) {
    return _SettingsPageScaffold(
      title: 'Sources and library',
      preferences: preferences,
      childrenBuilder: (context, prefs) => [
        const _SectionTitle('Anime'),
        FutureBuilder<List<SourceProvider>>(
          future: providersFuture,
          builder: (context, snapshot) {
            final providers = snapshot.data ?? const <SourceProvider>[];
            return _ProviderDropdownTile(
              icon: Icons.source_outlined,
              title: 'Default anime provider',
              selectedKey: prefs.lastAnimeProviderKey,
              providers: providers,
              onChanged: (provider) {
                prefs.setLastAnimeProvider(
                  SourceProviderChoice(key: provider.key, name: provider.name),
                );
              },
            );
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.public),
          title: const Text('Show non-Japanese anime'),
          value: prefs.showNonJapaneseAnime,
          onChanged: prefs.setShowNonJapaneseAnime,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.sort),
          title: const Text('Episodes descending'),
          value: prefs.episodesDescending,
          onChanged: prefs.setEpisodesDescending,
        ),
        _SelectionTile<EpisodeLayoutMode>(
          icon: Icons.grid_view,
          title: 'Episode layout',
          value: prefs.episodeLayoutMode,
          values: EpisodeLayoutMode.values,
          labelBuilder: (value) => _formatEnumLabel(value.name),
          onChanged: (value) {
            if (value != null) prefs.setEpisodeLayoutMode(value);
          },
        ),
        const SizedBox(height: 10),
        const _SectionTitle('Manga'),
        FutureBuilder<List<SourceProvider>>(
          future: mangaProvidersFuture,
          builder: (context, snapshot) {
            final providers = snapshot.data ?? const <SourceProvider>[];
            return _ProviderDropdownTile(
              icon: Icons.menu_book_outlined,
              title: 'Default manga provider',
              selectedKey: prefs.lastMangaProviderKey,
              providers: providers,
              onChanged: (provider) {
                prefs.setLastMangaProvider(
                  SourceProviderChoice(key: provider.key, name: provider.name),
                );
              },
            );
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.travel_explore),
          title: const Text('Show non-Japanese manga'),
          value: prefs.showNonJapaneseManga,
          onChanged: prefs.setShowNonJapaneseManga,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.sort_by_alpha),
          title: const Text('Manga chapters descending'),
          value: prefs.mangaChaptersDescending,
          onChanged: prefs.setMangaChaptersDescending,
        ),
      ],
    );
  }
}

class _SettingsPageScaffold extends StatelessWidget {
  const _SettingsPageScaffold({
    required this.title,
    required this.preferences,
    required this.childrenBuilder,
  });

  final String title;
  final PreferencesService preferences;
  final List<Widget> Function(BuildContext context, PreferencesService prefs)
  childrenBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: preferences,
          builder: (context, _) {
            return ListTileTheme.merge(
              shape: _settingsTileShape,
              child: AppContentConstraint(
                maxWidth: AppLayout.maxReadableWidth,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: childrenBuilder(context, preferences),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProviderDropdownTile extends StatelessWidget {
  const _ProviderDropdownTile({
    required this.icon,
    required this.title,
    required this.selectedKey,
    required this.providers,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String selectedKey;
  final List<SourceProvider> providers;
  final ValueChanged<SourceProvider> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedProvider = providers.where(
      (provider) => provider.key == selectedKey,
    );
    final selectedValue = selectedProvider.isEmpty
        ? (providers.isEmpty ? selectedKey : providers.first.key)
        : selectedKey;

    return _SelectionTile<String>(
      icon: icon,
      title: title,
      value: selectedValue,
      values: providers.map((provider) => provider.key).toList(),
      labelBuilder: (key) => providers
          .firstWhere(
            (provider) => provider.key == key,
            orElse: () => SourceProvider(key: key, name: key),
          )
          .name,
      onChanged: providers.isEmpty
          ? null
          : (key) {
              if (key == null) return;
              onChanged(
                providers.firstWhere((provider) => provider.key == key),
              );
            },
    );
  }
}

class _PalettePicker extends StatelessWidget {
  const _PalettePicker({required this.value, required this.onChanged});

  final ThemeColorPalette value;
  final ValueChanged<ThemeColorPalette> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 56,
            child: Padding(
              padding: EdgeInsets.only(top: 34),
              child: Icon(Icons.palette_outlined),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Color palette',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final palette in ThemeColorPalette.values) ...[
                        _PalettePreviewTile(
                          palette: palette,
                          selected: palette == value,
                          onTap: () => onChanged(palette),
                        ),
                        if (palette != ThemeColorPalette.values.last)
                          const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PalettePreviewTile extends StatelessWidget {
  const _PalettePreviewTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final ThemeColorPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = selected
        ? Color.alphaBlend(
            colorScheme.primary.withAlpha(22),
            colorScheme.surface,
          )
        : colorScheme.surface;

    return Semantics(
      button: true,
      selected: selected,
      label: '${AppTheme.paletteLabel(palette)} color palette',
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          onTap: onTap,
          child: SizedBox(
            width: 116,
            height: 154,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _PalettePreview(palette: palette)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppTheme.paletteLabel(palette),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      SizedBox(
                        width: 18,
                        child: selected
                            ? Icon(
                                Icons.check_circle,
                                color: colorScheme.primary,
                                size: 18,
                              )
                            : null,
                      ),
                    ],
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

class _PalettePreview extends StatelessWidget {
  const _PalettePreview({required this.palette});

  final ThemeColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppTheme.palettePrimary(palette, brightness);
    final secondary = AppTheme.paletteSecondary(palette, brightness);
    final surface = brightness == Brightness.dark
        ? AppTheme.surfaceDarkHigh
        : Colors.white;
    final surfaceHigh = brightness == Brightness.dark
        ? AppTheme.surfaceDarkHighest
        : const Color(0xFFF0F0F0);
    final lineColor = brightness == Brightness.dark
        ? const Color(0xFFD9D9D9)
        : const Color(0xFF5C5C5C);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Column(
          children: [
            Container(
              height: 24,
              color: Color.alphaBlend(primary.withAlpha(32), surface),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: lineColor.withAlpha(110),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      decoration: BoxDecoration(
                        color: secondary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PalettePreviewLine(color: primary, widthFactor: 1),
                          const SizedBox(height: 6),
                          _PalettePreviewLine(
                            color: lineColor.withAlpha(120),
                            widthFactor: 0.82,
                          ),
                          const SizedBox(height: 6),
                          _PalettePreviewLine(
                            color: lineColor.withAlpha(86),
                            widthFactor: 0.56,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 20,
              color: surfaceHigh,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PalettePreviewDot(color: primary),
                  _PalettePreviewDot(color: lineColor.withAlpha(90)),
                  _PalettePreviewDot(color: lineColor.withAlpha(90)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PalettePreviewLine extends StatelessWidget {
  const _PalettePreviewLine({required this.color, required this.widthFactor});

  final Color color;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _PalettePreviewDot extends StatelessWidget {
  const _PalettePreviewDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SelectionTile<T> extends StatelessWidget {
  const _SelectionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.values,
    required this.labelBuilder,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T?>? onChanged;

  bool get _enabled => onChanged != null && values.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final selectedValue = values.contains(value)
        ? value
        : (values.isEmpty ? null : values.first);

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        selectedValue == null
            ? 'No options available'
            : labelBuilder(selectedValue),
      ),
      trailing: const Icon(Icons.unfold_more),
      enabled: _enabled,
      onTap: _enabled
          ? () => unawaited(_showSelectionDialog(context, selectedValue))
          : null,
    );
  }

  Future<void> _showSelectionDialog(
    BuildContext context,
    T? selectedValue,
  ) async {
    final selected = await showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.only(top: 8, bottom: 12),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 420),
          child: SingleChildScrollView(
            child: RadioGroup<T>(
              groupValue: selectedValue,
              onChanged: (value) => Navigator.of(context).pop(value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in values)
                    RadioListTile<T>(
                      value: item,
                      title: Text(labelBuilder(item)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          AppDialogAction(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );

    if (selected != null && selected != value) {
      onChanged?.call(selected);
    }
  }
}

String _appSummary(PreferencesService prefs) {
  final theme = _formatEnumLabel(prefs.themeMode.name);
  final palette = AppTheme.paletteLabel(prefs.themeColorPalette);
  final startTab = _appStartTabLabel(prefs.appStartTab).toLowerCase();
  final updates = prefs.automaticUpdateChecks
      ? 'startup updates on'
      : 'startup updates off';
  return '$theme theme, $palette palette, starts on $startTab, $updates';
}

String _playbackSummary(PreferencesService prefs) {
  final speed = '${_formatSpeed(prefs.defaultPlaybackSpeed)}x';
  final resize = _formatEnumLabel(prefs.resizeMode.name).toLowerCase();
  final resume = prefs.resumePlayback ? 'resume on' : 'resume off';
  return '$speed default, $resize resize, $resume';
}

String _subtitlesSummary(PreferencesService prefs) {
  if (!prefs.subtitlesEnabled) return 'Off';
  final timestamps = prefs.timeStampsEnabled
      ? 'timestamps on'
      : 'timestamps off';
  return '${prefs.subtitleFontSize}px, $timestamps';
}

String _dataSummary(PreferencesService prefs) {
  final privacy = prefs.incognitoMode ? 'incognito on' : 'history on';
  return '$privacy, ${_downloadQualityLabel(prefs.downloadQualityPreference).toLowerCase()} downloads';
}

String _readerSummary(PreferencesService prefs) {
  final mode = _mangaReadingModeLabel(prefs.mangaReadingMode);
  final preload = prefs.mangaPreloadPages == 0
      ? 'preloading off'
      : '${prefs.mangaPreloadPages} pages preloaded';
  return '$mode, $preload';
}

String _sourcesSummary(PreferencesService prefs) {
  final anime = _providerLabel(
    key: prefs.lastAnimeProviderKey,
    name: prefs.lastAnimeProviderName,
  );
  final manga = _providerLabel(
    key: prefs.lastMangaProviderKey,
    name: prefs.lastMangaProviderName,
  );
  return 'Anime: $anime, manga: $manga';
}

String _trackingSummary(TrackingService trackingService) {
  final loggedIn = TrackingProvider.values
      .where(trackingService.isLoggedIn)
      .map((provider) => provider.label)
      .join(', ');
  final sync = trackingService.progressSyncEnabled ? 'sync on' : 'sync off';
  final provider = loggedIn.isEmpty ? 'no accounts' : loggedIn;
  return '${trackingService.primaryProvider.label}, $sync, $provider';
}

String _providerLabel({required String key, required String? name}) {
  final trimmedName = name?.trim();
  return trimmedName == null || trimmedName.isEmpty ? key : trimmedName;
}

String _appStartTabLabel(AppStartTab value) {
  return switch (value) {
    AppStartTab.home => 'Home',
    AppStartTab.search => 'Search',
    AppStartTab.library => 'Library',
  };
}

String _downloadQualityLabel(DownloadQualityPreference value) {
  return switch (value) {
    DownloadQualityPreference.askEveryTime => 'Ask every time',
    DownloadQualityPreference.highest => 'Highest available',
    DownloadQualityPreference.dataSaver => 'Data saver',
  };
}

String _mangaReadingModeLabel(MangaReadingMode value) {
  return switch (value) {
    MangaReadingMode.webtoon => 'Webtoon',
    MangaReadingMode.leftToRight => 'Left to right',
    MangaReadingMode.rightToLeft => 'Right to left',
  };
}

String _formatEnumLabel(String name) {
  return name[0].toUpperCase() + name.substring(1);
}

String _formatSpeed(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

String _formatStorageBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(kib >= 10 ? 0 : 1)} KB';
  final mib = kib / 1024;
  if (mib < 1024) return '${mib.toStringAsFixed(mib >= 10 ? 0 : 1)} MB';
  final gib = mib / 1024;
  return '${gib.toStringAsFixed(gib >= 10 ? 0 : 1)} GB';
}
