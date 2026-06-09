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
}
