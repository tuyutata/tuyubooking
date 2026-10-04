import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';
import 'package:tuyubooking/client/client_initialization_page.dart';

void main() {
  test('Android generated names use the AGP Variant API', () {
    final root = Platform.environment['TUYUBOOKING_ROOT'] ?? Directory.current.parent.path;
    final script = File('$root/app/android/app/build.gradle.kts').readAsStringSync();
    expect(script, contains('abstract class GenerateAppNameResources : DefaultTask'));
    expect(script, contains('generatedResources.set(appNameResources)'));
    expect(script, contains('androidComponents.onVariants'));
    expect(script, contains('addGeneratedSourceDirectory'));
    expect(script, contains('GenerateAppNameResources::generatedResources'));
    expect(script, isNot(contains('res.srcDir(appNameResources)')));
    expect(script, isNot(contains('android.sourceset.disallowProvider=false')));
  });

  test('macOS final wrapping and base names precede the outer signature', () {
    final root = Platform.environment['TUYUBOOKING_ROOT'] ?? Directory.current.parent.path;
    for (final name in ['build_release.sh', 'build_client_release.sh']) {
      final script = File('$root/scripts/macos/$name').readAsStringSync();
      final display = script.indexOf('Set :CFBundleDisplayName');
      final shortName = script.indexOf('Set :CFBundleName');
      final outer = script.lastIndexOf('codesign --force --sign');
      final finalPath = name == 'build_release.sh'
          ? r'APP="$ARTIFACT_DIR/tuyubooking.app"'
          : r'APP="$OUTPUT"';
      expect(script.indexOf(finalPath), greaterThanOrEqualTo(0));
      expect(script.indexOf(finalPath), lessThan(display));
      expect(display, lessThan(outer));
      expect(shortName, lessThan(outer));
      expect(script.substring(outer), isNot(contains(r'ditto "$APP"')));
      expect(script.substring(outer), isNot(contains(r'mv "$APP"')));
      expect(script.substring(outer), isNot(contains('Set :CFBundle')));
    }
  });

  test('Windows system names preserve separate technical identities', () {
    final root = Platform.environment['TUYUBOOKING_ROOT'] ?? Directory.current.parent.path;
    final runner = File('$root/app/windows/runner/main.cpp').readAsStringSync();
    expect(runner, contains('ApplicationDisplayName()'));
    expect(runner, contains('PKEY_AppUserModel_RelaunchDisplayNameResource'));
    expect(runner, contains('PKEY_AppUserModel_RelaunchCommand'));
    expect(runner, contains('IDS_TUYU_APPLICATION_NAME'));
    expect(runner, contains('SHSetLocalizedName'));
    expect(runner, contains('::_wcsicmp(expanded, executable.c_str()) != 0'));
    expect(runner, contains('FILE_ATTRIBUTE_REPARSE_POINT'));
    expect(runner, isNot(contains('CreateShortcut')));
    expect(File('$root/app/windows/runner/Runner.rc').readAsStringSync(), contains('#pragma code_page(65001)'));
  });

  final repository = bookingSource;

  String source(String relativePath) =>
      File('${repository.path}/$relativePath').readAsStringSync();

  test('安装名称按系统语言解析并保留产品身份', () {
    String source(String path) => File('${repository.path}/app/$path').readAsStringSync();
    for (final platform in ['ios', 'macos']) {
      final catalog = jsonDecode(source('$platform/Runner/InfoPlist.xcstrings'));
      for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
        for (final entry in {'en': 'TuyuBooking', 'zh-Hans': '途遇商家端', 'zh-Hant': '途遇商家端'}.entries) {
          expect(catalog['strings'][key]['localizations'][entry.key]['stringUnit']['value'], entry.value);
        }
      }
      expect(source('$platform/Runner.pbxproj'), contains('InfoPlist.xcstrings'));
    }
    expect(source('android/app/src/main/AndroidManifest.xml'), contains('android:label="@string/app_name"'));
    final gradle = source('android/app/build.gradle.kts');
    expect(gradle, contains('generateAppNameResources'));
    expect(gradle, contains('app_en.arb'));
    expect(gradle, contains('app_zh.arb'));
    expect(gradle, contains('layout.buildDirectory.dir("generated/app-name/res")'));
    final windows = source('windows/runner/Runner.rc');
    expect(windows, contains('IDS_TUYU_APPLICATION_NAME "TuyuBooking"'));
    expect(windows, contains('IDS_TUYU_APPLICATION_NAME "途遇商家端"'));
  });

  test('两个Linux架构使用相同的语言名称而非更改执行身份', () {
    for (final platform in ['linux-arm', 'linux-amd']) {
      final entry = source('scripts/$platform/tuyubooking.desktop');
      expect(entry, contains('Name=TuyuBooking\n'));
      expect(entry, contains('Name[zh]=途遇商家端\n'));
    }
  });

  // 直接编译并渲染分机入口页面，避免仅检查打包脚本文本而漏掉 Dart 导入错误。
  // SDK 由外层提供；未就绪时页面不得自行创建钱包或启动轻节点。
  testWidgets('client initialization waits for its injected SDK', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ClientInitializationPage(
          sdk: null,
          sdkStarting: true,
          onRetrySdk: () => retries++,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-citizen-sdk')), findsNothing);
    expect(find.byKey(const ValueKey('create-wallet')), findsNothing);
    expect(find.byKey(const ValueKey('import-wallet')), findsNothing);
    expect(retries, 0);
  });

  testWidgets('client initialization delegates SDK failure retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ClientInitializationPage(
          sdk: null,
          sdkStarting: false,
          onRetrySdk: () => retries++,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('create-wallet')), findsNothing);
    expect(find.byKey(const ValueKey('import-wallet')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('retry-citizen-sdk')));
    await tester.pump();
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  test('client installation identities stay independent from the host', () {
    final android = source('app/android/app/build.gradle.kts');
    final ios = source('app/ios/Runner.pbxproj');
    final macos = source('app/macos/Runner/Configs/Client.xcconfig');
    final windows = source('app/windows/CMakeLists.txt');

    expect(android, contains('com.tuyulove.tuyubooking.client'));
    expect(ios, contains('com.tuyulove.tuyubooking.client'));
    expect(macos, contains('com.tuyulove.tuyubooking.client'));
    expect(windows, contains('tuyubooking_client'));
  });

  test('macOS client package is thin and selects the client entrypoint', () {
    final package = source('scripts/macos/build_client_release.sh');

    expect(package, contains('--target lib/main_client.dart'));
    expect(package, isNot(contains('build_runtime.sh')));
    expect(package, isNot(contains('business-runtime/materialize.sh')));
    expect(package, isNot(contains('cargo build')));
    expect(package, contains('test ! -e'));
    expect(package, contains('prepare-citizensdk'));
    expect(package, contains('cleanup-citizensdk'));
    expect(package.indexOf('flutter test'), lessThan(package.indexOf('prepare-citizensdk')));
    expect(package.indexOf('prepare-citizensdk'), lessThan(package.indexOf('xcodebuild')));
    expect(
      package,
      contains('ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS=NO'),
    );
    expect(package, contains('Contents/Frameworks/CitizenSDK.framework'));
    expect(package, contains('== arm64'));
    expect(package, isNot(contains('rm -rf "\$FLUTTER_APP/.dart_tool"')));
  });

  test('iOS and Android remain one adaptive package per platform', () {
    final ios = source('app/ios/Runner.pbxproj');
    final androidManifest = source(
      'app/android/app/src/main/AndroidManifest.xml',
    );

    expect(ios, contains('TARGETED_DEVICE_FAMILY = "1,2";'));
    expect(androidManifest, contains('screenSize'));
    expect(androidManifest, contains('smallestScreenSize'));
  });
}
