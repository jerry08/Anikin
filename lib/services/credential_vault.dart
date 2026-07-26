import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SecureValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecureValueStore implements SecureValueStore {
  PlatformSecureValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemorySecureValueStore implements SecureValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class CredentialVault {
  CredentialVault({SecureValueStore? secureStore})
    : _secureStore = secureStore ?? PlatformSecureValueStore();

  final SecureValueStore _secureStore;

  Future<String?> read(
    String key, {
    SharedPreferences? legacyPreferences,
    String? legacyKey,
  }) async {
    try {
      final protected = await _secureStore.read(key);
      if (protected != null && protected.isNotEmpty) {
        return protected;
      }
    } on MissingPluginException {
      return _readLegacy(legacyPreferences, legacyKey);
    } on PlatformException {
      return _readLegacy(legacyPreferences, legacyKey);
    } on UnsupportedError {
      return _readLegacy(legacyPreferences, legacyKey);
    }

    final legacy = _readLegacy(legacyPreferences, legacyKey);
    if (legacy == null || legacy.isEmpty) {
      return null;
    }

    try {
      await _secureStore.write(key, legacy);
      final verified = await _secureStore.read(key);
      if (verified == legacy &&
          legacyPreferences != null &&
          legacyKey != null) {
        await legacyPreferences.remove(legacyKey);
      }
    } on MissingPluginException {
      // Tests and unsupported embedders retain the legacy value without loss.
    } on PlatformException {
      // A failed secure write must never delete the readable legacy value.
    } on UnsupportedError {
      // A failed secure write must never delete the readable legacy value.
    }
    return legacy;
  }

  Future<void> write(
    String key,
    String value, {
    SharedPreferences? legacyPreferences,
    String? legacyKey,
  }) async {
    try {
      await _secureStore.write(key, value);
      final verified = await _secureStore.read(key);
      if (verified != value) {
        throw StateError('Secure credential verification failed');
      }
      if (legacyPreferences != null && legacyKey != null) {
        await legacyPreferences.remove(legacyKey);
      }
    } on MissingPluginException {
      await _writeLegacy(legacyPreferences, legacyKey, value);
    } on UnsupportedError {
      await _writeLegacy(legacyPreferences, legacyKey, value);
    }
  }

  Future<void> delete(String key) async {
    try {
      await _secureStore.delete(key);
    } on MissingPluginException {
      // The caller also removes any known legacy value.
    } on UnsupportedError {
      // The caller also removes any known legacy value.
    }
  }

  String? _readLegacy(SharedPreferences? preferences, String? key) {
    if (preferences == null || key == null) {
      return null;
    }
    return preferences.getString(key);
  }

  Future<void> _writeLegacy(
    SharedPreferences? preferences,
    String? key,
    String value,
  ) async {
    if (preferences == null || key == null) {
      throw StateError('Secure storage is unavailable and no fallback exists');
    }
    await preferences.setString(key, value);
  }
}
