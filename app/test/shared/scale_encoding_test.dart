import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/shared/bytes.dart';

void main() {
  test('uses canonical SCALE Compact length modes', () {
    expect(scaleCompact(63), [0xfc]);
    expect(scaleCompact(64), [0x01, 0x01]);
    expect(scaleCompact(66), [0x09, 0x01]);
    expect(scaleCompact(16384), [0x02, 0x00, 0x01, 0x00]);
  });

  test('encodes a 0x-prefixed sr25519 public key string', () {
    final encoded = scaleString('0x${'11' * 32}');
    expect(encoded.take(2), [0x09, 0x01]);
    expect(encoded.length, 68);
  });
}
