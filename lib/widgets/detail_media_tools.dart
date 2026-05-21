import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ExpandableSelectableText extends StatefulWidget {
  const ExpandableSelectableText(
    this.text, {
    this.collapsedLines = 5,
    this.style,
    super.key,
  });

  final String text;
  final int collapsedLines;
  final TextStyle? style;

  @override
  State<ExpandableSelectableText> createState() =>
      _ExpandableSelectableTextState();
}

class _ExpandableSelectableTextState extends State<ExpandableSelectableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final canExpand = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectionArea(
              child: Text(
                widget.text,
                maxLines: _expanded ? null : widget.collapsedLines,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (canExpand) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(_expanded ? 'Show less' : 'Show more'),
              ),
            ],
          ],
        );
      },
    );
  }
}

Future<void> showImagePreviewSheet({
  required BuildContext context,
  required String imageUrl,
  required String title,
  Map<String, String> headers = const {},
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) =>
        _ImagePreviewSheet(imageUrl: imageUrl, title: title, headers: headers),
  );
}

class _ImagePreviewSheet extends StatefulWidget {
  const _ImagePreviewSheet({
    required this.imageUrl,
    required this.title,
    required this.headers,
  });

  final String imageUrl;
  final String title;
  final Map<String, String> headers;

  @override
  State<_ImagePreviewSheet> createState() => _ImagePreviewSheetState();
}

class _ImagePreviewSheetState extends State<_ImagePreviewSheet> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectionArea(
              child: Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    httpHeaders: widget.headers,
                    fit: BoxFit.contain,
                    placeholder: (context, _) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, _, _) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _downloading ? null : () => _download(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(_downloading ? 'Downloading' : 'Download'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    setState(() => _downloading = true);
    try {
      final file = await _downloadImage(
        imageUrl: widget.imageUrl,
        title: widget.title,
        headers: widget.headers,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved image to ${file.path}')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }
}

Future<File> _downloadImage({
  required String imageUrl,
  required String title,
  required Map<String, String> headers,
}) async {
  final uri = Uri.parse(imageUrl);
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Image download failed with HTTP ${response.statusCode}');
    }
    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    final directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final filename = _imageFilename(title, uri);
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  } finally {
    client.close(force: true);
  }
}

String _imageFilename(String title, Uri uri) {
  final path = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final extension = path.contains('.') ? path.split('.').last : 'jpg';
  final cleanExtension = extension
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .toLowerCase();
  final safeTitle = title
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  final base = safeTitle.isEmpty ? 'anikin-image' : safeTitle;
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '$base-$timestamp.${cleanExtension.isEmpty ? 'jpg' : cleanExtension}';
}
