import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  final repository = bookingSource;

  test('LinuxARM scripts contract is present', () {
    const requiredFiles = <String>[
      'app/linux/CMakeLists.txt',
      'app/linux/runner/my_application.cc',
      'scripts/linux-arm/build_runtime.sh',
      'scripts/linux-arm/build_package.sh',
      'scripts/linux-arm/verify_bundle.sh',
      'scripts/linux-arm/postgresql.runtime.lock.json',
      'scripts/business-runtime/materialize.sh',
      'scripts/business-runtime/runtime.lock.json',
      'scripts/business-runtime/tuyu_runtime_common.py',
      'scripts/business-runtime/tuyu_frappe_runtime.py',
      'scripts/business-runtime/tuyu_voyant_runtime.py',
    ];
    for (final relativePath in requiredFiles) {
      expect(
        File('${repository.path}/$relativePath').existsSync(),
        isTrue,
        reason: '$relativePath must be part of the LinuxARM contract',
      );
    }
  });

  test('LinuxAMD scripts contract is present', () {
    const requiredFiles = <String>[
      'app/linux/CMakeLists.txt',
      'app/linux/runner/my_application.cc',
      'scripts/linux-amd/build_runtime.sh',
      'scripts/linux-amd/build_package.sh',
      'scripts/linux-amd/verify_bundle.sh',
      'scripts/linux-amd/postgresql.runtime.lock.json',
      'scripts/business-runtime/materialize.sh',
      'scripts/business-runtime/runtime.lock.json',
    ];
    for (final relativePath in requiredFiles) {
      expect(
        File('${repository.path}/$relativePath').existsSync(),
        isTrue,
        reason: '$relativePath must be part of the LinuxAMD contract',
      );
    }
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
