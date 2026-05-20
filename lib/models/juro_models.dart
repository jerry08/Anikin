import '../core/json_utils.dart';
import '../core/text_utils.dart';

class SourceProvider {
  const SourceProvider({
    required this.key,
    required this.name,
    this.language = 'en',
    this.type = 0,
  });

  final String key;
  final String name;
  final String language;
  final int type;

  factory SourceProvider.fromJson(Map<String, dynamic> json) {
    return SourceProvider(
      key: readString(json, 'key') ?? readString(json, 'Key') ?? 'Anime',
      name: readString(json, 'name') ?? readString(json, 'Name') ?? 'Anime',
      language: readString(json, 'language') ?? 'en',
      type: readInt(json, 'type') ?? 0,
    );
  }
}

class JuroGenre {
  const JuroGenre(this.name);

  final String name;

  factory JuroGenre.fromJson(Object? value) {
    if (value is String) {
      return JuroGenre(value);
    }
    if (value is Map<String, dynamic>) {
      final fallback = value.values.isEmpty
          ? ''
          : value.values.first.toString();
      return JuroGenre(readString(value, 'name') ?? fallback);
    }
    return JuroGenre(value?.toString() ?? '');
  }
}

class JuroAnimeInfo {
  const JuroAnimeInfo({
    required this.id,
    required this.title,
    this.site = 0,
    this.released,
    this.category,
    this.link,
    this.image,
    this.type,
    this.status,
    this.otherNames,
    this.summary,
    this.genres = const [],
  });

  final String id;
  final String title;
  final int site;
  final String? released;
  final String? category;
  final String? link;
  final String? image;
  final String? type;
  final String? status;
  final String? otherNames;
  final String? summary;
  final List<JuroGenre> genres;

  factory JuroAnimeInfo.fromJson(Map<String, dynamic> json) {
    final rawGenres = readJson(json, 'genres');
    return JuroAnimeInfo(
      id: readString(json, 'id') ?? '',
      title: readString(json, 'title') ?? 'Untitled',
      site: readInt(json, 'site') ?? 0,
      released: readString(json, 'released'),
      category: readString(json, 'category'),
      link: readString(json, 'link'),
      image: readString(json, 'image'),
      type: readString(json, 'type'),
      status: readString(json, 'status'),
      otherNames: readString(json, 'otherNames'),
      summary: stripHtml(readString(json, 'summary')),
      genres: rawGenres is List
          ? rawGenres
                .map(JuroGenre.fromJson)
                .where((genre) => genre.name.isNotEmpty)
                .toList()
          : const [],
    );
  }
}

class MangaResult {
  const MangaResult({
    required this.id,
    required this.title,
    this.image,
    this.description,
    this.link,
    this.headers = const {},
    this.genres = const [],
    this.status,
    this.views,
    this.authors = const [],
    this.altTitles = const [],
  });

  final String id;
  final String title;
  final String? image;
  final String? description;
  final String? link;
  final Map<String, String> headers;
  final List<String> genres;
  final String? status;
  final String? views;
  final List<String> authors;
  final List<String> altTitles;

  String get displaySubtitle =>
      firstNonBlank([
        if (status != null) status,
        if (views != null) views,
        if (authors.isNotEmpty) authors.join(', '),
      ]) ??
      '';

  factory MangaResult.fromJson(Map<String, dynamic> json) {
    return MangaResult(
      id: readString(json, 'id') ?? '',
      title: readString(json, 'title') ?? 'Untitled',
      image: readString(json, 'image'),
      description: stripHtml(readString(json, 'description')),
      link: readString(json, 'link'),
      headers: readStringMap(readJson(json, 'headers')),
      genres: readStringList(readJson(json, 'genres')),
      status: _readMediaStatus(readJson(json, 'status')),
      views: readString(json, 'views'),
      authors: readStringList(readJson(json, 'authors')),
      altTitles: readStringList(readJson(json, 'altTitles')),
    );
  }
}

class MangaInfo extends MangaResult {
  const MangaInfo({
    required super.id,
    required super.title,
    super.image,
    super.description,
    super.link,
    super.headers,
    super.genres,
    super.status,
    super.views,
    super.authors,
    super.altTitles,
    this.chapters = const [],
  });

  final List<MangaChapter> chapters;

  factory MangaInfo.fromJson(Map<String, dynamic> json) {
    final rawChapters = readJson(json, 'chapters');
    return MangaInfo(
      id: readString(json, 'id') ?? '',
      title: readString(json, 'title') ?? 'Untitled',
      image: readString(json, 'image'),
      description: stripHtml(readString(json, 'description')),
      link: readString(json, 'link'),
      headers: readStringMap(readJson(json, 'headers')),
      genres: readStringList(readJson(json, 'genres')),
      status: _readMediaStatus(readJson(json, 'status')),
      views: readString(json, 'views'),
      authors: readStringList(readJson(json, 'authors')),
      altTitles: readStringList(readJson(json, 'altTitles')),
      chapters: rawChapters is List
          ? rawChapters
                .whereType<Map<String, dynamic>>()
                .map(MangaChapter.fromJson)
                .where((chapter) => chapter.id.isNotEmpty)
                .toList()
          : const [],
    );
  }
}

class MangaChapter {
  const MangaChapter({
    required this.id,
    this.title,
    required this.number,
    this.views,
    this.pages,
  });

  final String id;
  final String? title;
  final double number;
  final String? views;
  final int? pages;

  String get displayTitle {
    final numberText = AnimeEpisode.displayNumber(number);
    final chapterTitle = firstNonBlank([title]);
    if (chapterTitle == null || chapterTitle == numberText) {
      return 'Chapter $numberText';
    }
    return 'Ch $numberText • $chapterTitle';
  }

  String get metadata => [
    if (pages != null && pages! > 0) '$pages pages',
    if (views != null) views,
  ].join(' • ');

  factory MangaChapter.fromJson(Map<String, dynamic> json) {
    return MangaChapter(
      id: readString(json, 'id') ?? '',
      title: readString(json, 'title'),
      number: readDouble(json, 'number') ?? readDouble(json, 'page') ?? 0,
      views: readString(json, 'views'),
      pages: readInt(json, 'pages'),
    );
  }
}

class MangaChapterPage {
  const MangaChapterPage({
    required this.image,
    required this.page,
    this.title,
    this.headers = const {},
  });

  final String image;
  final int page;
  final String? title;
  final Map<String, String> headers;

  factory MangaChapterPage.fromJson(Map<String, dynamic> json) {
    return MangaChapterPage(
      image: readString(json, 'image') ?? '',
      page: readInt(json, 'page') ?? 0,
      title: readString(json, 'title'),
      headers: readStringMap(readJson(json, 'headers')),
    );
  }
}

String? _readMediaStatus(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return switch (value) {
      1 => 'Completed',
      2 => 'Ongoing',
      _ => 'Unknown',
    };
  }
  final text = value.toString().replaceAll('_', ' ').trim();
  if (text.isEmpty) {
    return null;
  }
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

class AnimeEpisode {
  const AnimeEpisode({
    required this.id,
    this.name,
    this.description,
    required this.number,
    this.duration = 0,
    this.link,
    this.image,
    this.progress = 0,
  });

  final String id;
  final String? name;
  final String? description;
  final double number;
  final double duration;
  final String? link;
  final String? image;
  final double progress;

  String get displayName {
    final title = firstNonBlank([name]);
    return title == null
        ? 'Episode ${displayNumber(number)}'
        : 'Ep ${displayNumber(number)} • $title';
  }

  static String displayNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  AnimeEpisode copyWith({String? image, double? progress}) {
    return AnimeEpisode(
      id: id,
      name: name,
      description: description,
      number: number,
      duration: duration,
      link: link,
      image: image ?? this.image,
      progress: progress ?? this.progress,
    );
  }

  factory AnimeEpisode.fromJson(Map<String, dynamic> json) {
    return AnimeEpisode(
      id: readString(json, 'id') ?? '',
      name: readString(json, 'name'),
      description: stripHtml(readString(json, 'description')),
      number: readDouble(json, 'number') ?? 0,
      duration: readDouble(json, 'duration') ?? 0,
      link: readString(json, 'link'),
      image: readString(json, 'image'),
      progress: readDouble(json, 'progress') ?? 0,
    );
  }
}

class FileUrl {
  const FileUrl({required this.url, this.headers = const {}});

  final String url;
  final Map<String, String> headers;

  factory FileUrl.fromJson(Object? value) {
    if (value is String) {
      return FileUrl(url: value);
    }
    if (value is Map<String, dynamic>) {
      return FileUrl(
        url: readString(value, 'url') ?? '',
        headers: readStringMap(readJson(value, 'headers')),
      );
    }
    return const FileUrl(url: '');
  }
}

class VideoServer {
  const VideoServer({required this.name, required this.embed});

  final String name;
  final FileUrl embed;

  factory VideoServer.fromJson(Map<String, dynamic> json) {
    return VideoServer(
      name: readString(json, 'name') ?? 'Default Server',
      embed: FileUrl.fromJson(readJson(json, 'embed')),
    );
  }
}

enum VideoFormat { container, m3u8, hls, dash }

VideoFormat parseVideoFormat(Object? value) {
  if (value is int && value >= 0 && value < VideoFormat.values.length) {
    return VideoFormat.values[value];
  }
  final text = value?.toString().toLowerCase() ?? '';
  if (text.contains('dash')) {
    return VideoFormat.dash;
  }
  if (text.contains('hls')) {
    return VideoFormat.hls;
  }
  if (text.contains('m3u8')) {
    return VideoFormat.m3u8;
  }
  return VideoFormat.container;
}

enum SubtitleKind { vtt, ass, srt }

SubtitleKind parseSubtitleKind(Object? value) {
  if (value is int && value >= 0 && value < SubtitleKind.values.length) {
    return SubtitleKind.values[value];
  }
  final text = value?.toString().toLowerCase() ?? '';
  if (text.contains('ass')) {
    return SubtitleKind.ass;
  }
  if (text.contains('srt')) {
    return SubtitleKind.srt;
  }
  return SubtitleKind.vtt;
}

class SubtitleTrack {
  const SubtitleTrack({
    required this.url,
    required this.language,
    this.kind = SubtitleKind.vtt,
    this.headers = const {},
  });

  final String url;
  final String language;
  final SubtitleKind kind;
  final Map<String, String> headers;

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    return SubtitleTrack(
      url: readString(json, 'url') ?? '',
      language: readString(json, 'language') ?? 'Unknown',
      kind: parseSubtitleKind(readJson(json, 'type')),
      headers: readStringMap(readJson(json, 'headers')),
    );
  }
}

class VideoSource {
  const VideoSource({
    this.title,
    this.resolution,
    required this.videoUrl,
    this.size,
    this.fileType,
    this.format = VideoFormat.container,
    this.extraNote,
    this.headers = const {},
    this.subtitles = const [],
    this.videoServer,
  });

  final String? title;
  final String? resolution;
  final String videoUrl;
  final int? size;
  final String? fileType;
  final VideoFormat format;
  final String? extraNote;
  final Map<String, String> headers;
  final List<SubtitleTrack> subtitles;
  final VideoServer? videoServer;

  String get displayTitle =>
      firstNonBlank([title, resolution, extraNote, fileType]) ??
      'Default Quality';

  String get serverName => videoServer?.name ?? 'Default Server';

  bool get isPlayable => videoUrl.trim().isNotEmpty;

  factory VideoSource.fromJson(Map<String, dynamic> json) {
    final rawSubtitles = readJson(json, 'subtitles');
    return VideoSource(
      title: readString(json, 'title'),
      resolution: readString(json, 'resolution'),
      videoUrl: readString(json, 'videoUrl') ?? '',
      size: readInt(json, 'size'),
      fileType: readString(json, 'fileType'),
      format: parseVideoFormat(readJson(json, 'format')),
      extraNote: readString(json, 'extraNote'),
      headers: readStringMap(readJson(json, 'headers')),
      subtitles: rawSubtitles is List
          ? rawSubtitles
                .whereType<Map<String, dynamic>>()
                .map(SubtitleTrack.fromJson)
                .where((subtitle) => subtitle.url.isNotEmpty)
                .toList()
          : const [],
      videoServer: readJson(json, 'videoServer') is Map<String, dynamic>
          ? VideoServer.fromJson(
              readJson(json, 'videoServer') as Map<String, dynamic>,
            )
          : null,
    );
  }
}
