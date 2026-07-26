import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/app_database.dart';
import '../services/novel_library_service.dart';
import '../services/preferences_service.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_error_view.dart';

class NovelReaderScreen extends StatefulWidget {
  const NovelReaderScreen({
    required this.book,
    required this.library,
    required this.preferences,
    this.initialChapter,
    super.key,
  });

  final NovelLibraryEntry book;
  final NovelLibraryService library;
  final PreferencesService preferences;
  final NovelChapterEntry? initialChapter;

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  List<NovelChapterEntry> _chapters = const [];
  NovelChapterEntry? _chapter;
  String? _content;
  Object? _error;
  bool _loading = true;
  Timer? _progressTimer;

  int get _chapterIndex => _chapter == null ? -1 : _chapters.indexOf(_chapter!);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    widget.preferences.addListener(_handlePreferencesChanged);
    unawaited(_applyWakelock());
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    unawaited(_saveProgress());
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    widget.preferences.removeListener(_handlePreferencesChanged);
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final chapters = await widget.library.chapters(widget.book.id);
      if (chapters.isEmpty) {
        throw const NovelImportException('This book has no readable chapters');
      }
      final requested = widget.initialChapter;
      NovelChapterEntry selected = chapters.first;
      if (requested != null) {
        selected = chapters.firstWhere(
          (chapter) => chapter.id == requested.id,
          orElse: () => selected,
        );
      } else {
        for (final chapter in chapters) {
          if (chapter.readAt != null &&
              (selected.readAt == null ||
                  chapter.readAt!.isAfter(selected.readAt!))) {
            selected = chapter;
          }
        }
      }
      if (!mounted) return;
      setState(() => _chapters = chapters);
      await _openChapter(selected);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openChapter(NovelChapterEntry chapter) async {
    await _saveProgress();
    if (mounted) {
      setState(() {
        _chapter = chapter;
        _content = null;
        _error = null;
        _loading = true;
      });
    }
    try {
      final content = await widget.library.readChapter(chapter);
      if (!mounted || _chapter?.id != chapter.id) return;
      setState(() {
        _content = content;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final position = _scrollController.position;
        _scrollController.jumpTo(
          (position.maxScrollExtent * chapter.progress).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      });
    } catch (error) {
      if (mounted && _chapter?.id == chapter.id) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _handleScroll() {
    _progressTimer?.cancel();
    _progressTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_saveProgress());
    });
    if (mounted) setState(() {});
  }

  double get _progress {
    if (!_scrollController.hasClients) return _chapter?.progress ?? 0;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return 1;
    return (_scrollController.offset / max).clamp(0, 1).toDouble();
  }

  Future<void> _saveProgress() async {
    final chapter = _chapter;
    if (chapter == null) return;
    await widget.library.saveProgress(chapter.id, _progress);
  }

  void _handlePreferencesChanged() {
    unawaited(_applyWakelock());
    if (mounted) setState(() {});
  }

  Future<void> _applyWakelock() => widget.preferences.novelKeepScreenOn
      ? WakelockPlus.enable()
      : WakelockPlus.disable();

  Future<void> _moveChapter(int offset) async {
    final index = _chapterIndex + offset;
    if (index < 0 || index >= _chapters.length) return;
    await _openChapter(_chapters[index]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _readerPalette(
      context,
      widget.preferences.novelReaderTheme,
    );
    final chapter = _chapter;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.foreground,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (chapter != null)
              Text(
                chapter.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.foreground.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chapters',
            onPressed: _chapters.isEmpty ? null : _showChapters,
            icon: const Icon(Icons.format_list_numbered),
          ),
          IconButton(
            tooltip: 'Reader settings',
            onPressed: _showReaderSettings,
            icon: const Icon(Icons.text_fields),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: _loading ? null : _progress,
            minHeight: 2,
          ),
          Expanded(child: _buildBody(palette)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ColoredBox(
          color: palette.background,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Previous chapter',
                  onPressed: _chapterIndex > 0 ? () => _moveChapter(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _chapterIndex < 0
                        ? 'Loading chapter…'
                        : '${_chapterIndex + 1} of ${_chapters.length}  •  ${(_progress * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.foreground),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Next chapter',
                  onPressed:
                      _chapterIndex >= 0 && _chapterIndex < _chapters.length - 1
                      ? () => _moveChapter(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(_NovelReaderPalette palette) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return AppErrorView(
        message: error.toString(),
        onRetry: _chapter == null ? _initialize : () => _openChapter(_chapter!),
      );
    }
    return SelectionArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 72),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            _content ?? '',
            style: TextStyle(
              color: palette.foreground,
              fontSize: widget.preferences.novelFontSize,
              height: widget.preferences.novelLineHeight,
              letterSpacing: 0.15,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showChapters() async {
    final selected = await showAppBottomSheet<NovelChapterEntry>(
      context: context,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Chapters',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: _chapters.length,
              itemBuilder: (context, index) {
                final chapter = _chapters[index];
                return ListTile(
                  selected: chapter.id == _chapter?.id,
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(chapter.title),
                  subtitle: chapter.progress <= 0
                      ? null
                      : Text('${(chapter.progress * 100).round()}% read'),
                  trailing: chapter.progress >= 0.99
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                  onTap: () => Navigator.of(context).pop(chapter),
                );
              },
            ),
          ),
        ],
      ),
    );
    if (selected != null) await _openChapter(selected);
  }

  Future<void> _showReaderSettings() {
    return showAppBottomSheet<void>(
      context: context,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.88,
      builder: (context, scrollController) => AnimatedBuilder(
        animation: widget.preferences,
        builder: (context, _) {
          final prefs = widget.preferences;
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                'Reader appearance',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SegmentedButton<NovelReaderTheme>(
                segments: const [
                  ButtonSegment(
                    value: NovelReaderTheme.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: NovelReaderTheme.sepia,
                    label: Text('Sepia'),
                    icon: Icon(Icons.wb_sunny_outlined),
                  ),
                  ButtonSegment(
                    value: NovelReaderTheme.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {prefs.novelReaderTheme},
                onSelectionChanged: (values) =>
                    prefs.setNovelReaderTheme(values.first),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Text size: ${prefs.novelFontSize.round()}'),
                subtitle: Slider(
                  min: 12,
                  max: 36,
                  divisions: 24,
                  value: prefs.novelFontSize,
                  onChanged: prefs.setNovelFontSize,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Line height: ${prefs.novelLineHeight.toStringAsFixed(1)}',
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
                contentPadding: EdgeInsets.zero,
                title: const Text('Keep screen on'),
                value: prefs.novelKeepScreenOn,
                onChanged: prefs.setNovelKeepScreenOn,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NovelReaderPalette {
  const _NovelReaderPalette({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

_NovelReaderPalette _readerPalette(
  BuildContext context,
  NovelReaderTheme theme,
) => switch (theme) {
  NovelReaderTheme.system => _NovelReaderPalette(
    background: Theme.of(context).colorScheme.surface,
    foreground: Theme.of(context).colorScheme.onSurface,
  ),
  NovelReaderTheme.sepia => const _NovelReaderPalette(
    background: Color(0xFFF4E8C9),
    foreground: Color(0xFF352C20),
  ),
  NovelReaderTheme.dark => const _NovelReaderPalette(
    background: Color(0xFF111313),
    foreground: Color(0xFFE7E5E1),
  ),
};
