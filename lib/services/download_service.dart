import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';
import '../models/downloaded_episode.dart';
import '../models/juro_models.dart';

class DownloadService extends ChangeNotifier {
  DownloadService({http.Client? client}) : _client = client ?? http.Client();

  static const _storageKey = 'downloads.episodes';

  final http.Client _client;
  final List<DownloadedEpisode> _items = [];
  final Map<String, EpisodeDownloadProgress> _tasks = {};
  final Set<String> _cancelledTaskIds = {};
  final Set<String> _pausedTaskIds = {};

  SharedPreferences? _prefs;
  bool _loaded = false;

  List<DownloadedEpisode> get items => List.unmodifiable(_items);
  List<EpisodeDownloadProgress> get activeTasks =>
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
            .whereType<DownloadedEpisode>(),
      );
    _items.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    _loaded = true;
    notifyListeners();
  }

  Future<void> ensureLoaded() => load();

  DownloadedEpisode? getById(String id) {
    for (final item in _items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  EpisodeDownloadProgress? taskFor(String id) => _tasks[id];

  EpisodeDownloadProgress? taskForSource(String sourceTaskId) {
    final exactTask = _tasks[sourceTaskId];
    if (exactTask != null) {
      return exactTask;
    }
    for (final task in _tasks.values) {
      if (task.sourceTaskId == sourceTaskId) {
        return task;
      }
    }
    return null;
  }

  EpisodeDownloadProgress? taskForEpisode(String episodeId) {
    for (final task in _tasks.values) {
      if (task.episodeId == episodeId) {
        return task;
      }
    }
    return null;
  }

  bool isDownloaded(String id) => getById(id) != null;

  Future<List<HlsDownloadVariant>> getHlsVariants(VideoSource source) async {
    final uri = Uri.tryParse(source.videoUrl.replaceAll(' ', '%20'));
    if (uri == null || !_isHls(source, uri)) {
      return const [];
    }

    final body = await _getText(
      uri,
      _headersFor(source),
      taskId: 'hls-variant:${source.videoUrl}',
    );
    final variants = _readHlsVariants(body, uri);
    variants.sort(_compareHlsVariants);
    return variants;
  }

  VideoSource sourceForHlsVariant(
    VideoSource source,
    HlsDownloadVariant variant,
  ) {
    return VideoSource(
      title: variant.displayTitle,
      resolution: variant.resolutionLabel,
      videoUrl: variant.uri.toString(),
      size: source.size,
      fileType: source.fileType ?? 'HLS',
      format: VideoFormat.hls,
      extraNote: source.extraNote,
      headers: source.headers,
      subtitles: source.subtitles,
      videoServer: source.videoServer,
    );
  }

  Future<void> startDownload(EpisodeDownloadRequest request) async {
    await ensureLoaded();
    final existing = getById(request.id);
    if (existing != null) {
      if (await File(existing.localPath).exists()) {
        return;
      }
      _items.removeWhere((item) => item.id == request.id);
      await _persist();
    }
    final existingTask = _tasks[request.taskId];
    if (existingTask != null) {
      if (existingTask.status == DownloadTaskStatus.paused) {
        await resumeDownload(existingTask.id);
        return;
      }
      if (existingTask.status != DownloadTaskStatus.failed) {
        return;
      }
      _tasks.remove(request.taskId);
    }

    final task = EpisodeDownloadProgress(
      request: request,
      status: DownloadTaskStatus.queued,
    );
    _tasks[task.id] = task;
    notifyListeners();
    unawaited(_runDownload(task));
  }

  Future<void> delete(String id) async {
    await ensureLoaded();
    final task = _tasks[id];
    if (task != null && task.status != DownloadTaskStatus.failed) {
      await cancelDownload(id);
      return;
    }

    _tasks.remove(id);
    _cancelledTaskIds.remove(id);
    _pausedTaskIds.remove(id);
    final item = getById(id);
    if (item != null) {
      _items.removeWhere((download) => download.id == id);
      await _persist();
      await _deleteStoredFile(item.localPath);
    }
    notifyListeners();
  }

  Future<void> cancelDownload(String id) async {
    await ensureLoaded();
    final task = _tasks[id];
    if (task == null) {
      return;
    }
    if (task.status == DownloadTaskStatus.failed) {
      _tasks.remove(id);
      notifyListeners();
      return;
    }
    if (task.status == DownloadTaskStatus.paused) {
      _tasks.remove(id);
      _pausedTaskIds.remove(id);
      _cancelledTaskIds.remove(id);
      await _deleteDownloadDirectory(id);
      notifyListeners();
      return;
    }

    _cancelledTaskIds.add(id);
    _pausedTaskIds.remove(id);
    _setTask(task.copyWith(status: DownloadTaskStatus.canceling));
  }

  Future<void> pauseDownload(String id) async {
    await ensureLoaded();
    final task = _tasks[id];
    if (task == null ||
        task.status == DownloadTaskStatus.failed ||
        task.status == DownloadTaskStatus.paused ||
        task.status == DownloadTaskStatus.canceling) {
      return;
    }

    _pausedTaskIds.add(id);
    _setTask(task.copyWith(status: DownloadTaskStatus.pausing));
  }

  Future<void> resumeDownload(String id) async {
    await ensureLoaded();
    final task = _tasks[id];
    if (task == null || task.status != DownloadTaskStatus.paused) {
      return;
    }

    _pausedTaskIds.remove(id);
    _cancelledTaskIds.remove(id);
    final resumed = task.copyWith(status: DownloadTaskStatus.queued);
    _setTask(resumed);
    unawaited(_runDownload(resumed, resume: true));
  }

  Future<void> cancelAllDownloads() async {
    await ensureLoaded();
    for (final id in _tasks.keys.toList()) {
      await cancelDownload(id);
    }
  }

  Future<void> pauseAllDownloads() async {
    await ensureLoaded();
    for (final id in _tasks.keys.toList()) {
      await pauseDownload(id);
    }
  }

  Future<void> resumeAllDownloads() async {
    await ensureLoaded();
    for (final id in _tasks.keys.toList()) {
      await resumeDownload(id);
    }
  }

  Future<void> _runDownload(
    EpisodeDownloadProgress task, {
    bool resume = false,
  }) async {
    final request = task.request;
    try {
      _throwIfCancelled(task.id);
      _setTask(task.copyWith(status: DownloadTaskStatus.downloading));
      final stored = await _storeVideo(request, resume: resume);
      _throwIfCancelled(task.id);
      final download = DownloadedEpisode(
        id: request.id,
        mediaId: request.media.id,
        mediaTitle: request.media.displayTitle,
        providerAnimeId: request.providerAnime.id,
        providerAnimeTitle: request.providerAnime.title,
        episodeId: request.episode.id,
        episodeName: request.episode.name,
        episodeNumber: request.episode.number,
        coverUrl:
            request.episode.image ??
            request.providerAnime.image ??
            request.media.cover.best,
        sourceTitle: request.source.displayTitle,
        serverName: request.source.serverName,
        localPath: stored.path,
        fileName: stored.fileName,
        bytes: stored.bytes,
        downloadedAt: DateTime.now(),
      );

      _items.removeWhere((item) => item.id == download.id);
      _items.insert(0, download);
      await _persist();
      _tasks.remove(task.id);
      _cancelledTaskIds.remove(task.id);
      _pausedTaskIds.remove(task.id);
      notifyListeners();
    } on DownloadPausedException {
      final current = _tasks[task.id] ?? task;
      _pausedTaskIds.add(task.id);
      _setTask(current.copyWith(status: DownloadTaskStatus.paused));
    } on DownloadCancelledException {
      _tasks.remove(task.id);
      _cancelledTaskIds.remove(task.id);
      _pausedTaskIds.remove(task.id);
      await _deleteDownloadDirectory(task.id);
      notifyListeners();
    } catch (error) {
      if (_cancelledTaskIds.contains(task.id)) {
        _tasks.remove(task.id);
        _cancelledTaskIds.remove(task.id);
        _pausedTaskIds.remove(task.id);
        await _deleteDownloadDirectory(task.id);
        notifyListeners();
        return;
      }
      await _deleteDownloadDirectory(task.id);
      _setTask(
        (_tasks[task.id] ?? task).copyWith(
          status: DownloadTaskStatus.failed,
          error: error.toString(),
        ),
      );
    }
  }

  void _setTask(EpisodeDownloadProgress task) {
    _tasks[task.id] = task;
    notifyListeners();
  }

  Future<_StoredVideo> _storeVideo(
    EpisodeDownloadRequest request, {
    required bool resume,
  }) async {
    final taskId = request.taskId;
    _throwIfCancelled(taskId);
    final source = request.source;
    if (source.format == VideoFormat.dash) {
      throw const DownloadException('DASH downloads are not supported yet.');
    }

    final root = await _downloadRoot();
    final episodeDirectory = Directory(_join(root.path, _safeFileName(taskId)));
    if (!resume && await episodeDirectory.exists()) {
      await episodeDirectory.delete(recursive: true);
    }
    await episodeDirectory.create(recursive: true);
    _throwIfCancelled(taskId);

    final uri = Uri.parse(source.videoUrl.replaceAll(' ', '%20'));
    final headers = _headersFor(source);
    if (_isHls(source, uri)) {
      return _storeHls(
        request: request,
        directory: episodeDirectory,
        uri: uri,
        headers: headers,
        resume: resume,
      );
    }

    final fileName =
        '${_safeFileName(request.displayTitle)}${_extensionFor(uri)}';
    final file = File(_join(episodeDirectory.path, fileName));
    final totalBytes = await _downloadToFile(
      uri: uri,
      file: file,
      headers: headers,
      taskId: taskId,
      resume: resume,
      onProgress: (received, total) {
        final current = _tasks[taskId];
        if (current == null) {
          return;
        }
        _setTask(current.copyWith(bytesReceived: received, bytesTotal: total));
      },
    );
    return _StoredVideo(path: file.path, fileName: fileName, bytes: totalBytes);
  }

  Future<_StoredVideo> _storeHls({
    required EpisodeDownloadRequest request,
    required Directory directory,
    required Uri uri,
    required Map<String, String> headers,
    required bool resume,
  }) async {
    final taskId = request.taskId;
    _throwIfCancelled(taskId);
    final playlist = await _loadMediaPlaylist(
      uri,
      headers,
      depth: 0,
      taskId: taskId,
    );
    final lines = const LineSplitter().convert(playlist.body);
    if (lines.any(_isEncryptedHlsLine)) {
      throw const DownloadException(
        'Encrypted HLS downloads are not supported for offline mode.',
      );
    }

    final segmentLines = lines
        .where((line) => line.trim().isNotEmpty && !line.trim().startsWith('#'))
        .length;
    var completedSegments = 0;
    var bytes = 0;
    var segmentIndex = 0;
    final output = <String>[];

    _setTask(
      (_tasks[taskId] ??
              EpisodeDownloadProgress(
                request: request,
                status: DownloadTaskStatus.downloading,
              ))
          .copyWith(itemsTotal: segmentLines),
    );

    for (final line in lines) {
      _throwIfCancelled(taskId);
      final trimmed = line.trim();
      if (trimmed.startsWith('#EXT-X-MAP')) {
        final rewritten = await _downloadHlsMap(
          line: line,
          playlistUri: playlist.uri,
          directory: directory,
          headers: headers,
          taskId: taskId,
          resume: resume,
        );
        bytes += rewritten.bytes;
        output.add(rewritten.line);
        continue;
      }

      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        output.add(line);
        continue;
      }

      final segmentUri = playlist.uri.resolve(trimmed);
      final extension = _extensionFor(segmentUri, fallback: '.ts');
      final fileName =
          'segment_${segmentIndex.toString().padLeft(5, '0')}$extension';
      final file = File(_join(directory.path, fileName));
      final segmentBytes = resume && await file.exists()
          ? await file.length()
          : await _downloadToFile(
              uri: segmentUri,
              file: file,
              headers: headers,
              taskId: taskId,
              resume: resume,
            );
      bytes += segmentBytes;
      completedSegments++;
      segmentIndex++;
      output.add(fileName);

      final current = _tasks[taskId];
      if (current != null) {
        _setTask(
          current.copyWith(
            bytesReceived: bytes,
            itemsCompleted: completedSegments,
            itemsTotal: segmentLines,
          ),
        );
      }
    }

    _throwIfCancelled(taskId);
    final playlistFile = File(_join(directory.path, 'index.m3u8'));
    await playlistFile.writeAsString(output.join('\n'));
    return _StoredVideo(
      path: playlistFile.path,
      fileName: 'index.m3u8',
      bytes: bytes,
    );
  }

  Future<_HlsMapResult> _downloadHlsMap({
    required String line,
    required Uri playlistUri,
    required Directory directory,
    required Map<String, String> headers,
    required String taskId,
    required bool resume,
  }) async {
    _throwIfCancelled(taskId);
    final match = RegExp('URI="([^"]+)"').firstMatch(line);
    if (match == null) {
      return _HlsMapResult(line: line, bytes: 0);
    }

    final mapUri = playlistUri.resolve(match.group(1)!);
    final fileName = 'init${_extensionFor(mapUri, fallback: '.mp4')}';
    final file = File(_join(directory.path, fileName));
    final bytes = resume && await file.exists()
        ? await file.length()
        : await _downloadToFile(
            uri: mapUri,
            file: file,
            headers: headers,
            taskId: taskId,
            resume: resume,
          );
    return _HlsMapResult(
      line: line.replaceFirst(match.group(1)!, fileName),
      bytes: bytes,
    );
  }

  Future<_HlsPlaylist> _loadMediaPlaylist(
    Uri uri,
    Map<String, String> headers, {
    required int depth,
    required String taskId,
  }) async {
    _throwIfCancelled(taskId);
    if (depth > 3) {
      throw const DownloadException('Unable to resolve HLS playlist.');
    }

    final body = await _getText(uri, headers, taskId: taskId);
    final variants = _readHlsVariants(body, uri)..sort(_compareHlsVariants);

    if (variants.isEmpty) {
      return _HlsPlaylist(uri: uri, body: body);
    }
    return _loadMediaPlaylist(
      variants.first.uri,
      headers,
      depth: depth + 1,
      taskId: taskId,
    );
  }

  Future<String> _getText(
    Uri uri,
    Map<String, String> headers, {
    required String taskId,
  }) async {
    _throwIfCancelled(taskId);
    final response = await _client.get(uri, headers: headers);
    _throwIfCancelled(taskId);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DownloadException(
        'Download failed with HTTP ${response.statusCode}.',
      );
    }
    return response.body;
  }

  Future<int> _downloadToFile({
    required Uri uri,
    required File file,
    required Map<String, String> headers,
    required String taskId,
    required bool resume,
    void Function(int received, int? total)? onProgress,
  }) async {
    _throwIfCancelled(taskId);
    final tempFile = File('${file.path}.download');
    final resumeOffset = resume && await tempFile.exists()
        ? await tempFile.length()
        : 0;
    final request = http.Request('GET', uri)..headers.addAll(headers);
    if (resumeOffset > 0) {
      request.headers['Range'] = 'bytes=$resumeOffset-';
    }
    final response = await _client.send(request);
    _throwIfCancelled(taskId);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DownloadException(
        'Download failed with HTTP ${response.statusCode}.',
      );
    }

    final canAppend = resumeOffset > 0 && response.statusCode == 206;
    if (resumeOffset > 0 && !canAppend && await tempFile.exists()) {
      await tempFile.delete();
    }
    final expectedTotal = canAppend && response.contentLength != null
        ? resumeOffset + response.contentLength!
        : response.contentLength;
    await tempFile.parent.create(recursive: true);
    final sink = tempFile.openWrite(
      mode: canAppend ? FileMode.append : FileMode.write,
    );
    var received = canAppend ? resumeOffset : 0;
    var lastNotified = 0;
    var completed = false;
    try {
      await for (final chunk in response.stream) {
        _throwIfCancelled(taskId);
        received += chunk.length;
        sink.add(chunk);
        if (received - lastNotified >= 512 * 1024 ||
            received == expectedTotal) {
          lastNotified = received;
          onProgress?.call(received, expectedTotal);
        }
      }
      completed = true;
    } finally {
      await sink.close();
      if (!completed &&
          !_pausedTaskIds.contains(taskId) &&
          await tempFile.exists()) {
        await tempFile.delete();
      }
    }

    _throwIfCancelled(taskId);
    onProgress?.call(received, expectedTotal);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
    return received;
  }

  Future<Directory> _downloadRoot() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(_join(root.path, 'offline_episodes'));
    await directory.create(recursive: true);
    return directory;
  }

  Map<String, String> _headersFor(VideoSource source) {
    final headers = Map<String, String>.from(source.headers);
    final hasUserAgent = headers.keys.any(
      (key) => key.toLowerCase() == 'user-agent',
    );
    if (!hasUserAgent) {
      headers['User-Agent'] = AppConstants.defaultUserAgent;
    }
    return headers;
  }

  bool _isHls(VideoSource source, Uri uri) {
    final path = uri.path.toLowerCase();
    return source.format == VideoFormat.hls ||
        source.format == VideoFormat.m3u8 ||
        path.endsWith('.m3u8') ||
        (source.fileType?.toLowerCase().contains('m3u8') ?? false);
  }

  bool _isEncryptedHlsLine(String line) {
    final upper = line.toUpperCase();
    return upper.startsWith('#EXT-X-KEY') && !upper.contains('METHOD=NONE');
  }

  List<HlsDownloadVariant> _readHlsVariants(String body, Uri playlistUri) {
    final lines = const LineSplitter().convert(body);
    final variants = <HlsDownloadVariant>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) {
        continue;
      }

      final attributes = _readHlsAttributes(line);
      for (var next = index + 1; next < lines.length; next++) {
        final candidate = lines[next].trim();
        if (candidate.isEmpty) {
          continue;
        }
        if (!candidate.startsWith('#')) {
          variants.add(
            HlsDownloadVariant(
              uri: playlistUri.resolve(candidate),
              bandwidth: int.tryParse(attributes['BANDWIDTH'] ?? '') ?? 0,
              averageBandwidth: int.tryParse(
                attributes['AVERAGE-BANDWIDTH'] ?? '',
              ),
              width: _readHlsWidth(attributes['RESOLUTION']),
              height: _readHlsHeight(attributes['RESOLUTION']),
              frameRate: double.tryParse(attributes['FRAME-RATE'] ?? ''),
              codecs: attributes['CODECS'],
            ),
          );
        }
        break;
      }
    }
    return variants;
  }

  Map<String, String> _readHlsAttributes(String line) {
    final separator = line.indexOf(':');
    if (separator < 0 || separator == line.length - 1) {
      return const {};
    }

    final attributes = <String, String>{};
    final matches = RegExp(
      r'([A-Z0-9-]+)=("[^"]*"|[^,]*)',
    ).allMatches(line.substring(separator + 1));
    for (final match in matches) {
      final name = match.group(1);
      final rawValue = match.group(2);
      if (name == null || rawValue == null) {
        continue;
      }
      attributes[name] = rawValue.startsWith('"') && rawValue.endsWith('"')
          ? rawValue.substring(1, rawValue.length - 1)
          : rawValue;
    }
    return attributes;
  }

  int? _readHlsWidth(String? resolution) {
    final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(resolution ?? '');
    return int.tryParse(match?.group(1) ?? '');
  }

  int? _readHlsHeight(String? resolution) {
    final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(resolution ?? '');
    return int.tryParse(match?.group(2) ?? '');
  }

  int _compareHlsVariants(HlsDownloadVariant left, HlsDownloadVariant right) {
    final heightComparison = (right.height ?? 0).compareTo(left.height ?? 0);
    if (heightComparison != 0) {
      return heightComparison;
    }
    return right.effectiveBandwidth.compareTo(left.effectiveBandwidth);
  }

  String _extensionFor(Uri uri, {String fallback = '.mp4'}) {
    final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dot = segment.lastIndexOf('.');
    if (dot >= 0 && dot < segment.length - 1) {
      final extension = segment.substring(dot).toLowerCase();
      if (extension.length <= 8) {
        return extension;
      }
    }
    return fallback;
  }

  Future<void> _deleteStoredFile(String localPath) async {
    final file = File(localPath);
    final root = await _downloadRoot();
    final parent = file.parent;
    if (parent.path.startsWith(root.path) && await parent.exists()) {
      await parent.delete(recursive: true);
    } else if (await file.exists()) {
      await file.delete();
    }
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
      throw const DownloadCancelledException();
    }
    if (_pausedTaskIds.contains(id)) {
      throw const DownloadPausedException();
    }
  }

  Future<void> _persist() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      _items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  DownloadedEpisode? _decodeDownload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return DownloadedEpisode.fromJson(decoded);
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

class DownloadException implements Exception {
  const DownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DownloadCancelledException implements Exception {
  const DownloadCancelledException();

  @override
  String toString() => 'Download cancelled';
}

class DownloadPausedException implements Exception {
  const DownloadPausedException();

  @override
  String toString() => 'Download paused';
}

class _StoredVideo {
  const _StoredVideo({
    required this.path,
    required this.fileName,
    required this.bytes,
  });

  final String path;
  final String fileName;
  final int bytes;
}

class _HlsPlaylist {
  const _HlsPlaylist({required this.uri, required this.body});

  final Uri uri;
  final String body;
}

class HlsDownloadVariant {
  const HlsDownloadVariant({
    required this.uri,
    required this.bandwidth,
    this.averageBandwidth,
    this.width,
    this.height,
    this.frameRate,
    this.codecs,
  });

  final Uri uri;
  final int bandwidth;
  final int? averageBandwidth;
  final int? width;
  final int? height;
  final double? frameRate;
  final String? codecs;

  int get effectiveBandwidth => averageBandwidth ?? bandwidth;

  String? get resolutionLabel {
    final heightValue = height;
    if (heightValue != null && heightValue > 0) {
      return '${heightValue}p';
    }

    final widthValue = width;
    if (widthValue != null && widthValue > 0) {
      return '${widthValue}px wide';
    }

    return null;
  }

  String? get bitrateLabel {
    final bitrate = effectiveBandwidth;
    if (bitrate <= 0) {
      return null;
    }
    if (bitrate >= 1000000) {
      final mbps = bitrate / 1000000;
      return '${mbps >= 10 ? mbps.toStringAsFixed(0) : mbps.toStringAsFixed(1)} Mbps';
    }
    return '${(bitrate / 1000).round()} kbps';
  }

  String get displayTitle {
    final title = [
      resolutionLabel,
      bitrateLabel,
    ].whereType<String>().join(' • ');
    return title.isEmpty ? 'Default quality' : title;
  }
}

class _HlsMapResult {
  const _HlsMapResult({required this.line, required this.bytes});

  final String line;
  final int bytes;
}
