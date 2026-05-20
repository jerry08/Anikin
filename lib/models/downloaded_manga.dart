import 'anilist_media.dart';
import 'juro_models.dart';

class DownloadedMangaPage {
  const DownloadedMangaPage({
    required this.page,
    required this.localPath,
    this.title,
    this.bytes = 0,
  });

  final int page;
  final String localPath;
  final String? title;
  final int bytes;

  MangaChapterPage toChapterPage() => MangaChapterPage(
    image: localPath,
    page: page,
    title: title,
    headers: const {},
  );

  Map<String, Object?> toJson() => {
    'page': page,
    'localPath': localPath,
    'title': title,
    'bytes': bytes,
  };

  factory DownloadedMangaPage.fromJson(Map<String, dynamic> json) {
    return DownloadedMangaPage(
      page: (json['page'] as num?)?.toInt() ?? 0,
      localPath: json['localPath']?.toString() ?? '',
      title: json['title']?.toString(),
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class DownloadedMangaChapter {
  const DownloadedMangaChapter({
    required this.id,
    required this.mediaId,
    required this.mediaTitle,
    required this.mangaId,
    required this.mangaTitle,
    required this.providerKey,
    required this.providerName,
    required this.chapterId,
    required this.chapterNumber,
    required this.pages,
    required this.bytes,
    required this.downloadedAt,
    this.coverUrl,
    this.chapterTitle,
    this.mangaImage,
    this.mangaDescription,
  });

  final String id;
  final int mediaId;
  final String mediaTitle;
  final String mangaId;
  final String mangaTitle;
  final String providerKey;
  final String providerName;
  final String chapterId;
  final double chapterNumber;
  final String? coverUrl;
  final String? chapterTitle;
  final String? mangaImage;
  final String? mangaDescription;
  final List<DownloadedMangaPage> pages;
  final int bytes;
  final DateTime downloadedAt;

  String get displayTitle => '$mediaTitle - ${chapter.displayTitle}';

  AniListMedia get media => AniListMedia(
    id: mediaId,
    title: MediaTitle(english: mediaTitle),
    cover: MediaCover(extraLarge: coverUrl, large: coverUrl),
  );

  MangaInfo get mangaInfo => MangaInfo(
    id: mangaId,
    title: mangaTitle,
    image: mangaImage ?? coverUrl,
    description: mangaDescription,
    chapters: [chapter],
  );

  MangaChapter get chapter => MangaChapter(
    id: chapterId,
    title: chapterTitle,
    number: chapterNumber,
    pages: pages.length,
  );

  List<MangaChapterPage> get chapterPages =>
      pages
          .map((page) => page.toChapterPage())
          .where((page) => page.image.isNotEmpty)
          .toList()
        ..sort((a, b) => a.page.compareTo(b.page));

  Map<String, Object?> toJson() => {
    'id': id,
    'mediaId': mediaId,
    'mediaTitle': mediaTitle,
    'mangaId': mangaId,
    'mangaTitle': mangaTitle,
    'providerKey': providerKey,
    'providerName': providerName,
    'chapterId': chapterId,
    'chapterNumber': chapterNumber,
    'coverUrl': coverUrl,
    'chapterTitle': chapterTitle,
    'mangaImage': mangaImage,
    'mangaDescription': mangaDescription,
    'pages': pages.map((page) => page.toJson()).toList(),
    'bytes': bytes,
    'downloadedAt': downloadedAt.toIso8601String(),
  };

  factory DownloadedMangaChapter.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'];
    return DownloadedMangaChapter(
      id: json['id']?.toString() ?? '',
      mediaId: (json['mediaId'] as num?)?.toInt() ?? 0,
      mediaTitle: json['mediaTitle']?.toString() ?? 'Unknown manga',
      mangaId: json['mangaId']?.toString() ?? '',
      mangaTitle: json['mangaTitle']?.toString() ?? 'Unknown manga',
      providerKey: json['providerKey']?.toString() ?? 'Manga',
      providerName: json['providerName']?.toString() ?? 'Manga',
      chapterId: json['chapterId']?.toString() ?? '',
      chapterNumber: (json['chapterNumber'] as num?)?.toDouble() ?? 0,
      coverUrl: json['coverUrl']?.toString(),
      chapterTitle: json['chapterTitle']?.toString(),
      mangaImage: json['mangaImage']?.toString(),
      mangaDescription: json['mangaDescription']?.toString(),
      pages: rawPages is List
          ? rawPages
                .whereType<Map<String, dynamic>>()
                .map(DownloadedMangaPage.fromJson)
                .where((page) => page.localPath.isNotEmpty)
                .toList()
          : const [],
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      downloadedAt:
          DateTime.tryParse(json['downloadedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class MangaChapterDownloadRequest {
  const MangaChapterDownloadRequest({
    required this.media,
    required this.manga,
    required this.chapter,
    required this.providerKey,
    required this.providerName,
  });

  final AniListMedia media;
  final MangaInfo manga;
  final MangaChapter chapter;
  final String providerKey;
  final String providerName;

  String get id => '${media.id}|${manga.id}|${chapter.id}';
  String get displayTitle => '${media.displayTitle} - ${chapter.displayTitle}';
}

enum MangaDownloadTaskStatus {
  queued,
  downloading,
  canceling,
  completed,
  failed,
}

class MangaChapterDownloadProgress {
  const MangaChapterDownloadProgress({
    required this.request,
    required this.status,
    this.pagesCompleted = 0,
    this.pagesTotal,
    this.bytesReceived = 0,
    this.error,
  });

  final MangaChapterDownloadRequest request;
  final MangaDownloadTaskStatus status;
  final int pagesCompleted;
  final int? pagesTotal;
  final int bytesReceived;
  final String? error;

  String get id => request.id;

  double? get progress {
    final total = pagesTotal;
    if (total != null && total > 0) {
      return (pagesCompleted / total).clamp(0, 1).toDouble();
    }
    return null;
  }

  MangaChapterDownloadProgress copyWith({
    MangaDownloadTaskStatus? status,
    int? pagesCompleted,
    int? pagesTotal,
    int? bytesReceived,
    String? error,
  }) {
    return MangaChapterDownloadProgress(
      request: request,
      status: status ?? this.status,
      pagesCompleted: pagesCompleted ?? this.pagesCompleted,
      pagesTotal: pagesTotal ?? this.pagesTotal,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      error: error ?? this.error,
    );
  }
}
