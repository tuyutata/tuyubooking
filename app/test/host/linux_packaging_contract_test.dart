import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  final repository = bookingSource;

  test('LinuxARM Workflow contract is present', () {
    const requiredFiles = <String>[
      'app/linux/CMakeLists.txt',
      'app/linux/runner/my_application.cc',
      '.github/workflows/hostlinuxarm.yml',
      'host/database/postgresql-linux-arm.lock.json',
      'scripts/build.mjs',
      'modules/runtime.lock.json',
      'modules/tuyu_runtime_common.py',
      'modules/tuyu_frappe_runtime.py',
      'modules/tuyu_voyant_runtime.py',
    ];
    for (final relativePath in requiredFiles) {
      expect(
        File('${repository.path}/$relativePath').existsSync(),
        isTrue,
        reason: '$relativePath must be part of the LinuxARM contract',
      );
    }
    // 真实Workflow必须调用本仓同平台完整入口，不能以空文件或另一平台代替。
    final workflow = bookingWorkflow('host-linux-arm');
    expect(workflow['permissions'], {'contents': 'read'});
    final job = (workflow['jobs'] as Map)['build'] as Map;
    final step = (job['steps'] as List).last as Map;
    expect(
      step['run'],
      'node scripts/build.mjs execute host-linux-arm --work "\$GITHUB_WORKSPACE/target/build/host-linux-arm"',
    );
    final declaration = jsonDecode(
      File('${repository.path}/host/database/postgresql-linux-arm.lock.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(declaration['architecture'], 'linux-arm');
  });

  test('LinuxAMD Workflow contract is present', () {
    const requiredFiles = <String>[
      'app/linux/CMakeLists.txt',
      'app/linux/runner/my_application.cc',
      '.github/workflows/hostlinuxamd.yml',
      'host/database/postgresql-linux-amd.lock.json',
      'scripts/build.mjs',
      'modules/runtime.lock.json',
    ];
    for (final relativePath in requiredFiles) {
      expect(
        File('${repository.path}/$relativePath').existsSync(),
        isTrue,
        reason: '$relativePath must be part of the LinuxAMD contract',
      );
    }
    // 真实Workflow必须调用本仓同平台完整入口，不能以空文件或另一平台代替。
    final workflow = bookingWorkflow('host-linux-amd');
    expect(workflow['permissions'], {'contents': 'read'});
    final job = (workflow['jobs'] as Map)['build'] as Map;
    final step = (job['steps'] as List).last as Map;
    expect(
      step['run'],
      'node scripts/build.mjs execute host-linux-amd --work "\$GITHUB_WORKSPACE/target/build/host-linux-amd"',
    );
    final declaration = jsonDecode(
      File('${repository.path}/host/database/postgresql-linux-amd.lock.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(declaration['architecture'], 'linux-amd');
  });

  test('Linux loads the native library from its own application bundle', () {
    final bridge = File(
      '${repository.path}/app/lib/host/infrastructure/native_bridge/native_bridge.dart',
    ).readAsStringSync();
    expect(bridge, contains('/lib/libtuyubooking_native.so'));
    expect(
      File(
        '${repository.path}/app/lib/host/authentication/device_tuyu_signer.dart',
      ).existsSync(),
      isFalse,
      reason: 'TuyuBooking must never contain a desktop private-key signer',
    );
  });
}
