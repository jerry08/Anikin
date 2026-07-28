import 'package:anikin/core/platform_capabilities.dart';
import 'package:anikin/services/update_service.dart';
import 'package:anikin/widgets/update_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('release parsing prefers the universal Android APK', () {
    final release = AppRelease.fromJson({
      'tag_name': 'v3.1.0',
      'assets': [
        {
          'name': 'Anikin-android-arm64-v8a.apk',
          'browser_download_url':
              'https://example.invalid/Anikin-android-arm64-v8a.apk',
        },
        {
          'name': 'Anikin-windows-x64.zip',
          'browser_download_url':
              'https://example.invalid/Anikin-windows-x64.zip',
        },
        {
          'name': 'Anikin-android-universal.apk',
          'browser_download_url':
              'https://example.invalid/Anikin-android-universal.apk',
        },
      ],
    });

    expect(release.assets, hasLength(3));
    expect(release.androidApkAsset?.name, 'Anikin-android-universal.apk');
  });

  test('release parsing avoids guessing between ABI-only APKs', () {
    final release = AppRelease.fromJson({
      'tag_name': 'v3.1.0',
      'assets': [
        {
          'name': 'Anikin-android-arm64-v8a.apk',
          'browser_download_url':
              'https://example.invalid/Anikin-android-arm64-v8a.apk',
        },
        {
          'name': 'Anikin-android-x86_64.apk',
          'browser_download_url':
              'https://example.invalid/Anikin-android-x86_64.apk',
        },
      ],
    });

    expect(release.androidApkAsset, isNull);
  });

  testWidgets('Android update queues the selected APK', (tester) async {
    const channel = MethodChannel('test/app_update');
    MethodCall? receivedCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      receivedCall = call;
      return 42;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    final service = UpdateService(
      currentVersion: '3.0.12',
      capabilities: const PlatformCapabilities(
        platform: TargetPlatform.android,
      ),
      appUpdateChannel: channel,
    );
    const release = AppRelease(
      tagName: 'v3.1.0',
      version: '3.1.0',
      title: '3.1.0',
      url: 'https://example.invalid/releases/v3.1.0',
      body: '',
      assets: [
        AppReleaseAsset(
          name: 'Anikin-android-universal.apk',
          downloadUrl: 'https://example.invalid/Anikin-android-universal.apk',
        ),
      ],
    );

    expect(service.canInstallDirectly(release), isTrue);
    expect(await service.downloadAndInstall(release), 42);
    expect(receivedCall?.method, 'downloadAndInstall');
    expect(receivedCall?.arguments, {
      'url': 'https://example.invalid/Anikin-android-universal.apk',
      'fileName': 'Anikin-android-universal.apk',
      'version': '3.1.0',
    });
  });

  testWidgets('Android update dialog downloads instead of opening GitHub', (
    tester,
  ) async {
    const channel = MethodChannel('test/update_dialog');
    var queued = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      queued = true;
      return 73;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    final service = UpdateService(
      currentVersion: '3.0.12',
      capabilities: const PlatformCapabilities(
        platform: TargetPlatform.android,
      ),
      appUpdateChannel: channel,
    );
    const release = AppRelease(
      tagName: 'v3.1.0',
      version: '3.1.0',
      title: '3.1.0',
      url: 'https://example.invalid/releases/v3.1.0',
      body: 'Bug fixes',
      assets: [
        AppReleaseAsset(
          name: 'Anikin-android-universal.apk',
          downloadUrl: 'https://example.invalid/Anikin-android-universal.apk',
        ),
      ],
    );
    const result = UpdateCheckResult(
      currentVersion: '3.0.12',
      release: release,
      isUpdateAvailable: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showUpdateAvailableDialog(context, result, service),
              child: const Text('Show update'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show update'));
    await tester.pumpAndSettle();

    expect(find.text('Download and install'), findsOneWidget);
    expect(find.text('Open release'), findsNothing);

    await tester.tap(find.text('Download and install'));
    await tester.pumpAndSettle();

    expect(queued, isTrue);
    expect(
      find.text(
        'Downloading Anikin 3.1.0. The installer will open when it is ready.',
      ),
      findsOneWidget,
    );
  });
}
