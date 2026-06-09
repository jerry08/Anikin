import 'package:anikin/core/image_url_utils.dart';
import 'package:anikin/models/anilist_media.dart';
import 'package:anikin/models/juro_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const malformed =
      'https://wp.youtube-anime.com/s4.anilist.co/file/anilistcdn/media/anime/cover/medium/b107342-CohOnqdwuycN.png?w=250';
  const direct =
      'https://s4.anilist.co/file/anilistcdn/media/anime/cover/medium/b107342-CohOnqdwuycN.png?w=250';

  test('normalizes malformed proxied AniList image URLs', () {
    expect(normalizeImageUrl(malformed), direct);
    expect(
      normalizeImageUrl('//s4.anilist.co/file/anilistcdn/image.png'),
      'https://s4.anilist.co/file/anilistcdn/image.png',
    );
    expect(
      normalizeImageUrl('s4.anilist.co/file/anilistcdn/image.png'),
      'https://s4.anilist.co/file/anilistcdn/image.png',
    );
    expect(normalizeImageUrl('C:/downloads/page.jpg'), 'C:/downloads/page.jpg');
  });

  test('normalizes provider and AniList model image fields', () {
    final anime = JuroAnimeInfo.fromJson({
      'id': 'anime-1',
      'title': 'Broken Cover',
      'image': malformed,
    });
    final chapterPage = MangaChapterPage.fromJson({
      'image': malformed,
      'page': 1,
    });
    final media = AniListMedia.fromJson({
      'id': 107342,
      'title': {'english': 'Broken Cover'},
      'coverImage': {'extraLarge': malformed},
      'bannerImage': malformed,
    });

    expect(anime.image, direct);
    expect(chapterPage.image, direct);
    expect(media.cover.best, direct);
    expect(media.bannerImage, direct);
  });
}
