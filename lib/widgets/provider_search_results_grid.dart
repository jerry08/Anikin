import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProviderSearchResultsSliver extends StatelessWidget {
  const ProviderSearchResultsSliver({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  static const double _minimumTileWidth = 108;
  static const double _crossAxisSpacing = 12;
  static const double _mainAxisSpacing = 10;

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columnCount =
            ((width + _crossAxisSpacing) /
                    (_minimumTileWidth + _crossAxisSpacing))
                .floor()
                .clamp(1, 4)
                .toInt();
        final itemWidth =
            (width - _crossAxisSpacing * (columnCount - 1)) / columnCount;
        final textScale = MediaQuery.textScalerOf(
          context,
        ).scale(1).clamp(1.0, 2.0).toDouble();

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
          sliver: SliverGrid.builder(
            key: const ValueKey('provider-search-results-grid'),
            itemCount: itemCount,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              crossAxisSpacing: _crossAxisSpacing,
              mainAxisSpacing: _mainAxisSpacing,
              mainAxisExtent: itemWidth * 1.5 + 76 * textScale,
            ),
            itemBuilder: itemBuilder,
          ),
        );
      },
    );
  }
}

class ProviderSearchResultCard extends StatelessWidget {
  const ProviderSearchResultCard({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.imageUrl,
    this.imageHeaders = const {},
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final Map<String, String> imageHeaders;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final titleStyle = (theme.textTheme.titleSmall ?? defaultTextStyle)
        .copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25);
    final subtitleStyle = (theme.textTheme.bodySmall ?? defaultTextStyle)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final subtitle = this.subtitle?.trim();
    final semanticsLabel = [
      title,
      if (subtitle != null && subtitle.isNotEmpty) subtitle,
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(12),
            focusColor: colorScheme.onSurface.withValues(alpha: 0.12),
            hoverColor: colorScheme.onSurface.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _ProviderSearchCover(
                        imageUrl: imageUrl,
                        imageHeaders: imageHeaders,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final titlePainter = TextPainter(
                          text: TextSpan(text: title, style: titleStyle),
                          maxLines: 4,
                          ellipsis: '…',
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        )..layout(maxWidth: constraints.maxWidth);
                        final hasSubtitle =
                            subtitle != null && subtitle.isNotEmpty;
                        var showSubtitle = false;
                        if (hasSubtitle) {
                          final subtitlePainter = TextPainter(
                            text: TextSpan(
                              text: subtitle,
                              style: subtitleStyle,
                            ),
                            maxLines: 1,
                            ellipsis: '…',
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          )..layout(maxWidth: constraints.maxWidth);
                          showSubtitle =
                              titlePainter.height +
                                  3 +
                                  subtitlePainter.height <=
                              constraints.maxHeight + 0.5;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                            if (showSubtitle) ...[
                              const Spacer(),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: subtitleStyle,
                              ),
                            ],
                          ],
                        );
                      },
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

class _ProviderSearchCover extends StatelessWidget {
  const _ProviderSearchCover({
    required this.imageUrl,
    required this.imageHeaders,
  });

  final String? imageUrl;
  final Map<String, String> imageHeaders;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image_outlined, color: colorScheme.onSurfaceVariant),
      ),
    );
    final imageUrl = this.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return placeholder;
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      httpHeaders: imageHeaders.isEmpty ? null : imageHeaders,
      fit: BoxFit.cover,
      placeholder: (context, _) => placeholder,
      errorWidget: (context, _, _) => ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
