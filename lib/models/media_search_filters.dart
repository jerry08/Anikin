enum MediaSearchSort {
  popularity('POPULARITY_DESC', 'Popularity'),
  score('SCORE_DESC', 'Score'),
  trending('TRENDING_DESC', 'Trending'),
  recentlyUpdated('UPDATED_AT_DESC', 'Recently updated'),
  titleAscending('TITLE_ROMAJI', 'Title A-Z'),
  titleDescending('TITLE_ROMAJI_DESC', 'Title Z-A');

  const MediaSearchSort(this.graphqlName, this.label);

  final String graphqlName;
  final String label;
}

class MediaSearchFilters {
  const MediaSearchFilters({
    this.sort = MediaSearchSort.popularity,
    this.status,
    this.source,
    this.format,
    this.season,
    this.seasonYear,
    this.countryOfOrigin,
    this.includedGenres = const {},
    this.excludedGenres = const {},
    this.includedTags = const {},
    this.excludedTags = const {},
  });

  static const _notProvided = Object();

  final MediaSearchSort sort;
  final String? status;
  final String? source;
  final String? format;
  final String? season;
  final int? seasonYear;
  final String? countryOfOrigin;
  final Set<String> includedGenres;
  final Set<String> excludedGenres;
  final Set<String> includedTags;
  final Set<String> excludedTags;

  bool get hasActive => activeCount > 0;

  int get activeCount {
    var count = sort == MediaSearchSort.popularity ? 0 : 1;
    count += status == null ? 0 : 1;
    count += source == null ? 0 : 1;
    count += format == null ? 0 : 1;
    count += season == null ? 0 : 1;
    count += seasonYear == null ? 0 : 1;
    count += countryOfOrigin == null ? 0 : 1;
    count += includedGenres.length;
    count += excludedGenres.length;
    count += includedTags.length;
    count += excludedTags.length;
    return count;
  }

  MediaSearchFilters copyWith({
    MediaSearchSort? sort,
    Object? status = _notProvided,
    Object? source = _notProvided,
    Object? format = _notProvided,
    Object? season = _notProvided,
    Object? seasonYear = _notProvided,
    Object? countryOfOrigin = _notProvided,
    Set<String>? includedGenres,
    Set<String>? excludedGenres,
    Set<String>? includedTags,
    Set<String>? excludedTags,
  }) {
    return MediaSearchFilters(
      sort: sort ?? this.sort,
      status: identical(status, _notProvided) ? this.status : status as String?,
      source: identical(source, _notProvided) ? this.source : source as String?,
      format: identical(format, _notProvided) ? this.format : format as String?,
      season: identical(season, _notProvided) ? this.season : season as String?,
      seasonYear: identical(seasonYear, _notProvided)
          ? this.seasonYear
          : seasonYear as int?,
      countryOfOrigin: identical(countryOfOrigin, _notProvided)
          ? this.countryOfOrigin
          : countryOfOrigin as String?,
      includedGenres: includedGenres ?? this.includedGenres,
      excludedGenres: excludedGenres ?? this.excludedGenres,
      includedTags: includedTags ?? this.includedTags,
      excludedTags: excludedTags ?? this.excludedTags,
    );
  }
}

const mediaStatuses = <String, String>{
  'RELEASING': 'Releasing',
  'FINISHED': 'Finished',
  'NOT_YET_RELEASED': 'Not yet released',
  'CANCELLED': 'Cancelled',
  'HIATUS': 'Hiatus',
};

const mediaSources = <String, String>{
  'ORIGINAL': 'Original',
  'MANGA': 'Manga',
  'LIGHT_NOVEL': 'Light novel',
  'VISUAL_NOVEL': 'Visual novel',
  'VIDEO_GAME': 'Video game',
  'NOVEL': 'Novel',
  'WEB_NOVEL': 'Web novel',
  'DOUJINSHI': 'Doujinshi',
  'ANIME': 'Anime',
  'LIVE_ACTION': 'Live action',
  'GAME': 'Game',
  'COMIC': 'Comic',
  'MULTIMEDIA_PROJECT': 'Multimedia project',
  'PICTURE_BOOK': 'Picture book',
  'OTHER': 'Other',
};

const animeFormats = <String, String>{
  'TV': 'TV',
  'TV_SHORT': 'TV short',
  'MOVIE': 'Movie',
  'SPECIAL': 'Special',
  'OVA': 'OVA',
  'ONA': 'ONA',
  'MUSIC': 'Music',
};

const mangaFormats = <String, String>{
  'MANGA': 'Manga',
  'NOVEL': 'Novel',
  'ONE_SHOT': 'One shot',
};

const mediaSeasons = <String, String>{
  'WINTER': 'Winter',
  'SPRING': 'Spring',
  'SUMMER': 'Summer',
  'FALL': 'Fall',
};

const mediaCountries = <String, String>{
  'JP': 'Japan',
  'KR': 'South Korea',
  'CN': 'China',
  'TW': 'Taiwan',
};
