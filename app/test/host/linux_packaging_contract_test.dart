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
    // 保留真实平台门槛：空Workflow不得作为已实现Linux流程通过。
    final workflow = File(
      '${repository.path}/.github/workflows/hostlinuxarm.yml',
    ).readAsStringSync();
    expect(workflow.trim(), isNotEmpty);
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
    // 保留真实平台门槛：空Workflow不得作为已实现Linux流程通过。
    final workflow = File(
      '${repository.path}/.github/workflows/hostlinuxamd.yml',
    ).readAsStringSync();
    expect(workflow.trim(), isNotEmpty);
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
