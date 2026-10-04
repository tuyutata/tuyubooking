import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  sourcePathRegressions();

  test('CitizenSDK全部构建场景统一锁定Git来源', () {
    final pubspec = bookingAppFile('pubspec.yaml').readAsStringSync();
    final lock = bookingAppFile('pubspec.lock').readAsStringSync();
    final contract = jsonDecode(bookingAppFile('sdk-dependencies.json').readAsStringSync()) as Map<String, dynamic>;
    const sha = '52b83f8f33a9424f3a92161da4f183678263ab7c';
    const url = 'https://github.com/crcfrcn/citizensdk.git';
    expect(contract['source'], {'url': url, 'path': '.', 'ref': sha});
    for (final value in [pubspec, lock]) {
      expect(value, contains(url));
      expect(value, contains(sha));
    }
    expect(contract.containsKey('modes'), isFalse);
    final project = bookingAppFile('scripts/project.mjs').readAsStringSync();
    expect(project, contains('resolveFirstPartyDependencies'));
    expect(project, contains('assertFlutterSourceView'));
    expect(project, contains('prepareNativeProject'));
    final preparer = bookingSourceFile('scripts/sdk-dependencies.mjs').readAsStringSync();
    expect(preparer, contains("command !== 'prepare'"));
    expect(preparer, isNot(contains("mode === 'local'")));
  });

  test('全部分机CI消费同一SDK视图并保留未安全释放现场', () {
    for (final platform in ['ios', 'android', 'macos', 'windows']) {
      final script = bookingSourceFile('scripts/client/ci/$platform/index.mjs').readAsStringSync();
      expect(script, contains('prepareNativeProject({ source, work: projectWork, output: project'));
      expect(script, contains('platform: '+"'$platform'"+' }'));
      expect(script, contains('error.retainSdkStage || error.status === 75'));
      expect(script, contains('projectOwned = null; process.exitCode = 75'));
      expect(script, contains('current.dev !== projectOwned.dev || current.ino !== projectOwned.ino'));
    }
  });

  test('mobile hosts satisfy CitizenSDK platform requirements', () {
    final androidHost = bookingAppFile(
      'android/app/src/main/kotlin/com/tuyulove/tuyubooking/MainActivity.kt',
    ).readAsStringSync();
    final androidBuild = bookingAppFile(
      'android/app/build.gradle.kts',
    ).readAsStringSync();
    final iosProject = bookingAppFile(
      'ios/Runner.pbxproj',
    ).readAsStringSync();
    final iosInfo = bookingAppFile('ios/Runner/Info.plist').readAsStringSync();
    expect(androidHost, contains('FlutterFragmentActivity'));
    expect(androidBuild, contains('minSdk = 24'));
    expect(iosProject, contains('IPHONEOS_DEPLOYMENT_TARGET = 16.0;'));
    expect(iosInfo, contains('<key>NSFaceIDUsageDescription</key>'));
  });

  test('host and client directly use the standard CitizenSdk', () {
    final host = bookingAppFile('lib/host/host_app.dart').readAsStringSync();
    final client = bookingAppFile('lib/client/client_app.dart').readAsStringSync();
    expect(host, contains('CitizenSdk.open()'));
    expect(client, contains('CitizenSdk.open()'));
    expect(host, contains('Provider<CitizenSdk?>'));
    expect(client, contains('Provider<CitizenSdk?>'));
    expect(host, isNot(contains('CitizenSdkClient')));
    expect(client, isNot(contains('CitizenSdkRuntime')));
  });

  test('Android reads product state and native SDK output without project substitution', () {
    final settings = bookingAppFile('android/settings.gradle.kts').readAsStringSync();
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
    final stage = Directory.systemTemp.createTempSync('booking-source-contract-');
    addTearDown(() => stage.deleteSync(recursive: true));
    final product = Directory('${stage.path}/tuyubooking')..createSync();
    for (final name in ['app', 'host', 'scripts']) {
      Directory('${product.path}/$name').createSync();
    }
    File('${product.path}/app/pubspec.yaml').writeAsStringSync('name: tuyubooking\n');
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
