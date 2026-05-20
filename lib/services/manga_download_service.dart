import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';
import '../models/downloaded_manga.dart';
import '../models/juro_models.dart';
import 'juro_service.dart';

class MangaDownloadService extends ChangeNotifier {
  MangaDownloadService({JuroService? juroService, http.Client? client})
    : _juroService = juroService,
      _client = client ?? http.Client();

  static const _storageKey = 'downloads.mangaChapters';

  final JuroService? _juroService;
  final http.Client _client;
  final List<DownloadedMangaChapter> _items = [];
  final Map<String, MangaChapterDownloadProgress> _tasks = {};
  final Set<String> _cancelledTaskIds = {};

  SharedPreferences? _prefs;
  bool _loaded = false;

  List<DownloadedMangaChapter> get items => List.unmodifiable(_items);
  List<MangaChapterDownloadProgress> get activeTasks =>
      List.unmodifiable(_tasks.values);

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    _items
      ..clear()
      ..addAll(
        (_prefs!.getStringList(_storageKey) ?? const [])
            .map(_decodeDownload)
            .whereType<DownloadedMangaChapter>(),
      );
    _items.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    _loaded = true;
    notifyListeners();
  }

  Future<void> ensureLoaded() => load();

  DownloadedMangaChapter? getById(String id) {
    for (final item in _items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  MangaChapterDownloadProgress? taskFor(String id) => _tasks[id];

  bool isDownloaded(String id) => getById(id) != null;

  Future<List<MangaChapterPage>?> pagesFor(String id) async {
    await ensureLoaded();
    final item = getById(id);
    if (item == null) {
      return null;
    }

    final pages = item.chapterPages;
    for (final page in pages) {
      if (!await File(page.image).exists()) {
        return null;
      }
    }
    return pages;
  }

  Future<void> startDownload(MangaChapterDownloadRequest request) async {
    await ensureLoaded();
    final existing = getById(request.id);
    if (existing != null && await _allFilesExist(existing)) {
      return;
    }
    if (existing != null) {
      _items.removeWhere((item) => item.id == request.id);
      await _persist();
      await _deleteDownloadDirectory(request.id);
    }

    final existingTask = _tasks[request.id];
    if (existingTask != null) {
      if (existingTask.status != MangaDownloadTaskStatus.failed) {
        return;
      }
      _tasks.remove(request.id);
    }

    final task = MangaChapterDownloadProgress(
      request: request,
      status: MangaDownloadTaskStatus.queued,
    );
    _tasks[task.id] = task;
    notifyListeners();
    unawaited(_runDownload(task));
  }

  Future<void> cancelDownload(String id) async {
    await ensureLoaded();
    final task = _tasks[id];
    if (task == null) {
      return;
    }
    if (task.status == MangaDownloadTaskStatus.failed) {
      _tasks.remove(id);
      notifyListeners();
      return;
    }

    _cancelledTaskIds.add(id);
    _setTask(task.copyWith(status: MangaDownloadTaskStatus.canceling));
  }

  Future<void> delete(String id) async {
    await ensureLoaded();
    final task = _tasks[id];
    if (task != null && task.status != MangaDownloadTaskStatus.failed) {
      await cancelDownload(id);
      return;
    }

    _tasks.remove(id);
    _cancelledTaskIds.remove(id);
    final item = getById(id);
    if (item != null) {
      _items.removeWhere((download) => download.id == id);
      await _persist();
    }
    await _deleteDownloadDirectory(id);
    notifyListeners();
  }

  Future<void> cancelAllDownloads() async {
    await ensureLoaded();
    for (final id in _tasks.keys.toList()) {
      await cancelDownload(id);
    }
  }

  Future<void> _runDownload(MangaChapterDownloadProgress task) async {
    final request = task.request;
    try {
      _throwIfCancelled(task.id);
      _setTask(task.copyWith(status: MangaDownloadTaskStatus.downloading));
      final pages = await _loadPages(request);
      _throwIfCancelled(task.id);
      _setTask(task.copyWith(pagesTotal: pages.length));

      final root = await _downloadRoot();
      final directory = Directory(_join(root.path, _safeFileName(task.id)));
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await directory.create(recursive: true);

      final downloadedPages = <DownloadedMangaPage>[];
      var bytes = 0;
      for (var index = 0; index < pages.length; index++) {
        _throwIfCancelled(task.id);
        final page = pages[index];
        final fileName =
            'page_${(index + 1).toString().padLeft(4, '0')}${_extensionFor(page.image)}';
        final file = File(_join(directory.path, fileName));
        final pageBytes = await _downloadPage(page, file, task.id);
        bytes += pageBytes;
        downloadedPages.add(
          DownloadedMangaPage(
            page: page.page == 0 ? index + 1 : page.page,
            localPath: file.path,
            title: page.title,
            bytes: pageBytes,
          ),
        );

        final current = _tasks[task.id];
        if (current != null) {
          _setTask(
            current.copyWith(
              pagesCompleted: index + 1,
              pagesTotal: pages.length,
              bytesReceived: bytes,
            ),
          );
        }
      }

      _throwIfCancelled(task.id);
      final download = DownloadedMangaChapter(
        id: request.id,
        mediaId: request.media.id,
        mediaTitle: request.media.displayTitle,
        mangaId: request.manga.id,
        mangaTitle: request.manga.title,
        providerKey: request.providerKey,
        providerName: request.providerName,
        chapterId: request.chapter.id,
        chapterNumber: request.chapter.number,
        coverUrl: request.media.cover.best,
        chapterTitle: request.chapter.title,
        mangaImage: request.manga.image,
        mangaDescription: request.manga.description,
        pages: downloadedPages,
        bytes: bytes,
        downloadedAt: DateTime.now(),
      );

      _items.removeWhere((item) => item.id == download.id);
      _items.insert(0, download);
      await _persist();
      _tasks.remove(task.id);
      _cancelledTaskIds.remove(task.id);
      notifyListeners();
    } on MangaDownloadCancelledException {
      _tasks.remove(task.id);
      _cancelledTaskIds.remove(task.id);
      await _deleteDownloadDirectory(task.id);
      notifyListeners();
    } catch (error) {
      if (_cancelledTaskIds.contains(task.id)) {
        _tasks.remove(task.id);
        _cancelledTaskIds.remove(task.id);
        await _deleteDownloadDirectory(task.id);
        notifyListeners();
        return;
      }
      await _deleteDownloadDirectory(task.id);
      _setTask(
        (_tasks[task.id] ?? task).copyWith(
          status: MangaDownloadTaskStatus.failed,
          error: error.toString(),
        ),
      );
    }
  }

  Future<List<MangaChapterPage>> _loadPages(
    MangaChapterDownloadRequest request,
  ) {
    final service = _juroService;
    if (service == null) {
      throw const MangaDownloadException('Manga service is unavailable.');
    }
    return service.getChapterPages(
      request.chapter.id,
      providerKey: request.providerKey,
    );
  }

  Future<int> _downloadPage(
    MangaChapterPage page,
    File file,
    String taskId,
  ) async {
    _throwIfCancelled(taskId);
    final uri = Uri.parse(page.image.replaceAll(' ', '%20'));
    final request = http.Request('GET', uri)
      ..headers.addAll(_headersFor(page.headers));
    final response = await _client.send(request);
    _throwIfCancelled(taskId);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MangaDownloadException(
        'Page download failed with HTTP ${response.statusCode}.',
      );
    }

    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    var received = 0;
    var completed = false;
    try {
      await for (final chunk in response.stream) {
        _throwIfCancelled(taskId);
        received += chunk.length;
        sink.add(chunk);
      }
      completed = true;
    } finally {
      await sink.close();
      if (!completed && await file.exists()) {
        await file.delete();
      }
    }
    _throwIfCancelled(taskId);
    return received;
  }

  void _setTask(MangaChapterDownloadProgress task) {
    _tasks[task.id] = task;
    notifyListeners();
  }

  Future<bool> _allFilesExist(DownloadedMangaChapter item) async {
    if (item.pages.isEmpty) {
      return false;
    }
    for (final page in item.pages) {
      if (!await File(page.localPath).exists()) {
        return false;
      }
    }
    return true;
  }

  Future<Directory> _downloadRoot() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(_join(root.path, 'offline_manga'));
    await directory.create(recursive: true);
    return directory;
  }

  Map<String, String> _headersFor(Map<String, String> input) {
    final headers = Map<String, String>.from(input);
    final hasUserAgent = headers.keys.any(
      (key) => key.toLowerCase() == 'user-agent',
    );
    if (!hasUserAgent) {
      headers['User-Agent'] = AppConstants.defaultUserAgent;
    }
    return headers;
  }

  String _extensionFor(String value) {
    final uri = Uri.tryParse(value);
    final segment = uri?.pathSegments.isEmpty == false
        ? uri!.pathSegments.last
        : '';
    final dot = segment.lastIndexOf('.');
    if (dot >= 0 && dot < segment.length - 1) {
      final extension = segment.substring(dot).toLowerCase();
      if (extension.length <= 8) {
        return extension;
      }
    }
    return '.jpg';
  }

  Future<void> _deleteDownloadDirectory(String id) async {
    final root = await _downloadRoot();
    final directory = Directory(_join(root.path, _safeFileName(id)));
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  void _throwIfCancelled(String id) {
    if (_cancelledTaskIds.contains(id)) {
      throw const MangaDownloadCancelledException();
    }
  }

  Future<void> _persist() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      _items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  DownloadedMangaChapter? _decodeDownload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return DownloadedMangaChapter.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String _safeFileName(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (sanitized.isEmpty) {
      return 'download';
    }
    return sanitized.length > 120
        ? sanitized.substring(0, 120).trim()
        : sanitized;
  }

  String _join(String left, String right) =>
      left.endsWith(Platform.pathSeparator)
      ? '$left$right'
      : '$left${Platform.pathSeparator}$right';
}

class MangaDownloadException implements Exception {
  const MangaDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MangaDownloadCancelledException implements Exception {
  const MangaDownloadCancelledException();

  @override
  String toString() => 'Manga download cancelled';
}
