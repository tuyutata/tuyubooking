import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  final repository = bookingSource;

  String source(String relative) =>
      File('${repository.path}/$relative').readAsStringSync();

  test('employee gateway is administrator controlled and HTTPS only', () {
    final native = source('host/src/ffi/mod.rs');
    final proxy = source('scripts/business-runtime/tuyu_https_proxy.py');
    expect(native, contains('tuyubooking_enable_employee_gateway'));
    expect(native, contains('create_administrator_assertion'));
    expect(proxy, contains('ssl.PROTOCOL_TLS_SERVER'));
    expect(proxy, contains('default="127.0.0.1"'));
    expect(proxy, isNot(contains('HTTPServer(("0.0.0.0"')));
  });

  test('employee connection uses its fixed LAN host instead of QR', () {
    final page = source(
      'app/lib/host/infrastructure/lan_service/employee_access_page.dart',
    );
    final model = source(
      'app/lib/host/infrastructure/native_bridge/native_models.dart',
    );
    expect(page, contains('employeeAccessDiscoveryHint'));
    expect(model, isNot(contains('TUYUBOOKING_EMPLOYEE_GATEWAY')));
    expect(model, isNot(contains("'private_key'")));
  });

  test('one gateway exposes four stable module paths', () {
    final lock = source('scripts/business-runtime/runtime.lock.json');
    for (final route in ['/hotel', '/restaurant', '/tour', '/ticket']) {
      expect(lock, contains('"$route"'));
    }
  });
}
