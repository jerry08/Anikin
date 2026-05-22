import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/anilist_media.dart';

class MediaPosterCard extends StatelessWidget {
  const MediaPosterCard({
    required this.media,
    required this.onTap,
    this.width = 132,
    this.showMetadata = true,
    this.showRating = true,
    super.key,
  });

  final AniListMedia media;
  final VoidCallback onTap;
  final double width;
  final bool showMetadata;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final cardRadius = BorderRadius.circular(8);
    final titleStyle = (theme.textTheme.bodyMedium ?? defaultTextStyle)
        .copyWith(fontWeight: FontWeight.w700);
    final metadataStyle = (theme.textTheme.bodySmall ?? defaultTextStyle)
        .copyWith(color: theme.colorScheme.onSurfaceVariant);
    final hasMetadata = showMetadata && media.metadata.isNotEmpty;
    final showRatingBadge = showRating && media.meanScore != null;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        borderRadius: cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: cardRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
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
                      borderRadius: cardRadius,
                      child: SizedBox(
                        width: cardWidth,
                        height: posterHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _PosterImage(url: media.cover.best),
                            if (showRatingBadge)
                              Positioned(
                                right: 7,
                                bottom: 7,
                                child: _RatingBadge(score: media.meanScore!),
                              ),
                          ],
                        ),
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

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFD166)),
            const SizedBox(width: 3),
            Text(
              '$score%',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
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
