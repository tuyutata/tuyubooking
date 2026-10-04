import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  final repository = bookingSource;

  String source(String relative) =>
      File('${repository.path}/$relative').readAsStringSync();

  test('one application camera scanner covers all desktop platforms', () {
    final pubspec = source('app/pubspec.yaml');
    final scanner = source('app/lib/shared/qr/qr_scanner.dart');
    expect(pubspec, contains('flutter_lite_camera:'));
    expect(pubspec, contains('zxing2:'));
    expect(scanner, contains('FlutterLiteCamera'));
    expect(scanner, contains('decodeRgbQr'));
    expect(scanner, isNot(contains('Bluetooth')));
    expect(scanner, isNot(contains('Usb')));
  });

  test('mobile employee mode uses its native ticket QR scanner', () {
    final pubspec = source('app/pubspec.yaml');
    final scanner = source('app/lib/shared/qr/mobile_qr_scanner.dart');
    expect(pubspec, contains('mobile_scanner:'));
    expect(scanner, contains('MobileScanner'));
    expect(scanner, isNot(contains('TuyuServe')));
  });

  test('macOS, Linux, and Windows declare their camera boundary', () {
    expect(
      source('app/macos/Runner/Info.plist'),
      contains('NSCameraUsageDescription'),
    );
    expect(
      source('app/macos/Runner/Release.entitlements'),
      contains('com.apple.security.device.camera'),
    );
    expect(
      source('app/linux/CMakeLists.txt'),
      contains('TUYUBOOKING_CAMERA_BACKEND "V4L2"'),
    );
    expect(
      source('app/windows/CMakeLists.txt'),
      contains('TUYUBOOKING_CAMERA_BACKEND "MEDIA_FOUNDATION"'),
    );
  });
}
