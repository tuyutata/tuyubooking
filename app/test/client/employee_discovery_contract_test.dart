import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  final repository = bookingSource;

  String source(String relative) =>
      File('${repository.path}/$relative').readAsStringSync();

  test('DNS-SD is limited to first client initialization', () {
    final host = source('scripts/business-runtime/tuyu_https_proxy.py');
    final employee = source(
      'app/lib/client/host_connection/mdns_discovery.dart',
    );
    expect(host, contains('_tuyubooking._tcp.local'));
    expect(employee, contains('_tuyubooking._tcp.local'));
    expect(host, contains('protocol=TUYU/1'));
    expect(employee, contains("text['protocol'] != 'TUYU/1'"));
    expect(employee, contains('Runs once while a client initializes'));
  });

  test('initial connection has no QR or Tuyu identity dependency', () {
    final employee = source(
      'app/lib/client/host_connection/mdns_discovery.dart',
    );
    expect(employee, isNot(contains('QrCode')));
    expect(employee, isNot(contains('TuyuServe')));
    expect(employee, isNot(contains('sr25519')));
  });
}
