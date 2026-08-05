import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest remains discoverable and installable on TV', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    for (final feature in const [
      'android.hardware.touchscreen',
      'android.hardware.faketouch',
      'android.software.leanback',
    ]) {
      expect(
        RegExp(
          '<uses-feature\\s+android:name="$feature"\\s+'
          'android:required="false"',
          multiLine: true,
        ).hasMatch(manifest),
        isTrue,
        reason: '$feature must remain optional for TV compatibility.',
      );
    }
    expect(manifest, contains('android:banner="@drawable/tv_banner"'));
    expect(manifest, contains('android:icon="@mipmap/ic_launcher_tv"'));
    expect(manifest, contains('android.intent.category.LEANBACK_LAUNCHER'));
  });

  test('Android TV launcher banner is the required 320 by 180 pixels', () {
    final bytes = File(
      'android/app/src/main/res/drawable-xhdpi/tv_banner.png',
    ).readAsBytesSync();
    final pngHeader = ByteData.sublistView(bytes);

    expect(pngHeader.getUint32(16), 320);
    expect(pngHeader.getUint32(20), 180);
  });

  test('Android TV launcher icon is at least 160 pixels at xhdpi', () {
    final bytes = File(
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher_tv.png',
    ).readAsBytesSync();
    final pngHeader = ByteData.sublistView(bytes);

    expect(pngHeader.getUint32(16), greaterThanOrEqualTo(160));
    expect(pngHeader.getUint32(20), greaterThanOrEqualTo(160));
  });
}
