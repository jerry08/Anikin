import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/text_utils.dart';
import '../models/anilist_media.dart';
import '../models/anilist_media_details.dart';
import '../models/anilist_person_details.dart';
import '../services/anilist_service.dart';
import '../widgets/app_error_view.dart';
import '../widgets/detail_media_tools.dart';
import '../widgets/media_poster_card.dart';

class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({
    required this.person,
    required this.kind,
    required this.aniListService,
    required this.onMediaTap,
    super.key,
  });

  final AniListPersonCredit person;
  final AniListPersonKind kind;
  final AniListService aniListService;
  final ValueChanged<AniListMedia> onMediaTap;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  late Future<AniListPersonDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _load();
  }

  Future<AniListPersonDetails> _load() {
    return widget.aniListService.getPersonDetails(
      id: widget.person.id,
      kind: widget.kind,
    );
  }

  void _retry() {
    setState(() => _detailsFuture = _load());
  }

  Future<void> _openAniList(AniListPersonDetails? details) async {
    final fallbackKind = widget.kind == AniListPersonKind.character
        ? 'character'
        : 'staff';
    final uri = Uri.parse(
      details?.siteUrl ??
          'https://anilist.co/$fallbackKind/${widget.person.id}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AniListPersonDetails>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        final details = snapshot.data;
        final imageUrl = details?.imageUrl ?? widget.person.imageUrl;
        final name = details?.name ?? widget.person.name;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 330,
                actions: [
                  IconButton(
                    tooltip: 'Open on AniList',
                    onPressed: () => unawaited(_openAniList(details)),
                    icon: const Icon(Icons.open_in_new),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: _PersonHero(
                    person: widget.person,
                    kind: widget.kind,
                    imageUrl: imageUrl,
                    name: name,
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppErrorView(
                    message:
                        'Could not load ${widget.kind.label.toLowerCase()} details.',
                    onRetry: _retry,
                  ),
                )
              else if (details != null) ...[
                SliverToBoxAdapter(child: _PersonOverview(details: details)),
                if (details.knownFor.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _KnownForRail(
                      items: details.knownFor,
                      onTap: widget.onMediaTap,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PersonHero extends StatelessWidget {
  const _PersonHero({
    required this.person,
    required this.kind,
    required this.imageUrl,
    required this.name,
  });

  final AniListPersonCredit person;
  final AniListPersonKind kind;
  final String? imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer,
                colorScheme.surfaceContainerHighest,
              ],
            ),
          ),
        ),
        if (imageUrl != null)
          Opacity(
            opacity: 0.22,
            child: CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xE8000000)],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 72, 20, 62),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Hero(
                  tag: 'person-${kind.name}-${person.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 118,
                      height: 170,
                      child: imageUrl == null
                          ? ColoredBox(
                              color: colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.person, size: 54),
                            )
                          : CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kind.label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonOverview extends StatelessWidget {
  const _PersonOverview({required this.details});

  final AniListPersonDetails details;

  @override
  Widget build(BuildContext context) {
    final metadata = <({IconData icon, String label})>[
      if (details.nativeName case final value?)
        (icon: Icons.translate, label: value),
      if (details.gender case final value?)
        (icon: Icons.person_outline, label: value),
      if (details.age case final value?)
        (icon: Icons.cake_outlined, label: 'Age $value'),
      if (details.dateOfBirth case final value?)
        (icon: Icons.event_outlined, label: value),
      if (details.homeTown case final value?)
        (icon: Icons.place_outlined, label: value),
      if (details.bloodType case final value?)
        (icon: Icons.bloodtype_outlined, label: 'Blood type $value'),
      if (details.favourites case final value?)
        (icon: Icons.favorite_border, label: compactNumber(value)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metadata.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in metadata)
                  Chip(
                    avatar: Icon(item.icon, size: 17),
                    label: Text(item.label),
                  ),
              ],
            ),
          if (details.primaryOccupations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              details.primaryOccupations.join(' · '),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
          if (details.description.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'About',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ExpandableSelectableText(
              details.description,
              collapsedLines: 8,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (details.alternativeNames.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Also known as',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(details.alternativeNames.take(8).join(' · ')),
          ],
        ],
      ),
    );
  }
}

class _KnownForRail extends StatelessWidget {
  const _KnownForRail({required this.items, required this.onTap});

  final List<AniListMedia> items;
  final ValueChanged<AniListMedia> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Known for',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 238,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _detailsLimit(items.length),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final media = items[index];
                return SizedBox(
                  width: 132,
                  child: MediaPosterCard(
                    media: media,
                    width: 132,
                    onTap: () => onTap(media),
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

int _detailsLimit(int length) => length > 20 ? 20 : length;
