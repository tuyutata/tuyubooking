import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  sourcePathRegressions();

  test('CitizenSDK全部构建场景统一锁定Git来源', () {
    final pubspec = bookingAppFile('pubspec.yaml').readAsStringSync();
    final lock = bookingAppFile('pubspec.lock').readAsStringSync();
    const url = 'https://github.com/crcfrcn/citizensdk.git';
    final sha = RegExp(r'ref: ([a-f0-9]{40})').firstMatch(pubspec)!.group(1)!;
    for (final value in [pubspec, lock]) {
      expect(value, contains(url));
      expect(value, contains(sha));
    }
    final project = bookingAppFile('scripts/project.mjs').readAsStringSync();
    expect(project, contains('resolveFirstPartyDependencies'));
    expect(project, contains('api.consume'));
    expect(project, contains('CITIZENSDK_PACKAGE'));
    expect(project, isNot(contains('localSdkMode')));
    expect(project, contains('prepareNativeProject'));
  });

  test('全部分机自动化独立消费锁定SDK来源', () {
    for (final platform in ['ios', 'android', 'macos', 'windows']) {
      final script = bookingSourceFile('.github/workflows/client$platform.yml')
          .readAsStringSync();
      expect(script.trim(), isNotEmpty, reason: '声明平台必须有真实自动化工作流');
      expect(script, contains('--enforce-lockfile'));
      expect(script, isNot(contains('scripts/build.mjs')));
      expect(script, isNot(contains('scripts/publish.mjs')));
    }
  });

  test('mobile hosts satisfy CitizenSDK platform requirements', () {
    final androidHost = bookingAppFile(
      'android/app/src/main/kotlin/com/tuyulove/tuyubooking/MainActivity.kt',
    ).readAsStringSync();
    final androidBuild = bookingAppFile('android/app/build.gradle.kts')
        .readAsStringSync();
    final iosProject = bookingAppFile('ios/Runner.pbxproj').readAsStringSync();
    final iosInfo = bookingAppFile('ios/Runner/Info.plist').readAsStringSync();
    expect(androidHost, contains('FlutterFragmentActivity'));
    expect(androidBuild, contains('minSdk = 24'));
    expect(iosProject, contains('IPHONEOS_DEPLOYMENT_TARGET = 16.0;'));
    expect(iosInfo, contains('<key>NSFaceIDUsageDescription</key>'));
  });

  test('host and client directly use the standard CitizenSdk', () {
    final host = bookingAppFile('lib/host/host_app.dart').readAsStringSync();
    final client = bookingAppFile('lib/client/client_app.dart')
        .readAsStringSync();
    expect(host, contains('CitizenSdk.open('));
    expect(client, contains('CitizenSdk.open('));
    expect(host, contains('Provider<CitizenSdk?>'));
    expect(client, contains('Provider<CitizenSdk?>'));
    expect(host, isNot(contains('CitizenSdkClient')));
    expect(client, isNot(contains('CitizenSdkRuntime')));
  });

  test('Android reads product state and native SDK output without project substitution', () {
    final settings = bookingAppFile('android/settings.gradle.kts')
        .readAsStringSync();
    final root = bookingAppFile('android/build.gradle.kts').readAsStringSync();
    expect(settings, contains('System.getenv("TUYUBOOKING_PROJECT_ROOT")'));
    expect(settings, contains('.flutter-plugins-dependencies'));
    expect(settings, isNot(contains('project(":citizen_sdk").projectDir')));
    expect(root, contains('environmentVariable("TUYUBOOKING_BUILD_DIR")'));
    expect(root, contains('java.io.tmpdir'));
  });
}

void sourcePathRegressions() {
  test('source identity is independent of generated platform roots', () {
    final stage = Directory.systemTemp.createTempSync(
      'booking-source-contract-',
    );
    addTearDown(() => stage.deleteSync(recursive: true));
    final product = Directory('${stage.path}/tuyubooking')..createSync();
    for (final name in ['app', 'host', 'scripts']) {
      Directory('${product.path}/$name').createSync();
    }
    File('${product.path}/app/pubspec.yaml')
        .writeAsStringSync('name: tuyubooking\n');
    expect(
      resolveBookingSource(
        environment: {'TUYUBOOKING_ROOT': product.path},
        workingDirectory: Directory('${stage.path}/work'),
      ).path,
      product.resolveSymbolicLinksSync(),
    );
    expect(
      resolveBookingSource(
        environment: {},
        workingDirectory: Directory('${product.path}/app'),
      ).path,
      product.resolveSymbolicLinksSync(),
    );
    expect(
      () => resolveBookingSource(environment: {'TUYUBOOKING_ROOT': 'relative'}),
      throwsStateError,
    );
    expect(() => bookingSourceFile('../outside'), throwsArgumentError);
  });
}
