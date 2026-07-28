import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release rules do not optimize host-resolved extension APIs', () {
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();
    const hostResolvedPackages = [
      'eu.kanade.tachiyomi.**',
      'androidx.preference.**',
      'uy.kohesive.injekt.**',
      'kotlin.**',
      'kotlinx.coroutines.**',
      'kotlinx.serialization.**',
      'okhttp3.**',
      'okio.**',
      'org.jsoup.**',
      'rx.**',
      'app.cash.quickjs.**',
    ];

    for (final package in hostResolvedPackages) {
      expect(
        rules,
        contains('-keep class $package { public protected *; }'),
        reason: '$package must retain its external subclassing ABI',
      );
      expect(
        rules,
        isNot(contains('-keep,allowoptimization class $package')),
        reason: 'R8 optimization can make open members final in $package',
      );
    }
  });

  test('class loader shares only host-provided extension dependencies', () {
    final loader = File(
      'android/app/src/main/kotlin/com/oneb/anikin/extensions/'
      'ChildFirstPathClassLoader.kt',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(loader, contains('name.startsWith("androidx.preference.")'));
    expect(loader, isNot(contains('name.startsWith("androidx.")')));
    expect(loader, contains('name.startsWith("kotlinx.coroutines.")'));
    expect(loader, contains('name.startsWith("kotlinx.serialization.")'));
    expect(loader, isNot(contains('name.startsWith("kotlinx.")')));
    expect(loader, contains('name.startsWith("app.cash.quickjs.")'));
    expect(gradle, contains('kotlinx-serialization-protobuf:1.9.0'));
    expect(gradle, contains('app.cash.quickjs:quickjs-android:0.9.2'));
  });

  test('configurable source APIs expose source-scoped preferences', () {
    const apiFiles = [
      'android/app/src/main/kotlin/eu/kanade/tachiyomi/animesource/'
          'ConfigurableAnimeSource.kt',
      'android/app/src/main/kotlin/eu/kanade/tachiyomi/source/'
          'ConfigurableSource.kt',
    ];

    for (final path in apiFiles) {
      final source = File(path).readAsStringSync();
      expect(source, contains('fun getSourcePreferences(): SharedPreferences'));
      expect(source, contains('fun Configurable'));
      expect(source, contains('preferenceKey(): String = "source_\$id"'));
      expect(source, contains('sourcePreferences(): SharedPreferences'));
      expect(source, contains('fun sourcePreferences(key: String)'));
    }
  });
}
