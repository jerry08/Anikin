import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/app_constants.dart';
import '../core/platform_capabilities.dart';

class LnReaderPluginService extends ChangeNotifier {
  LnReaderPluginService({
    required PlatformCapabilities capabilities,
    http.Client? client,
    @visibleForTesting Future<Directory> Function()? directoryProvider,
  }) : _capabilities = capabilities,
       _client = client ?? http.Client(),
       _directoryProvider = directoryProvider;

  static final defaultRepository = Uri.parse(
    'https://raw.githubusercontent.com/LNReader/lnreader-plugins/'
    'plugins/v3.0.0/.dist/plugins.min.json',
  );
  static const _maximumIndexBytes = 5 * 1024 * 1024;
  static const _maximumPluginBytes = 12 * 1024 * 1024;

  final PlatformCapabilities _capabilities;
  final http.Client _client;
  final Future<Directory> Function()? _directoryProvider;
  List<LnReaderPlugin> _available = const [];

  bool get isSupported => _capabilities.supportsLnReaderPlugins;
  List<LnReaderPlugin> get available => List.unmodifiable(_available);

  Future<List<LnReaderPlugin>> refreshIndex({Uri? repository}) async {
    _requireAndroid();
    final uri = repository ?? defaultRepository;
    _validateRemoteUri(uri);
    final response = await _client
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': AppConstants.defaultUserAgent,
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw LnReaderPluginException(
        'Plugin repository returned HTTP ${response.statusCode}',
      );
    }
    if (response.bodyBytes.length > _maximumIndexBytes) {
      throw const LnReaderPluginException('Plugin repository is too large');
    }
    final parsed = parseIndex(utf8.decode(response.bodyBytes));
    _available = parsed;
    notifyListeners();
    return parsed;
  }

  Future<List<LnReaderPlugin>> installed() async {
    if (!isSupported) return const [];
    final directory = await _pluginDirectory();
    final results = <LnReaderPlugin>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.plugin.json')) continue;
      try {
        final metadata = jsonDecode(await entity.readAsString());
        if (metadata is! Map) continue;
        final plugin = LnReaderPlugin.fromJson(
          metadata.cast<String, dynamic>(),
        );
        if (plugin.id.isEmpty ||
            !await _scriptFile(directory, plugin.id).exists()) {
          continue;
        }
        results.add(plugin);
      } catch (_) {
        // Ignore incomplete installs; a later install can repair them.
      }
    }
    results.sort((left, right) => left.name.compareTo(right.name));
    return results;
  }

  Future<void> install(LnReaderPlugin plugin) async {
    _requireAndroid();
    _validatePlugin(plugin);
    final uri = Uri.parse(plugin.downloadUrl);
    _validateRemoteUri(uri);
    final response = await _client
        .get(
          uri,
          headers: const {
            'Accept': 'application/javascript, text/javascript, text/plain',
            'User-Agent': AppConstants.defaultUserAgent,
          },
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw LnReaderPluginException(
        'Plugin download returned HTTP ${response.statusCode}',
      );
    }
    if (response.bodyBytes.isEmpty ||
        response.bodyBytes.length > _maximumPluginBytes) {
      throw const LnReaderPluginException(
        'Plugin download has an invalid size',
      );
    }
    final directory = await _pluginDirectory();
    final script = _scriptFile(directory, plugin.id);
    final temporary = File('${script.path}.tmp');
    await temporary.writeAsBytes(response.bodyBytes, flush: true);
    if (await script.exists()) await script.delete();
    await temporary.rename(script.path);
    await _metadataFile(
      directory,
      plugin.id,
    ).writeAsString(jsonEncode(plugin.toJson()), flush: true);
    notifyListeners();
  }

  Future<void> uninstall(String pluginId) async {
    _requireAndroid();
    _validateId(pluginId);
    final directory = await _pluginDirectory();
    for (final file in [
      _scriptFile(directory, pluginId),
      _metadataFile(directory, pluginId),
    ]) {
      if (await file.exists()) await file.delete();
    }
    notifyListeners();
  }

  Future<String?> installedScript(String pluginId) async {
    _requireAndroid();
    _validateId(pluginId);
    final file = _scriptFile(await _pluginDirectory(), pluginId);
    if (!await file.exists()) return null;
    if (await file.length() > _maximumPluginBytes) {
      throw const LnReaderPluginException('Installed plugin is too large');
    }
    return file.readAsString();
  }

  @visibleForTesting
  static List<LnReaderPlugin> parseIndex(String source) {
    final decoded = jsonDecode(source);
    final rawItems = switch (decoded) {
      List value => value,
      Map value when value['plugins'] is List => value['plugins'] as List,
      _ => throw const LnReaderPluginException(
        'Plugin repository does not contain a plugin list',
      ),
    };
    final seen = <String>{};
    final plugins = <LnReaderPlugin>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final plugin = LnReaderPlugin.fromJson(raw.cast<String, dynamic>());
      try {
        _validatePlugin(plugin);
      } on LnReaderPluginException {
        continue;
      }
      if (seen.add(plugin.id)) plugins.add(plugin);
    }
    plugins.sort((left, right) {
      final language = left.language.compareTo(right.language);
      return language == 0 ? left.name.compareTo(right.name) : language;
    });
    return plugins;
  }

  Future<Directory> _pluginDirectory() async {
    final override = _directoryProvider;
    final directory = override != null
        ? await override()
        : Directory(
            '${(await getApplicationSupportDirectory()).path}'
            '${Platform.pathSeparator}lnreader_plugins',
          );
    await directory.create(recursive: true);
    return directory;
  }

  static File _scriptFile(Directory directory, String id) =>
      File('${directory.path}${Platform.pathSeparator}$id.js');

  static File _metadataFile(Directory directory, String id) =>
      File('${directory.path}${Platform.pathSeparator}$id.plugin.json');

  void _requireAndroid() {
    if (!isSupported) {
      throw const LnReaderPluginException(
        'LNReader plugins are available only on Android',
      );
    }
  }

  static void _validatePlugin(LnReaderPlugin plugin) {
    _validateId(plugin.id);
    if (plugin.name.trim().isEmpty || plugin.downloadUrl.trim().isEmpty) {
      throw const LnReaderPluginException('Plugin metadata is incomplete');
    }
    _validateRemoteUri(Uri.parse(plugin.downloadUrl));
  }

  static void _validateId(String id) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,120}$').hasMatch(id)) {
      throw const LnReaderPluginException('Plugin ID is unsafe');
    }
  }

  static void _validateRemoteUri(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const LnReaderPluginException('Plugin URLs must use HTTPS');
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class LnReaderPlugin {
  const LnReaderPlugin({
    required this.id,
    required this.name,
    required this.language,
    required this.version,
    required this.downloadUrl,
    this.siteUrl,
    this.iconUrl,
  });

  final String id;
  final String name;
  final String language;
  final String version;
  final String downloadUrl;
  final String? siteUrl;
  final String? iconUrl;

  factory LnReaderPlugin.fromJson(Map<String, dynamic> json) => LnReaderPlugin(
    id: json['id']?.toString().trim() ?? '',
    name: json['name']?.toString().trim() ?? '',
    language: (json['lang'] ?? json['language'])?.toString().trim() ?? 'other',
    version: json['version']?.toString().trim() ?? '0.0.0',
    downloadUrl: (json['url'] ?? json['downloadUrl'])?.toString().trim() ?? '',
    siteUrl: json['site']?.toString().trim(),
    iconUrl: (json['iconUrl'] ?? json['icon'])?.toString().trim(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'lang': language,
    'version': version,
    'url': downloadUrl,
    if (siteUrl != null) 'site': siteUrl,
    if (iconUrl != null) 'iconUrl': iconUrl,
  };
}

class LnReaderPluginException implements Exception {
  const LnReaderPluginException(this.message);

  final String message;

  @override
  String toString() => message;
}
