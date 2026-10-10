import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  final repository = bookingSource;

  String source(String relativePath) =>
      File('${repository.path}/$relativePath').readAsStringSync();

  test('host packages always select the host entrypoint', () {
    expect(
      bookingBuildSource('shell', 'host'),
      contains('--target lib/main_host.dart'),
    );
    expect(
      bookingWorkflowSource('host-linux-arm', 'assemble'),
      contains('--target lib/main_host.dart'),
    );
    expect(
      bookingWorkflowSource('host-linux-amd', 'assemble'),
      contains('--target lib/main_host.dart'),
    );
  });

  test('host identities and complete runtime boundary stay explicit', () {
    final macosHost = source('app/macos/Runner/Configs/Host.xcconfig');
    final linux = source('app/linux/CMakeLists.txt');
    final macosRelease = bookingBuildSource('shell', 'host');
    final windows = source('app/windows/CMakeLists.txt');

    expect(macosHost, contains('com.tuyulove.tuyubooking.host'));
    expect(linux, contains('com.tuyulove.tuyubooking.host'));
    expect(windows, contains('tuyubooking_host'));
    expect(macosRelease, contains('Contents/Resources/postgresql'));
    expect(macosRelease, contains('Contents/Resources/business'));
    expect(macosRelease, contains('libtuyubooking_native.dylib'));
  });
}
