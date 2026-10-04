import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/host/infrastructure/runtime/postgres_socket.dart';

void main() {
  test('PostgreSQL Unix socket path stays below the macOS limit', () {
    final directory = postgresSocketDirectory(processId: 123456);

    if (Platform.isWindows) {
      expect(directory, isNull);
      return;
    }

    expect(directory, '/tmp/tuyubooking-pg-123456');
    expect(
      '$directory/.s.PGSQL.65535'.length,
      lessThanOrEqualTo(postgresUnixSocketPathLimit),
    );
  });
}
