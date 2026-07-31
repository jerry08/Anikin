import 'dart:async';

import 'package:flutter/material.dart';

import '../services/preferences_service.dart';

class EpisodeActionBar extends StatelessWidget {
  const EpisodeActionBar({
    required this.dubbed,
    required this.descending,
    required this.layoutMode,
    required this.onDubbedChanged,
    required this.onSortPressed,
    required this.onLayoutChanged,
    required this.onDownloadAll,
    this.onCancelAllDownloads,
    super.key,
  });

  final bool dubbed;
  final bool descending;
  final EpisodeLayoutMode layoutMode;
  final ValueChanged<bool>? onDubbedChanged;
  final VoidCallback? onSortPressed;
  final ValueChanged<EpisodeLayoutMode> onLayoutChanged;
  final VoidCallback? onDownloadAll;
  final VoidCallback? onCancelAllDownloads;

  static const _controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );
  static const _controlHeight = 48.0;
  static const _controlSurfaceHeight = 40.0;
  static const _singleLineMinWidth = 300.0;

  @override
  Widget build(BuildContext context) {
    final optionsButton = Tooltip(
      message: 'Episode options',
      child: FilledButton.tonalIcon(
        key: const ValueKey('episode-options-button'),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.padded,
          minimumSize: const Size(0, _controlSurfaceHeight),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: _controlShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: () => unawaited(_showOptions(context)),
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: const Text('Options'),
      ),
    );

    return Semantics(
      container: true,
      label: 'Episode controls',
      child: Padding(
        key: const ValueKey('episode-action-bar'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final useSingleLine =
                constraints.maxWidth >= _singleLineMinWidth &&
                textScale <= 1.15;
            if (useSingleLine) {
              return SizedBox(
                height: _controlHeight,
                child: Row(
                  children: [
                    _EpisodeLanguageSelector(
                      dubbed: dubbed,
                      onChanged: onDubbedChanged,
                    ),
                    const Spacer(),
                    optionsButton,
                  ],
                ),
              );
            }

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _EpisodeLanguageSelector(
                  dubbed: dubbed,
                  onChanged: onDubbedChanged,
                ),
                optionsButton,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showOptions(BuildContext context) async {
    // Desktop embedders can deliver a frame while mouse hover bookkeeping is
    // still settling. Crossing the frame boundary keeps route changes out of
    // that device-update phase.
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) {
      return;
    }
    final result = await showDialog<_EpisodeOptionsResult>(
      context: context,
      builder: (context) => _EpisodeOptionsDialog(
        descending: descending,
        layoutMode: layoutMode,
        sortEnabled: onSortPressed != null,
        downloadEnabled: onDownloadAll != null,
        cancelDownloadsEnabled: onCancelAllDownloads != null,
      ),
    );
    if (result == null) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) {
      return;
    }
    if (result.descending != descending) {
      onSortPressed?.call();
    }
    if (result.layoutMode != layoutMode) {
      onLayoutChanged(result.layoutMode);
    }
    if (result.downloadAll) {
      onDownloadAll?.call();
    }
    if (result.cancelAllDownloads) {
      onCancelAllDownloads?.call();
    }
  }
}

class _EpisodeLanguageSelector extends StatelessWidget {
  const _EpisodeLanguageSelector({
    required this.dubbed,
    required this.onChanged,
  });

  final bool dubbed;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Episode audio',
      child: SegmentedButton<bool>(
        key: const ValueKey('episode-audio-selector'),
        segments: const [
          ButtonSegment<bool>(
            value: false,
            icon: Icon(Icons.subtitles_outlined, size: 18),
            label: Text('Sub'),
          ),
          ButtonSegment<bool>(
            value: true,
            icon: Icon(Icons.record_voice_over_outlined, size: 18),
            label: Text('Dub'),
          ),
        ],
        selected: {dubbed},
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.padded,
          minimumSize: const WidgetStatePropertyAll(
            Size(0, EpisodeActionBar._controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.38);
            }
            return states.contains(WidgetState.selected)
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return states.contains(WidgetState.selected)
                  ? colorScheme.onSurface.withValues(alpha: 0.12)
                  : colorScheme.surface;
            }
            return states.contains(WidgetState.selected)
                ? colorScheme.primaryContainer
                : colorScheme.surface;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            return BorderSide(
              color: colorScheme.outlineVariant.withValues(
                alpha: states.contains(WidgetState.disabled) ? 0.5 : 1,
              ),
            );
          }),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        onSelectionChanged: onChanged == null
            ? null
            : (selection) {
                final value = selection.single;
                if (value != dubbed) {
                  onChanged!(value);
                }
              },
      ),
    );
  }
}

class _EpisodeOptionsResult {
  const _EpisodeOptionsResult({
    required this.descending,
    required this.layoutMode,
    this.downloadAll = false,
    this.cancelAllDownloads = false,
  });

  final bool descending;
  final EpisodeLayoutMode layoutMode;
  final bool downloadAll;
  final bool cancelAllDownloads;
}

class _EpisodeOptionsDialog extends StatefulWidget {
  const _EpisodeOptionsDialog({
    required this.descending,
    required this.layoutMode,
    required this.sortEnabled,
    required this.downloadEnabled,
    required this.cancelDownloadsEnabled,
  });

  final bool descending;
  final EpisodeLayoutMode layoutMode;
  final bool sortEnabled;
  final bool downloadEnabled;
  final bool cancelDownloadsEnabled;

  @override
  State<_EpisodeOptionsDialog> createState() => _EpisodeOptionsDialogState();
}

class _EpisodeOptionsDialogState extends State<_EpisodeOptionsDialog> {
  late bool _descending;
  late EpisodeLayoutMode _layoutMode;

  @override
  void initState() {
    super.initState();
    _descending = widget.descending;
    _layoutMode = widget.layoutMode;
  }

  void _close({bool downloadAll = false, bool cancelAllDownloads = false}) {
    Navigator.of(context).pop(
      _EpisodeOptionsResult(
        descending: _descending,
        layoutMode: _layoutMode,
        downloadAll: downloadAll,
        cancelAllDownloads: cancelAllDownloads,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const ValueKey('episode-options-dialog'),
      icon: Icon(Icons.tune_rounded, color: colorScheme.primary),
      title: const Text('Episode options'),
      scrollable: true,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EpisodeLayoutOptions(
              value: _layoutMode,
              onChanged: (value) => setState(() => _layoutMode = value),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Material(
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: const ValueKey('episode-sort-option'),
                enabled: widget.sortEnabled,
                minTileHeight: 64,
                leading: Icon(
                  _descending
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                ),
                title: const Text('Sort order'),
                subtitle: Text(
                  _descending ? 'Newest first' : 'Oldest first',
                  key: const ValueKey('episode-sort-value'),
                ),
                trailing: const Icon(Icons.swap_vert_rounded),
                onTap: widget.sortEnabled
                    ? () => setState(() => _descending = !_descending)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Downloads',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Queue every available episode for offline viewing.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              key: const ValueKey('episode-download-all-button'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  EpisodeActionBar._controlHeight,
                ),
                shape: EpisodeActionBar._controlShape,
              ),
              onPressed: widget.downloadEnabled
                  ? () => _close(downloadAll: true)
                  : null,
              icon: const Icon(Icons.download_for_offline_outlined),
              label: const Text('Download all episodes'),
            ),
            if (widget.cancelDownloadsEnabled) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('episode-cancel-all-downloads-button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                  minimumSize: const Size(
                    double.infinity,
                    EpisodeActionBar._controlHeight,
                  ),
                  shape: EpisodeActionBar._controlShape,
                ),
                onPressed: () => _close(cancelAllDownloads: true),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Cancel all episode downloads'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('episode-options-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('episode-options-apply'),
          onPressed: _close,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _EpisodeLayoutOptions extends StatelessWidget {
  const _EpisodeLayoutOptions({required this.value, required this.onChanged});

  final EpisodeLayoutMode value;
  final ValueChanged<EpisodeLayoutMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Layout',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    final choices = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final mode in EpisodeLayoutMode.values) ...[
          if (mode != EpisodeLayoutMode.values.first) const SizedBox(width: 6),
          Semantics(
            button: true,
            selected: mode == value,
            label: mode.label,
            child: Tooltip(
              message: mode.label,
              child: IconButton(
                key: ValueKey('episode-layout-${mode.name}'),
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(
                    EpisodeActionBar._controlHeight,
                  ),
                  foregroundColor: mode == value
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  backgroundColor: mode == value
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  side: BorderSide(
                    color: mode == value
                        ? colorScheme.primary.withValues(alpha: 0.42)
                        : colorScheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => onChanged(mode),
                icon: Icon(mode.icon),
              ),
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [labels, const SizedBox(height: 10), choices],
    );
  }
}

extension on EpisodeLayoutMode {
  String get label => switch (this) {
    EpisodeLayoutMode.semi => 'Compact grid',
    EpisodeLayoutMode.full => 'Full cards',
    EpisodeLayoutMode.list => 'List view',
  };

  IconData get icon => switch (this) {
    EpisodeLayoutMode.semi => Icons.grid_view_rounded,
    EpisodeLayoutMode.full => Icons.view_module_outlined,
    EpisodeLayoutMode.list => Icons.view_list_rounded,
  };
}
