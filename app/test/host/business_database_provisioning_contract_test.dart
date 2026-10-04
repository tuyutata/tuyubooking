import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

String _source(String path) {
  final root = bookingSource;
  return File('${root.path}/$path').readAsStringSync();
}

void main() {
  test('Frappe provisions its role and Schema before bootstrap', () {
    final source = _source('scripts/business-runtime/tuyu_frappe_runtime.py');

    expect(source, contains('CREATE ROLE \\"{role}\\" LOGIN'));
    expect(source, contains('CREATE SCHEMA'));
    expect(source, contains('--db-password'));
    expect(source, contains('--db-socket'));
    expect(source, contains('--no-setup-db'));
    expect(source, isNot(contains('--no-mariadb-socket')));
    final provisionCall = source.lastIndexOf('provision_database(');
    final bootstrapCommand = source.indexOf('"new-site"', provisionCall);
    expect(provisionCall, greaterThanOrEqualTo(0));
    expect(bootstrapCommand, greaterThan(provisionCall));
  });

  test('Hi.Events creates role and Schema before its extension', () {
    final source = _source(
      'scripts/business-runtime/tuyu_hi_events_runtime.py',
    );

    final role = source.indexOf('CREATE ROLE');
    final schema = source.indexOf('CREATE SCHEMA');
    final extension = source.indexOf('CREATE EXTENSION');
    expect(role, greaterThanOrEqualTo(0));
    expect(schema, greaterThan(role));
    expect(extension, greaterThan(schema));
  });

  test('macOS scripts rejects every non-system absolute dependency', () {
    final relocator = _source('scripts/business-runtime/relocate_macos.sh');
    final verifier = _source('scripts/macos/verify_bundle.sh');

    expect(relocator, contains('canonical_path'));
    expect(relocator, contains('/System/Library/*|/usr/lib/*'));
    expect(relocator, contains('unrelocated absolute dependency'));
    expect(
      verifier,
      contains('release bundle contains an external dependency'),
    );
  });

  test(
    'packaged upstream runtimes keep build-only dependencies out of startup',
    () {
      final frappe = _source(
        'upstream/frappe/frappe/database/postgres/database.py',
      );
      final hiEvents = _source('upstream/hi_events/frontend/server.js');

      expect(frappe, contains('"host": self.socket or self.host'));
      expect(frappe, contains('if self.port:'));
      expect(
        hiEvents,
        isNot(contains('import {createServer as viteServer} from "vite"')),
      );
      expect(hiEvents, contains('await import("vite")'));
    },
  );
}
