import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  test('Frappe Tuyu backend prefers the private PostgreSQL socket', () {
    final source = bookingSourceFile('upstream/frappe/frappe/utils/tuyu_postgres_backend.py').readAsStringSync();

    expect(
      source,
      contains('frappe.conf.get("db_socket") or frappe.conf.get("db_host")'),
    );
  });
}
