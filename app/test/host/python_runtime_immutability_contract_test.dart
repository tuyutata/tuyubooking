import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  test('packaged Python never writes bytecode into the signed app', () {
    final source = bookingSourceFile('host/src/runtime/process.rs').readAsStringSync();

    expect(source, contains('.env("PYTHONDONTWRITEBYTECODE", "1")'));
  });
}
