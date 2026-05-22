import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/watch_history.dart';

class WatchHistoryService {
  static const _storageKey = 'player.watchedEpisodes';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<Map<String, WatchedEpisode>> getAll() async {
    final prefs = await _store;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return {};
    }

    return decoded.map((key, value) {
      if (value is Map<String, dynamic>) {
        return MapEntry(key.toString(), WatchedEpisode.fromJson(value));
      }
      if (value is Map) {
        return MapEntry(
          key.toString(),
          WatchedEpisode.fromJson(value.cast<String, dynamic>()),
        );
      }
      return MapEntry(
        key.toString(),
        WatchedEpisode(
          id: key.toString(),
          animeName: '',
          watchedDurationMs: 0,
          watchedPercentage: 0,
        ),
      );
    });
  }

  Future<WatchedEpisode?> get(String id) async {
    final all = await getAll();
    return all[id];
  }

  Future<void> save(WatchedEpisode item) async {
    final prefs = await _store;
    final all = await getAll();
    all[item.id] = item;
    await prefs.setString(
      _storageKey,
      jsonEncode(all.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  Future<void> remove(String id) async {
    final prefs = await _store;
    final all = await getAll();
    if (all.remove(id) == null) {
      return;
    }
    await prefs.setString(
      _storageKey,
      jsonEncode(all.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }
}
