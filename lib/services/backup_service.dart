import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import 'preferences_service.dart';

class BackupService {
  BackupService({
    required AppDatabase database,
    required PreferencesService preferences,
    @visibleForTesting int keyDerivationIterations = 210000,
  }) : _database = database,
       _preferences = preferences,
       _keyDerivationIterations = keyDerivationIterations;

  static const _format = 'anikin-encrypted-backup';
  static const _version = 1;
  static const _aad = 'anikin-backup-v1';
  static const _maximumBackupBytes = 256 * 1024 * 1024;

  final AppDatabase _database;
  final PreferencesService _preferences;
  final int _keyDerivationIterations;

  Future<Uint8List> create(String password) async {
    _validatePassword(password);
    final payload = await _buildPayload();
    final clearText = utf8.encode(jsonEncode(payload));
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final cipher = AesGcm.with256bits();
    final secretKey = await _deriveKey(
      password,
      salt,
      _keyDerivationIterations,
    );
    final box = await cipher.encrypt(
      clearText,
      secretKey: secretKey,
      aad: utf8.encode(_aad),
    );
    final envelope = <String, Object>{
      'format': _format,
      'version': _version,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'kdf': {
        'name': 'pbkdf2-hmac-sha256',
        'iterations': _keyDerivationIterations,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'name': 'aes-256-gcm',
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
        'data': base64Encode(box.cipherText),
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  Future<BackupRestoreResult> restore(
    Uint8List encrypted,
    String password,
  ) async {
    _validatePassword(password);
    if (encrypted.isEmpty || encrypted.length > _maximumBackupBytes) {
      throw const BackupException('The selected backup has an invalid size');
    }
    try {
      final envelope = _asStringMap(jsonDecode(utf8.decode(encrypted)));
      if (envelope['format'] != _format || envelope['version'] != _version) {
        throw const BackupException('This is not a supported Anikin backup');
      }
      final kdf = _asStringMap(envelope['kdf']);
      final cipherData = _asStringMap(envelope['cipher']);
      final iterations = kdf['iterations'];
      if (kdf['name'] != 'pbkdf2-hmac-sha256' ||
          cipherData['name'] != 'aes-256-gcm' ||
          iterations is! int ||
          iterations < 10000 ||
          iterations > 2000000) {
        throw const BackupException(
          'The backup encryption settings are invalid',
        );
      }
      final salt = base64Decode(kdf['salt'] as String);
      final secretKey = await _deriveKey(password, salt, iterations);
      final box = SecretBox(
        base64Decode(cipherData['data'] as String),
        nonce: base64Decode(cipherData['nonce'] as String),
        mac: Mac(base64Decode(cipherData['mac'] as String)),
      );
      final clearText = await AesGcm.with256bits().decrypt(
        box,
        secretKey: secretKey,
        aad: utf8.encode(_aad),
      );
      final payload = _asStringMap(jsonDecode(utf8.decode(clearText)));
      return _restorePayload(payload);
    } on BackupException {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const BackupException('Wrong password or damaged backup');
    } on FormatException {
      throw const BackupException('The selected file is not a valid backup');
    } on TypeError {
      throw const BackupException('The backup data is malformed');
    }
  }

  Future<Map<String, Object>> _buildPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final preferenceValues = <String, Object>{};
    final keys = prefs.getKeys().toList()..sort();
    for (final key in keys) {
      if (!_isPortablePreference(key)) continue;
      final value = prefs.get(key);
      if (value is bool || value is int || value is double || value is String) {
        preferenceValues[key] = value!;
      } else if (value is List<String>) {
        preferenceValues[key] = value;
      }
    }

    final searchHistory = await _database
        .select(_database.searchHistoryEntries)
        .get();
    final subscriptions = await _database
        .select(_database.notificationSubscriptions)
        .get();
    final notifications = await _database
        .select(_database.appNotifications)
        .get();

    return {
      'schema': _version,
      'preferences': preferenceValues,
      'searchHistory': searchHistory.map((item) => item.toJson()).toList(),
      'notificationSubscriptions': subscriptions
          .map((item) => item.toJson())
          .toList(),
      'notifications': notifications.map((item) => item.toJson()).toList(),
    };
  }

  Future<BackupRestoreResult> _restorePayload(
    Map<String, Object?> payload,
  ) async {
    if (payload['schema'] != _version) {
      throw const BackupException('This backup version is not supported');
    }
    final restoredPreferences = await _restorePreferences(
      payload['preferences'],
    );
    var restoredRows = 0;
    await _database.transaction(() async {
      for (final raw in _asMapList(payload['searchHistory'])) {
        final item = SearchHistoryEntry.fromJson(raw);
        await _database
            .into(_database.searchHistoryEntries)
            .insertOnConflictUpdate(
              SearchHistoryEntriesCompanion.insert(
                target: item.target,
                query: item.query,
                usedAt: item.usedAt,
              ),
            );
        restoredRows++;
      }
      for (final raw in _asMapList(payload['notificationSubscriptions'])) {
        final item = NotificationSubscription.fromJson(raw);
        await _database
            .into(_database.notificationSubscriptions)
            .insertOnConflictUpdate(item);
        restoredRows++;
      }
      for (final raw in _asMapList(payload['notifications'])) {
        final item = AppNotification.fromJson(raw);
        await _database
            .into(_database.appNotifications)
            .insertOnConflictUpdate(item);
        restoredRows++;
      }
    });
    await _preferences.load();
    return BackupRestoreResult(
      preferences: restoredPreferences,
      records: restoredRows,
    );
  }

  Future<int> _restorePreferences(Object? raw) async {
    final values = _asStringMap(raw);
    final prefs = await SharedPreferences.getInstance();
    var count = 0;
    for (final entry in values.entries) {
      if (!_isPortablePreference(entry.key)) continue;
      final value = entry.value;
      final saved = switch (value) {
        bool value => await prefs.setBool(entry.key, value),
        int value => await prefs.setInt(entry.key, value),
        double value => await prefs.setDouble(entry.key, value),
        String value => await prefs.setString(entry.key, value),
        List value when value.every((item) => item is String) =>
          await prefs.setStringList(entry.key, value.cast<String>()),
        _ => false,
      };
      if (saved) count++;
    }
    return count;
  }

  Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) {
    return Pbkdf2.hmacSha256(
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }

  static bool _isPortablePreference(String key) {
    final lower = key.toLowerCase();
    if (lower.startsWith('downloads.')) return false;
    if (lower.startsWith('tracking.account.')) return false;
    return !lower.contains('token') &&
        !lower.contains('secret') &&
        !lower.contains('password') &&
        !lower.contains('verifier');
  }

  static Map<String, Object?> _asStringMap(Object? value) {
    if (value is! Map) throw const FormatException('Expected an object');
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Map<String, Object?>> _asMapList(Object? value) {
    if (value == null) return const [];
    if (value is! List) throw const FormatException('Expected a list');
    return value.map(_asStringMap).toList();
  }

  static void _validatePassword(String password) {
    if (password.length < 8) {
      throw const BackupException('Use a password with at least 8 characters');
    }
  }
}

class BackupRestoreResult {
  const BackupRestoreResult({required this.preferences, required this.records});

  final int preferences;
  final int records;
}

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}
