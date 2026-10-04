import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

Iterable<File> _dartFiles(String path) => bookingAppDirectory(path)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

void main() {
  test('client source cannot own host runtime dependencies', () {
    final sources = <File>[
      bookingAppFile('lib/main_client.dart'),
      ..._dartFiles('lib/client'),
    ];
    const forbidden = <String>[
      'package:tuyubooking/host/',
      'RuntimeController',
      'FfiNativeGateway',
      'DesktopRuntimeConfiguration',
      'postgresql',
      'libtuyubooking_native',
      'business-runtime',
    ];

    for (final file in sources) {
      final source = file.readAsStringSync();
      for (final token in forbidden) {
        expect(
          source,
          isNot(contains(token)),
          reason: '${file.path} must not contain host token $token',
        );
      }
    }
  });

  test('host remains the sole owner of local runtime startup', () {
    final host = bookingAppFile('lib/host/host_app.dart').readAsStringSync();
    final client = bookingAppFile('lib/client/client_app.dart').readAsStringSync();

    expect(host, contains('widget.dependencies.runtime.start()'));
    expect(host, contains('widget.dependencies.runtime.stop()'));
    expect(client, isNot(contains('.runtime.start()')));
    expect(client, isNot(contains('.runtime.stop()')));
  });

  test('client path ends in fixed-host upstream employee authentication', () {
    final initialization = bookingAppFile('lib/client/client_initialization_page.dart').readAsStringSync();
    final connection = bookingAppFile('lib/client/host_connection/employee_discovery_controller.dart').readAsStringSync();
    final modules = bookingAppFile('lib/client/employee_access/employee_module_page.dart').readAsStringSync();
    final login = bookingAppFile('lib/client/employee_access/employee_login_page.dart').readAsStringSync();

    expect(initialization, contains('EmployeeDiscoveryPage'));
    expect(connection, contains('client.reconnect(fixedHost)'));
    // 约束首次连接的持久化顺序，不依赖用于暂存连接结果的局部变量名。
    // 保存失败不发布 profile 的运行行为由 client_lan_connection_test 覆盖。
    final save = RegExp(r'await\s+store\.save\([^;]+\);').firstMatch(connection);
    expect(save, isNotNull, reason: 'First connection must persist the verified host');
    final initialConnection = connection.substring(
      connection.indexOf('client.verify(hosts.single)'),
    );
    final initialSave = RegExp(r'await\s+store\.save\([^;]+\);').firstMatch(initialConnection);
    final publication = RegExp(r'profile\s*=\s*[^;]+;').firstMatch(initialConnection);
    expect(initialSave, isNotNull);
    expect(publication, isNotNull);
    expect(initialSave!.end, lessThan(publication!.start),
      reason: 'Publish the host only after persistence completes');
    expect(modules, contains('EmployeeLoginPage'));
    expect(login, contains('_adapter.signIn('));
  });
}
