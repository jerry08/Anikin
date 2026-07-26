import 'package:anikin/core/platform_capabilities.dart';
import 'package:anikin/data/app_database.dart';
import 'package:anikin/services/credential_vault.dart';
import 'package:anikin/services/feature_gate_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('database creates the foundation schema and stores metadata', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.initialize();
    await database.setMetadata('foundation.schema', '1');

    expect(await database.metadata('foundation.schema'), '1');
    expect(await database.select(database.searchHistoryEntries).get(), isEmpty);
    expect(
      await database.select(database.notificationSubscriptions).get(),
      isEmpty,
    );
  });

  test('credential vault migrates and removes verified plaintext', () async {
    SharedPreferences.setMockInitialValues({'legacy.token': 'secret'});
    final preferences = await SharedPreferences.getInstance();
    final secureStore = MemorySecureValueStore();
    final vault = CredentialVault(secureStore: secureStore);

    final value = await vault.read(
      'secure.token',
      legacyPreferences: preferences,
      legacyKey: 'legacy.token',
    );

    expect(value, 'secret');
    expect(secureStore.values['secure.token'], 'secret');
    expect(preferences.containsKey('legacy.token'), isFalse);
  });

  test('feature gates retain rollout overrides', () async {
    SharedPreferences.setMockInitialValues({
      'features.notifications': true,
      'features.advancedSearch': false,
    });
    final preferences = await SharedPreferences.getInstance();
    final gates = FeatureGateService(preferences: preferences);

    await gates.load();

    expect(gates.isEnabled(AppFeature.notifications), isTrue);
    expect(gates.isEnabled(AppFeature.advancedSearch), isFalse);
    expect(gates.isEnabled(AppFeature.glassUi), isTrue);
  });

  test('platform capabilities keep Android-only features isolated', () {
    const android = PlatformCapabilities(platform: TargetPlatform.android);
    const windows = PlatformCapabilities(platform: TargetPlatform.windows);

    expect(android.supportsAniyomiExtensions, isTrue);
    expect(android.supportsPictureInPicture, isTrue);
    expect(android.supportsLnReaderPlugins, isTrue);
    expect(windows.supportsAniyomiExtensions, isFalse);
    expect(windows.supportsPictureInPicture, isFalse);
    expect(windows.supportsLocalBookImport, isTrue);
  });
}
