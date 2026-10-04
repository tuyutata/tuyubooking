import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  test('packaged smoke covers the real first-run migration window', () {
    final source = bookingSourceFile('scripts/macos/smoke_bundle.py').readAsStringSync();

    expect(source, contains('PACKAGED_SMOKE_TIMEOUT_SECONDS = 900'));
    expect(source, contains('except subprocess.TimeoutExpired as error'));
  });
}
