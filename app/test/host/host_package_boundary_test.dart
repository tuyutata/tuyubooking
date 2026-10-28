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
    final build = source('scripts/build.mjs');
    expect(build, contains("platform.startsWith('host-linux-')"));
    expect(build, contains("'--target','lib/main_host.dart'"));
    expect(build, contains("arm?'linux-arm64':'linux-x64'"));
    expect(
      build,
      contains("arm?'aarch64-unknown-linux-gnu':'x86_64-unknown-linux-gnu'"),
    );
    for (final platform in [
      'host-macos',
      'host-windows',
      'host-linux-arm',
      'host-linux-amd',
    ]) {
      final job = (bookingWorkflow(platform)['jobs'] as Map)['build'] as Map;
      final step = (job['steps'] as List).last as Map;
      expect(
        step['run'],
        'node scripts/build.mjs execute $platform --work "\$GITHUB_WORKSPACE/target/build/$platform"',
      );
    }
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
