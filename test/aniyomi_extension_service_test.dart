import 'package:anikin/services/aniyomi_extension_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logs Aniyomi extension platform errors', (tester) async {
    const channel = MethodChannel('test/aniyomi_extensions');
    final service = AniyomiExtensionService(channel: channel, isAndroid: true);
    final messages = <String>[];
    final previousDebugPrint = debugPrint;

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      throw PlatformException(
        code: 'ANIYOMI_EXTENSION_ERROR',
        message: 'Native source failed',
        details: 'native stack trace',
      );
    });

    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        messages.add(message);
      }
    };

    try {
      await expectLater(
        service.getAnimeProviders(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'ANIYOMI_EXTENSION_ERROR',
          ),
        ),
      );
    } finally {
      debugPrint = previousDebugPrint;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    }

    final output = messages.join('\n');
    expect(output, contains('ANIYOMI_EXTENSION_ERROR'));
    expect(output, contains('getAnimeProviders'));
    expect(output, contains('Native source failed'));
    expect(output, contains('native stack trace'));
  });

  testWidgets('preserves installed extension load failures', (tester) async {
    const channel = MethodChannel('test/aniyomi_extension_load_failure');
    final service = AniyomiExtensionService(channel: channel, isAndroid: true);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'getInstalledExtensions');
      return <Map<String, Object?>>[
        {
          'name': 'GoogleDriveIndex',
          'pkgName': 'eu.kanade.tachiyomi.animeextension.all.googledriveindex',
          'versionName': '14.7',
          'versionCode': 7,
          'libVersion': 14.0,
          'mediaType': 'anime',
          'type': 0,
          'sources': <Object?>[],
          'isInstalled': true,
          'isLoaded': false,
          'loadError':
              'VerifyError: getClient overrides final method in AnimeHttpSource',
          'installLocation': 'system',
        },
      ];
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    final extensions = await service.getInstalledExtensions();

    expect(extensions, hasLength(1));
    final extension = extensions.single;
    expect(extension.isInstalled, isTrue);
    expect(extension.isLoaded, isFalse);
    expect(extension.loadError, contains('VerifyError'));
    expect(extension.displaySubtitle, contains('Load failed'));
    expect(extension.installLocationLabel, 'System installed');
  });
}
