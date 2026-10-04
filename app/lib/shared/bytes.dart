import 'dart:typed_data';

String bytesToHex(List<int> bytes) =>
    '0x${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';

void clearBytes(List<int> bytes) {
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = 0;
  }
}

Uint8List concatBytes(Iterable<List<int>> values) =>
    Uint8List.fromList(values.expand((value) => value).toList(growable: false));

Uint8List uint64LittleEndian(int value) {
  final result = Uint8List(8);
  ByteData.sublistView(result).setUint64(0, value, Endian.little);
  return result;
}

Uint8List scaleString(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  return concatBytes([scaleCompact(bytes.length), bytes]);
}

/// Encodes a non-negative length with the canonical SCALE Compact prefix.
Uint8List scaleCompact(int value) {
  if (value < 0 || value >= 1 << 30) {
    throw ArgumentError.value(
      value,
      'value',
      'SCALE compact value is out of range',
    );
  }
  if (value < 1 << 6) return Uint8List.fromList([value << 2]);
  if (value < 1 << 14) {
    final encoded = (value << 2) | 0x01;
    return Uint8List.fromList([encoded & 0xff, encoded >> 8]);
  }
  final encoded = (value << 2) | 0x02;
  final output = Uint8List(4);
  ByteData.sublistView(output).setUint32(0, encoded, Endian.little);
  return output;
}
