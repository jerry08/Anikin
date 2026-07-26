import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/anilist_media.dart';
import '../models/anilist_media_details.dart';
import '../models/anilist_person_details.dart';
import 'media_poster_card.dart';

typedef PersonCreditTapCallback =
    void Function(AniListPersonCredit person, AniListPersonKind kind);

class RichMediaDetailsPanel extends StatelessWidget {
  const RichMediaDetailsPanel({
    required this.details,
    required this.onMediaTap,
    required this.onPersonTap,
    super.key,
  });

  final AniListMediaDetails details;
  final ValueChanged<AniListMedia> onMediaTap;
  final PersonCreditTapCallback onPersonTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (details.relations.isNotEmpty)
          _MediaRail(
            title: 'Related',
            items: details.relations.map((relation) => relation.media).toList(),
            labels: {
              for (final relation in details.relations)
                relation.media.id: relation.type,
            },
            onTap: onMediaTap,
          ),
        if (details.recommendations.isNotEmpty)
          _MediaRail(
            title: 'You may also like',
            items: details.recommendations,
            onTap: onMediaTap,
          ),
        if (details.characters.isNotEmpty)
          _PeopleRail(
            title: 'Characters',
            people: details.characters,
            kind: AniListPersonKind.character,
            onTap: onPersonTap,
          ),
        if (details.staff.isNotEmpty)
          _PeopleRail(
            title: 'Staff',
            people: details.staff,
            kind: AniListPersonKind.staff,
            onTap: onPersonTap,
          ),
      ],
    );
  }
}

class MediaDetailHighlightsCard extends StatelessWidget {
  const MediaDetailHighlightsCard({required this.details, super.key});

  final AniListMediaDetails details;

  @override
  Widget build(BuildContext context) {
    final nextAiringAt = details.nextAiringAt;
    final trailerUrl = details.trailerUrl;
    if (nextAiringAt == null && trailerUrl == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (details.trailerThumbnail case final thumbnail?)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: thumbnail,
                  width: 112,
                  height: 70,
                  fit: BoxFit.cover,
                  placeholder: (context, _) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const SizedBox(width: 112, height: 70),
                  ),
                  errorWidget: (context, _, _) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const SizedBox(
                      width: 112,
                      height: 70,
                      child: Icon(Icons.movie_outlined),
                    ),
                  ),
                ),
              )
            else
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(
                  nextAiringAt != null
                      ? Icons.schedule_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nextAiringAt != null)
                    Text(
                      'Episode ${details.nextAiringEpisode ?? '?'} airs ${DateFormat('EEE, MMM d · jm').format(nextAiringAt)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (nextAiringAt != null && trailerUrl != null)
                    const SizedBox(height: 8),
                  if (trailerUrl != null)
                    FilledButton.tonalIcon(
                      onPressed: () => launchUrl(
                        Uri.parse(trailerUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Watch trailer'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaRail extends StatelessWidget {
  const _MediaRail({
    required this.title,
    required this.items,
    required this.onTap,
    this.labels = const {},
  });

  final String title;
  final List<AniListMedia> items;
  final Map<int, String> labels;
  final ValueChanged<AniListMedia> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 258,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final media = items[index];
                return SizedBox(
                  width: 132,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: MediaPosterCard(
                          media: media,
                          width: 132,
                          onTap: () => onTap(media),
                        ),
                      ),
                      if (labels[media.id] case final label?) ...[
                        const SizedBox(height: 3),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleRail extends StatelessWidget {
  const _PeopleRail({
    required this.title,
    required this.people,
    required this.kind,
    required this.onTap,
  });

  final String title;
  final List<AniListPersonCredit> people;
  final AniListPersonKind kind;
  final PersonCreditTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 104,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final person = people[index];
                return SizedBox(
                  width: 210,
                  child: Material(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: person.id <= 0 ? null : () => onTap(person, kind),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Hero(
                              tag: 'person-${kind.name}-${person.id}',
                              child: CircleAvatar(
                                radius: 34,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                backgroundImage: person.imageUrl == null
                                    ? null
                                    : CachedNetworkImageProvider(
                                        person.imageUrl!,
                                      ),
                                child: person.imageUrl == null
                                    ? const Icon(Icons.person_outline)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    person.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (person.role.isNotEmpty)
                                    Text(
                                      person.role,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
