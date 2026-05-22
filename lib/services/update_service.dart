import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import 'anilist_service.dart';

class UpdateService {
  UpdateService({
    http.Client? client,
    this.currentVersion = AppConstants.appVersion,
    Uri? latestReleaseUri,
  }) : _client = client ?? http.Client(),
       _latestReleaseUri =
           latestReleaseUri ??
           Uri.parse(AppConstants.githubLatestReleaseEndpoint);

  final http.Client _client;
  final String currentVersion;
  final Uri _latestReleaseUri;

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
  });

  final String tagName;
  final String version;
  final String title;
  final String url;
  final String body;

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
    );
  }

  static String _normalizeTagVersion(String tagName) {
    return tagName.trim().replaceFirst(RegExp(r'^[vV]'), '');
  }
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
