import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/anilist_media.dart';
import '../models/tracking.dart';
import 'app_bottom_sheet.dart';

Future<AniListListEntryEditResult?> showAniListListEntrySheet({
  required BuildContext context,
  required AniListMedia media,
  required TrackingMediaKind kind,
  AniListMediaListEntry? entry,
}) {
  return showAppBottomSheet<AniListListEntryEditResult>(
    context: context,
    initialChildSize: 0.74,
    minChildSize: 0.42,
    maxChildSize: 0.94,
    builder: (context, scrollController) => _AniListListEntrySheet(
      media: media,
      kind: kind,
      entry: entry,
      scrollController: scrollController,
    ),
  );
}

enum AniListListEntryEditAction { save, delete }

class AniListListEntryEditResult {
  const AniListListEntryEditResult.save(this.request)
    : action = AniListListEntryEditAction.save;

  const AniListListEntryEditResult.delete()
    : action = AniListListEntryEditAction.delete,
      request = null;

  final AniListListEntryEditAction action;
  final AniListMediaListSaveRequest? request;
}

class _AniListListEntrySheet extends StatefulWidget {
  const _AniListListEntrySheet({
    required this.media,
    required this.kind,
    required this.entry,
    required this.scrollController,
  });

  final AniListMedia media;
  final TrackingMediaKind kind;
  final AniListMediaListEntry? entry;
  final ScrollController scrollController;

  @override
  State<_AniListListEntrySheet> createState() => _AniListListEntrySheetState();
}

class _AniListListEntrySheetState extends State<_AniListListEntrySheet> {
  late AniListMediaListStatus _status;
  late final TextEditingController _progressController;
  late final TextEditingController _volumeController;
  late final TextEditingController _scoreController;
  late final TextEditingController _repeatController;
  late final TextEditingController _notesController;
  DateTime? _startedAt;
  DateTime? _completedAt;
  bool _private = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _status = entry?.status ?? AniListMediaListStatus.current;
    _progressController = TextEditingController(
      text: _numberText(entry?.progress),
    );
    _volumeController = TextEditingController(
      text: _numberText(entry?.progressVolumes),
    );
    _scoreController = TextEditingController(text: _scoreText(entry?.score));
    _repeatController = TextEditingController(text: _numberText(entry?.repeat));
    _notesController = TextEditingController(text: entry?.notes ?? '');
    _startedAt = entry?.startedAt?.dateTime;
    _completedAt = entry?.completedAt?.dateTime;
    _private = entry?.private ?? false;
  }

  @override
  void dispose() {
    _progressController.dispose();
    _volumeController.dispose();
    _scoreController.dispose();
    _repeatController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final kindLabel = widget.kind == TrackingMediaKind.anime
        ? 'Anime'
        : 'Manga';
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AniList list',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              widget.media.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<AniListMediaListStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.playlist_add_check),
              ),
              items: [
                for (final status in AniListMediaListStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _progressController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: widget.kind == TrackingMediaKind.anime
                          ? 'Episodes'
                          : 'Chapters',
                      prefixIcon: Icon(
                        widget.kind == TrackingMediaKind.anime
                            ? Icons.movie_filter_outlined
                            : Icons.menu_book_outlined,
                      ),
                    ),
                  ),
                ),
                if (widget.kind == TrackingMediaKind.manga) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _volumeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Volumes',
                        prefixIcon: Icon(Icons.book_outlined),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _scoreController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Score',
                      prefixIcon: Icon(Icons.star_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _repeatController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: widget.kind == TrackingMediaKind.anime
                          ? 'Rewatches'
                          : 'Rereads',
                      prefixIcon: const Icon(Icons.repeat),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DateField(
              label: 'Started',
              value: _startedAt,
              onPick: () async {
                final picked = await _pickDate(_startedAt);
                if (picked != null) {
                  setState(() => _startedAt = picked);
                }
              },
              onClear: _startedAt == null
                  ? null
                  : () => setState(() => _startedAt = null),
            ),
            const SizedBox(height: 8),
            _DateField(
              label: 'Finished',
              value: _completedAt,
              onPick: () async {
                final picked = await _pickDate(_completedAt);
                if (picked != null) {
                  setState(() => _completedAt = picked);
                }
              },
              onClear: _completedAt == null
                  ? null
                  : () => setState(() => _completedAt = null),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private'),
              value: _private,
              onChanged: (value) => setState(() => _private = value),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                if (widget.entry != null)
                  TextButton.icon(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text('Save $kindLabel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(DateTime? initialDate) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from AniList?'),
        content: Text(widget.media.displayTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(const AniListListEntryEditResult.delete());
    }
  }

  void _save() {
    _error = null;
    final progress = _parseInt(_progressController.text, 'Progress');
    final progressVolumes = _parseInt(_volumeController.text, 'Volumes');
    final repeat = _parseInt(_repeatController.text, 'Repeat count');
    final score = _parseScore(_scoreController.text);
    if (_error != null) {
      setState(() {});
      return;
    }
    Navigator.of(context).pop(
      AniListListEntryEditResult.save(
        AniListMediaListSaveRequest(
          media: widget.media,
          kind: widget.kind,
          status: _status,
          progress: progress,
          progressVolumes: widget.kind == TrackingMediaKind.manga
              ? progressVolumes
              : null,
          score: score,
          repeat: repeat,
          private: _private,
          notes: _notesController.text,
          startedAt: _startedAt,
          completedAt: _completedAt,
        ),
      ),
    );
  }

  int? _parseInt(String raw, String label) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0) {
      _error = '$label must be a positive number';
      return null;
    }
    return parsed;
  }

  double? _parseScore(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null || parsed < 0 || parsed > 100) {
      _error = 'Score must be between 0 and 100';
      return null;
    }
    return parsed;
  }

  static String _numberText(int? value) {
    if (value == null || value <= 0) {
      return '';
    }
    return value.toString();
  }

  static String _scoreText(double? value) {
    if (value == null || value <= 0) {
      return '';
    }
    final rounded = value.roundToDouble();
    return value == rounded ? rounded.toInt().toString() : value.toString();
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onPick,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_month_outlined),
            suffixIcon: onClear == null
                ? null
                : IconButton(
                    tooltip: 'Clear $label',
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  ),
          ),
          child: Text(
            _dateText(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  static String _dateText(DateTime? date) {
    if (date == null) {
      return 'None';
    }
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
