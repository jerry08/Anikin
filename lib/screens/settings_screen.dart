import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/juro_models.dart';
import '../services/juro_service.dart';
import '../services/preferences_service.dart';

const _settingsTileShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.preferences,
    required this.juroService,
    super.key,
  });

  final PreferencesService preferences;
  final JuroService juroService;

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
        animation: widget.preferences,
        builder: (context, _) {
          final prefs = widget.preferences;
          return ListTileTheme.merge(
            shape: _settingsTileShape,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
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
                    _AppSettingsPage(preferences: widget.preferences),
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
              ],
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

class _AppSettingsPage extends StatelessWidget {
  const _AppSettingsPage({required this.preferences});

  final PreferencesService preferences;

  @override
  Widget build(BuildContext context) {
    return _SettingsPageScaffold(
      title: 'App',
      preferences: preferences,
      childrenBuilder: (context, prefs) => [
        const _SectionTitle('Display'),
        _DropdownTile<ThemeMode>(
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
        const SizedBox(height: 10),
        const _SectionTitle('Diagnostics'),
        SwitchListTile(
          secondary: const Icon(Icons.code),
          title: const Text('Developer error details'),
          value: prefs.developerMode,
          onChanged: prefs.setDeveloperMode,
        ),
      ],
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
        _DropdownTile<double>(
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
        _DropdownTile<ResizeModeSetting>(
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
          secondary: const Icon(Icons.skip_next),
          title: const Text('Autoplay next episode'),
          value: prefs.autoPlayNext,
          onChanged: prefs.setAutoPlayNext,
        ),
        const SizedBox(height: 10),
        const _SectionTitle('Controls'),
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
        _DropdownTile<EpisodeLayoutMode>(
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: childrenBuilder(context, preferences),
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
          fontWeight: FontWeight.w800,
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

    return _DropdownTile<String>(
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

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 56, child: Icon(icon)),
          Expanded(
            child: DropdownButtonFormField<T>(
              initialValue: values.contains(value) ? value : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: title),
              items: values
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(labelBuilder(item)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

String _appSummary(PreferencesService prefs) {
  final theme = _formatEnumLabel(prefs.themeMode.name);
  final palette = AppTheme.paletteLabel(prefs.themeColorPalette);
  final diagnostics = prefs.developerMode
      ? 'developer details on'
      : 'developer details off';
  return '$theme theme, $palette palette, $diagnostics';
}

String _playbackSummary(PreferencesService prefs) {
  final speed = '${_formatSpeed(prefs.defaultPlaybackSpeed)}x';
  final resize = _formatEnumLabel(prefs.resizeMode.name).toLowerCase();
  return '$speed default, $resize resize';
}

String _subtitlesSummary(PreferencesService prefs) {
  if (!prefs.subtitlesEnabled) return 'Off';
  final timestamps = prefs.timeStampsEnabled
      ? 'timestamps on'
      : 'timestamps off';
  return '${prefs.subtitleFontSize}px, $timestamps';
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

String _providerLabel({required String key, required String? name}) {
  final trimmedName = name?.trim();
  return trimmedName == null || trimmedName.isEmpty ? key : trimmedName;
}

String _formatEnumLabel(String name) {
  return name[0].toUpperCase() + name.substring(1);
}

String _formatSpeed(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}
