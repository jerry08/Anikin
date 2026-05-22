import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';

enum ResizeModeSetting { original, zoom, stretch }

enum EpisodeLayoutMode { semi, full, list }

enum MangaReadingMode { webtoon, leftToRight, rightToLeft }

enum MangaPageFitMode { width, contain }

enum MangaReaderBackground { black, dark, gray, white }

class PreferencesService extends ChangeNotifier {
  SharedPreferences? _prefs;

  ThemeMode themeMode = ThemeMode.dark;
  ThemeColorPalette themeColorPalette = ThemeColorPalette.anikin;
  bool showNonJapaneseAnime = false;
  String lastAnimeProviderKey = 'Anime';
  String? lastAnimeProviderName;
  String lastMangaProviderKey = 'Manga';
  String? lastMangaProviderName;
  bool episodesDescending = true;
  bool mangaChaptersDescending = true;
  bool showNonJapaneseManga = true;
  MangaReadingMode mangaReadingMode = MangaReadingMode.webtoon;
  MangaPageFitMode mangaPageFitMode = MangaPageFitMode.width;
  MangaReaderBackground mangaReaderBackground = MangaReaderBackground.black;
  double mangaPageGap = 4;
  bool mangaKeepScreenOn = true;
  EpisodeLayoutMode episodeLayoutMode = EpisodeLayoutMode.semi;
  bool alwaysLandscape = true;
  bool selectServerBeforePlaying = false;
  bool cursedSpeeds = false;
  int defaultSpeedIndex = 5;
  int seekTimeSeconds = 10;
  ResizeModeSetting resizeMode = ResizeModeSetting.original;
  bool subtitlesEnabled = true;
  int subtitleFontSize = 20;
  bool autoPlayNext = true;
  bool doubleTapSeek = true;
  bool timeStampsEnabled = true;
  bool showTimeStampButton = true;
  bool developerMode = false;
  bool automaticUpdateChecks = false;

  List<double> get playbackSpeeds => cursedSpeeds
      ? const [1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5, 10, 25, 50]
      : const [0.25, 0.33, 0.5, 0.66, 0.75, 1, 1.25, 1.33, 1.5, 1.66, 1.75, 2];

  double get defaultPlaybackSpeed {
    final speeds = playbackSpeeds;
    return speeds[defaultSpeedIndex.clamp(0, speeds.length - 1).toInt()];
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;

    themeMode =
        ThemeMode.values[(prefs.getInt('themeMode') ?? ThemeMode.dark.index)
            .clamp(0, ThemeMode.values.length - 1)
            .toInt()];
    themeColorPalette =
        ThemeColorPalette.values[(prefs.getInt('themeColorPalette') ??
                ThemeColorPalette.anikin.index)
            .clamp(0, ThemeColorPalette.values.length - 1)
            .toInt()];
    showNonJapaneseAnime = prefs.getBool('showNonJapaneseAnime') ?? false;
    lastAnimeProviderKey = prefs.getString('lastAnimeProviderKey') ?? 'Anime';
    lastAnimeProviderName = prefs.getString('lastAnimeProviderName');
    lastMangaProviderKey = prefs.getString('lastMangaProviderKey') ?? 'Manga';
    lastMangaProviderName = prefs.getString('lastMangaProviderName');
    episodesDescending = prefs.getBool('episodesDescending') ?? true;
    mangaChaptersDescending = prefs.getBool('mangaChaptersDescending') ?? true;
    showNonJapaneseManga = prefs.getBool('showNonJapaneseManga') ?? true;
    mangaReadingMode =
        MangaReadingMode.values[(prefs.getInt('mangaReadingMode') ??
                MangaReadingMode.webtoon.index)
            .clamp(0, MangaReadingMode.values.length - 1)
            .toInt()];
    mangaPageFitMode =
        MangaPageFitMode.values[(prefs.getInt('mangaPageFitMode') ??
                MangaPageFitMode.width.index)
            .clamp(0, MangaPageFitMode.values.length - 1)
            .toInt()];
    mangaReaderBackground =
        MangaReaderBackground.values[(prefs.getInt('mangaReaderBackground') ??
                MangaReaderBackground.black.index)
            .clamp(0, MangaReaderBackground.values.length - 1)
            .toInt()];
    mangaPageGap = prefs.getDouble('mangaPageGap') ?? 4;
    mangaKeepScreenOn = prefs.getBool('mangaKeepScreenOn') ?? true;
    episodeLayoutMode =
        EpisodeLayoutMode.values[(prefs.getInt('episodeLayoutMode') ??
                EpisodeLayoutMode.semi.index)
            .clamp(0, EpisodeLayoutMode.values.length - 1)
            .toInt()];
    alwaysLandscape = prefs.getBool('alwaysLandscape') ?? true;
    selectServerBeforePlaying =
        prefs.getBool('selectServerBeforePlaying') ?? false;
    cursedSpeeds = prefs.getBool('cursedSpeeds') ?? false;
    defaultSpeedIndex = prefs.getInt('defaultSpeedIndex') ?? 5;
    seekTimeSeconds = prefs.getInt('seekTimeSeconds') ?? 10;
    resizeMode =
        ResizeModeSetting.values[(prefs.getInt('resizeMode') ??
                ResizeModeSetting.original.index)
            .clamp(0, ResizeModeSetting.values.length - 1)
            .toInt()];
    subtitlesEnabled = prefs.getBool('subtitlesEnabled') ?? true;
    subtitleFontSize = prefs.getInt('subtitleFontSize') ?? 20;
    autoPlayNext = prefs.getBool('autoPlayNext') ?? true;
    doubleTapSeek = prefs.getBool('doubleTapSeek') ?? true;
    timeStampsEnabled = prefs.getBool('timeStampsEnabled') ?? true;
    showTimeStampButton = prefs.getBool('showTimeStampButton') ?? true;
    developerMode = prefs.getBool('developerMode') ?? false;
    automaticUpdateChecks = prefs.getBool('automaticUpdateChecks') ?? false;
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    await _prefs!.setInt('themeMode', value.index);
    notifyListeners();
  }

  Future<void> setThemeColorPalette(ThemeColorPalette value) async {
    themeColorPalette = value;
    await _prefs!.setInt('themeColorPalette', value.index);
    notifyListeners();
  }

  Future<void> setShowNonJapaneseAnime(bool value) async {
    showNonJapaneseAnime = value;
    await _prefs!.setBool('showNonJapaneseAnime', value);
    notifyListeners();
  }

  Future<void> setLastAnimeProvider(SourceProviderChoice choice) async {
    lastAnimeProviderKey = choice.key;
    lastAnimeProviderName = choice.name;
    await _prefs!.setString('lastAnimeProviderKey', choice.key);
    await _prefs!.setString('lastAnimeProviderName', choice.name);
    notifyListeners();
  }

  Future<void> setLastMangaProvider(SourceProviderChoice choice) async {
    lastMangaProviderKey = choice.key;
    lastMangaProviderName = choice.name;
    await _prefs!.setString('lastMangaProviderKey', choice.key);
    await _prefs!.setString('lastMangaProviderName', choice.name);
    notifyListeners();
  }

  Future<void> setEpisodesDescending(bool value) async {
    episodesDescending = value;
    await _prefs!.setBool('episodesDescending', value);
    notifyListeners();
  }

  Future<void> setMangaChaptersDescending(bool value) async {
    mangaChaptersDescending = value;
    await _prefs!.setBool('mangaChaptersDescending', value);
    notifyListeners();
  }

  Future<void> setShowNonJapaneseManga(bool value) async {
    showNonJapaneseManga = value;
    await _prefs!.setBool('showNonJapaneseManga', value);
    notifyListeners();
  }

  Future<void> setMangaReadingMode(MangaReadingMode value) async {
    mangaReadingMode = value;
    await _prefs!.setInt('mangaReadingMode', value.index);
    notifyListeners();
  }

  Future<void> setMangaPageFitMode(MangaPageFitMode value) async {
    mangaPageFitMode = value;
    await _prefs!.setInt('mangaPageFitMode', value.index);
    notifyListeners();
  }

  Future<void> setMangaReaderBackground(MangaReaderBackground value) async {
    mangaReaderBackground = value;
    await _prefs!.setInt('mangaReaderBackground', value.index);
    notifyListeners();
  }

  Future<void> setMangaPageGap(double value) async {
    mangaPageGap = value.clamp(0, 24).toDouble();
    await _prefs!.setDouble('mangaPageGap', mangaPageGap);
    notifyListeners();
  }

  Future<void> setMangaKeepScreenOn(bool value) async {
    mangaKeepScreenOn = value;
    await _prefs!.setBool('mangaKeepScreenOn', value);
    notifyListeners();
  }

  Future<void> setEpisodeLayoutMode(EpisodeLayoutMode value) async {
    episodeLayoutMode = value;
    await _prefs!.setInt('episodeLayoutMode', value.index);
    notifyListeners();
  }

  Future<void> setAlwaysLandscape(bool value) async {
    alwaysLandscape = value;
    await _prefs!.setBool('alwaysLandscape', value);
    notifyListeners();
  }

  Future<void> setSelectServerBeforePlaying(bool value) async {
    selectServerBeforePlaying = value;
    await _prefs!.setBool('selectServerBeforePlaying', value);
    notifyListeners();
  }

  Future<void> setCursedSpeeds(bool value) async {
    cursedSpeeds = value;
    defaultSpeedIndex = value ? 0 : 5;
    await _prefs!.setBool('cursedSpeeds', value);
    await _prefs!.setInt('defaultSpeedIndex', defaultSpeedIndex);
    notifyListeners();
  }

  Future<void> setDefaultSpeedIndex(int value) async {
    defaultSpeedIndex = value;
    await _prefs!.setInt('defaultSpeedIndex', value);
    notifyListeners();
  }

  Future<void> setSeekTimeSeconds(int value) async {
    seekTimeSeconds = value.clamp(5, 120).toInt();
    await _prefs!.setInt('seekTimeSeconds', seekTimeSeconds);
    notifyListeners();
  }

  Future<void> setResizeMode(ResizeModeSetting value) async {
    resizeMode = value;
    await _prefs!.setInt('resizeMode', value.index);
    notifyListeners();
  }

  Future<void> setSubtitlesEnabled(bool value) async {
    subtitlesEnabled = value;
    await _prefs!.setBool('subtitlesEnabled', value);
    notifyListeners();
  }

  Future<void> setSubtitleFontSize(int value) async {
    subtitleFontSize = value.clamp(12, 42).toInt();
    await _prefs!.setInt('subtitleFontSize', subtitleFontSize);
    notifyListeners();
  }

  Future<void> setAutoPlayNext(bool value) async {
    autoPlayNext = value;
    await _prefs!.setBool('autoPlayNext', value);
    notifyListeners();
  }

  Future<void> setDoubleTapSeek(bool value) async {
    doubleTapSeek = value;
    await _prefs!.setBool('doubleTapSeek', value);
    notifyListeners();
  }

  Future<void> setTimeStampsEnabled(bool value) async {
    timeStampsEnabled = value;
    await _prefs!.setBool('timeStampsEnabled', value);
    notifyListeners();
  }

  Future<void> setShowTimeStampButton(bool value) async {
    showTimeStampButton = value;
    await _prefs!.setBool('showTimeStampButton', value);
    notifyListeners();
  }

  Future<void> setDeveloperMode(bool value) async {
    developerMode = value;
    await _prefs!.setBool('developerMode', value);
    notifyListeners();
  }

  Future<void> setAutomaticUpdateChecks(bool value) async {
    automaticUpdateChecks = value;
    await _prefs!.setBool('automaticUpdateChecks', value);
    notifyListeners();
  }
}

class SourceProviderChoice {
  const SourceProviderChoice({required this.key, required this.name});

  final String key;
  final String name;
}
