import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/anilist_media.dart';

class MediaPosterCard extends StatelessWidget {
  const MediaPosterCard({
    required this.media,
    required this.onTap,
    this.width = 132,
    this.showMetadata = true,
    super.key,
  });

  final AniListMedia media;
  final VoidCallback onTap;
  final double width;
  final bool showMetadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final titleStyle = (theme.textTheme.bodyMedium ?? defaultTextStyle)
        .copyWith(fontWeight: FontWeight.w700);
    final metadataStyle = (theme.textTheme.bodySmall ?? defaultTextStyle)
        .copyWith(color: theme.colorScheme.onSurfaceVariant);
    final hasMetadata = showMetadata && media.metadata.isNotEmpty;

    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : width;
            final posterHeight = _posterHeightFor(
              context: context,
              constraints: constraints,
              cardWidth: cardWidth,
              titleStyle: titleStyle,
              metadataStyle: metadataStyle,
              hasMetadata: hasMetadata,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: cardWidth,
                    height: posterHeight,
                    child: _PosterImage(url: media.cover.best),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  media.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                if (hasMetadata) ...[
                  const SizedBox(height: 3),
                  Text(
                    media.metadata,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: metadataStyle,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  double _posterHeightFor({
    required BuildContext context,
    required BoxConstraints constraints,
    required double cardWidth,
    required TextStyle titleStyle,
    required TextStyle metadataStyle,
    required bool hasMetadata,
  }) {
    final naturalPosterHeight = cardWidth * 1.48;
    if (!constraints.hasBoundedHeight) {
      return naturalPosterHeight;
    }

    var textHeight =
        8 +
        _measureTextHeight(
          context: context,
          text: media.displayTitle,
          style: titleStyle,
          maxLines: 2,
          maxWidth: cardWidth,
        );
    if (hasMetadata) {
      textHeight +=
          3 +
          _measureTextHeight(
            context: context,
            text: media.metadata,
            style: metadataStyle,
            maxLines: 1,
            maxWidth: cardWidth,
          );
    }

    return (constraints.maxHeight - textHeight)
        .clamp(0.0, naturalPosterHeight)
        .toDouble();
  }

  double _measureTextHeight({
    required BuildContext context,
    required String text,
    required TextStyle style,
    required int maxLines,
    required double maxWidth,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      ellipsis: '...',
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);

    return textPainter.height;
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;
    if (url == null || url!.isEmpty) {
      return ColoredBox(
        color: placeholderColor,
        child: const Center(child: Icon(Icons.movie_filter_outlined)),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (context, _) => ColoredBox(color: placeholderColor),
      errorWidget: (context, _, _) => ColoredBox(
        color: placeholderColor,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
