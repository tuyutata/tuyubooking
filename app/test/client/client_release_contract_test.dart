import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  test('Apple builds keep the existing CocoaPods integration', () {
    final manifest = bookingAppFile('pubspec.yaml').readAsStringSync();
    expect(manifest, contains('enable-swift-package-manager: false'));
    expect(bookingAppFile('ios/Podfile').existsSync(), isTrue);
    expect(bookingAppFile('macos/Podfile').existsSync(), isTrue);
    for (final platform in ['ios', 'macos']) {
      final project = bookingAppFile('$platform/Runner.pbxproj')
          .readAsStringSync();
      expect(project, isNot(contains('FlutterGeneratedPluginSwiftPackage')));
    }
  });
  test('mobile application identifiers and device families stay stable', () {
    final androidGradle = bookingAppFile('android/app/build.gradle.kts').readAsStringSync();
    final iosProject = bookingAppFile('ios/Runner.pbxproj').readAsStringSync();

    expect(androidGradle, contains('namespace = "com.tuyulove.tuyubooking"'));
    expect(
      androidGradle,
      contains('applicationId = "com.tuyulove.tuyubooking.client"'),
    );
    expect(
      iosProject,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.tuyulove.tuyubooking.client;'),
    );
    expect(iosProject, contains('TARGETED_DEVICE_FAMILY = "1,2";'));
  });

  test('release source never falls back to Android debug signing', () {
    final androidGradle = bookingAppFile('android/app/build.gradle.kts').readAsStringSync();

    expect(androidGradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(androidGradle, contains('Release artifacts stay unsigned'));
  });

  test(
    'Android local builds honor the TuyuBooking product build directory',
    () {
      final rootGradle = bookingAppFile('android/build.gradle.kts').readAsStringSync();

      expect(
        rootGradle,
        contains('environmentVariable("TUYUBOOKING_BUILD_DIR")'),
      );
      expect(rootGradle, contains('java.io.tmpdir'));
      expect(rootGradle, contains('productBuildFile'));
    },
  );

  test('mobile runtime and local network declarations stay available', () {
    final mainSource = bookingAppFile('lib/main_client.dart').readAsStringSync();
    final iosInfo = bookingAppFile('ios/Runner/Info.plist').readAsStringSync();

    expect(mainSource, contains('TuyuBookingClientApp'));
    expect(iosInfo, contains('NSLocalNetworkUsageDescription'));
    expect(iosInfo, contains('NSBonjourServices'));
  });

  test('formal CitizenSDK mode remains pinned to a fixed Git revision', () {
    final contract = bookingAppFile('sdk-dependencies.json').readAsStringSync();

    expect(contract, contains('"ref": "be75a90b866eaec9fd67c2aa8fd375ff654dead7"'));
  });

  test('iOS uses standard Flutter plugin registration and SDK-owned framework input', () {
    final podfile = bookingAppFile('ios/Podfile').readAsStringSync();

    expect(podfile, contains('flutter_install_all_ios_pods'));
    expect(podfile, isNot(contains('File.symlink')));
    expect(podfile, isNot(contains('File.unlink')));
    expect(
      podfile,
      contains(
        "configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'",
      ),
    );
    final builder = bookingSourceFile(
      'scripts/macos/build_client_release.sh',
    ).readAsStringSync();
    expect(builder, contains('CITIZENSDK_APPLE_FRAMEWORK_DIR'));
    expect(builder, contains('scripts/build-native.sh'));
  });
}
