import '../core/json_utils.dart';
import 'anilist_media.dart';

class AniListAiringSchedule {
  const AniListAiringSchedule({
    required this.id,
    required this.airingAt,
    required this.episode,
    required this.media,
  });

  final int id;
  final int airingAt;
  final int episode;
  final AniListMedia media;

  DateTime get airingDateTime => DateTime.fromMillisecondsSinceEpoch(
    airingAt * 1000,
    isUtc: true,
  ).toLocal();

  factory AniListAiringSchedule.fromJson(Map<String, dynamic> json) {
    return AniListAiringSchedule(
      id: readInt(json, 'id') ?? 0,
      airingAt: readInt(json, 'airingAt') ?? 0,
      episode: readInt(json, 'episode') ?? 0,
      media: AniListMedia.fromJson(
        (readJson(json, 'media') as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
    );
  }
}
