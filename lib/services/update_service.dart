import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import '../core/platform_capabilities.dart';
import 'anilist_service.dart';

class UpdateService {
  UpdateService({
    required this.currentVersion,
    http.Client? client,
    Uri? latestReleaseUri,
    PlatformCapabilities? capabilities,
    MethodChannel? appUpdateChannel,
  }) : _client = client ?? http.Client(),
       _latestReleaseUri =
           latestReleaseUri ??
           Uri.parse(AppConstants.githubLatestReleaseEndpoint),
       _capabilities = capabilities ?? PlatformCapabilities.detect(),
       _appUpdateChannel =
           appUpdateChannel ?? const MethodChannel(_appUpdateChannelName);

  static const _appUpdateChannelName = 'com.oneb.anikin/app_update';

  final http.Client _client;
  final String currentVersion;
  final Uri _latestReleaseUri;
  final PlatformCapabilities _capabilities;
  final MethodChannel _appUpdateChannel;

  Future<UpdateCheckResult> checkForUpdate() async {
    final response = await _client.get(
      _latestReleaseUri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': AppConstants.defaultUserAgent,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Update check returned ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Unexpected update response shape');
    }

    final release = AppRelease.fromJson(decoded);
    final latest = AppVersion.parse(release.version);
    final current = AppVersion.parse(currentVersion);
    return UpdateCheckResult(
      currentVersion: currentVersion,
      release: release,
      isUpdateAvailable: latest.compareTo(current) > 0,
    );
  }

  bool canInstallDirectly(AppRelease release) =>
      _capabilities.isAndroid && release.androidApkAsset != null;

  Future<int> downloadAndInstall(AppRelease release) async {
    if (!_capabilities.isAndroid) {
      throw const AppUpdateException(
        'In-app installation is only available on Android.',
      );
    }

    final asset = release.androidApkAsset;
    if (asset == null) {
      throw const AppUpdateException(
        'This release does not include a compatible Android APK.',
      );
    }

    final downloadUri = Uri.tryParse(asset.downloadUrl);
    if (downloadUri == null ||
        downloadUri.scheme.toLowerCase() != 'https' ||
        downloadUri.host.isEmpty) {
      throw const AppUpdateException(
        'The Android update has an invalid download URL.',
      );
    }

    try {
      final downloadId = await _appUpdateChannel
          .invokeMethod<int>('downloadAndInstall', {
            'url': downloadUri.toString(),
            'fileName': asset.name,
            'version': release.version,
          });
      if (downloadId == null || downloadId < 0) {
        throw const AppUpdateException(
          'Android could not start the update download.',
        );
      }
      return downloadId;
    } on MissingPluginException {
      throw const AppUpdateException(
        'The Android update installer is unavailable.',
      );
    } on PlatformException catch (error) {
      throw AppUpdateException(
        error.message ?? 'Android could not start the update download.',
      );
    }
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.release,
    required this.isUpdateAvailable,
  });

  final String currentVersion;
  final AppRelease release;
  final bool isUpdateAvailable;
}

class AppRelease {
  const AppRelease({
    required this.tagName,
    required this.version,
    required this.title,
    required this.url,
    required this.body,
    this.assets = const [],
  });

  final String tagName;
  final String version;
  final String title;
  final String url;
  final String body;
  final List<AppReleaseAsset> assets;

  AppReleaseAsset? get androidApkAsset {
    final apks = assets
        .where((asset) => asset.isDownloadableApk)
        .toList(growable: false);
    if (apks.isEmpty) {
      return null;
    }

    for (final asset in apks) {
      if (asset.name.toLowerCase().contains('universal')) {
        return asset;
      }
    }

    final withoutExplicitAbi = apks
        .where((asset) {
          final name = asset.name.toLowerCase();
          return !name.contains('arm64') &&
              !name.contains('armeabi') &&
              !name.contains('x86') &&
              !name.contains('x64');
        })
        .toList(growable: false);
    if (withoutExplicitAbi.length == 1) {
      return withoutExplicitAbi.single;
    }
    if (apks.length == 1) {
      return apks.single;
    }
    return null;
  }

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name']?.toString().trim() ?? '';
    if (tagName.isEmpty) {
      throw const ApiException('Latest release is missing a version tag');
    }

    return AppRelease(
      tagName: tagName,
      version: _normalizeTagVersion(tagName),
      title: (json['name']?.toString().trim().isNotEmpty ?? false)
          ? json['name'].toString().trim()
          : tagName,
      url: (json['html_url']?.toString().trim().isNotEmpty ?? false)
          ? json['html_url'].toString().trim()
          : AppConstants.githubReleasesUrl,
      body: json['body']?.toString().trim() ?? '',
      assets: _parseReleaseAssets(json['assets']),
    );
  }

  static String _normalizeTagVersion(String tagName) {
    return tagName.trim().replaceFirst(RegExp(r'^[vV]'), '');
  }
}

class AppReleaseAsset {
  const AppReleaseAsset({required this.name, required this.downloadUrl});

  final String name;
  final String downloadUrl;

  bool get isDownloadableApk {
    if (!name.toLowerCase().endsWith('.apk')) {
      return false;
    }
    final uri = Uri.tryParse(downloadUrl);
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.isNotEmpty;
  }

  static AppReleaseAsset? tryFromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString().trim() ?? '';
    final downloadUrl = json['browser_download_url']?.toString().trim() ?? '';
    if (name.isEmpty || downloadUrl.isEmpty) {
      return null;
    }
    return AppReleaseAsset(name: name, downloadUrl: downloadUrl);
  }
}

List<AppReleaseAsset> _parseReleaseAssets(Object? value) {
  if (value is! List) {
    return const [];
  }

  final assets = <AppReleaseAsset>[];
  for (final item in value) {
    if (item is! Map) {
      continue;
    }
    final asset = AppReleaseAsset.tryFromJson(
      item.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (asset != null) {
      assets.add(asset);
    }
  }
  return List.unmodifiable(assets);
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts, this.buildNumber);

  final List<int> parts;
  final int? buildNumber;

  factory AppVersion.parse(String value) {
    final match = RegExp(
      r'(\d+(?:\.\d+){0,3})(?:[-+](\d+))?',
    ).firstMatch(value.trim());
    if (match == null) {
      throw ApiException('Unable to read version "$value"');
    }

    final parts = match
        .group(1)!
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final buildNumber = int.tryParse(match.group(2) ?? '');
    return AppVersion(parts, buildNumber);
  }

  @override
  int compareTo(AppVersion other) {
    final maxLength = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var index = 0; index < maxLength; index++) {
      final left = index < parts.length ? parts[index] : 0;
      final right = index < other.parts.length ? other.parts[index] : 0;
      if (left != right) {
        return left.compareTo(right);
      }
    }

    final leftBuild = buildNumber;
    final rightBuild = other.buildNumber;
    if (leftBuild != null && rightBuild != null && leftBuild != rightBuild) {
      return leftBuild.compareTo(rightBuild);
    }
    return 0;
  }
}
