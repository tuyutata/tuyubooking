import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  final repository = bookingSource;

  test(
    'Windows x86-64 package keeps Native and camera plugins in one bundle',
    () {
      final cmake = File(
        '${repository.path}/app/windows/CMakeLists.txt',
      ).readAsStringSync();
      final runner = File(
        '${repository.path}/app/windows/runner/CMakeLists.txt',
      ).readAsStringSync();
      expect(cmake, contains('include(flutter/generated_plugins.cmake)'));
      expect(cmake, contains('PLUGIN_BUNDLED_LIBRARIES'));
      expect(cmake, contains('MEDIA_FOUNDATION'));
      expect(runner, contains('TUYU_CAMERA_BACKEND_MEDIA_FOUNDATION'));
    },
  );
}
