import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  final repository = bookingSource;

  String source(String relative) =>
      File('${repository.path}/$relative').readAsStringSync();

  test('macOS通过CitizenSDK产品入口准备唯一框架且Podfile保持标准接入', () {
    final package = source('scripts/macos/build_release.sh');
    final podfile = source('app/macos/Podfile');
    expect(package, contains('scripts/dependencies.mjs'));
    expect(package, contains('scripts/build-native.sh'));
    expect(package, contains('CITIZENSDK_APPLE_FRAMEWORK_DIR'));
    expect(package.indexOf('build-native.sh'), lessThan(package.indexOf('pod install')));
    expect(package, contains('Contents/Frameworks/CitizenSDK.framework'));
    expect(podfile, contains('flutter_install_all_macos_pods'));
    expect(podfile, isNot(contains('File.symlink')));
    expect(podfile, isNot(contains('FileUtils.cp')));
  });

  final work = Platform.environment['TUYUBOOKING_TEST_WORK_DIR'] ??
      Directory.systemTemp.path;

  // 执行真实 Python 验收入口，但用最小应用夹具代替业务运行时。
  for (final scenario in [
    'host-binary-plist',
    'client-xml-plist',
    'missing-executable-field',
    'invalid-executable-path',
    'missing-executable-file',
    'non-executable-file',
    'missing-bundle-identifier',
    'invalid-bundle-identifier',
  ]) {
    test('macOS smoke uses bundle metadata: $scenario', () {
      final stage = Directory(work).createTempSync('macos-smoke-contract-');
      addTearDown(() => stage.deleteSync(recursive: true));
      final result = Process.runSync('python3', [
        '-B',
        '-c',
        r'''
import importlib.util
import plistlib
import sys
from pathlib import Path
from unittest.mock import patch

script, directory, scenario = sys.argv[1:]
spec = importlib.util.spec_from_file_location("smoke_bundle", script)
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)
root = Path(directory)
client = scenario == "client-xml-plist"
name = "TuyuBooking Client" if client else "TuyuBooking Host"
bundle_id = "com.tuyulove.tuyubooking.client" if client else "com.tuyulove.tuyubooking.host"
app = root / f"{name}.app"
executable = app / "Contents/MacOS" / name
executable.parent.mkdir(parents=True)
executable.write_text('#!/bin/sh\nprintf \'{"ok":true}\\n\' > "$TUYU_PACKAGED_SMOKE_RESULT"\n')
executable.chmod(0o700)
info = {"CFBundleExecutable": name, "CFBundleIdentifier": bundle_id}
expected_error = None
if scenario == "missing-executable-field":
    del info["CFBundleExecutable"]
    expected_error = "CFBundleExecutable"
elif scenario == "invalid-executable-path":
    info["CFBundleExecutable"] = "../outside"
    expected_error = "CFBundleExecutable"
elif scenario == "missing-executable-file":
    executable.unlink()
    expected_error = "missing or not executable"
elif scenario == "non-executable-file":
    executable.chmod(0o600)
    expected_error = "missing or not executable"
elif scenario == "missing-bundle-identifier":
    del info["CFBundleIdentifier"]
    expected_error = "CFBundleIdentifier"
elif scenario == "invalid-bundle-identifier":
    info["CFBundleIdentifier"] = "../outside"
    expected_error = "CFBundleIdentifier"
with (app / "Contents/Info.plist").open("wb") as stream:
    plistlib.dump(info, stream, fmt=plistlib.FMT_XML if client else plistlib.FMT_BINARY)
home = root / "home"
with patch.object(smoke.Path, "home", return_value=home), patch.object(
    sys, "argv", [script, str(app)]
):
    if expected_error:
        try:
            smoke.main()
        except RuntimeError as error:
            assert expected_error in str(error), str(error)
        else:
            raise AssertionError("Invalid bundle must fail before launch")
        assert not home.exists(), "Invalid metadata must not create a container"
    else:
        assert smoke.bundle_identity(app) == (executable, bundle_id)
        assert smoke.main() == 0
        container = home / "Library/Containers" / bundle_id / "Data/tmp"
        assert container.is_dir(), "The container must use CFBundleIdentifier"
        assert not list(container.iterdir()), "Smoke temporary data must be removed"
''',
        '${repository.path}/scripts/macos/smoke_bundle.py',
        stage.path,
        scenario,
      ]);
      expect(
        result.exitCode,
        0,
        reason: '${result.stdout}\n${result.stderr}',
      );
    }, skip: !Platform.isMacOS);
  }

  test(
    'macOS release builds and embeds the business runtime automatically',
    () {
      const requiredFiles = [
        'scripts/business-runtime/build_macos.sh',
        'scripts/business-runtime/materialize.sh',
        'scripts/macos/build_release.sh',
        'scripts/macos/verify_bundle.sh',
        'scripts/macos/smoke_bundle.py',
        'scripts/macos/write_sha256_manifest.py',
        'app/lib/host/infrastructure/runtime/packaged_smoke.dart',
      ];
      for (final relative in requiredFiles) {
        expect(File('${repository.path}/$relative').existsSync(), isTrue);
      }
      final release = source('scripts/macos/build_release.sh');
      final verifier = source('scripts/macos/verify_bundle.sh');
      final releaseBuilder = source('scripts/macos/build_release.sh');
      final materialize = source('scripts/business-runtime/materialize.sh');
      expect(release, contains('build_macos.sh'));
      expect(release, contains('smoke_bundle.py'));
      expect(release, contains('write_sha256_manifest.py'));
      expect(release, contains('mktemp -d'));
      expect(release, contains("-perm -111 -o -name '*.dylib'"));
      expect(release, contains('"\$APP/Contents/Resources/business"'));
      expect(release, isNot(contains('postgresql-child.entitlements')));
      expect(release, contains('requires System V IPC'));
      expect(release, contains('if [ "\$IDENTITY" = "-" ]'));
      expect(
        release,
        contains('com.apple.security.cs.disable-library-validation'),
      );
      expect(release, contains('--entitlements "\$APP_ENTITLEMENTS" "\$APP"'));
      expect(release, contains('CODE_SIGN_ENTITLEMENTS='));
      expect(verifier, contains("-perm -111 -o -name '*.dylib'"));
      expect(verifier, contains("-o -name '*.node'"));
      expect(verifier, contains('bench/apps/ury/LICENSE'));
      expect(verifier, isNot(contains('bench/apps/ury/license.txt')));
      expect(
        materialize,
        contains('relocate_macos.sh" "\$DESTINATION" "\$SOURCE"'),
      );
      expect(materialize, contains('DESTINATION/php/pecl'));
      expect(
        materialize,
        contains('business runtime contains an absolute symlink'),
      );
      expect(verifier, contains('release bundle contains an absolute symlink'));
      expect(verifier, contains('macOS bundle verification failed at line'));
      expect(verifier, isNot(contains('tuyubooking_sr25519_sign')));
      expect(verifier, isNot(contains('grep -Fqx')));
      expect(releaseBuilder, contains('sign_nested_code'));
      expect(releaseBuilder, contains('app_signing_output'));
      expect(releaseBuilder, contains('TUYUBOOKING_WORK_DIR'));
      expect(releaseBuilder, contains('TUYUBOOKING_ARTIFACT_DIR'));
      expect(releaseBuilder, isNot(contains('source/tuyubooking-desktop')));
      expect(releaseBuilder, isNot(contains('/Users/')));
      final main = source('app/lib/main_host.dart');
      final smoke = source(
        'app/lib/host/infrastructure/runtime/packaged_smoke.dart',
      );
      expect(main, contains("TUYU_PACKAGED_SMOKE'] == '1'"));
      expect(main, contains('runPackagedSmoke()'));
      expect(smoke, contains('FfiNativeGateway'));
      expect(smoke, contains('_assertCleanCore'));
      expect(smoke, contains('_assertUninitializedAccountReady'));
      expect(smoke, contains('gateway.administratorState()'));
      expect(smoke, contains('gateway.createQrLoginChallenge()'));
      expect(smoke, contains('moduleConfigurationComplete'));
      expect(smoke, contains('enabledModules.isNotEmpty'));
      expect(smoke, contains('NativeModuleRuntimeStatus.disabled'));
      expect(smoke, isNot(contains('SecureSocket.connect')));
      expect(smoke, isNot(contains('restartModule(')));
      expect(smoke, isNot(contains('initializeAdministrator(')));
      expect(smoke, contains('secondInstallationId != firstInstallationId'));
      expect(smoke, isNot(contains('secondCount <= firstCount')));
    },
  );

  test('macOS package uses the Voyant Nitro production entry', () {
    final materialize = source('scripts/business-runtime/materialize.sh');
    final nativeTour = source('host/src/runtime/tour.rs');
    final voyantVite = source(
      'upstream/voyant/templates/operator/vite.config.ts',
    );
    final voyantNitro = source(
      'upstream/voyant/templates/operator/nitro.config.ts',
    );
    final voyantBuilder = source(
      'upstream/voyant/templates/operator/scripts/build-tuyu.mjs',
    );
    final businessBuilder = source('scripts/business-runtime/build_macos.sh');
    expect(materialize, contains('voyant/operator/.output/server/index.mjs'));
    expect(materialize, contains('rsync -a --delete'));
    expect(materialize, isNot(contains('ditto "\$source" "\$destination"')));
    expect(nativeTour, contains('voyant/operator/.output/server/index.mjs'));
    expect(materialize, isNot(contains('voyant/dist/server/index.js')));
    expect(voyantVite, contains('TUYU_VOYANT_OUTPUT_DIR'));
    expect(voyantVite, contains('output: { dir: tuyuOutputDir }'));
    expect(voyantNitro, contains('TUYU_BOOKING_RUNTIME'));
    expect(
      voyantNitro,
      contains('output: { dir: path.resolve(configuredOutput!) }'),
    );
    expect(voyantBuilder, contains('"build", "--preset=node-server"'));
    expect(voyantBuilder, contains('"--builder=vite"'));
    expect(voyantBuilder, contains('path.join(outputDir, "migration")'));
    expect(
      voyantBuilder,
      contains('path.join(outputDir, "server", "index.mjs")'),
    );
    expect(voyantBuilder, contains('fs.rm(sourceOutputDir'));
    expect(voyantBuilder, isNot(contains('outDir: ".output')));
    expect(
      businessBuilder,
      contains('VOYANT_OUTPUT="\$TUYU_VOYANT_OUTPUT_DIR"'),
    );
    expect(businessBuilder, contains('preparePnpmDependencyEnvironment'));
    expect(businessBuilder, contains(r'"$VOYANT_PNPM" install --frozen-lockfile'));
    expect(businessBuilder, contains('VOYANT_BUILD_SOURCE'));
    expect(businessBuilder, contains(r'--store-dir "$VOYANT_PNPM_STORE"'));
    expect(businessBuilder, isNot(contains('clean_voyant_source_residue')));
    expect(
      businessBuilder,
      isNot(contains('upstream/voyant/node_modules/.bin')),
    );
    expect(
      businessBuilder,
      isNot(contains('ROOT/upstream/voyant/templates/operator/.output')),
    );
  });

  test('release uses Hardened Runtime without an App Sandbox', () {
    final entitlements = source('app/macos/Runner/Release.entitlements');
    final debugEntitlements = source(
      'app/macos/Runner/DebugProfile.entitlements',
    );
    final runtimeLock = source('scripts/business-runtime/runtime.lock.json');
    final relocator = source('scripts/business-runtime/relocate_macos.sh');
    expect(entitlements, isNot(contains('com.apple.security.app-sandbox')));
    expect(entitlements, isNot(contains('com.apple.security.network.server')));
    expect(entitlements, isNot(contains('keychain-access-groups')));
    expect(debugEntitlements, isNot(contains('keychain-access-groups')));
    expect(
      entitlements,
      isNot(contains('com.apple.security.cs.disable-library-validation')),
    );
    final verifier = source('scripts/macos/verify_bundle.sh');
    expect(
      verifier,
      contains('App Sandbox is incompatible with embedded PostgreSQL'),
    );
    expect(
      verifier,
      contains('must not request a shared Keychain access group'),
    );
    final runtimeConfiguration = source(
      'app/lib/host/infrastructure/runtime/runtime_controller.dart',
    );
    expect(runtimeConfiguration, isNot(contains('FlutterSecureStorage')));
    expect(
      File(
        '${repository.path}/app/lib/host/authentication/session_store.dart',
      ).existsSync(),
      isFalse,
      reason: 'Administrator login sessions remain only in Native memory',
    );
    expect(
      File(
        '${repository.path}/app/lib/host/authentication/device_tuyu_signer.dart',
      ).existsSync(),
      isFalse,
    );
    final nativeProcess = source('host/src/runtime/process.rs');
    expect(nativeProcess, contains('command.process_group(0)'));
    expect(nativeProcess, contains('terminate_child_tree'));
    expect(nativeProcess, contains('libc::kill(process_group, libc::SIGTERM)'));
    expect(nativeProcess, contains('libc::kill(process_group, libc::SIGKILL)'));
    expect(nativeProcess, contains('BUSINESS_SHUTDOWN_TIMEOUT'));
    final packagedSmoke = source(
      'app/lib/host/infrastructure/runtime/packaged_smoke.dart',
    );
    expect(packagedSmoke, contains('_assertCleanCore'));
    expect(
      packagedSmoke,
      contains(
        'A clean first installation started a business subsystem before selection.',
      ),
    );
    expect(packagedSmoke, isNot(contains('state.error')));
    expect(packagedSmoke, isNot(contains(r'modules=[$details]')));
    final bundleSmoke = source('scripts/macos/smoke_bundle.py');
    expect(bundleSmoke, contains('prefix="tuyubooking cold start-"'));
    final frappeRuntime = source(
      'scripts/business-runtime/tuyu_frappe_runtime.py',
    );
    expect(frappeRuntime, contains('str(path.resolve())'));
    final hiEventsRuntime = source(
      'scripts/business-runtime/tuyu_hi_events_runtime.py',
    );
    expect(hiEventsRuntime, contains('access_log "'));
    expect(hiEventsRuntime, contains('error_log "'));
    expect(runtimeLock, contains('"network_install_allowed": false'));
    expect(
      relocator,
      contains(
        'case "\$binary" in *.dylib) install_name_tool -id '
        '"@loader_path/\$(basename "\$binary")"',
      ),
    );
    expect(relocator, contains('@loader_path/*|@rpath/*'));
    expect(relocator, contains('SOURCE_ROOT'));
    expect(relocator, contains('HOST_PYTHON="\$(command -v python3)"'));
    expect(relocator, contains('otool -D "\$binary"'));
    expect(relocator, contains('module-qualified @rpath LC_ID_DYLIB'));
    expect(relocator, contains("awk '/^[[:space:]]/{print \$1}'"));
    expect(relocator, isNot(contains('tail -n +2')));
    expect(
      relocator,
      contains('unrelocated dependency: \$binary -> \$dependency'),
    );
  });

  test('release embeds an isolated PostgreSQL-only Python runtime', () {
    final builder = source('scripts/business-runtime/build_macos.sh');
    final nativeProcess = source('host/src/runtime/process.rs');
    expect(
      builder,
      contains('https://www.python.org/ftp/python/3.14.3/Python-3.14.3.tgz'),
    );
    expect(builder, contains('--prefix="\$DESTINATION/python"'));
    expect(builder, contains('ac_cv_func_dup3=no'));
    expect(builder, contains('ac_cv_func_pipe2=no'));
    expect(builder, isNot(contains('ensure_formula python@3.14')));
    expect(builder, contains('MariaDB-only Frappe dependencies'));
    expect(builder, contains('PIP_CACHE_DIR="\$DEPENDENCY_WORK_DIR/package-managers/pip"'));
    expect(builder, isNot(contains('--no-cache-dir')));
    expect(builder, contains('unset PIP_NO_CACHE_DIR UV_NO_CACHE'));
    expect(builder, contains(r'PIP_CACHE_DIR="$TASK_WORK/cache/package-managers/pip"'));
    expect(builder, contains(r'UV_CACHE_DIR="$TASK_WORK/cache/package-managers/uv"'));
    expect(builder, contains(r'--cache-dir "$PIP_CACHE_DIR" "$BENCH/apps/frappe"'));
    expect(builder, isNot(contains('preparePythonDependencyEnvironment')));
    expect(builder, isNot(contains('PYTHON_CONSTRAINTS')));
    expect(nativeProcess, contains('.env("PYTHONHOME", &python_home)'));
    expect(nativeProcess, contains('.env("PYTHONNOUSERSITE", "1")'));
  });

  test('macOS package declares its real native runtime minimum', () {
    final builder = source('scripts/business-runtime/build_macos.sh');
    final postgresBuilder = source('scripts/macos/build_runtime.sh');
    final project = source('app/macos/Runner.pbxproj');
    final podfile = source('app/macos/Podfile');
    expect(builder, contains('MACOSX_DEPLOYMENT_TARGET=26.0'));
    expect(
      postgresBuilder,
      contains(
        'https://ftp.postgresql.org/pub/source/v\${POSTGRES_VERSION}/'
        'postgresql-\${POSTGRES_VERSION}.tar.bz2',
      ),
    );
    expect(
      postgresBuilder,
      contains(
        'dd27f2b3c59e73ed14aa3324901242bf69a032a6347805f274e6260322d42979',
      ),
    );
    expect(postgresBuilder, contains('--prefix="\$DEST"'));
    expect(postgresBuilder, contains('--datadir="\$DEST/share/postgresql"'));
    expect(postgresBuilder, isNot(contains('POSTGRES_SOURCE_PREFIX')));
    expect(podfile, contains("platform :osx, '26.0'"));
    expect(
      podfile,
      contains(
        "configuration.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '26.0'",
      ),
    );
    expect(project, isNot(contains('MACOSX_DEPLOYMENT_TARGET = 12.0')));
    expect('MACOSX_DEPLOYMENT_TARGET = 26.0'.allMatches(project), hasLength(3));
  });
}
