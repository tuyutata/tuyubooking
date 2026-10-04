import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';
import 'package:tuyubooking/shared/application_target.dart';

Iterable<File> dartFiles(String path) => bookingAppDirectory(path)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

void main() {
  test('host and client use explicit independent entrypoints', () {
    final host = bookingAppFile('lib/main_host.dart').readAsStringSync();
    final client = bookingAppFile('lib/main_client.dart').readAsStringSync();

    expect(host, contains('host/host_app.dart'));
    expect(host, contains('TuyuBookingHostApp'));
    expect(
      host,
      contains('TuyuBookingApplicationTarget.host.requireSupportedPlatform()'),
    );
    expect(host, isNot(contains('TuyuBookingClientApp')));
    expect(host, isNot(contains('Platform.isIOS || Platform.isAndroid')));

    expect(client, contains('client/client_app.dart'));
    expect(client, contains('TuyuBookingClientApp'));
    expect(
      client,
      contains(
        'TuyuBookingApplicationTarget.client.requireSupportedPlatform()',
      ),
    );
    expect(client, isNot(contains('TuyuBookingHostApp')));
    expect(bookingAppFile('lib/main.dart').existsSync(), isFalse);
  });

  test('host and client platform matrices cannot overlap incorrectly', () {
    const host = TuyuBookingApplicationTarget.host;
    const client = TuyuBookingApplicationTarget.client;

    expect(host.supports(TargetPlatform.macOS), isTrue);
    expect(host.supports(TargetPlatform.windows), isTrue);
    expect(host.supports(TargetPlatform.linux), isTrue);
    expect(host.supports(TargetPlatform.iOS), isFalse);
    expect(host.supports(TargetPlatform.android), isFalse);

    expect(client.supports(TargetPlatform.iOS), isTrue);
    expect(client.supports(TargetPlatform.android), isTrue);
    expect(client.supports(TargetPlatform.macOS), isTrue);
    expect(client.supports(TargetPlatform.windows), isTrue);
    expect(client.supports(TargetPlatform.linux), isFalse);
  });

  test('host and client source boundaries do not cross', () {
    expect(bookingAppDirectory('lib/desktop').existsSync(), isFalse);
    expect(bookingAppDirectory('lib/mobile').existsSync(), isFalse);
    expect(bookingAppDirectory('lib/terminal').existsSync(), isFalse);

    for (final file in dartFiles('lib/host')) {
      expect(
        file.readAsStringSync(),
        isNot(contains('package:tuyubooking/client/')),
        reason: '${file.path} must not import client implementation',
      );
    }
    for (final file in dartFiles('lib/client')) {
      expect(
        file.readAsStringSync(),
        isNot(contains('package:tuyubooking/host/')),
        reason: '${file.path} must not import host implementation',
      );
    }
  });
}
