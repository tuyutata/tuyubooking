import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_paths.dart';

void main() {
  final desktop = bookingAppSource;

  test('first status request pins the presented certificate before login', () {
    final source = File(
      '${desktop.path}/lib/shared/network/pinned_https_client.dart',
    ).readAsStringSync();
    expect(source, contains('sha256.convert(certificate.der)'));
    expect(source, contains("path: '/tuyu/status'"));
    expect(source, contains('expectedFingerprint'));
    expect(source, isNot(contains('password')));
    expect(source, isNot(contains('private_key')));
  });
}
